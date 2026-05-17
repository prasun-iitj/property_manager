import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_paths.dart';

class PropertyCollectionStats {
  final int todayCollection;
  final int monthCollection;
  final int totalOutstanding;
  final int paymentCountThisMonth;

  const PropertyCollectionStats({
    required this.todayCollection,
    required this.monthCollection,
    required this.totalOutstanding,
    required this.paymentCountThisMonth,
  });
}

/// Installment totals for one calendar month (ledger cash flow).
class LedgerMonthBucket {
  final int lendingIn;
  final int borrowingOut;
  final int lendingInterest;
  final int lendingPrincipal;
  final int borrowingInterest;
  final int borrowingPrincipal;

  const LedgerMonthBucket({
    this.lendingIn = 0,
    this.borrowingOut = 0,
    this.lendingInterest = 0,
    this.lendingPrincipal = 0,
    this.borrowingInterest = 0,
    this.borrowingPrincipal = 0,
  });

  LedgerMonthBucket addInstallment({
    required bool isLending,
    required int amount,
    required int interestPaid,
    required int principalPaid,
  }) {
    if (isLending) {
      return LedgerMonthBucket(
        lendingIn: lendingIn + amount,
        borrowingOut: borrowingOut,
        lendingInterest: lendingInterest + interestPaid,
        lendingPrincipal: lendingPrincipal + principalPaid,
        borrowingInterest: borrowingInterest,
        borrowingPrincipal: borrowingPrincipal,
      );
    }
    return LedgerMonthBucket(
      lendingIn: lendingIn,
      borrowingOut: borrowingOut + amount,
      lendingInterest: lendingInterest,
      lendingPrincipal: lendingPrincipal,
      borrowingInterest: borrowingInterest + interestPaid,
      borrowingPrincipal: borrowingPrincipal + principalPaid,
    );
  }

  int get netInflow => lendingIn - borrowingOut;
}

class LedgerOverviewStats {
  final int totalLentPrincipal;
  final int totalBorrowedPrincipal;
  final int totalLendingRemaining;
  final int totalBorrowingRemaining;
  final int interestEarned;
  final int interestPaid;
  final int overpaidLoansCount;

  const LedgerOverviewStats({
    required this.totalLentPrincipal,
    required this.totalBorrowedPrincipal,
    required this.totalLendingRemaining,
    required this.totalBorrowingRemaining,
    required this.interestEarned,
    required this.interestPaid,
    required this.overpaidLoansCount,
  });

  int get netPosition => totalLentPrincipal - totalBorrowedPrincipal;
  int get interestNet => interestEarned - interestPaid;
}

class DashboardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<PropertyCollectionStats> loadPropertyStats() async {
    final now = DateTime.now();
    var todayTotal = 0;
    var monthTotal = 0;
    var monthPayments = 0;
    var outstanding = 0;

    final paymentsSnap = await _db.collectionGroup(FirestorePaths.payments).get();

    for (final doc in paymentsSnap.docs) {
      final data = doc.data();
      final amount = _asInt(data['amount']);
      final ts = data['date'];
      if (ts is! Timestamp) continue;
      final date = ts.toDate();

      if (date.year == now.year && date.month == now.month) {
        monthTotal += amount;
        monthPayments++;
      }
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        todayTotal += amount;
      }
    }

    final sitesSnap = await _db.collection(FirestorePaths.sites).get();
    for (final site in sitesSnap.docs) {
      final plotsSnap = await site.reference.collection(FirestorePaths.plots).get();
      for (final plot in plotsSnap.docs) {
        final customer = await plot.reference
            .collection(FirestorePaths.customer)
            .doc(FirestorePaths.customerDetailsId)
            .get();
        if (!customer.exists) continue;
        outstanding += _asInt(customer.data()?['remaining']);
      }
    }

    return PropertyCollectionStats(
      todayCollection: todayTotal,
      monthCollection: monthTotal,
      totalOutstanding: outstanding,
      paymentCountThisMonth: monthPayments,
    );
  }

  /// Monthly lending collections vs borrowing payments for [year] (1–12 keys).
  Future<Map<int, LedgerMonthBucket>> loadLedgerMonthlyBreakdown(int year) async {
    final buckets = <int, LedgerMonthBucket>{
      for (var m = 1; m <= 12; m++) m: const LedgerMonthBucket(),
    };

    Future<void> scanCollection(String type, bool isLending) async {
      final snap = await _ledgerCollection(type).get();
      for (final loan in snap.docs) {
        final inst = await loan.reference.collection(FirestorePaths.installments).get();
        for (final doc in inst.docs) {
          final data = doc.data();
          final ts = data['date'];
          if (ts is! Timestamp) continue;
          final date = ts.toDate();
          if (date.year != year) continue;

          final amount = _asInt(data['amount']);
          final interest = _asInt(data['interestPaid']);
          final principal = _asInt(data['principalPaid']);
          final month = date.month;
          buckets[month] = buckets[month]!.addInstallment(
            isLending: isLending,
            amount: amount,
            interestPaid: interest,
            principalPaid: principal,
          );
        }
      }
    }

    await scanCollection(FirestorePaths.lending, true);
    await scanCollection(FirestorePaths.borrowing, false);
    return buckets;
  }

  Future<LedgerOverviewStats> loadLedgerOverview() async {
    var lent = 0;
    var borrowed = 0;
    var lendingRemaining = 0;
    var borrowingRemaining = 0;
    var earned = 0;
    var paid = 0;
    var overpaidCount = 0;

    final lendingSnap = await _ledgerCollection(FirestorePaths.lending).get();
    for (final loan in lendingSnap.docs) {
      final data = loan.data();
      lent += _asInt(data['principal']);
      final rem = _asInt(data['remainingPrincipal']);
      lendingRemaining += rem;
      if (rem < 0) overpaidCount++;

      final inst = await loan.reference.collection(FirestorePaths.installments).get();
      for (final i in inst.docs) {
        earned += _asInt(i.data()['interestPaid']);
      }
    }

    final borrowSnap = await _ledgerCollection(FirestorePaths.borrowing).get();
    for (final loan in borrowSnap.docs) {
      final data = loan.data();
      borrowed += _asInt(data['principal']);
      final rem = _asInt(data['remainingPrincipal']);
      borrowingRemaining += rem;
      if (rem < 0) overpaidCount++;

      final inst = await loan.reference.collection(FirestorePaths.installments).get();
      for (final i in inst.docs) {
        paid += _asInt(i.data()['interestPaid']);
      }
    }

    return LedgerOverviewStats(
      totalLentPrincipal: lent,
      totalBorrowedPrincipal: borrowed,
      totalLendingRemaining: lendingRemaining,
      totalBorrowingRemaining: borrowingRemaining,
      interestEarned: earned,
      interestPaid: paid,
      overpaidLoansCount: overpaidCount,
    );
  }

  CollectionReference<Map<String, dynamic>> _ledgerCollection(String type) {
    return _db
        .collection(FirestorePaths.ledgerRoot)
        .doc(FirestorePaths.ledgerDataDoc)
        .collection(type);
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_paths.dart';
import '../utils/ledger_calculator.dart';
import 'app_cache.dart';

class LedgerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> loanRef({
    required String ledgerType,
    required String loanId,
  }) {
    return _firestore
        .collection(FirestorePaths.ledgerRoot)
        .doc(FirestorePaths.ledgerDataDoc)
        .collection(ledgerType)
        .doc(loanId);
  }

  /// Recomputes interest/principal split for every installment (by date)
  /// and updates remaining principal on the loan.
  Future<LedgerReplayResult> recalculateLoan({
    required String ledgerType,
    required String loanId,
  }) async {
    final ref = loanRef(ledgerType: ledgerType, loanId: loanId);
    final loanDoc = await ref.get();

    if (!loanDoc.exists) {
      throw StateError('Loan not found');
    }

    final loanData = loanDoc.data()!;
    final originalPrincipal = _asInt(loanData['principal']);
    final monthlyRate = _asInt(loanData['interestRate']);

    final installmentsSnap =
        await ref.collection(FirestorePaths.installments).orderBy('date').get();

    final payments = installmentsSnap.docs.map((doc) {
      final data = doc.data();
      final ts = data['date'];
      final date = ts is Timestamp ? ts.toDate() : DateTime.now();
      return LedgerPaymentInput(date: date, amount: _asInt(data['amount']));
    }).toList();

    final replay = LedgerCalculator.replay(
      originalPrincipal: originalPrincipal,
      monthlyRatePercent: monthlyRate,
      payments: payments,
    );

    WriteBatch batch = _firestore.batch();
    var writes = 0;

    Future<void> commitIfNeeded({bool force = false}) async {
      if (writes >= 450 || (force && writes > 0)) {
        await batch.commit();
        batch = _firestore.batch();
        writes = 0;
      }
    }

    for (var i = 0; i < installmentsSnap.docs.length; i++) {
      final doc = installmentsSnap.docs[i];
      final split = replay.splits[i];

      batch.update(doc.reference, {
        'interestPaid': split.interestPaid,
        'principalPaid': split.principalPaid,
        'principalApplied': split.principalApplied,
        'overpayment': split.overpayment,
        'interestDue': split.interestDue,
        'remainingBefore': split.remainingBefore,
        'remainingAfter': split.remainingAfter,
      });
      writes++;
      await commitIfNeeded();
    }

    batch.update(ref, {
      'remainingPrincipal': replay.remainingPrincipal,
      'overpaidAmount': replay.overpaidAmount,
      'isOverpaid': replay.isOverpaid,
      'totalPaid': replay.totalPaid,
      'totalInterestPaid': replay.totalInterestPaid,
      'totalPrincipalPaid': replay.totalPrincipalPaid,
    });
    writes++;
    await commitIfNeeded(force: true);

    AppCache.instance.invalidateLedger();
    return replay;
  }

  Future<LedgerReplayResult> addInstallment({
    required String ledgerType,
    required String loanId,
    required int amount,
    required DateTime date,
    required String note,
  }) async {
    final ref = loanRef(ledgerType: ledgerType, loanId: loanId);

    await ref.collection(FirestorePaths.installments).add({
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return recalculateLoan(ledgerType: ledgerType, loanId: loanId);
  }

  Future<void> deleteInstallment({
    required String ledgerType,
    required String loanId,
    required String installmentId,
  }) async {
    final ref = loanRef(ledgerType: ledgerType, loanId: loanId);
    await ref.collection(FirestorePaths.installments).doc(installmentId).delete();
    await recalculateLoan(ledgerType: ledgerType, loanId: loanId);
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

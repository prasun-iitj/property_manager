import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_paths.dart';

class PropertyMonthBucket {
  final int collected;
  final int paymentCount;

  const PropertyMonthBucket({this.collected = 0, this.paymentCount = 0});
}

class PropertyGlobalStats {
  final int siteCount;
  final int totalPlots;
  final int occupiedPlots;
  final int vacantPlots;
  final int totalOutstanding;
  final int monthCollection;
  final int todayCollection;
  final int emiDueCount;

  const PropertyGlobalStats({
    this.siteCount = 0,
    this.totalPlots = 0,
    this.occupiedPlots = 0,
    this.vacantPlots = 0,
    this.totalOutstanding = 0,
    this.monthCollection = 0,
    this.todayCollection = 0,
    this.emiDueCount = 0,
  });

  double get occupancyRate =>
      totalPlots > 0 ? occupiedPlots / totalPlots : 0;
}

class SiteSummary {
  final String siteId;
  final String name;
  final String location;
  final int plotCount;
  final int occupied;
  final int outstanding;
  final int monthCollection;

  const SiteSummary({
    required this.siteId,
    required this.name,
    required this.location,
    this.plotCount = 0,
    this.occupied = 0,
    this.outstanding = 0,
    this.monthCollection = 0,
  });
}

class PlotSummary {
  final String plotId;
  final String plotNumber;
  final int totalPrice;
  final bool hasCustomer;
  final String customerName;
  final int remaining;
  final int totalPaid;
  final bool emiDue;

  const PlotSummary({
    required this.plotId,
    required this.plotNumber,
    required this.totalPrice,
    required this.hasCustomer,
    this.customerName = '',
    this.remaining = 0,
    this.totalPaid = 0,
    this.emiDue = false,
  });
}

class InsightsComparison {
  final PropertyGlobalStats property;
  final int ledgerNetPosition;
  final int ledgerInterestNet;
  final int totalCashInPropertyMonth;
  final int totalCashInLedgerMonth;

  const InsightsComparison({
    required this.property,
    required this.ledgerNetPosition,
    required this.ledgerInterestNet,
    required this.totalCashInPropertyMonth,
    required this.totalCashInLedgerMonth,
  });
}

class PropertyAnalyticsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<PropertyGlobalStats> loadGlobalStats() async {
    final now = DateTime.now();
    var sites = 0;
    var plots = 0;
    var occupied = 0;
    var outstanding = 0;
    var emiDue = 0;

    final sitesSnap = await _db.collection(FirestorePaths.sites).get();
    sites = sitesSnap.docs.length;

    for (final site in sitesSnap.docs) {
      final plotsSnap =
          await site.reference.collection(FirestorePaths.plots).get();
      for (final plot in plotsSnap.docs) {
        plots++;
        final customer = await plot.reference
            .collection(FirestorePaths.customer)
            .doc(FirestorePaths.customerDetailsId)
            .get();
        if (!customer.exists) continue;
        occupied++;
        final data = customer.data() ?? {};
        outstanding += _asInt(data['remaining']);
        final nextEmi = data['nextEmiDate'];
        if (nextEmi is Timestamp && nextEmi.toDate().isBefore(now)) {
          emiDue++;
        }
      }
    }

    var today = 0;
    var month = 0;
    final paySnap =
        await _db.collectionGroup(FirestorePaths.payments).get();
    for (final doc in paySnap.docs) {
      final ts = doc.data()['date'];
      if (ts is! Timestamp) continue;
      final d = ts.toDate();
      final amount = _asInt(doc.data()['amount']);
      if (d.year == now.year && d.month == now.month) month += amount;
      if (d.year == now.year && d.month == now.month && d.day == now.day) {
        today += amount;
      }
    }

    return PropertyGlobalStats(
      siteCount: sites,
      totalPlots: plots,
      occupiedPlots: occupied,
      vacantPlots: plots - occupied,
      totalOutstanding: outstanding,
      monthCollection: month,
      todayCollection: today,
      emiDueCount: emiDue,
    );
  }

  Future<List<SiteSummary>> loadSiteSummaries() async {
    final now = DateTime.now();
    final sitesSnap = await _db.collection(FirestorePaths.sites).get();
    final summaries = <SiteSummary>[];

    for (final site in sitesSnap.docs) {
      final data = site.data();
      var plotCount = 0;
      var occupied = 0;
      var outstanding = 0;
      var monthCol = 0;

      final plotsSnap =
          await site.reference.collection(FirestorePaths.plots).get();
      for (final plot in plotsSnap.docs) {
        plotCount++;
        final customerRef = plot.reference
            .collection(FirestorePaths.customer)
            .doc(FirestorePaths.customerDetailsId);
        final customer = await customerRef.get();
        if (customer.exists) {
          occupied++;
          outstanding += _asInt(customer.data()?['remaining']);
        }

        final payments = await customerRef.collection(FirestorePaths.payments).get();
        for (final p in payments.docs) {
          final ts = p.data()['date'];
          if (ts is! Timestamp) continue;
          final d = ts.toDate();
          if (d.year == now.year && d.month == now.month) {
            monthCol += _asInt(p.data()['amount']);
          }
        }
      }

      summaries.add(SiteSummary(
        siteId: site.id,
        name: (data['name'] ?? 'Site').toString(),
        location: (data['location'] ?? '').toString(),
        plotCount: plotCount,
        occupied: occupied,
        outstanding: outstanding,
        monthCollection: monthCol,
      ));
    }

    summaries.sort((a, b) => b.outstanding.compareTo(a.outstanding));
    return summaries;
  }

  Future<List<PlotSummary>> loadPlotSummaries(String siteId) async {
    final now = DateTime.now();
    final plotsSnap = await _db
        .collection(FirestorePaths.sites)
        .doc(siteId)
        .collection(FirestorePaths.plots)
        .get();

    final list = <PlotSummary>[];
    for (final plot in plotsSnap.docs) {
      final data = plot.data();
      final plotNumber = (data['plotNumber'] ?? plot.id).toString();
      final totalPrice = _asInt(data['totalPrice']);

      final customer = await plot.reference
          .collection(FirestorePaths.customer)
          .doc(FirestorePaths.customerDetailsId)
          .get();

      if (!customer.exists) {
        list.add(PlotSummary(
          plotId: plot.id,
          plotNumber: plotNumber,
          totalPrice: totalPrice,
          hasCustomer: false,
        ));
        continue;
      }

      final c = customer.data() ?? {};
      final nextEmi = c['nextEmiDate'];
      var emiDue = false;
      if (nextEmi is Timestamp) {
        emiDue = nextEmi.toDate().isBefore(now);
      }

      list.add(PlotSummary(
        plotId: plot.id,
        plotNumber: plotNumber,
        totalPrice: totalPrice,
        hasCustomer: true,
        customerName: (c['name'] ?? '').toString(),
        remaining: _asInt(c['remaining']),
        totalPaid: _asInt(c['totalPaid']),
        emiDue: emiDue,
      ));
    }

    list.sort((a, b) => a.plotNumber.compareTo(b.plotNumber));
    return list;
  }

  Future<Map<int, PropertyMonthBucket>> loadPropertyMonthlyBreakdown(
    int year,
  ) async {
    final buckets = <int, PropertyMonthBucket>{
      for (var m = 1; m <= 12; m++) m: const PropertyMonthBucket(),
    };

    final snap = await _db.collectionGroup(FirestorePaths.payments).get();
    for (final doc in snap.docs) {
      final data = doc.data();
      final ts = data['date'];
      if (ts is! Timestamp) continue;
      final d = ts.toDate();
      if (d.year != year) continue;
      final m = d.month;
      final prev = buckets[m]!;
      buckets[m] = PropertyMonthBucket(
        collected: prev.collected + _asInt(data['amount']),
        paymentCount: prev.paymentCount + 1,
      );
    }
    return buckets;
  }

  Future<Map<int, PropertyMonthBucket>> loadPlotPaymentMonthly({
    required String siteId,
    required String plotId,
    required int year,
  }) async {
    final buckets = <int, PropertyMonthBucket>{
      for (var m = 1; m <= 12; m++) m: const PropertyMonthBucket(),
    };

    final snap = await _db
        .collection(FirestorePaths.sites)
        .doc(siteId)
        .collection(FirestorePaths.plots)
        .doc(plotId)
        .collection(FirestorePaths.customer)
        .doc(FirestorePaths.customerDetailsId)
        .collection(FirestorePaths.payments)
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final ts = data['date'];
      if (ts is! Timestamp) continue;
      final d = ts.toDate();
      if (d.year != year) continue;
      final m = d.month;
      final prev = buckets[m]!;
      buckets[m] = PropertyMonthBucket(
        collected: prev.collected + _asInt(data['amount']),
        paymentCount: prev.paymentCount + 1,
      );
    }
    return buckets;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

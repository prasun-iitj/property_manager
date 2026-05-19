import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/plot_model.dart';
import 'app_cache.dart';

class PlotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Case-insensitive, trimmed comparison (e.g. "1" and " 1 " are duplicates).
  static String normalizePlotNumber(String plotNumber) =>
      plotNumber.trim().toLowerCase();

  /// Returns true if another plot in this site already uses [plotNumber].
  Future<bool> isPlotNumberTaken({
    required String siteId,
    required String plotNumber,
    String? excludePlotId,
  }) async {
    final normalized = normalizePlotNumber(plotNumber);
    if (normalized.isEmpty) return false;

    final snap = await _firestore
        .collection('sites')
        .doc(siteId)
        .collection('plots')
        .get();

    for (final doc in snap.docs) {
      if (excludePlotId != null && doc.id == excludePlotId) continue;
      final existing =
          normalizePlotNumber((doc.data()['plotNumber'] ?? '').toString());
      if (existing == normalized) return true;
    }
    return false;
  }

  Future<void> addPlot({
    required String siteId,
    required PlotModel plot,
  }) async {
    if (await isPlotNumberTaken(siteId: siteId, plotNumber: plot.plotNumber)) {
      throw StateError(
        'Plot "${plot.plotNumber}" already exists in this site. '
        'Use a different plot number.',
      );
    }

    await _firestore
        .collection('sites')
        .doc(siteId)
        .collection('plots')
        .add(plot.toMap());
    AppCache.instance.invalidatePlotSite(siteId);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamPlots(String siteId) {
    return _firestore
        .collection('sites')
        .doc(siteId)
        .collection('plots')
        .snapshots();
  }
}

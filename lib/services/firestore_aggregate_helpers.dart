import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_paths.dart';

/// Shared Firestore reads for dashboard / analytics (handles rule edge cases).
class FirestoreAggregateHelpers {
  FirestoreAggregateHelpers._();

  /// Uses collection group when allowed; otherwise walks sites → plots → payments.
  static Future<void> forEachPayment(
    FirebaseFirestore db,
    void Function(Map<String, dynamic> data) onPayment,
  ) async {
    try {
      final snap = await db.collectionGroup(FirestorePaths.payments).get();
      for (final doc in snap.docs) {
        onPayment(doc.data());
      }
      return;
    } catch (_) {
      // Fall through when collection-group rules are missing or query fails.
    }

    final sitesSnap = await db.collection(FirestorePaths.sites).get();
    for (final site in sitesSnap.docs) {
      final plotsSnap =
          await site.reference.collection(FirestorePaths.plots).get();
      for (final plot in plotsSnap.docs) {
        final paySnap = await plot.reference
            .collection(FirestorePaths.customer)
            .doc(FirestorePaths.customerDetailsId)
            .collection(FirestorePaths.payments)
            .get();
        for (final doc in paySnap.docs) {
          onPayment(doc.data());
        }
      }
    }
  }

  static Future<void> forEachLedgerLoan(
    FirebaseFirestore db,
    String type,
    Future<void> Function(
      QueryDocumentSnapshot<Map<String, dynamic>> loan,
    ) onLoan,
  ) async {
    for (final containerId in FirestorePaths.ledgerContainerDocIds) {
      final snap = await db
          .collection(FirestorePaths.ledgerRoot)
          .doc(containerId)
          .collection(type)
          .get();
      for (final loan in snap.docs) {
        await onLoan(loan);
      }
    }
  }
}

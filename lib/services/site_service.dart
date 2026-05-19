import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/site_model.dart';
import 'app_cache.dart';

class SiteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> streamSites() {
    return _firestore.collection('sites').snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getSite(String siteId) {
    return _firestore.collection('sites').doc(siteId).get();
  }

  Future<void> saveSite({
    required SiteModel site,
    String? siteId,
    required bool isEdit,
  }) async {
    if (isEdit && siteId != null) {
      await _firestore
          .collection('sites')
          .doc(siteId)
          .set(site.toMap(), SetOptions(merge: true));
      AppCache.instance.invalidateProperty();
      return;
    }

    await _firestore
        .collection('sites')
        .add(site.toMap(includeCreatedAt: true));
    AppCache.instance.invalidateProperty();
  }

  Future<void> deleteSiteCascade(String siteId) async {
    final plotsSnapshot = await _firestore
        .collection('sites')
        .doc(siteId)
        .collection('plots')
        .get();

    for (final plotDoc in plotsSnapshot.docs) {
      final customerRef = _firestore
          .collection('sites')
          .doc(siteId)
          .collection('plots')
          .doc(plotDoc.id)
          .collection('customer')
          .doc('details');

      await _deleteCustomerSubcollections(customerRef);

      await customerRef.delete();

      await plotDoc.reference.delete();
    }

    await _firestore.collection('sites').doc(siteId).delete();
    AppCache.instance.invalidateProperty();
  }

  Future<void> _deleteCustomerSubcollections(
    DocumentReference<Map<String, dynamic>> customerRef,
  ) async {
    final paymentsSnapshot = await customerRef.collection('payments').get();
    final documentsSnapshot = await customerRef.collection('documents').get();
    final storageUrls = documentsSnapshot.docs
        .map((doc) => doc.data()['fileUrl']?.toString())
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toList();

    WriteBatch batch = _firestore.batch();
    var writeCount = 0;

    Future<void> deleteDoc(DocumentReference reference) async {
      batch.delete(reference);
      writeCount++;

      if (writeCount == 450) {
        await batch.commit();
        batch = _firestore.batch();
        writeCount = 0;
      }
    }

    for (final payment in paymentsSnapshot.docs) {
      await deleteDoc(payment.reference);
    }

    for (final document in documentsSnapshot.docs) {
      await deleteDoc(document.reference);
    }

    if (writeCount > 0) {
      await batch.commit();
    }

    for (final url in storageUrls) {
      await _deleteStorageFile(url);
    }
  }

  Future<void> _deleteStorageFile(String fileUrl) async {
    try {
      await _storage.refFromURL(fileUrl).delete();
    } catch (_) {
      // Missing files should not prevent Firestore cleanup.
    }
  }
}

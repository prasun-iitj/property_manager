import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/customer_model.dart';
import 'app_cache.dart';

class PaymentSaveResult {
  final String phone;
  final int totalPaid;
  final int remaining;

  const PaymentSaveResult({
    required this.phone,
    required this.totalPaid,
    required this.remaining,
  });
}

class CustomerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> _customerDetailsRef({
    required String siteId,
    required String plotId,
  }) {
    return _firestore
        .collection('sites')
        .doc(siteId)
        .collection('plots')
        .doc(plotId)
        .collection('customer')
        .doc('details');
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getCustomerDetails({
    required String siteId,
    required String plotId,
  }) {
    return _customerDetailsRef(siteId: siteId, plotId: plotId).get();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamCustomerDetails({
    required String siteId,
    required String plotId,
  }) {
    return _customerDetailsRef(siteId: siteId, plotId: plotId).snapshots();
  }

  void _invalidatePropertyCaches(String siteId) {
    AppCache.instance.invalidatePlotSite(siteId);
  }

  Future<void> saveCustomer({
    required String siteId,
    required String plotId,
    required CustomerModel customer,
  }) async {
    await _customerDetailsRef(siteId: siteId, plotId: plotId).set(
      customer.toMap(),
      SetOptions(merge: true),
    );
    _invalidatePropertyCaches(siteId);
  }

  Future<void> deleteCustomer({
    required String siteId,
    required String plotId,
  }) async {
    final customerRef = _customerDetailsRef(siteId: siteId, plotId: plotId);
    await _deleteCustomerSubcollections(customerRef);
    await customerRef.delete();
    _invalidatePropertyCaches(siteId);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamPayments({
    required String siteId,
    required String plotId,
  }) {
    return _customerDetailsRef(siteId: siteId, plotId: plotId)
        .collection('payments')
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> deletePayment({
    required String siteId,
    required String plotId,
    required String paymentId,
  }) async {
    final customerRef = _customerDetailsRef(siteId: siteId, plotId: plotId);
    final paymentRef = customerRef.collection('payments').doc(paymentId);

    await _firestore.runTransaction((transaction) async {
      final customerSnapshot = await transaction.get(customerRef);
      final paymentSnapshot = await transaction.get(paymentRef);

      if (!paymentSnapshot.exists) return;

      final customerData = customerSnapshot.data() ?? {};
      final paymentData = paymentSnapshot.data() ?? {};
      final amount = _asInt(paymentData['amount']);
      final totalPrice = _asInt(customerData['totalPrice']);
      final currentTotalPaid = _asInt(customerData['totalPaid']);
      final paidAfterDelete = currentTotalPaid - amount;
      final newTotalPaid = paidAfterDelete < 0 ? 0 : paidAfterDelete;
      final remaining = totalPrice - newTotalPaid;

      transaction.delete(paymentRef);

      if (customerSnapshot.exists) {
        transaction.update(customerRef, {
          'totalPaid': newTotalPaid,
          'remaining': remaining,
        });
      }
    });
    _invalidatePropertyCaches(siteId);
  }

  Future<PaymentSaveResult> addPayment({
    required String siteId,
    required String plotId,
    required int amount,
    required DateTime selectedDate,
    required String mode,
  }) async {
    final customerRef = _customerDetailsRef(siteId: siteId, plotId: plotId);
    final paymentRef = customerRef.collection('payments').doc();

    return _firestore.runTransaction((transaction) async {
      final customerDoc = await transaction.get(customerRef);

      if (!customerDoc.exists) {
        throw StateError('Customer details not found');
      }

      final data = customerDoc.data() ?? {};
      final totalPaid = _asInt(data['totalPaid']);
      final totalPrice = _asInt(data['totalPrice']);
      final emiDay = _asInt(data['emiDay']) == 0 ? 5 : _asInt(data['emiDay']);
      final newTotalPaid = totalPaid + amount;
      // Allow overpayment — remaining may go negative (customer paid extra).
      final remaining = totalPrice - newTotalPaid;

      transaction.set(paymentRef, {
        'amount': amount,
        'date': Timestamp.fromDate(selectedDate),
        'mode': mode,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.update(customerRef, {
        'totalPaid': newTotalPaid,
        'remaining': remaining,
        'nextEmiDate': Timestamp.fromDate(
          _nextEmiDate(selectedDate: selectedDate, emiDay: emiDay),
        ),
      });

      return PaymentSaveResult(
        phone: data['phone']?.toString() ?? '',
        totalPaid: newTotalPaid,
        remaining: remaining,
      );
    }).whenComplete(() => _invalidatePropertyCaches(siteId));
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

  DateTime _nextEmiDate({
    required DateTime selectedDate,
    required int emiDay,
  }) {
    if (selectedDate.day >= emiDay) {
      return DateTime(selectedDate.year, selectedDate.month + 1, emiDay);
    }

    return DateTime(selectedDate.year, selectedDate.month, emiDay);
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

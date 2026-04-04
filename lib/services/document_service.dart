import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/document_model.dart';

class DocumentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// ==============================
  /// 📤 UPLOAD (MOBILE)
  /// ==============================
  Future<String> uploadDocumentFile({
    required File file,
    required String customerId,
    required String fileName,
  }) async {
    final ref =
        _storage.ref().child('customers/$customerId/$fileName');

    await ref.putFile(file);

    return await ref.getDownloadURL();
  }

  /// ==============================
  /// 🌐 UPLOAD (WEB)
  /// ==============================
  Future<String> uploadDocumentBytes({
    required Uint8List bytes,
    required String customerId,
    required String fileName,
  }) async {
    final ref =
        _storage.ref().child('customers/$customerId/$fileName');

    await ref.putData(bytes);

    return await ref.getDownloadURL();
  }

  /// ==============================
  /// 🚀 UPLOAD WITH PROGRESS (NEW)
  /// ==============================
  Stream<double> uploadDocumentWithProgress({
    required Uint8List bytes,
    required String customerId,
    required String fileName,
  }) async* {
    final ref =
        _storage.ref().child('customers/$customerId/$fileName');

    final uploadTask = ref.putData(bytes);

    await for (final snapshot in uploadTask.snapshotEvents) {
      final progress =
          snapshot.bytesTransferred / snapshot.totalBytes;
      yield progress; // 0.0 → 1.0
    }
  }

  /// ==============================
  /// 📎 GET DOWNLOAD URL (NEW HELPER)
  /// ==============================
  Future<String> getDownloadUrl({
    required String customerId,
    required String fileName,
  }) async {
    final ref =
        _storage.ref().child('customers/$customerId/$fileName');

    return await ref.getDownloadURL();
  }

  /// ==============================
  /// ➕ SAVE DOCUMENT DATA
  /// ==============================
  Future<void> addDocument(
      String customerId, DocumentModel document) async {
    await _firestore
        .collection('customers')
        .doc(customerId)
        .collection('documents')
        .add(document.toMap());
  }

  /// ==============================
  /// 📥 GET DOCUMENTS (REAL-TIME)
  /// ==============================
  Stream<List<DocumentModel>> getDocuments(String customerId) {
    return _firestore
        .collection('customers')
        .doc(customerId)
        .collection('documents')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                DocumentModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// ==============================
  /// ✏️ RENAME DOCUMENT
  /// ==============================
  Future<void> updateDocumentName(
      String customerId, String docId, String newName) async {
    await _firestore
        .collection('customers')
        .doc(customerId)
        .collection('documents')
        .doc(docId)
        .update({'name': newName});
  }

  /// ==============================
  /// ❌ DELETE DOCUMENT
  /// ==============================
  Future<void> deleteDocument(
      String customerId, String docId) async {
    await _firestore
        .collection('customers')
        .doc(customerId)
        .collection('documents')
        .doc(docId)
        .delete();
  }
}
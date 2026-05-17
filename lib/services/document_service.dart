import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/document_model.dart';
import '../firebase_options.dart';
import '../utils/storage_bytes_fetcher.dart';
import '../utils/storage_path_parser.dart';

class DocumentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _v2DocumentsCollection({
    required String siteId,
    required String plotId,
  }) {
    return _firestore
        .collection('sites')
        .doc(siteId)
        .collection('plots')
        .doc(plotId)
        .collection('customer')
        .doc('details')
        .collection('documents');
  }

  CollectionReference<Map<String, dynamic>> _legacyDocumentsCollection(
    String legacyCustomerId,
  ) {
    return _firestore
        .collection('customers')
        .doc(legacyCustomerId)
        .collection('documents');
  }

  /// ==============================
  /// 📤 UPLOAD (MOBILE)
  /// ==============================
  Future<String> uploadDocumentFile({
    required File file,
    required String customerId,
    required String fileName,
  }) async {
    final ref = _storage.ref().child('customers/$customerId/$fileName');

    await ref.putFile(
      file,
      SettableMetadata(contentType: _contentTypeFor(fileName)),
    );

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
    final ref = _storage.ref().child('customers/$customerId/$fileName');

    await ref.putData(
      bytes,
      SettableMetadata(contentType: _contentTypeFor(fileName)),
    );

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
    final ref = _storage.ref().child('customers/$customerId/$fileName');

    final uploadTask = ref.putData(
      bytes,
      SettableMetadata(contentType: _contentTypeFor(fileName)),
    );

    await for (final snapshot in uploadTask.snapshotEvents) {
      final progress = snapshot.bytesTransferred / snapshot.totalBytes;
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
    final ref = _storage.ref().child('customers/$customerId/$fileName');

    return await ref.getDownloadURL();
  }

  /// ==============================
  /// ➕ SAVE DOCUMENT DATA
  /// ==============================
  Future<String?> addDocument({
    required String siteId,
    required String plotId,
    required DocumentModel document,
  }) async {
    final ref = await _v2DocumentsCollection(siteId: siteId, plotId: plotId)
        .add(document.toMap());
    return ref.id;
  }

  /// ==============================
  /// 📥 GET DOCUMENTS (REAL-TIME)
  /// ==============================
  Stream<List<DocumentModel>> getDocuments({
    required String siteId,
    required String plotId,
    required String legacyCustomerId,
  }) async* {
    await for (final snapshot in _v2DocumentsCollection(
      siteId: siteId,
      plotId: plotId,
    ).orderBy('uploadedAt', descending: true).snapshots()) {
      final primaryDocs = snapshot.docs
          .map((doc) => DocumentModel.fromMap(doc.id, doc.data()))
          .toList();

      if (primaryDocs.isNotEmpty) {
        yield primaryDocs;
        continue;
      }

      final legacySnapshot = await _legacyDocumentsCollection(
        legacyCustomerId,
      ).orderBy('uploadedAt', descending: true).get();

      final legacyDocs = legacySnapshot.docs
          .map(
            (doc) => DocumentModel.fromMap(
              doc.id,
              doc.data(),
              isLegacy: true,
            ),
          )
          .toList();

      yield legacyDocs;
    }
  }

  /// ==============================
  /// ✏️ RENAME DOCUMENT
  /// ==============================
  Future<void> updateDocumentName({
    required String siteId,
    required String plotId,
    required String legacyCustomerId,
    required String docId,
    required String newName,
    required bool isLegacy,
  }) async {
    if (isLegacy) {
      await _legacyDocumentsCollection(legacyCustomerId)
          .doc(docId)
          .update({'name': newName});
      return;
    }

    await _v2DocumentsCollection(siteId: siteId, plotId: plotId)
        .doc(docId)
        .update({'name': newName});
  }

  /// ==============================
  /// ❌ DELETE DOCUMENT
  /// ==============================
  Future<void> deleteDocument({
    required String siteId,
    required String plotId,
    required String legacyCustomerId,
    required String docId,
    required bool isLegacy,
  }) async {
    if (isLegacy) {
      final docRef = _legacyDocumentsCollection(legacyCustomerId).doc(docId);
      final snapshot = await docRef.get();
      await docRef.delete();
      await _deleteStorageFile(snapshot.data()?['fileUrl']?.toString());
      return;
    }

    final docRef =
        _v2DocumentsCollection(siteId: siteId, plotId: plotId).doc(docId);
    final snapshot = await docRef.get();
    await docRef.delete();
    await _deleteStorageFile(snapshot.data()?['fileUrl']?.toString());
  }

  Future<void> _deleteStorageFile(String? fileUrl) async {
    if (fileUrl == null || fileUrl.isEmpty) return;

    try {
      await _storage.refFromURL(fileUrl).delete();
    } catch (_) {
      // Metadata cleanup should still succeed when the file is already gone.
    }
  }

  static const int _maxDownloadBytes = 50 * 1024 * 1024; // 50 MB

  /// Fetches file bytes via Firebase Storage SDK (authenticated).
  /// On web, requires Storage bucket CORS — see cors.json in project root.
  Future<Uint8List> fetchDocumentBytes({
    String? fileUrl,
    String? customerId,
    String? fileName,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw Exception('Please sign in again to access documents');
    }

    Object? lastError;
    final bucket = _storage.bucket;
    final storageBucket =
        bucket.isNotEmpty ? bucket : (DefaultFirebaseOptions.web.storageBucket ?? '');

    String? objectPath;
    if (customerId != null && fileName != null && fileName.isNotEmpty) {
      objectPath = 'customers/$customerId/$fileName';
    } else if (fileUrl != null && fileUrl.isNotEmpty) {
      objectPath = storagePathFromDownloadUrl(fileUrl);
    }

    // 1) Web: authenticated REST download → blob save (real file download).
    if (kIsWeb && objectPath != null && storageBucket.isNotEmpty) {
      try {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        if (token != null) {
          final data = await fetchStorageBytesWithAuth(
            bucket: storageBucket,
            objectPath: objectPath,
            idToken: token,
          );
          if (data != null && data.isNotEmpty) return data;
        }
      } catch (e) {
        lastError = e;
      }
    }

    // 2) SDK getData by path.
    if (objectPath != null) {
      try {
        final data = await _storage.ref(objectPath).getData(_maxDownloadBytes);
        if (data != null && data.isNotEmpty) return data;
      } catch (e) {
        lastError = e;
      }
    }

    // 3) Legacy path if objectPath was built from customerId.
    if (customerId != null && fileName != null && fileName.isNotEmpty) {
      try {
        final data = await _storage
            .ref()
            .child('customers/$customerId/$fileName')
            .getData(_maxDownloadBytes);
        if (data != null && data.isNotEmpty) return data;
      } catch (e) {
        lastError = e;
      }
    }

    // 3) Dio HTTP only on mobile/desktop (never works on web due to CORS).
    if (!kIsWeb && fileUrl != null && fileUrl.isNotEmpty) {
      try {
        final response = await Dio().get<List<int>>(
          fileUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        final data = response.data;
        if (data != null && data.isNotEmpty) {
          return Uint8List.fromList(data);
        }
      } catch (e) {
        lastError = e;
      }
    }

    if (kIsWeb) {
      throw Exception(
        'Could not load file via Firebase Storage on web. '
        'Apply CORS on your Storage bucket (see cors.json), or use '
        '"Open in browser" / direct download. '
        '${lastError ?? ''}',
      );
    }

    throw Exception('Could not load document: ${lastError ?? 'unknown error'}');
  }

  static bool isPdfFile(String fileName, String fileUrl) {
    final lower = '$fileName $fileUrl'.toLowerCase();
    return lower.contains('.pdf');
  }

  static bool isImageFile(String fileName, String fileUrl) {
    final lower = '$fileName $fileUrl'.toLowerCase();
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png');
  }

  String _contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'application/octet-stream';
  }
}

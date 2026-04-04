import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadAadharWeb({
    required Uint8List fileBytes,
    required String customerId,
    required String fileName,
  }) async {
    try {
      final ref = _storage
          .ref()
          .child('customers')
          .child(customerId)
          .child('aadhar')
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

      UploadTask uploadTask = ref.putData(fileBytes);

      TaskSnapshot snapshot = await uploadTask;

      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print("Upload Error: $e");
      return null;
    }
  }

  /// ✅ FIXED: inside class
  Future<void> deleteFile(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      await ref.delete();
    } catch (e) {
      print("Delete Error: $e");
    }
  }
}
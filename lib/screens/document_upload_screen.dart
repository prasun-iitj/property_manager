import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/document_service.dart';
import '../models/document_model.dart';
import 'document_preview_screen.dart';

class DocumentUploadScreen extends StatefulWidget {
  final String customerId;

  const DocumentUploadScreen({super.key, required this.customerId});

  @override
  State<DocumentUploadScreen> createState() =>
      _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final DocumentService _service = DocumentService();

  String? selectedFileName;

  double uploadProgress = 0;
  bool isUploading = false;

  /// 📥 DOWNLOAD
  Future<void> downloadFile(String url, String name) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = "${dir.path}/$name";

      await Dio().download(url, filePath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Downloaded to $filePath")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Download failed")),
      );
    }
  }

  /// ✏️ RENAME
  Future<void> showRenameDialog(DocumentModel doc) async {
    final controller = TextEditingController(text: doc.name);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Rename Document"),
        content: TextField(controller: controller),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;

              await _service.updateDocumentName(
                  widget.customerId, doc.id, newName);

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Renamed successfully")),
              );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  /// 📤 FILE PICK UPLOAD
  Future<void> pickFile(String type, String displayName) async {
    final result = await FilePicker.platform.pickFiles(withData: true);

    if (result != null && result.files.single.bytes != null) {
      await _uploadBytes(
        bytes: result.files.single.bytes!,
        type: type,
        displayName: displayName,
      );
    }
  }

  /// 📷 CAMERA SCAN
  Future<void> scanDocument(String type, String displayName) async {
    final picker = ImagePicker();

    final XFile? image =
        await picker.pickImage(source: ImageSource.camera);

    if (image == null) return;

    final bytes = await image.readAsBytes();

    await _uploadBytes(
      bytes: bytes,
      type: type,
      displayName: displayName,
    );
  }

  /// 🔥 COMMON UPLOAD HANDLER (BEST PRACTICE)
  Future<void> _uploadBytes({
    required Uint8List bytes,
    required String type,
    required String displayName,
  }) async {
    setState(() {
      isUploading = true;
      uploadProgress = 0;
    });

    final fileName =
        "${type}_${DateTime.now().millisecondsSinceEpoch}";

    String url = '';

    await for (final progress in _service.uploadDocumentWithProgress(
      bytes: bytes,
      customerId: widget.customerId,
      fileName: fileName,
    )) {
      setState(() => uploadProgress = progress);

      if (progress == 1.0) {
        url = await _service.getDownloadUrl(
          customerId: widget.customerId,
          fileName: fileName,
        );
      }
    }

    await _service.addDocument(
      widget.customerId,
      DocumentModel(
        id: '',
        name: displayName,
        type: type,
        fileUrl: url,
        fileName: fileName,
        uploadedAt: DateTime.now(),
      ),
    );

    setState(() => isUploading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$displayName uploaded")),
    );
  }

  Widget buildTile(String title, String type) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Upload
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: () => pickFile(type, title),
            ),

            /// Camera 🔥
            IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.green),
              onPressed: () => scanDocument(type, title),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildUploadedList() {
    return StreamBuilder<List<DocumentModel>>(
      stream: _service.getDocuments(widget.customerId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!;
        if (docs.isEmpty) return const Text("No documents uploaded");

        return Column(
          children: docs.map((doc) {
            final isImage = doc.fileUrl.toLowerCase().endsWith('.jpg') ||
                doc.fileUrl.toLowerCase().endsWith('.png') ||
                doc.fileUrl.toLowerCase().endsWith('.jpeg');

            return Card(
              child: ListTile(
                leading: isImage
                    ? Image.network(doc.fileUrl,
                        width: 50, height: 50, fit: BoxFit.cover)
                    : const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text(doc.name),
                subtitle: Text(doc.type),

                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DocumentPreviewScreen(
                      url: doc.fileUrl,
                      name: doc.name,
                    ),
                  ),
                ),

                onLongPress: () => showRenameDialog(doc),

                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.download, color: Colors.blue),
                      onPressed: () =>
                          downloadFile(doc.fileUrl, doc.fileName),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await _service.deleteDocument(
                            widget.customerId, doc.id);
                      },
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload Documents")),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (isUploading)
            Column(
              children: [
                const Text("Uploading..."),
                LinearProgressIndicator(value: uploadProgress),
                const SizedBox(height: 10),
              ],
            ),

          if (selectedFileName != null)
            Text("Selected: $selectedFileName"),

          buildTile("Aadhar Card", "aadhar"),
          buildTile("PAN Card", "pan"),
          buildTile("Registry", "registry"),
          buildTile("Other Document", "other"),

          const SizedBox(height: 20),
          const Text("Uploaded Documents",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

          const SizedBox(height: 10),
          buildUploadedList(),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/document_service.dart';
import '../models/document_model.dart';
import '../utils/file_saver/file_saver.dart';
import 'document_preview_screen.dart';

class DocumentUploadScreen extends StatefulWidget {
  final String siteId;
  final String plotId;
  final String customerId;

  const DocumentUploadScreen({
    super.key,
    required this.siteId,
    required this.plotId,
    required this.customerId,
  });

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final DocumentService _service = DocumentService();

  String? selectedFileName;

  double uploadProgress = 0;
  bool isUploading = false;

  /// 📥 DOWNLOAD
  Future<void> downloadFile(DocumentModel doc) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Preparing download…'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final downloadName = doc.fileName.isNotEmpty
          ? doc.fileName
          : '${doc.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}.pdf';

      final bytes = await _service.fetchDocumentBytes(
        fileUrl: doc.fileUrl,
        customerId: widget.customerId,
        fileName: doc.fileName,
      );
      final result = await saveFile(bytes, downloadName);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Download failed. Use Open in browser from preview, or apply Storage CORS (cors.json).'
                : 'Download failed: $e',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// ✏️ RENAME
  Future<void> showRenameDialog(DocumentModel doc) async {
    await _promptRenameAfterUpload(
      docId: doc.id,
      currentName: doc.name,
      isLegacy: doc.isLegacy,
    );
  }

  Future<void> _promptRenameAfterUpload({
    required String docId,
    required String currentName,
    required bool isLegacy,
  }) async {
    final controller = TextEditingController(text: currentName);

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Name this document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Give a clear name (e.g. Sale deed, NOC, Bank statement).',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Document name',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => Navigator.pop(context, true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (saved != true || !mounted) return;

      final newName = controller.text.trim();
      if (newName.isEmpty || newName == currentName) return;

      await _service.updateDocumentName(
        siteId: widget.siteId,
        plotId: widget.plotId,
        legacyCustomerId: widget.customerId,
        docId: docId,
        newName: newName,
        isLegacy: isLegacy,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Renamed to "$newName"')),
      );
    } finally {
      controller.dispose();
    }
  }

  /// 📤 FILE PICK UPLOAD
  Future<void> pickFile(String type, String displayName) async {
    final result = await FilePicker.pickFiles(withData: true);

    if (result != null && result.files.single.bytes != null) {
      final name = result.files.single.name;
      await _uploadBytes(
        bytes: result.files.single.bytes!,
        type: type,
        displayName: displayName,
        extension: _extensionFromName(name) ?? 'dat',
      );
    }
  }

  /// 📷 CAMERA SCAN
  Future<void> scanDocument(String type, String displayName) async {
    final picker = ImagePicker();

    try {
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image == null) return; // user cancelled

      final bytes = await image.readAsBytes();
      final ext = _extensionFromName(image.name) ??
          (image.mimeType?.contains('png') == true ? 'png' : 'jpg');

      await _uploadBytes(
        bytes: bytes,
        type: type,
        displayName: displayName,
        extension: ext,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? "Camera blocked or unavailable. Allow camera in the browser, or use Upload file."
                : "Camera not available (${e.toString()}). Use Upload file.",
          ),
          action: kIsWeb
              ? SnackBarAction(
                  label: 'Pick image',
                  onPressed: () => _pickImageFallback(type, displayName),
                )
              : null,
        ),
      );
    }
  }

  Future<void> _pickImageFallback(String type, String displayName) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    final ext = _extensionFromName(image.name) ??
        (image.mimeType?.contains('png') == true ? 'png' : 'jpg');

    await _uploadBytes(
      bytes: bytes,
      type: type,
      displayName: displayName,
      extension: ext,
    );
  }

  String? _extensionFromName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot >= name.length - 1) return null;
    return name.substring(dot + 1).toLowerCase();
  }

  /// 🔥 COMMON UPLOAD HANDLER (BEST PRACTICE)
  Future<void> _uploadBytes({
    required Uint8List bytes,
    required String type,
    required String displayName,
    required String extension,
  }) async {
    setState(() {
      isUploading = true;
      uploadProgress = 0;
    });

    try {
      final fileName =
          "${type}_${DateTime.now().millisecondsSinceEpoch}.$extension";

      String url = '';

      await for (final progress in _service.uploadDocumentWithProgress(
        bytes: bytes,
        customerId: widget.customerId,
        fileName: fileName,
      )) {
        if (!mounted) return;
        setState(() => uploadProgress = progress);

        if (progress == 1.0) {
          url = await _service.getDownloadUrl(
            customerId: widget.customerId,
            fileName: fileName,
          );
        }
      }

      final docRef = await _service.addDocument(
        siteId: widget.siteId,
        plotId: widget.plotId,
        document: DocumentModel(
          id: '',
          name: displayName,
          type: type,
          fileUrl: url,
          fileName: fileName,
          uploadedAt: DateTime.now(),
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$displayName uploaded")),
      );

      if (type == 'other' && docRef != null) {
        await _promptRenameAfterUpload(
          docId: docRef,
          currentName: displayName,
          isLegacy: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Upload failed. Please try again.")),
      );
    } finally {
      if (mounted) {
        setState(() => isUploading = false);
      }
    }
  }

  bool _isImageDocument(DocumentModel doc) {
    bool hasImageExt(String value) {
      final lower = value.toLowerCase();
      return lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png');
    }

    return hasImageExt(doc.fileUrl) || hasImageExt(doc.fileName);
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
              onPressed: isUploading ? null : () => pickFile(type, title),
            ),

            /// Camera 🔥
            IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.green),
              onPressed: isUploading ? null : () => scanDocument(type, title),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildUploadedList() {
    return StreamBuilder<List<DocumentModel>>(
      stream: _service.getDocuments(
        siteId: widget.siteId,
        plotId: widget.plotId,
        legacyCustomerId: widget.customerId,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!;
        if (docs.isEmpty) return const Text("No documents uploaded");

        return Column(
          children: docs.map((doc) {
            final isImage = _isImageDocument(doc);

            return Card(
              child: ListTile(
                leading: isImage
                    ? const Icon(Icons.image, color: Color(0xFF2563EB), size: 36)
                    : const Icon(Icons.picture_as_pdf, color: Colors.red, size: 36),
                title: Text(doc.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${doc.type} · ${doc.fileName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: false,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DocumentPreviewScreen(
                      url: doc.fileUrl,
                      name: doc.name,
                      fileName: doc.fileName,
                      customerId: widget.customerId,
                    ),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Color(0xFF6D28D9)),
                      tooltip: 'Rename',
                      onPressed: () => showRenameDialog(doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download, color: Colors.blue),
                      tooltip: 'Download',
                      onPressed: () => downloadFile(doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete',
                      onPressed: () async {
                        await _service.deleteDocument(
                          siteId: widget.siteId,
                          plotId: widget.plotId,
                          legacyCustomerId: widget.customerId,
                          docId: doc.id,
                          isLegacy: doc.isLegacy,
                        );
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
          if (selectedFileName != null) Text("Selected: $selectedFileName"),
          buildTile("Aadhar Card", "aadhar"),
          buildTile("PAN Card", "pan"),
          buildTile("Registry", "registry"),
          buildTile("Other Document", "other"),
          const SizedBox(height: 8),
          Text(
            kIsWeb
                ? "Camera: allow permission when prompted (HTTPS required). "
                    "If blocked, gallery or Upload file will be offered."
                : "Camera tip: allow app camera permission when prompted. "
                    "If camera does not open, use Upload file.",
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 20),
          const Text("Uploaded Documents",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Tap to preview · purple icon to rename · blue to download',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          buildUploadedList(),
        ],
      ),
    );
  }
}

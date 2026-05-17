import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/document_service.dart';
import '../widgets/storage_url_view.dart';

class DocumentPreviewScreen extends StatefulWidget {
  final String url;
  final String name;
  final String fileName;
  final String? customerId;

  const DocumentPreviewScreen({
    super.key,
    required this.url,
    required this.name,
    required this.fileName,
    this.customerId,
  });

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  final DocumentService _service = DocumentService();

  Uint8List? _bytes;
  bool _loading = true;
  String? _error;
  bool _useWebEmbed = false;
  late final String _webViewType = 'doc-preview-${widget.url.hashCode}';

  bool get _isPdf =>
      DocumentService.isPdfFile(widget.fileName, widget.url);

  bool get _isImage =>
      DocumentService.isImageFile(widget.fileName, widget.url);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _useWebEmbed = false;
      _bytes = null;
    });

    try {
      final bytes = await _service.fetchDocumentBytes(
        fileUrl: widget.url,
        customerId: widget.customerId,
        fileName: widget.fileName,
      );
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // On web, embed Firebase URL in iframe — works without downloading bytes.
      if (kIsWeb && widget.url.isNotEmpty) {
        setState(() {
          _useWebEmbed = true;
          _loading = false;
          _error = null;
        });
        return;
      }
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in browser',
            onPressed: _openInBrowser,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_useWebEmbed) {
      return Column(
        children: [
          MaterialBanner(
            content: const Text(
              'Showing document in browser viewer (web mode). '
              'For in-app preview, apply Storage CORS — see cors.json in project.',
            ),
            actions: [
              TextButton(
                onPressed: _openInBrowser,
                child: const Text('Open in new tab'),
              ),
            ],
          ),
          Expanded(
            child: buildStorageUrlPreview(
              widget.url,
              viewType: _webViewType,
            ),
          ),
        ],
      );
    }

    if (_error != null || _bytes == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
              const SizedBox(height: 16),
              const Text(
                'Could not preview this document',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _openInBrowser,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open in browser'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isPdf) {
      return SfPdfViewer.memory(
        _bytes!,
        canShowScrollHead: true,
        canShowScrollStatus: true,
      );
    }

    if (_isImage) {
      return InteractiveViewer(
        child: Center(
          child: Image.memory(_bytes!, fit: BoxFit.contain),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.insert_drive_file, size: 64),
            const SizedBox(height: 12),
            const Text('Preview not available for this file type'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openInBrowser,
              icon: const Icon(Icons.download),
              label: const Text('Open / download file'),
            ),
          ],
        ),
      ),
    );
  }
}

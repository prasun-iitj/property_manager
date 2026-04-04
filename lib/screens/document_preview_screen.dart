import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class DocumentPreviewScreen extends StatelessWidget {
  final String url;
  final String name;

  const DocumentPreviewScreen({
    super.key,
    required this.url,
    required this.name,
  });

  bool isPdf(String url) {
    return url.toLowerCase().endsWith('.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: isPdf(url)
          ? SfPdfViewer.network(url)
          : InteractiveViewer(
              child: Center(
                child: Image.network(url),
              ),
            ),
    );
  }
}
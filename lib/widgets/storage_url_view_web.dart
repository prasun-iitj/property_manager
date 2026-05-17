import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

Widget buildStorageUrlPreview(String url, {required String viewType}) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int _) {
      final iframe = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'fullscreen';
      return iframe;
    },
  );

  return HtmlElementView(viewType: viewType);
}

/// Cross-origin URLs ignore [download] — opens PDF instead. Prefer blob save.
Future<String> downloadViaBrowserUrl(String url, String fileName) async {
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();

  return 'If file opened instead of downloading, use browser Save (Ctrl+S)';
}


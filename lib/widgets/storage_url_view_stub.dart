import 'package:flutter/material.dart';

/// Non-web: no iframe preview — caller should use in-memory viewer.
Widget buildStorageUrlPreview(String url, {required String viewType}) {
  return const SizedBox.shrink();
}

Future<String> downloadViaBrowserUrl(String url, String fileName) async {
  throw UnsupportedError('Browser URL download is only available on web');
}

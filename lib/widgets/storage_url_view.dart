import 'package:flutter/material.dart';

import 'storage_url_view_stub.dart'
    if (dart.library.html) 'storage_url_view_web.dart' as impl;

Widget buildStorageUrlPreview(String url, {required String viewType}) {
  return impl.buildStorageUrlPreview(url, viewType: viewType);
}

Future<String> downloadViaBrowserUrl(String url, String fileName) {
  return impl.downloadViaBrowserUrl(url, fileName);
}

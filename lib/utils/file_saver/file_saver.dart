import 'dart:typed_data';

import 'file_saver_stub.dart'
    if (dart.library.html) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_io.dart' as impl;

Future<String> saveFile(Uint8List bytes, String fileName) {
  return impl.saveFile(bytes, fileName);
}

import 'dart:typed_data';

import 'storage_bytes_fetcher_stub.dart'
    if (dart.library.html) 'storage_bytes_fetcher_web.dart' as impl;

Future<Uint8List?> fetchStorageBytesWithAuth({
  required String bucket,
  required String objectPath,
  required String idToken,
}) {
  return impl.fetchStorageBytesWithAuth(
    bucket: bucket,
    objectPath: objectPath,
    idToken: idToken,
  );
}

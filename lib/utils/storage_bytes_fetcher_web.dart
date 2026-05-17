import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Downloads a Storage object using Firebase Auth (Bearer token).
/// Works on web when bucket CORS allows your origin (apply cors.json).
Future<Uint8List?> fetchStorageBytesWithAuth({
  required String bucket,
  required String objectPath,
  required String idToken,
}) async {
  final encodedObject = Uri.encodeComponent(objectPath);
  final url =
      'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedObject?alt=media';

  final completer = Completer<Uint8List?>();

  final xhr = html.HttpRequest();
  xhr.responseType = 'arraybuffer';
  xhr.open('GET', url);
  xhr.setRequestHeader('Authorization', 'Bearer $idToken');

  xhr.onLoad.listen((_) {
    if (xhr.status == 200 && xhr.response != null) {
      final buffer = xhr.response as ByteBuffer;
      completer.complete(Uint8List.view(buffer));
    } else {
      completer.completeError(
        'Storage HTTP ${xhr.status}: ${xhr.statusText ?? 'failed'}',
      );
    }
  });

  xhr.onError.listen((_) {
    completer.completeError('Network error loading document from Storage');
  });

  xhr.send();
  return completer.future;
}

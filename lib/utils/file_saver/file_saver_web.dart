import 'dart:html' as html;
import 'dart:typed_data';

String _mimeFor(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  return 'application/octet-stream';
}

Future<String> saveFile(Uint8List bytes, String fileName) async {
  final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final blob = html.Blob([bytes], _mimeFor(safeName));
  final objectUrl = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: objectUrl)
    ..download = safeName
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();

  // Revoke after a short delay so the download can start.
  Future.delayed(const Duration(seconds: 2), () {
    html.Url.revokeObjectUrl(objectUrl);
  });

  return 'Saved as $safeName — check your Downloads folder';
}

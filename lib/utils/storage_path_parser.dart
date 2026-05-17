/// Extracts the object path from a Firebase Storage download URL.
String? storagePathFromDownloadUrl(String url) {
  try {
    final uri = Uri.parse(url);
    final path = uri.path;
    const marker = '/o/';
    final index = path.indexOf(marker);
    if (index >= 0) {
      final encoded = path.substring(index + marker.length);
      return Uri.decodeComponent(encoded);
    }

    final segments = uri.pathSegments;
    final oIdx = segments.indexOf('o');
    if (oIdx >= 0 && oIdx + 1 < segments.length) {
      return Uri.decodeComponent(segments.sublist(oIdx + 1).join('/'));
    }
  } catch (_) {
    // Ignore parse errors.
  }
  return null;
}

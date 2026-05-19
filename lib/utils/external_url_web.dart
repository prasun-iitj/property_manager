// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<bool> openUrlInBrowser(String url) async {
  try {
    final opened = html.window.open(url, '_blank');
    if (opened != null) return true;
  } catch (_) {}

  try {
    html.window.location.href = url;
    return true;
  } catch (_) {
    return false;
  }
}

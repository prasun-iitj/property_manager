import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'external_url_stub.dart'
    if (dart.library.html) 'external_url_web.dart' as impl;

/// Opens [url] in browser / external app. Web uses `window.open` (works on iOS Safari).
Future<bool> openExternalUrl(String url) async {
  if (kIsWeb) {
    return impl.openUrlInBrowser(url);
  }
  final uri = Uri.parse(url);
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return true;
    }
    return launchUrl(uri, mode: LaunchMode.platformDefault);
  } catch (_) {
    return false;
  }
}

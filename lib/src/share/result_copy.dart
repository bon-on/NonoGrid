import 'package:flutter/services.dart';

import 'result_copy_stub.dart'
    if (dart.library.js_interop) 'result_copy_web.dart'
    as web;

/// Copies result text to the clipboard (feature-daily-puzzle). Never
/// throws; tests inject a fake.
class ResultCopier {
  const ResultCopier();

  /// Flutter's clipboard first; on web a hidden textarea +
  /// `execCommand('copy')` fallback for frames that block the async API.
  Future<bool> copyText(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (_) {
      try {
        return web.webCopyFallback(text);
      } catch (_) {
        return false;
      }
    }
  }
}

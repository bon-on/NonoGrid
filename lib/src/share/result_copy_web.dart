import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Copies through a hidden textarea and `execCommand('copy')`, for frames
/// where the async clipboard API is blocked. Catches its own errors.
bool webCopyFallback(String text) {
  try {
    final document = globalContext.getProperty<JSObject?>('document'.toJS);
    final body = document?.getProperty<JSObject?>('body'.toJS);
    if (document == null || body == null) return false;
    final area = document.callMethod<JSObject>(
      'createElement'.toJS,
      'textarea'.toJS,
    );
    area.setProperty('value'.toJS, text.toJS);
    area.callMethod<JSAny?>('setAttribute'.toJS, 'readonly'.toJS, ''.toJS);
    final style = area.getProperty<JSObject>('style'.toJS);
    style.setProperty('position'.toJS, 'fixed'.toJS);
    style.setProperty('left'.toJS, '-9999px'.toJS);
    style.setProperty('opacity'.toJS, '0'.toJS);
    body.callMethod<JSAny?>('appendChild'.toJS, area);
    try {
      area.callMethod<JSAny?>('select'.toJS);
      final ok = document.callMethod<JSAny?>('execCommand'.toJS, 'copy'.toJS);
      return ok.dartify() == true;
    } finally {
      area.callMethod<JSAny?>('remove'.toJS);
    }
  } catch (_) {
    return false;
  }
}

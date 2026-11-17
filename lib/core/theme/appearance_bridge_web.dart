import 'dart:js_interop';

@JS('localStorage.setItem')
external void _setItem(JSString key, JSString value);

void mirrorAppearance(String mode) {
  try {
    _setItem('jotit.appearance'.toJS, mode.toJS);
  } catch (_) {}
}

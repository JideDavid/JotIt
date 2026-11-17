import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('location.hostname')
external String get _hostname;
@JS('FIREBASE_APPCHECK_DEBUG_TOKEN')
external set _debugToken(JSAny value);

/// Firebase's documented debug provider is permitted only in a local debug
/// build. Production web builds require an actual reCAPTCHA provider.
void enableLocalAppCheckDebug() {
  if (!kDebugMode || !['localhost', '127.0.0.1', '[::1]'].contains(_hostname)) {
    throw StateError('App Check debugging requires a local debug build.');
  }
  _debugToken = true.toJS;
}

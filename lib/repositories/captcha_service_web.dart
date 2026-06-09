import 'dart:async';
import 'dart:js_interop';

import '../core/config.dart';

// JS interop bindings for grecaptcha v3
@JS()
extension type _Grecaptcha._(JSObject _) implements JSObject {
  external JSPromise<JSString> execute(String siteKey, _Options options);
}

@JS('grecaptcha')
external _Grecaptcha? get _grecaptcha;

extension type _Options._(JSObject _) implements JSObject {
  external factory _Options({String action});
}

/// Returns a reCAPTCHA v3 token for the given action.
/// Returns null when the site key is not configured or the script is not loaded.
Future<String?> getCaptchaToken(String action) async {
  final siteKey = AppConfig.recaptchaSiteKey;
  if (siteKey.isEmpty) return null;

  try {
    final grecaptcha = _grecaptcha;
    if (grecaptcha == null) return null;

    final jsToken = await grecaptcha
        .execute(siteKey, _Options(action: action))
        .toDart;
    return jsToken.toDart;
  } catch (_) {
    return null;
  }
}

import 'package:flutter/foundation.dart' show kIsWeb;

/// Single source of truth for all app-wide constants and environment values.
///
/// Backend switching:
///   1. For normal work, change `_defaultBackendEnvironment` below.
///   2. For one-off runs, override with:
///      flutter run --dart-define=API_BASE_URL=https://example.ngrok-free.dev
///   3. Or choose a named environment:
///      flutter run --dart-define=BACKEND_ENV=local
class AppConfig {
  const AppConfig._();

  // ── App identity ──────────────────────────────────────────────────────────
  static const String appName = 'CareSkill';
  static const String appVersion = '1.0.0';
  static const String fontFamily = 'Inter';

  // ── Storage ───────────────────────────────────────────────────────────────
  /// Prefix for all session-storage keys, e.g. "careskill.token"
  static const String storagePrefix = 'careskill';

  // ── API ───────────────────────────────────────────────────────────────────
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _envBackendEnvironment = String.fromEnvironment(
    'BACKEND_ENV',
  );
  static const Duration apiTimeout = Duration(seconds: 10);

  /// Change this one value when you want the whole frontend to point somewhere
  /// else without editing screens, repositories, or API calls.
  ///
  /// Available values:
  ///   `ngrok`      -> public tunnel backend
  ///   `local`      -> local desktop/web backend
  ///   `android`    -> Android emulator backend
  ///   `same-host`  -> Flutter Web host with port 8000
  ///   `test`       -> test/staging backend
  ///   `prod`       -> production backend
  static const String _defaultBackendEnvironment = 'local';

  // ── Runtime override (preferred) ─────────────────────────────────────────
  // Pass at launch instead of editing this file:
  //   flutter run --dart-defhttps://streak-pogo-bonded.ngrok-free.devine=API_BASE_URL=https://xxxx.ngrok-free.app
  // The start_dev.sh script does this automatically.

  // ── Fallback URLs per environment ─────────────────────────────────────────
  // ngrokBackendUrl is the ONLY value you may need to change manually when not
  // using start_dev.sh. Replace with the URL printed by `ngrok http 8000`.
  static const String ngrokBackendUrl =
      'https://streak-pogo-bonded.ngrok-free.dev';
  static const String localBackendUrl = 'http://localhost:8000';
  // Android emulator reaches the host machine via 10.0.2.2.
  static const String androidEmulatorBackendUrl = 'http://10.0.2.2:8000';
  static const String testBackendUrl =
      'https://streak-pogo-bonded.ngrok-free.dev';
  static const String productionBackendUrl =
      'https://streak-pogo-bonded.ngrok-free.dev';

  /// Resolved API base URL.
  ///
  /// Priority:
  ///   1. `--dart-define=API_BASE_URL=<url>` for a direct one-off URL
  ///   2. `--dart-define=BACKEND_ENV=<name>` for a named environment
  ///   3. `_defaultBackendEnvironment` from this file
  ///
  /// Android emulator: `--dart-define=API_BASE_URL=http://10.0.2.2:8000`
  /// Physical device:  `--dart-define=API_BASE_URL=http://<machine-ip>:8000`
  static String get apiBaseUrl {
    if (_envBaseUrl.trim().isNotEmpty) return _cleanBaseUrl(_envBaseUrl);

    final environment = _envBackendEnvironment.trim().isNotEmpty
        ? _envBackendEnvironment
        : _defaultBackendEnvironment;

    switch (environment.trim().toLowerCase()) {
      case 'ngrok':
      case 'tunnel':
        return _cleanBaseUrl(ngrokBackendUrl);
      case 'local':
      case 'desktop':
      case 'web-local':
        return _cleanBaseUrl(localBackendUrl);
      case 'android':
      case 'emulator':
        return _cleanBaseUrl(androidEmulatorBackendUrl);
      case 'same-host':
      case 'same_host':
        return _cleanBaseUrl(_sameHostBackendUrl);
      case 'test':
      case 'staging':
        return _cleanBaseUrl(testBackendUrl);
      case 'prod':
      case 'production':
        return _cleanBaseUrl(productionBackendUrl);
      default:
        return _cleanBaseUrl(ngrokBackendUrl);
    }
  }

  static String get _sameHostBackendUrl {
    if (!kIsWeb) return localBackendUrl;
    final host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
    final scheme = Uri.base.scheme.isEmpty ? 'http' : Uri.base.scheme;
    return '$scheme://$host:8000';
  }

  static String _cleanBaseUrl(String value) {
    var url = value.trim();
    if (url.startsWith('=')) url = url.substring(1).trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  // ── Auth0 ─────────────────────────────────────────────────────────────────
  // Set these via --dart-define at build time, or fill in the defaults below
  // after creating your Auth0 application (Applications → Native).
  //   flutter run --dart-define=AUTH0_DOMAIN=dev-xxxx.us.auth0.com \
  //               --dart-define=AUTH0_CLIENT_ID=xxxxxxxxxxxxxxxx
  static const String auth0Domain = String.fromEnvironment(
    'AUTH0_DOMAIN',
    defaultValue: 'dev-qbjxxdq7ztdlaohf.us.auth0.com',
  );
  static const String auth0ClientId = String.fromEnvironment(
    'AUTH0_CLIENT_ID',
    defaultValue: 'SiTtwlLQLL6pusF9Ov0qwpPNNCbQ29lv',
  );

  // Custom URI scheme for Android deep-link callback.
  // Must match manifestPlaceholders["auth0Scheme"] in build.gradle.kts.
  // Callback URL registered in Auth0 Dashboard:
  //   com.careskill.app://{auth0Domain}/android/com.careskill.app/callback
  //   https://android-app/android/com.careskill.app/callback  (HTTPS App Links)
  static const String auth0CallbackScheme = 'com.careskill.app';

  // ── Google reCAPTCHA v3 ───────────────────────────────────────────────────
  // Get your site key from https://www.google.com/recaptcha/admin
  //   flutter run --dart-define=RECAPTCHA_SITE_KEY=6Lc...
  static const String recaptchaSiteKey = String.fromEnvironment(
    'RECAPTCHA_SITE_KEY',
    defaultValue: '',
  );

  // ── WebSocket base URL ────────────────────────────────────────────────────
  /// Converts the HTTP base URL to a WebSocket base URL.
  /// http://... → ws://...   |   https://... → wss://...
  static String get wsBaseUrl {
    final base = apiBaseUrl;
    if (base.startsWith('https://')) return base.replaceFirst('https://', 'wss://');
    return base.replaceFirst('http://', 'ws://');
  }

  // ── Default values ────────────────────────────────────────────────────────
  /// Default hex theme colour used when creating a new event.
  static const String defaultEventColor = '#41A7F5';

  /// Default difficulty sent when importing a quiz file.
  static const String defaultQuizDifficulty = 'medium';

  /// XP awarded for a correct safety-awareness answer (mirrors backend).
  static const int safetyXpReward = 5;
}

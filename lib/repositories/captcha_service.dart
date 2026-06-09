// Conditional export: Dart picks the right file at compile time.
//   dart.library.html  → web browser build  → captcha_service_web.dart
//   dart.library.io    → Android / iOS      → captcha_service_stub.dart
export 'captcha_service_stub.dart'
    if (dart.library.html) 'captcha_service_web.dart';

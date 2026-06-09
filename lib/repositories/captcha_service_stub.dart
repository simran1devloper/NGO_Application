// Mobile / non-web — CAPTCHA not needed; return null so backend skips check.
Future<String?> getCaptchaToken(String action) async => null;

import '../core/config.dart';
import '../models/auth_models.dart';
import 'api_client.dart';
import 'auth0_strategy.dart';

class AuthRepository {
  const AuthRepository._();

  // ── Email / password ──────────────────────────────────────────────────────

  static Future<TokenResponse> login(
    String email,
    String password, {
    String? recaptchaToken,
  }) async {
    final body = <String, dynamic>{'email': email, 'password': password};
    if (recaptchaToken != null) body['recaptcha_token'] = recaptchaToken;
    final json = await ApiClient.post('/auth/login', body) as Map<String, dynamic>;
    return TokenResponse.fromJson(json);
  }

  /// General public registration — sets role=student and access_status=pending_verification.
  /// requested_role is stored server-side for admin review; it does NOT grant access.
  static Future<TokenResponse> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? className,
    String? schoolName,
    String? location,
    int? age,
    String? parentEmail,
    String? requestedRole,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
    };
    void addIfFilled(String key, String? value) {
      if (value != null && value.isNotEmpty) body[key] = value;
    }

    addIfFilled('phone', phone);
    addIfFilled('class_name', className);
    addIfFilled('school_name', schoolName);
    addIfFilled('location', location);
    if (age != null) body['age'] = age;
    addIfFilled('parent_email', parentEmail);
    addIfFilled('requested_role', requestedRole);

    final raw =
        await ApiClient.post('/auth/register', body) as Map<String, dynamic>;
    return TokenResponse.fromJson(raw);
  }

  /// Registers a new user via POST /auth/register.
  /// Role is always forced to 'student' server-side.
  /// requested_role is stored for admin review; it does NOT grant access.
  static Future<TokenResponse> registerStudent({
    required String name,
    required String email,
    required String password,
    required String className,
    required String schoolName,
    required String location,
    int? age,
    String? parentEmail,
    String? phone,
    String? requestedRole,
    String? recaptchaToken,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      'class_name': className,
      'school_name': schoolName,
      'location': location,
    };
    void addIfFilled(String key, String? value) {
      if (value != null && value.isNotEmpty) body[key] = value;
    }

    if (age != null) body['age'] = age;
    addIfFilled('parent_email', parentEmail);
    addIfFilled('phone', phone);
    addIfFilled('requested_role', requestedRole);
    if (recaptchaToken != null) body['recaptcha_token'] = recaptchaToken;

    final raw =
        await ApiClient.post('/auth/register', body) as Map<String, dynamic>;
    return TokenResponse.fromJson(raw);
  }

  /// Returns the OTP string when the email is registered with a password
  /// account, null otherwise (backend never reveals non-existent emails).
  static Future<String?> forgotPassword(String email) async {
    final json =
        await ApiClient.post('/auth/forgot-password', {'email': email})
            as Map<String, dynamic>;
    return json['reset_token'] as String?;
  }

  static Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await ApiClient.post('/auth/reset-password', {
      'email': email,
      'otp': otp,
      'new_password': newPassword,
    });
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await ApiClient.post('/auth/change-password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  static Future<void> logout() async {
    try {
      await ApiClient.post('/auth/logout', {});
    } catch (_) {}
  }

  // ── Auth0 ─────────────────────────────────────────────────────────────────

  /// Web: called at startup by main() to exchange the redirect callback token.
  /// Android: always returns null (login completes inside loginWithAuth0).
  static Future<TokenResponse?> handleAuth0RedirectCallback() async {
    final idToken = getRedirectIdToken();
    if (idToken == null) return null;
    final json =
        await ApiClient.post('/auth/auth0', {'id_token': idToken})
            as Map<String, dynamic>;
    return TokenResponse.fromJson(json);
  }

  /// Initiates Auth0 login.
  /// - Web: redirects the whole page to Auth0 (this future never resolves on web).
  ///   The completed login is handled by handleAuth0RedirectCallback() in main().
  /// - Android/iOS: opens Chrome Custom Tabs and returns a CareSkill JWT.
  static Future<TokenResponse?> loginWithAuth0() async {
    final idToken = await performAuth0Login(
      AppConfig.auth0Domain,
      AppConfig.auth0ClientId,
      AppConfig.auth0CallbackScheme,
    );
    final json =
        await ApiClient.post('/auth/auth0', {'id_token': idToken})
            as Map<String, dynamic>;
    return TokenResponse.fromJson(json);
  }

  static Future<void> auth0Logout() async {
    await performAuth0Logout(
      AppConfig.auth0Domain,
      AppConfig.auth0ClientId,
      AppConfig.auth0CallbackScheme,
    );
  }
}

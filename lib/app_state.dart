import 'core/config.dart';
import 'models/auth_models.dart';
import 'services/session_storage.dart';

/// Global runtime state set after a successful login.
class AppState {
  const AppState._();

  static const _userIdKey       = '${AppConfig.storagePrefix}.userId';
  static const _tokenKey        = '${AppConfig.storagePrefix}.token';
  static const _roleKey         = '${AppConfig.storagePrefix}.role';
  static const _rolesKey        = '${AppConfig.storagePrefix}.roles';
  static const _activeRoleKey   = '${AppConfig.storagePrefix}.activeRole';
  static const _nameKey         = '${AppConfig.storagePrefix}.studentName';
  static const _accessStatusKey = '${AppConfig.storagePrefix}.accessStatus';

  static int userId = 1;
  static String? token;

  /// Primary (highest-privilege) role — used for RBAC checks.
  static UserRole role = UserRole.student;

  /// All roles the user holds. Always contains at least [role].
  static List<UserRole> roles = [UserRole.student];

  /// The role context currently displayed (can differ from [role] when user
  /// switches modes). Defaults to [role] after login.
  static UserRole activeRole = UserRole.student;

  static String? studentName;
  static AccessStatus accessStatus = AccessStatus.approved;

  static bool get isAuthenticated => token != null;

  /// True when the user's account is fully approved and can access dashboards.
  static bool get canAccessDashboard =>
      accessStatus == AccessStatus.approved || role.isAdmin;

  static void setFromLogin(
    int id,
    String accessToken,
    UserRole userRole, {
    String? name,
    AccessStatus? status,
    List<UserRole>? allRoles,
  }) {
    userId = id;
    token = accessToken.isEmpty ? null : accessToken;
    role = userRole;
    roles = allRoles != null && allRoles.isNotEmpty ? allRoles : [userRole];
    if (!roles.contains(userRole)) roles.insert(0, userRole);
    activeRole = userRole;
    studentName = name;
    accessStatus = userRole.isAdmin
        ? AccessStatus.approved
        : (status ?? AccessStatus.approved);

    SessionStorage.write(_userIdKey, id.toString());
    if (token != null) SessionStorage.write(_tokenKey, token!);
    SessionStorage.write(_roleKey, userRole.apiValue);
    SessionStorage.write(_rolesKey, roles.map((r) => r.apiValue).join(','));
    SessionStorage.write(_activeRoleKey, activeRole.apiValue);
    SessionStorage.write(_accessStatusKey, accessStatus.apiValue);
    if (name != null) SessionStorage.write(_nameKey, name);
  }

  /// Switch the active role context. The active role must be in [roles].
  /// Returns false if the role is not held by this user.
  static bool setActiveRole(UserRole r) {
    if (!roles.contains(r)) return false;
    activeRole = r;
    SessionStorage.write(_activeRoleKey, r.apiValue);
    return true;
  }

  static void clear() {
    userId = 0;
    token = null;
    role = UserRole.guest;
    roles = [UserRole.guest];
    activeRole = UserRole.guest;
    studentName = null;
    accessStatus = AccessStatus.approved;
    SessionStorage.remove(_userIdKey);
    SessionStorage.remove(_tokenKey);
    SessionStorage.remove(_roleKey);
    SessionStorage.remove(_rolesKey);
    SessionStorage.remove(_activeRoleKey);
    SessionStorage.remove(_nameKey);
    SessionStorage.remove(_accessStatusKey);
  }

  static void restore() {
    final savedToken  = SessionStorage.read(_tokenKey);
    final savedUserId = int.tryParse(SessionStorage.read(_userIdKey) ?? '');
    final savedRole   = SessionStorage.read(_roleKey);
    if (savedToken == null || savedUserId == null || savedRole == null) return;
    userId      = savedUserId;
    token       = savedToken;
    role        = UserRole.fromString(savedRole);
    studentName = SessionStorage.read(_nameKey);

    final savedRolesStr = SessionStorage.read(_rolesKey);
    if (savedRolesStr != null && savedRolesStr.isNotEmpty) {
      roles = savedRolesStr
          .split(',')
          .map(UserRole.fromString)
          .toList();
    } else {
      roles = [role];
    }

    final savedActive = SessionStorage.read(_activeRoleKey);
    if (savedActive != null) {
      final ar = UserRole.fromString(savedActive);
      activeRole = roles.contains(ar) ? ar : role;
    } else {
      activeRole = role;
    }

    final savedStatus = SessionStorage.read(_accessStatusKey);
    accessStatus = savedStatus != null
        ? AccessStatus.fromString(savedStatus)
        : AccessStatus.approved;
  }
}

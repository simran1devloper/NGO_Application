enum UserRole {
  superAdmin,
  admin,
  mediator,
  mentor,       // Counsellor
  contentCreator,
  student,
  eventManager,
  supportStaff,
  guest;

  static UserRole fromString(String value) => switch (value) {
        'super_admin'     => UserRole.superAdmin,
        'admin'           => UserRole.admin,
        'mediator'        => UserRole.mediator,
        'mentor'          => UserRole.mentor,
        'counsellor'      => UserRole.mentor,   // backend alias
        'content_creator' => UserRole.contentCreator,
        'student'         => UserRole.student,
        'event_manager'   => UserRole.eventManager,
        'support_staff'   => UserRole.supportStaff,
        _                 => UserRole.guest,
      };

  bool get isAdmin          => this == superAdmin || this == admin;
  bool get isMediator       => this == mediator;
  bool get isMentor         => this == mentor;
  bool get isStudent        => this == student;
  bool get isContentCreator => this == contentCreator;
  bool get isEventManager   => this == eventManager;
  bool get isSupportStaff   => this == supportStaff;

  String get displayName => switch (this) {
        UserRole.superAdmin     => 'Super Admin',
        UserRole.admin          => 'Admin',
        UserRole.mediator       => 'Mediator',
        UserRole.mentor         => 'Counsellor',
        UserRole.contentCreator => 'Content Creator',
        UserRole.student        => 'Student',
        UserRole.eventManager   => 'Event Manager',
        UserRole.supportStaff   => 'Support Staff',
        UserRole.guest          => 'Guest',
      };

  String get apiValue => switch (this) {
        UserRole.superAdmin     => 'super_admin',
        UserRole.admin          => 'admin',
        UserRole.mediator       => 'mediator',
        UserRole.mentor         => 'mentor',
        UserRole.contentCreator => 'content_creator',
        UserRole.student        => 'student',
        UserRole.eventManager   => 'event_manager',
        UserRole.supportStaff   => 'support_staff',
        UserRole.guest          => 'guest',
      };
}

/// Account verification status set by admin after registration.
enum AccessStatus {
  pendingVerification,
  approved,
  rejected,
  deactivated;

  static AccessStatus fromString(String value) => switch (value) {
        'pending_verification' => AccessStatus.pendingVerification,
        'approved'             => AccessStatus.approved,
        'rejected'             => AccessStatus.rejected,
        'deactivated'          => AccessStatus.deactivated,
        _                      => AccessStatus.pendingVerification,
      };

  String get apiValue => switch (this) {
        AccessStatus.pendingVerification => 'pending_verification',
        AccessStatus.approved            => 'approved',
        AccessStatus.rejected            => 'rejected',
        AccessStatus.deactivated         => 'deactivated',
      };

  bool get isApproved => this == approved;
  bool get isPending  => this == pendingVerification;
  bool get isRejected => this == rejected;
}

class TokenResponse {
  const TokenResponse({
    required this.accessToken,
    required this.role,
    required this.roles,
    required this.userId,
    required this.name,
    this.accessStatus,
    this.requestedRole,
  });

  final String accessToken;
  final String role;
  final List<String> roles;
  final int userId;
  final String name;
  final String? accessStatus;
  final String? requestedRole;

  factory TokenResponse.fromJson(Map<String, dynamic> j) {
    // Handles three response shapes:
    //  1. Login:       flat  { access_token, role, roles, user_id, name, ... }
    //  2. Login+user:  nested { access_token, user: { id, role, name, ... } }
    //  3. Register:    { message, user: { id, role, name, access_status, ... } }
    //     (no access_token — registration keeps user in pending state)
    final user  = j['user'] as Map<String, dynamic>?;
    final token = (j['access_token'] as String?) ?? '';
    final role  = ((user?['role'] ?? j['role']) as String?) ?? 'student';
    final id    = (user?['id'] ?? user?['user_id'] ?? j['user_id']) as int? ?? 0;
    final name  = ((user?['name'] ?? j['name']) as String?) ?? '';
    final status = (user?['access_status'] ?? j['access_status']) as String?;
    final reqRole = (user?['requested_role'] ?? j['requested_role']) as String?;
    final rawRoles = (j['roles'] as List<dynamic>?) ?? [];
    final roles = rawRoles.whereType<String>().toList();
    if (!roles.contains(role)) roles.insert(0, role);
    return TokenResponse(
      accessToken:   token,
      role:          role,
      roles:         roles,
      userId:        id,
      name:          name,
      accessStatus:  status,
      requestedRole: reqRole,
    );
  }
}

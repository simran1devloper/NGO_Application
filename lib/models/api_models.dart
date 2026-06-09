// API response models — plain Dart classes with fromJson factories.
// These map 1-to-1 with the FastAPI schemas in backend/app/schemas/.

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.level,
    required this.xp,
    this.age,
    this.email,
    this.dateOfBirth,
    this.createdAt,
    this.parentEmail,
    this.className,
    this.schoolName,
    this.location,
    this.phone,
    this.role,
    this.roles = const [],
    this.accessStatus,
    this.requestedRole,
    this.verificationNote,
  });

  final int id;
  final String name;
  final String? email;
  final int? age;
  final DateTime? dateOfBirth;
  final DateTime? createdAt;
  final int level;
  final int xp;
  final String? parentEmail;
  final String? className;
  final String? schoolName;
  final String? location;
  final String? phone;
  final String? role;
  final List<String> roles;
  final String? accessStatus;
  final String? requestedRole;
  final String? verificationNote;

  AppUser copyWith({
    String? name,
    String? email,
    int? age,
    DateTime? dateOfBirth,
    DateTime? createdAt,
    String? parentEmail,
    String? className,
    String? schoolName,
    String? location,
    String? phone,
    String? role,
    List<String>? roles,
    String? accessStatus,
    String? requestedRole,
    String? verificationNote,
  }) => AppUser(
    id: id,
    name: name ?? this.name,
    email: email ?? this.email,
    level: level,
    xp: xp,
    age: age ?? this.age,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    createdAt: createdAt ?? this.createdAt,
    parentEmail: parentEmail ?? this.parentEmail,
    className: className ?? this.className,
    schoolName: schoolName ?? this.schoolName,
    location: location ?? this.location,
    phone: phone ?? this.phone,
    role: role ?? this.role,
    roles: roles ?? this.roles,
    accessStatus: accessStatus ?? this.accessStatus,
    requestedRole: requestedRole ?? this.requestedRole,
    verificationNote: verificationNote ?? this.verificationNote,
  );

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'] as int,
    name: j['name'] as String,
    email: j['email'] as String?,
    age: j['age'] as int?,
    dateOfBirth: j['date_of_birth'] == null
        ? null
        : DateTime.parse(j['date_of_birth'] as String),
    createdAt: j['created_at'] == null
        ? null
        : DateTime.parse(j['created_at'] as String),
    level: (j['level'] as int?) ?? 1,
    xp: (j['xp'] as int?) ?? 0,
    parentEmail: j['parent_email'] as String?,
    className: j['class_name'] as String?,
    schoolName: j['school_name'] as String?,
    location: j['location'] as String?,
    phone: j['phone'] as String?,
    role: j['role'] as String?,
    roles: (j['roles'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        [
          if (j['role'] is String) j['role'] as String,
        ],
    accessStatus: j['access_status'] as String?,
    requestedRole: j['requested_role'] as String?,
    verificationNote: j['verification_note'] as String?,
  );
}

/// A user card shown in the admin pending-approvals list.
class PendingUserItem {
  const PendingUserItem({
    required this.id,
    required this.name,
    required this.email,
    required this.currentRole,
    required this.accessStatus,
    required this.createdAt,
    this.requestedRole,
    this.phone,
    this.className,
    this.schoolName,
    this.location,
  });

  final int id;
  final String name;
  final String email;
  final String currentRole;
  final String accessStatus;
  final DateTime createdAt;
  final String? requestedRole;
  final String? phone;
  final String? className;
  final String? schoolName;
  final String? location;

  factory PendingUserItem.fromJson(Map<String, dynamic> j) => PendingUserItem(
    id: j['id'] as int,
    name: j['name'] as String,
    email: j['email'] as String,
    currentRole: (j['current_role'] ?? j['role'] ?? 'student') as String,
    accessStatus: (j['access_status'] ?? 'pending_verification') as String,
    createdAt: DateTime.parse(j['created_at'] as String),
    requestedRole: j['requested_role'] as String?,
    phone: j['phone'] as String?,
    className: j['class_name'] as String?,
    schoolName: j['school_name'] as String?,
    location: j['location'] as String?,
  );
}

/// Full user record shown in the admin User Management table.
class AdminUserItem {
  const AdminUserItem({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.roles,
    required this.accessStatus,
    required this.createdAt,
    this.requestedRole,
    this.phone,
    this.className,
    this.schoolName,
    this.location,
    this.verificationNote,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final List<String> roles;
  final String accessStatus;
  final DateTime createdAt;
  final String? requestedRole;
  final String? phone;
  final String? className;
  final String? schoolName;
  final String? location;
  final String? verificationNote;

  bool get isBlocked => accessStatus == 'deactivated';
  bool get isPending => accessStatus == 'pending_verification';
  bool get isApproved => accessStatus == 'approved';
  bool get isRejected => accessStatus == 'rejected';

  AdminUserItem copyWith({
    String? role,
    List<String>? roles,
    String? accessStatus,
  }) => AdminUserItem(
    id: id,
    name: name,
    email: email,
    role: role ?? this.role,
    roles: roles ?? this.roles,
    accessStatus: accessStatus ?? this.accessStatus,
    createdAt: createdAt,
    requestedRole: requestedRole,
    phone: phone,
    className: className,
    schoolName: schoolName,
    location: location,
    verificationNote: verificationNote,
  );

  factory AdminUserItem.fromJson(Map<String, dynamic> j) => AdminUserItem(
    id: j['id'] as int,
    name: j['name'] as String,
    email: j['email'] as String,
    role: (j['role'] ?? 'student') as String,
    roles: (j['roles'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        [(j['role'] ?? 'student') as String],
    accessStatus: (j['access_status'] ?? 'pending_verification') as String,
    createdAt: DateTime.parse(j['created_at'] as String),
    requestedRole: j['requested_role'] as String?,
    phone: j['phone'] as String?,
    className: j['class_name'] as String?,
    schoolName: j['school_name'] as String?,
    location: j['location'] as String?,
    verificationNote: j['verification_note'] as String?,
  );
}

/// User statistics summary for the admin dashboard.
class AdminStats {
  const AdminStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.pendingUsers,
    required this.blockedUsers,
    required this.rejectedUsers,
    this.roleCounts = const {},
  });

  final int totalUsers;
  final int activeUsers;
  final int pendingUsers;
  final int blockedUsers;
  final int rejectedUsers;
  final Map<String, int> roleCounts;

  factory AdminStats.fromJson(Map<String, dynamic> j) => AdminStats(
    totalUsers: (j['total_users'] as int?) ?? 0,
    activeUsers: (j['active_users'] as int?) ?? 0,
    pendingUsers: (j['pending_users'] as int?) ?? 0,
    blockedUsers: (j['blocked_users'] as int?) ?? 0,
    rejectedUsers: (j['rejected_users'] as int?) ?? 0,
    roleCounts:
        (j['role_counts'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as int?) ?? 0),
        ) ??
        const {},
  );

  factory AdminStats.empty() => const AdminStats(
    totalUsers: 0,
    activeUsers: 0,
    pendingUsers: 0,
    blockedUsers: 0,
    rejectedUsers: 0,
  );
}

/// Admin dashboard notification model.
class AdminNotification {
  const AdminNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.userId,
    this.actionUrl,
  });

  final int id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final int? userId;
  final String? actionUrl;

  AdminNotification copyWith({bool? isRead}) => AdminNotification(
    id: id,
    title: title,
    message: message,
    type: type,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
    userId: userId,
    actionUrl: actionUrl,
  );

  factory AdminNotification.fromJson(Map<String, dynamic> j) =>
      AdminNotification(
        id: j['id'] as int,
        title: j['title'] as String,
        message: j['message'] as String,
        type: (j['type'] ?? 'general') as String,
        isRead: (j['is_read'] as bool?) ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
        userId: j['user_id'] as int?,
        actionUrl: j['action_url'] as String?,
      );
}

class UserStats {
  const UserStats({
    required this.userId,
    required this.weeklyLearningHours,
    required this.skillGrowthPercent,
    required this.quizRank,
    this.coursesEnrolled = 0,
    this.lessonsCompleted = 0,
    this.studyStreakDays = 0,
  });

  final int userId;
  final double weeklyLearningHours;
  final int skillGrowthPercent;
  final int quizRank;
  final int coursesEnrolled;
  final int lessonsCompleted;
  final int studyStreakDays;

  factory UserStats.fromJson(Map<String, dynamic> j) => UserStats(
    userId: j['user_id'] as int,
    weeklyLearningHours: (j['weekly_learning_hours'] as num).toDouble(),
    skillGrowthPercent: j['skill_growth_percent'] as int,
    quizRank: j['quiz_rank'] as int,
    coursesEnrolled: (j['courses_enrolled'] as int?) ?? 0,
    lessonsCompleted: (j['lessons_completed'] as int?) ?? 0,
    studyStreakDays: (j['study_streak_days'] as int?) ?? 0,
  );
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.name,
    required this.xp,
    required this.level,
  });

  final int rank;
  final int userId;
  final String name;
  final int xp;
  final int level;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
    rank: j['rank'] as int,
    userId: j['user_id'] as int,
    name: j['name'] as String,
    xp: j['xp'] as int,
    level: j['level'] as int,
  );
}

class ApiCounsellingSession {
  const ApiCounsellingSession({
    required this.id,
    required this.counsellorName,
    required this.topic,
    required this.scheduledAt,
    required this.status,
    this.slotId,
    this.mentorId,
    this.endsAt,
    this.meetingUrl,
    this.notes,
  });

  final int id;
  final int? slotId;
  final int? mentorId;
  final String counsellorName;
  final String topic;
  final DateTime scheduledAt;
  final DateTime? endsAt;
  final String status; // upcoming | completed | cancelled
  final String? meetingUrl;
  final String? notes;

  bool get isUpcoming => status == 'upcoming';
  bool get hasMeetingLink => meetingUrl != null && meetingUrl!.isNotEmpty;

  /// Returns a human-readable time like "Today, 5:00 PM" or "23/6, 3:30 PM".
  String get formattedTime {
    final now = DateTime.now();
    final isToday =
        scheduledAt.year == now.year &&
        scheduledAt.month == now.month &&
        scheduledAt.day == now.day;
    final h = scheduledAt.hour % 12 == 0 ? 12 : scheduledAt.hour % 12;
    final m = scheduledAt.minute.toString().padLeft(2, '0');
    final ampm = scheduledAt.hour < 12 ? 'AM' : 'PM';
    final day = isToday ? 'Today' : '${scheduledAt.day}/${scheduledAt.month}';
    return '$day, $h:$m $ampm';
  }

  factory ApiCounsellingSession.fromJson(Map<String, dynamic> j) =>
      ApiCounsellingSession(
        id: j['id'] as int,
        slotId: j['slot_id'] as int?,
        mentorId: j['mentor_id'] as int?,
        counsellorName: j['counsellor_name'] as String,
        topic: j['topic'] as String,
        scheduledAt: DateTime.parse(j['scheduled_at'] as String),
        endsAt: j['ends_at'] != null
            ? DateTime.tryParse(j['ends_at'] as String)
            : null,
        status: j['status'] as String,
        meetingUrl: j['meeting_url'] as String?,
        notes: j['notes'] as String?,
      );
}

class ApiCounsellingSlot {
  const ApiCounsellingSlot({
    required this.id,
    required this.mentorId,
    required this.mentorName,
    required this.startsAt,
    required this.endsAt,
    required this.capacity,
    required this.bookedCount,
    required this.availableCount,
    required this.isActive,
    required this.isAvailable,
    this.topic,
    this.meetingUrl,
  });

  final int id;
  final int mentorId;
  final String mentorName;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? topic;
  final int capacity;
  final int bookedCount;
  final int availableCount;
  final String? meetingUrl;
  final bool isActive;
  final bool isAvailable;

  bool get hasMeetingLink => meetingUrl != null && meetingUrl!.isNotEmpty;

  String get formattedTime {
    final h = startsAt.hour % 12 == 0 ? 12 : startsAt.hour % 12;
    final m = startsAt.minute.toString().padLeft(2, '0');
    final ampm = startsAt.hour < 12 ? 'AM' : 'PM';
    return '${startsAt.day}/${startsAt.month}, $h:$m $ampm';
  }

  factory ApiCounsellingSlot.fromJson(Map<String, dynamic> j) =>
      ApiCounsellingSlot(
        id: j['id'] as int,
        mentorId: j['mentor_id'] as int,
        mentorName: j['mentor_name'] as String,
        startsAt: DateTime.parse(j['starts_at'] as String),
        endsAt: DateTime.parse(j['ends_at'] as String),
        topic: j['topic'] as String?,
        capacity: j['capacity'] as int,
        bookedCount: j['booked_count'] as int,
        availableCount: j['available_count'] as int,
        meetingUrl: j['meeting_url'] as String?,
        isActive: j['is_active'] as bool,
        isAvailable: j['is_available'] as bool,
      );
}

class ApiBadge {
  const ApiBadge({
    required this.id,
    required this.iconName,
    required this.label,
    required this.category,
  });

  final int id;
  final String iconName;
  final String label;
  final String category;

  factory ApiBadge.fromJson(Map<String, dynamic> j) => ApiBadge(
    id: j['id'] as int,
    iconName: j['icon_name'] as String,
    label: j['label'] as String,
    category: j['category'] as String,
  );
}

class UserBadge {
  const UserBadge({
    required this.id,
    required this.badgeId,
    required this.earnedAt,
    required this.badge,
  });

  final int id;
  final int badgeId;
  final DateTime earnedAt;
  final ApiBadge badge;

  factory UserBadge.fromJson(Map<String, dynamic> j) => UserBadge(
    id: j['id'] as int,
    badgeId: j['badge_id'] as int,
    earnedAt: DateTime.parse(j['earned_at'] as String),
    badge: ApiBadge.fromJson(j['badge'] as Map<String, dynamic>),
  );
}

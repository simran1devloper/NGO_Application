class RewardTransaction {
  const RewardTransaction({
    required this.id,
    required this.userId,
    required this.points,
    required this.xp,
    required this.trigger,
    required this.title,
    required this.createdAt,
    this.actorId,
    this.message,
    this.sourceType,
    this.sourceId,
  });

  final int id;
  final int userId;
  final int? actorId;
  final int points;
  final int xp;
  final String trigger;
  final String title;
  final String? message;
  final String? sourceType;
  final int? sourceId;
  final DateTime createdAt;

  factory RewardTransaction.fromJson(Map<String, dynamic> j) =>
      RewardTransaction(
        id: j['id'] as int,
        userId: j['user_id'] as int,
        actorId: j['actor_id'] as int?,
        points: (j['points'] as int?) ?? 0,
        xp: (j['xp'] as int?) ?? 0,
        trigger: (j['trigger'] ?? 'manual') as String,
        title: (j['title'] ?? 'Reward') as String,
        message: j['message'] as String?,
        sourceType: j['source_type'] as String?,
        sourceId: j['source_id'] as int?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class RewardSummary {
  const RewardSummary({
    required this.userId,
    required this.totalPoints,
    required this.totalXpFromRewards,
    required this.rewards,
  });

  final int userId;
  final int totalPoints;
  final int totalXpFromRewards;
  final List<RewardTransaction> rewards;

  factory RewardSummary.empty(int userId) => RewardSummary(
        userId: userId,
        totalPoints: 0,
        totalXpFromRewards: 0,
        rewards: const [],
      );

  factory RewardSummary.fromJson(Map<String, dynamic> j) => RewardSummary(
        userId: j['user_id'] as int,
        totalPoints: (j['total_points'] as int?) ?? 0,
        totalXpFromRewards: (j['total_xp_from_rewards'] as int?) ?? 0,
        rewards: ((j['rewards'] as List<dynamic>?) ?? const [])
            .map((e) => RewardTransaction.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class RewardRule {
  const RewardRule({
    required this.id,
    required this.role,
    required this.trigger,
    required this.points,
    required this.xp,
    required this.title,
    required this.isActive,
    required this.createdAt,
    this.description,
  });

  final int id;
  final String role;
  final String trigger;
  final int points;
  final int xp;
  final String title;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  factory RewardRule.fromJson(Map<String, dynamic> j) => RewardRule(
        id: j['id'] as int,
        role: (j['role'] ?? 'student') as String,
        trigger: (j['trigger'] ?? 'manual') as String,
        points: (j['points'] as int?) ?? 0,
        xp: (j['xp'] as int?) ?? 0,
        title: (j['title'] ?? '') as String,
        description: j['description'] as String?,
        isActive: (j['is_active'] as bool?) ?? true,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class RewardTask {
  const RewardTask({
    required this.id,
    required this.userId,
    required this.title,
    required this.targetCount,
    required this.currentCount,
    required this.rewardPoints,
    required this.rewardXp,
    required this.status,
    required this.createdAt,
    this.createdBy,
    this.description,
    this.dueAt,
    this.completedAt,
  });

  final int id;
  final int userId;
  final int? createdBy;
  final String title;
  final String? description;
  final int targetCount;
  final int currentCount;
  final int rewardPoints;
  final int rewardXp;
  final String status;
  final DateTime? dueAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  double get progress => targetCount <= 0 ? 0 : currentCount / targetCount;
  bool get isCompleted => status == 'completed';

  factory RewardTask.fromJson(Map<String, dynamic> j) => RewardTask(
        id: j['id'] as int,
        userId: j['user_id'] as int,
        createdBy: j['created_by'] as int?,
        title: (j['title'] ?? 'Reward task') as String,
        description: j['description'] as String?,
        targetCount: (j['target_count'] as int?) ?? 1,
        currentCount: (j['current_count'] as int?) ?? 0,
        rewardPoints: (j['reward_points'] as int?) ?? 0,
        rewardXp: (j['reward_xp'] as int?) ?? 0,
        status: (j['status'] ?? 'active') as String,
        dueAt: j['due_at'] == null ? null : DateTime.parse(j['due_at'] as String),
        completedAt: j['completed_at'] == null
            ? null
            : DateTime.parse(j['completed_at'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class UserStreak {
  const UserStreak({
    required this.userId,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalActiveDays,
    this.lastActivityDate,
  });

  final int userId;
  final int currentStreak;
  final int longestStreak;
  final int totalActiveDays;
  final DateTime? lastActivityDate;

  factory UserStreak.fromJson(Map<String, dynamic> j) => UserStreak(
        userId: j['user_id'] as int,
        currentStreak: (j['current_streak'] as int?) ?? 0,
        longestStreak: (j['longest_streak'] as int?) ?? 0,
        totalActiveDays: (j['total_active_days'] as int?) ?? 0,
        lastActivityDate: j['last_activity_date'] == null
            ? null
            : DateTime.parse(j['last_activity_date'] as String),
      );
}

class UserMilestone {
  const UserMilestone({
    required this.id,
    required this.userId,
    required this.milestoneKey,
    required this.title,
    required this.points,
    required this.xp,
    required this.achievedAt,
    this.description,
  });

  final int id;
  final int userId;
  final String milestoneKey;
  final String title;
  final String? description;
  final int points;
  final int xp;
  final DateTime achievedAt;

  factory UserMilestone.fromJson(Map<String, dynamic> j) => UserMilestone(
        id: j['id'] as int,
        userId: j['user_id'] as int,
        milestoneKey: j['milestone_key'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        points: (j['points'] as int?) ?? 0,
        xp: (j['xp'] as int?) ?? 0,
        achievedAt: DateTime.parse(j['achieved_at'] as String),
      );
}

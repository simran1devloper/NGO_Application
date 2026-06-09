import '../models/reward_models.dart';
import 'api_client.dart';

class RewardRepository {
  const RewardRepository._();

  // ── User wallet ───────────────────────────────────────────────────────────

  static Future<RewardSummary> getMyRewards() async {
    final json = await ApiClient.get('/rewards/me') as Map<String, dynamic>;
    return RewardSummary.fromJson(json);
  }

  static Future<RewardSummary> getUserRewards(int userId) async {
    final json = await ApiClient.get('/rewards/users/$userId') as Map<String, dynamic>;
    return RewardSummary.fromJson(json);
  }

  // ── Tasks ─────────────────────────────────────────────────────────────────

  static Future<List<RewardTask>> getMyTasks() async {
    final list = await ApiClient.get('/rewards/tasks/me') as List<dynamic>;
    return list
        .map((e) => RewardTask.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<RewardTask> advanceTask(int taskId, {int increment = 1}) async {
    final json = await ApiClient.patch('/rewards/tasks/$taskId/progress', {
      'increment': increment,
    }) as Map<String, dynamic>;
    return RewardTask.fromJson(json);
  }

  /// Create a rewarded task for a user [mentor/admin only].
  static Future<RewardTask> createTask({
    required int userId,
    required String title,
    String? description,
    int targetCount = 1,
    int rewardPoints = 0,
    int rewardXp = 0,
    DateTime? dueAt,
  }) async {
    final json = await ApiClient.post('/rewards/tasks', {
      'user_id': userId,
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      'target_count': targetCount,
      'reward_points': rewardPoints,
      'reward_xp': rewardXp,
      if (dueAt != null) 'due_at': dueAt.toIso8601String(),
    }) as Map<String, dynamic>;
    return RewardTask.fromJson(json);
  }

  // ── Gift ──────────────────────────────────────────────────────────────────

  static Future<RewardTransaction> sendGift({
    required int recipientId,
    required int points,
    required String title,
    String? message,
  }) async {
    final json = await ApiClient.post('/rewards/gift', {
      'recipient_id': recipientId,
      'points': points,
      'title': title,
      if (message != null && message.isNotEmpty) 'message': message,
    }) as Map<String, dynamic>;
    return RewardTransaction.fromJson(json);
  }

  // ── Admin: reward rules ───────────────────────────────────────────────────

  static Future<List<RewardRule>> getRewardRules() async {
    final list = await ApiClient.get('/rewards/rules') as List<dynamic>;
    return list
        .map((e) => RewardRule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<RewardRule> createRewardRule({
    required String role,
    required String trigger,
    required int points,
    required int xp,
    required String title,
    String? description,
    bool isActive = true,
  }) async {
    final json = await ApiClient.post('/rewards/rules', {
      'role': role,
      'trigger': trigger,
      'points': points,
      'xp': xp,
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      'is_active': isActive,
    }) as Map<String, dynamic>;
    return RewardRule.fromJson(json);
  }

  static Future<RewardRule> updateRewardRule(
    int ruleId, {
    int? points,
    int? xp,
    String? title,
    String? description,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{
      if (points != null) 'points': points,
      if (xp != null) 'xp': xp,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (isActive != null) 'is_active': isActive,
    };
    final json = await ApiClient.patch('/rewards/rules/$ruleId', body) as Map<String, dynamic>;
    return RewardRule.fromJson(json);
  }

  static Future<UserStreak> getMyStreak() async {
    final json = await ApiClient.get('/rewards/streak/me') as Map<String, dynamic>;
    return UserStreak.fromJson(json);
  }

  static Future<List<UserMilestone>> getMyMilestones() async {
    final list = await ApiClient.get('/rewards/milestones/me') as List<dynamic>;
    return list.map((e) => UserMilestone.fromJson(e as Map<String, dynamic>)).toList();
  }
}

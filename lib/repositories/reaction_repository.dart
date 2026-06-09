import '../models/reaction.dart';
import 'api_client.dart';

class ReactionRepository {
  const ReactionRepository._();

  static Future<ReactionCounts> toggle({
    required TargetType targetType,
    required int targetId,
    required ReactionType reactionType,
  }) async {
    final json = await ApiClient.post('/reactions/toggle', {
      'target_type':   targetType.value,
      'target_id':     targetId,
      'reaction_type': reactionType.value,
    }) as Map<String, dynamic>;
    return ReactionCounts.fromJson(json);
  }

  static Future<ReactionCounts> getCounts({
    required TargetType targetType,
    required int targetId,
  }) async {
    final json = await ApiClient.get(
      '/reactions/${targetType.value}/$targetId',
    ) as Map<String, dynamic>;
    return ReactionCounts.fromJson(json);
  }

  static Future<List<ReactionCounts>> getBulkCounts({
    required TargetType targetType,
    required List<int> ids,
  }) async {
    if (ids.isEmpty) return [];
    final idStr = ids.join(',');
    final list = await ApiClient.get(
      '/reactions/bulk/${targetType.value}?ids=$idStr',
    ) as List<dynamic>;
    return list.map((e) => ReactionCounts.fromJson(e as Map<String, dynamic>)).toList();
  }
}

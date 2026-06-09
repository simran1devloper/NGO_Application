import '../models/feedback_model.dart';
import 'api_client.dart';

class FeedbackRepository {
  const FeedbackRepository._();

  static Future<FeedbackItem> submitFeedback({
    required String name,
    String? email,
    required String category,
    int? rating,
    required String subject,
    required String message,
    int? referenceId,
    bool authenticated = false,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'category': category,
      'subject': subject,
      'message': message,
    };
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (rating != null) body['rating'] = rating;
    if (referenceId != null) body['reference_id'] = referenceId;

    final endpoint = authenticated ? '/feedback/auth' : '/feedback';
    final json = await ApiClient.post(endpoint, body) as Map<String, dynamic>;
    return FeedbackItem.fromJson(json);
  }

  static Future<List<FeedbackItem>> listFeedback({
    String? category,
    String? status,
  }) async {
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    if (status != null) params['status'] = status;

    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final list =
        await ApiClient.get('/feedback$query') as List<dynamic>;
    return list
        .map((e) => FeedbackItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<FeedbackItem> replyToFeedback({
    required int feedbackId,
    required String adminReply,
    String status = 'reviewed',
  }) async {
    final json = await ApiClient.patch('/feedback/$feedbackId/reply', {
      'admin_reply': adminReply,
      'status': status,
    }) as Map<String, dynamic>;
    return FeedbackItem.fromJson(json);
  }

  static Future<void> deleteFeedback(int feedbackId) async {
    await ApiClient.delete('/feedback/$feedbackId');
  }

  static Future<Map<String, dynamic>> getStats() async {
    return await ApiClient.get('/feedback/stats') as Map<String, dynamic>;
  }
}

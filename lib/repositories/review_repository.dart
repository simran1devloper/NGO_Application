import '../models/review.dart';
import 'api_client.dart';

class ReviewRepository {
  const ReviewRepository._();

  // ── public ──────────────────────────────────────────────────────────────────

  static Future<ReviewSummary> getSummary({
    required ReviewTargetType targetType,
    required int targetId,
  }) async {
    final json = await ApiClient.get(
      '/reviews/${targetType.value}/$targetId/summary',
    ) as Map<String, dynamic>;
    return ReviewSummary.fromJson(json);
  }

  static Future<List<Review>> listReviews({
    required ReviewTargetType targetType,
    required int targetId,
    int skip = 0,
    int limit = 20,
  }) async {
    final list = await ApiClient.get(
      '/reviews/${targetType.value}/$targetId?skip=$skip&limit=$limit',
    ) as List<dynamic>;
    return list.map((e) => Review.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── authenticated ────────────────────────────────────────────────────────────

  static Future<List<Review>> myReviews() async {
    final list = await ApiClient.get('/reviews/my') as List<dynamic>;
    return list.map((e) => Review.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Review> createReview({
    required ReviewTargetType targetType,
    required int targetId,
    required int rating,
    required String body,
    String? title,
  }) async {
    final payload = <String, dynamic>{
      'target_type': targetType.value,
      'target_id':   targetId,
      'rating':      rating,
      'body':        body,
      'title':       title,
    };
    final json = await ApiClient.post('/reviews', payload) as Map<String, dynamic>;
    return Review.fromJson(json);
  }

  static Future<Review> editReview({
    required int reviewId,
    int? rating,
    String? title,
    String? body,
  }) async {
    final payload = <String, dynamic>{
      'rating': rating,
      'title':  title,
      'body':   body,
    };
    final json = await ApiClient.patch(
      '/reviews/$reviewId',
      payload,
    ) as Map<String, dynamic>;
    return Review.fromJson(json);
  }

  static Future<void> deleteReview(int reviewId) async {
    await ApiClient.delete('/reviews/$reviewId');
  }

  // ── mediator ─────────────────────────────────────────────────────────────────

  static Future<List<Review>> pendingReviews({int skip = 0, int limit = 50}) async {
    final list = await ApiClient.get(
      '/reviews/pending?skip=$skip&limit=$limit',
    ) as List<dynamic>;
    return list.map((e) => Review.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Review> approveReview(int reviewId) async {
    final json = await ApiClient.patch(
      '/reviews/$reviewId/approve',
      {},
    ) as Map<String, dynamic>;
    return Review.fromJson(json);
  }

  static Future<Review> rejectReview(int reviewId, String reason) async {
    final json = await ApiClient.patch(
      '/reviews/$reviewId/reject',
      {'reason': reason},
    ) as Map<String, dynamic>;
    return Review.fromJson(json);
  }
}

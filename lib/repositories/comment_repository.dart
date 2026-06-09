import '../models/comment.dart';
import 'api_client.dart';

class CommentRepository {
  const CommentRepository._();

  static Future<List<Comment>> listComments(int postId, {int skip = 0, int limit = 50}) async {
    final list = await ApiClient.get(
      '/comments/post/$postId?skip=$skip&limit=$limit',
    ) as List<dynamic>;
    return list.map((e) => Comment.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<int> getCommentCount(int postId) async {
    final json = await ApiClient.get('/comments/post/$postId/count') as Map<String, dynamic>;
    return json['count'] as int? ?? 0;
  }

  static Future<Comment> postComment({
    required int postId,
    required String body,
    int? parentId,
  }) async {
    final payload = <String, dynamic>{'post_id': postId, 'body': body};
    if (parentId != null) payload['parent_id'] = parentId;
    final json = await ApiClient.post('/comments', payload) as Map<String, dynamic>;
    return Comment.fromJson(json);
  }

  static Future<Comment> editComment({
    required int commentId,
    required String body,
  }) async {
    final json = await ApiClient.patch(
      '/comments/$commentId',
      {'body': body},
    ) as Map<String, dynamic>;
    return Comment.fromJson(json);
  }

  static Future<void> deleteComment(int commentId) async {
    await ApiClient.delete('/comments/$commentId');
  }
}

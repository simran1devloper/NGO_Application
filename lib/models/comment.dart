class CommentUser {
  final int id;
  final String name;

  const CommentUser({required this.id, required this.name});

  factory CommentUser.fromJson(Map<String, dynamic> j) =>
      CommentUser(id: j['id'] as int, name: j['name'] as String);
}

class Comment {
  final int id;
  final int postId;
  final int userId;
  final int? parentId;
  final String body;
  final bool isEdited;
  final bool isDeleted;
  /// True when a mediator/admin has hidden this comment.
  /// The body will already be replaced by the API with the moderation notice.
  final bool isHidden;
  /// Human-readable notice set by the API when isHidden is true,
  /// e.g. "This comment was removed by the moderation team."
  final String? moderationLabel;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CommentUser? user;
  final int replyCount;
  final List<Comment> replies;

  const Comment({
    required this.id,
    required this.postId,
    required this.userId,
    this.parentId,
    required this.body,
    required this.isEdited,
    required this.isDeleted,
    this.isHidden = false,
    this.moderationLabel,
    required this.createdAt,
    required this.updatedAt,
    this.user,
    this.replyCount = 0,
    this.replies = const [],
  });

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id:               j['id'] as int,
        postId:           j['post_id'] as int,
        userId:           j['user_id'] as int,
        parentId:         j['parent_id'] as int?,
        body:             j['body'] as String,
        isEdited:         j['is_edited'] as bool? ?? false,
        isDeleted:        j['is_deleted'] as bool? ?? false,
        isHidden:         j['is_hidden'] as bool? ?? false,
        moderationLabel:  j['moderation_label'] as String?,
        createdAt:        DateTime.parse(j['created_at'] as String),
        updatedAt:        DateTime.parse(j['updated_at'] as String),
        user: j['user'] != null
            ? CommentUser.fromJson(j['user'] as Map<String, dynamic>)
            : null,
        replyCount: j['reply_count'] as int? ?? 0,
        replies: (j['replies'] as List<dynamic>?)
                ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

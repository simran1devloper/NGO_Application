enum ReviewTargetType {
  course,
  mentor,
  post,
  event;

  String get value => name;

  static ReviewTargetType fromValue(String v) =>
      ReviewTargetType.values.firstWhere((e) => e.value == v);
}

enum ReviewStatus {
  pending,
  approved,
  rejected;

  String get value => name;

  static ReviewStatus fromValue(String v) =>
      ReviewStatus.values.firstWhere((e) => e.value == v,
          orElse: () => ReviewStatus.pending);
}

class Review {
  final int id;
  final int userId;
  final String? authorName;
  final ReviewTargetType targetType;
  final int targetId;
  final int rating;
  final String? title;
  final String body;
  final ReviewStatus status;
  final String? rejectionReason;
  final bool isEdited;
  /// True when any moderation action has been taken.
  /// The actual moderator identity is never included in public/mediator responses.
  final bool moderated;
  /// Human-readable note from the API, e.g. "Reviewed by the moderation team."
  final String? moderationLabel;
  final DateTime? reviewedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Review({
    required this.id,
    required this.userId,
    this.authorName,
    required this.targetType,
    required this.targetId,
    required this.rating,
    this.title,
    required this.body,
    required this.status,
    this.rejectionReason,
    required this.isEdited,
    this.moderated = false,
    this.moderationLabel,
    this.reviewedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id:               j['id'] as int,
        userId:           j['user_id'] as int,
        authorName:       j['author_name'] as String?,
        targetType:       ReviewTargetType.fromValue(j['target_type'] as String),
        targetId:         j['target_id'] as int,
        rating:           j['rating'] as int,
        title:            j['title'] as String?,
        body:             j['body'] as String,
        status:           ReviewStatus.fromValue(j['status'] as String? ?? 'pending'),
        rejectionReason:  j['rejection_reason'] as String?,
        isEdited:         j['is_edited'] as bool? ?? false,
        moderated:        j['moderated'] as bool? ?? false,
        moderationLabel:  j['moderation_label'] as String?,
        reviewedAt: j['reviewed_at'] != null
            ? DateTime.tryParse(j['reviewed_at'] as String)
            : null,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
        updatedAt: j['updated_at'] != null
            ? DateTime.tryParse(j['updated_at'] as String)
            : null,
      );
}

class ReviewSummary {
  final int count;
  final double? averageRating;

  const ReviewSummary({required this.count, this.averageRating});

  factory ReviewSummary.fromJson(Map<String, dynamic> j) => ReviewSummary(
        count:         j['count'] as int? ?? 0,
        averageRating: (j['average_rating'] as num?)?.toDouble(),
      );
}

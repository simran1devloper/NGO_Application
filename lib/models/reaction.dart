enum ReactionType { like, dislike, upvote, downvote }

enum TargetType { post, course, event, comment }

extension ReactionTypeX on ReactionType {
  String get value => name;
  static ReactionType fromString(String s) =>
      ReactionType.values.firstWhere((e) => e.name == s);
}

extension TargetTypeX on TargetType {
  String get value => name;
  static TargetType fromString(String s) =>
      TargetType.values.firstWhere((e) => e.name == s);
}

class ReactionCounts {
  final TargetType targetType;
  final int targetId;
  final int like;
  final int dislike;
  final int upvote;
  final int downvote;
  final ReactionType? userReaction;

  const ReactionCounts({
    required this.targetType,
    required this.targetId,
    this.like = 0,
    this.dislike = 0,
    this.upvote = 0,
    this.downvote = 0,
    this.userReaction,
  });

  int get total => like + dislike + upvote + downvote;
  int get score => (like + upvote) - (dislike + downvote);

  factory ReactionCounts.fromJson(Map<String, dynamic> j) => ReactionCounts(
        targetType: TargetTypeX.fromString(j['target_type'] as String),
        targetId: j['target_id'] as int,
        like: j['like'] as int? ?? 0,
        dislike: j['dislike'] as int? ?? 0,
        upvote: j['upvote'] as int? ?? 0,
        downvote: j['downvote'] as int? ?? 0,
        userReaction: j['user_reaction'] != null
            ? ReactionTypeX.fromString(j['user_reaction'] as String)
            : null,
      );

  ReactionCounts copyWith({ReactionType? userReaction, bool clearUserReaction = false}) =>
      ReactionCounts(
        targetType: targetType,
        targetId: targetId,
        like: like,
        dislike: dislike,
        upvote: upvote,
        downvote: downvote,
        userReaction: clearUserReaction ? null : (userReaction ?? this.userReaction),
      );
}

class FeedbackItem {
  final int id;
  final int? userId;
  final String name;
  final String? email;
  final String category;
  final int? rating;
  final String subject;
  final String message;
  final String status;
  final String? adminReply;
  final int? referenceId;
  final DateTime createdAt;

  const FeedbackItem({
    required this.id,
    this.userId,
    required this.name,
    this.email,
    required this.category,
    this.rating,
    required this.subject,
    required this.message,
    required this.status,
    this.adminReply,
    this.referenceId,
    required this.createdAt,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> j) => FeedbackItem(
        id: j['id'] as int,
        userId: j['user_id'] as int?,
        name: j['name'] as String,
        email: j['email'] as String?,
        category: j['category'] as String,
        rating: j['rating'] as int?,
        subject: j['subject'] as String,
        message: j['message'] as String,
        status: j['status'] as String,
        adminReply: j['admin_reply'] as String?,
        referenceId: j['reference_id'] as int?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

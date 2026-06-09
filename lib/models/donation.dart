class Donation {
  final int id;
  final String donorName;
  final String? donorEmail;
  final String? donorPhone;
  final int amount;
  final String currency;
  final String? message;
  final String status;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final int? userId;
  final DateTime createdAt;

  const Donation({
    required this.id,
    required this.donorName,
    this.donorEmail,
    this.donorPhone,
    required this.amount,
    required this.currency,
    this.message,
    required this.status,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.userId,
    required this.createdAt,
  });

  double get amountInRupees => amount / 100.0;

  factory Donation.fromJson(Map<String, dynamic> j) => Donation(
        id: j['id'] as int,
        donorName: j['donor_name'] as String,
        donorEmail: j['donor_email'] as String?,
        donorPhone: j['donor_phone'] as String?,
        amount: j['amount'] as int,
        currency: j['currency'] as String? ?? 'INR',
        message: j['message'] as String?,
        status: j['status'] as String,
        razorpayOrderId: j['razorpay_order_id'] as String?,
        razorpayPaymentId: j['razorpay_payment_id'] as String?,
        userId: j['user_id'] as int?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

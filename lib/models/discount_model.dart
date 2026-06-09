class DiscountCode {
  final int id;
  final String code;
  final String? description;
  final String discountType;
  final int discountValue;
  final int? maxUses;
  final int usedCount;
  final int minAmount;
  final bool isActive;
  final DateTime? expiresAt;
  final DateTime createdAt;

  const DiscountCode({
    required this.id,
    required this.code,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.maxUses,
    required this.usedCount,
    required this.minAmount,
    required this.isActive,
    this.expiresAt,
    required this.createdAt,
  });

  factory DiscountCode.fromJson(Map<String, dynamic> j) => DiscountCode(
        id: j['id'] as int,
        code: j['code'] as String,
        description: j['description'] as String?,
        discountType: j['discount_type'] as String,
        discountValue: j['discount_value'] as int,
        maxUses: j['max_uses'] as int?,
        usedCount: j['used_count'] as int,
        minAmount: j['min_amount'] as int,
        isActive: j['is_active'] as bool,
        expiresAt: j['expires_at'] != null
            ? DateTime.parse(j['expires_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class ValidateCodeResult {
  final bool valid;
  final String? discountType;
  final int? discountValue;
  final int? discountAmount;
  final int? finalAmount;
  final String message;

  const ValidateCodeResult({
    required this.valid,
    this.discountType,
    this.discountValue,
    this.discountAmount,
    this.finalAmount,
    required this.message,
  });

  factory ValidateCodeResult.fromJson(Map<String, dynamic> j) =>
      ValidateCodeResult(
        valid: j['valid'] as bool,
        discountType: j['discount_type'] as String?,
        discountValue: j['discount_value'] as int?,
        discountAmount: j['discount_amount'] as int?,
        finalAmount: j['final_amount'] as int?,
        message: j['message'] as String,
      );
}

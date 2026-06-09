import '../models/discount_model.dart';
import 'api_client.dart';

class DiscountRepository {
  const DiscountRepository._();

  static Future<ValidateCodeResult> validateCode({
    required String code,
    required int amountPaise,
  }) async {
    final json = await ApiClient.post('/discounts/validate', {
      'code': code,
      'amount': amountPaise,
    }) as Map<String, dynamic>;
    return ValidateCodeResult.fromJson(json);
  }

  static Future<Map<String, dynamic>> applyCode({
    required String code,
    required int amountPaise,
  }) async {
    return await ApiClient.post('/discounts/apply', {
      'code': code,
      'amount': amountPaise,
    }) as Map<String, dynamic>;
  }

  // ── Admin ──────────────────────────────────────────────────────────────────

  static Future<List<DiscountCode>> listCodes() async {
    final list = await ApiClient.get('/discounts') as List<dynamic>;
    return list
        .map((e) => DiscountCode.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<DiscountCode> createCode({
    required String code,
    String? description,
    required String discountType,
    required int discountValue,
    int? maxUses,
    int minAmount = 0,
    DateTime? expiresAt,
  }) async {
    final body = <String, dynamic>{
      'code': code,
      'discount_type': discountType,
      'discount_value': discountValue,
      'min_amount': minAmount,
    };
    if (description != null) body['description'] = description;
    if (maxUses != null) body['max_uses'] = maxUses;
    if (expiresAt != null) body['expires_at'] = expiresAt.toIso8601String();

    final json =
        await ApiClient.post('/discounts', body) as Map<String, dynamic>;
    return DiscountCode.fromJson(json);
  }

  static Future<DiscountCode> updateCode(
      int codeId, Map<String, dynamic> updates) async {
    final json = await ApiClient.patch('/discounts/$codeId', updates)
        as Map<String, dynamic>;
    return DiscountCode.fromJson(json);
  }

  static Future<void> deleteCode(int codeId) async {
    await ApiClient.delete('/discounts/$codeId');
  }
}

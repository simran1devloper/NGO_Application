import '../models/donation.dart';
import 'api_client.dart';

class DonationRepository {
  const DonationRepository._();

  static Future<Map<String, dynamic>> initiateDonation({
    required String donorName,
    String? donorEmail,
    String? donorPhone,
    required int amountPaise,
    String? message,
  }) async {
    final body = <String, dynamic>{
      'donor_name': donorName,
      'amount': amountPaise,
      'currency': 'INR',
    };
    if (donorEmail != null && donorEmail.isNotEmpty) body['donor_email'] = donorEmail;
    if (donorPhone != null && donorPhone.isNotEmpty) body['donor_phone'] = donorPhone;
    if (message != null && message.isNotEmpty) body['message'] = message;

    return await ApiClient.post('/donations', body) as Map<String, dynamic>;
  }

  static Future<Donation> verifyDonation({
    required int donationId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final json = await ApiClient.post('/donations/verify', {
      'donation_id': donationId,
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
    }) as Map<String, dynamic>;
    return Donation.fromJson(json);
  }

  static Future<List<Donation>> listDonations() async {
    final list = await ApiClient.get('/donations') as List<dynamic>;
    return list.map((e) => Donation.fromJson(e as Map<String, dynamic>)).toList();
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../repositories/discount_repository.dart';
import '../../repositories/donation_repository.dart';

class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _couponCtrl  = TextEditingController();

  int _selectedAmountPaise = 50000; // ₹500
  int? _customAmountPaise;
  bool _useCustomAmount = false;

  String? _couponCode;
  int? _discountAmount;
  String _couponMessage = '';
  bool _couponLoading = false;

  bool _loading = false;

  Razorpay? _razorpay;

  // Tracks the pending donation id for signature verification
  int? _pendingDonationId;
  String? _pendingOrderId;

  static const _presets = [
    (label: '₹100', paise: 10000),
    (label: '₹500', paise: 50000),
    (label: '₹1000', paise: 100000),
    (label: '₹5000', paise: 500000),
  ];

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _razorpay = Razorpay()
        ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess)
        ..on(Razorpay.EVENT_PAYMENT_ERROR,   _onError)
        ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onWallet);
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _messageCtrl.dispose();
    _couponCtrl.dispose();
    super.dispose();
  }

  int get _finalAmountPaise {
    final base = _useCustomAmount ? (_customAmountPaise ?? 0) : _selectedAmountPaise;
    return base - (_discountAmount ?? 0);
  }

  Future<void> _validateCoupon() async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _couponLoading = true);
    try {
      final result = await DiscountRepository.validateCode(
        code: code,
        amountPaise: _useCustomAmount ? (_customAmountPaise ?? 0) : _selectedAmountPaise,
      );
      setState(() {
        _couponMessage = result.message;
        if (result.valid) {
          _couponCode = code;
          _discountAmount = result.discountAmount;
        } else {
          _couponCode = null;
          _discountAmount = null;
        }
      });
    } catch (e) {
      setState(() => _couponMessage = 'Failed to validate coupon.');
    } finally {
      setState(() => _couponLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_finalAmountPaise < 100) {
      _showMsg('Minimum donation amount is ₹1.');
      return;
    }

    setState(() => _loading = true);
    try {
      final order = await DonationRepository.initiateDonation(
        donorName: _nameCtrl.text.trim(),
        donorEmail: _emailCtrl.text.trim(),
        donorPhone: _phoneCtrl.text.trim(),
        amountPaise: _finalAmountPaise,
        message: _messageCtrl.text.trim(),
      );

      _pendingDonationId = order['donation_id'] as int;
      _pendingOrderId    = order['razorpay_order_id'] as String;
      final keyId        = order['key_id'] as String;

      if (kIsWeb) {
        _showMsg('Web payment: use Razorpay checkout.js integration. Order ID: $_pendingOrderId');
      } else {
        _razorpay!.open({
          'key':          keyId,
          'order_id':     _pendingOrderId,
          'amount':       _finalAmountPaise,
          'currency':     'INR',
          'name':         'NGO Donation',
          'description':  'Thank you for your generosity',
          'prefill': {
            'name':    _nameCtrl.text.trim(),
            'email':   _emailCtrl.text.trim(),
            'contact': _phoneCtrl.text.trim(),
          },
          'theme': {'color': '#6C63FF'},
        });
      }
    } catch (e) {
      _showMsg('Failed to initiate payment: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onSuccess(PaymentSuccessResponse resp) async {
    try {
      await DonationRepository.verifyDonation(
        donationId: _pendingDonationId!,
        razorpayOrderId: _pendingOrderId!,
        razorpayPaymentId: resp.paymentId!,
        razorpaySignature: resp.signature!,
      );
      if (_couponCode != null) {
        await DiscountRepository.applyCode(
          code: _couponCode!,
          amountPaise: _finalAmountPaise,
        );
      }
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Thank You!'),
            content: const Text('Your donation was received successfully. We appreciate your support!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        _formKey.currentState?.reset();
        _nameCtrl.clear(); _emailCtrl.clear();
        _phoneCtrl.clear(); _messageCtrl.clear();
        _couponCtrl.clear();
        setState(() { _couponCode = null; _discountAmount = null; });
      }
    } catch (e) {
      _showMsg('Payment recorded but verification failed: $e');
    }
  }

  void _onError(PaymentFailureResponse resp) {
    _showMsg('Payment failed: ${resp.message}');
  }

  void _onWallet(ExternalWalletResponse resp) {
    _showMsg('External wallet selected: ${resp.walletName}');
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Make a Donation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.primaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.favorite, color: cs.onPrimary, size: 36),
                    const SizedBox(height: 8),
                    Text('Support Our Mission',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Your donation helps us empower more lives.',
                        style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.85))),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Amount presets
              Text('Select Amount', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: _presets.map((p) {
                  final selected = !_useCustomAmount && _selectedAmountPaise == p.paise;
                  return ChoiceChip(
                    label: Text(p.label),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _selectedAmountPaise = p.paise;
                      _useCustomAmount = false;
                      _couponCode = null;
                      _discountAmount = null;
                    }),
                  );
                }).toList()
                  ..add(ChoiceChip(
                    label: const Text('Custom'),
                    selected: _useCustomAmount,
                    onSelected: (_) => setState(() => _useCustomAmount = true),
                  )),
              ),
              if (_useCustomAmount) ...[
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Custom Amount (₹)',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    setState(() => _customAmountPaise = parsed != null ? parsed * 100 : null);
                  },
                  validator: (v) {
                    final parsed = int.tryParse(v ?? '');
                    if (parsed == null || parsed < 1) return 'Enter a valid amount';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 24),

              // Donor info
              Text('Your Details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Message (optional)',
                  prefixIcon: Icon(Icons.message_outlined),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Coupon code
              Text('Discount Coupon', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _couponCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Enter coupon code',
                      prefixIcon: Icon(Icons.local_offer_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _couponLoading ? null : _validateCoupon,
                  child: _couponLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Apply'),
                ),
              ]),
              if (_couponMessage.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _couponMessage,
                  style: TextStyle(
                    color: _couponCode != null ? Colors.green : Colors.red,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  _summaryRow('Donation amount',
                      '₹${((_useCustomAmount ? _customAmountPaise ?? 0 : _selectedAmountPaise) / 100).toStringAsFixed(0)}'),
                  if (_discountAmount != null)
                    _summaryRow('Discount', '- ₹${(_discountAmount! / 100).toStringAsFixed(0)}',
                        color: Colors.green),
                  const Divider(),
                  _summaryRow('Total',
                      '₹${(_finalAmountPaise / 100).toStringAsFixed(0)}',
                      bold: true),
                ]),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.favorite),
                  label: Text(_loading ? 'Processing...' : 'Donate Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null),
            Text(value,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : null,
                  color: color,
                )),
          ],
        ),
      );
}

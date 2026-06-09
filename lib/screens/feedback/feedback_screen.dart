import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../../repositories/feedback_repository.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  String _category = 'general';
  int _rating      = 0;
  bool _loading    = false;
  bool _submitted  = false;

  static const _categories = [
    ('general',    'General',    Icons.chat_bubble_outline),
    ('course',     'Course',     Icons.school_outlined),
    ('mentor',     'Mentor',     Icons.person_outline),
    ('event',      'Event',      Icons.event_outlined),
    ('platform',   'Platform',   Icons.devices_outlined),
    ('suggestion', 'Suggestion', Icons.lightbulb_outline),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await FeedbackRepository.submitFeedback(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        category: _category,
        rating: _rating > 0 ? _rating : null,
        subject: _subjectCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
      );
      setState(() => _submitted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit feedback: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: _submitted ? _successView(cs) : _formView(cs),
    );
  }

  Widget _successView(ColorScheme cs) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 80, color: cs.primary),
              const SizedBox(height: 20),
              Text('Thank You!',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                'Your feedback has been submitted. We\'ll review it and respond if needed.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => setState(() {
                  _submitted = false;
                  _formKey.currentState?.reset();
                  _nameCtrl.clear();
                  _emailCtrl.clear();
                  _subjectCtrl.clear();
                  _messageCtrl.clear();
                  _rating = 0;
                  _category = 'general';
                }),
                child: const Text('Submit Another'),
              ),
            ],
          ),
        ),
      );

  Widget _formView(ColorScheme cs) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category chips
              Text('Category',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((c) {
                  final selected = _category == c.$1;
                  return ChoiceChip(
                    avatar: Icon(c.$3, size: 16),
                    label: Text(c.$2),
                    selected: selected,
                    onSelected: (_) => setState(() => _category = c.$1),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Star rating
              Text('Rating (optional)',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              RatingBar.builder(
                initialRating: _rating.toDouble(),
                minRating: 0,
                allowHalfRating: false,
                itemCount: 5,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4),
                itemBuilder: (_, _) =>
                    Icon(Icons.star, color: cs.primary),
                onRatingUpdate: (r) => setState(() => _rating = r.toInt()),
              ),
              const SizedBox(height: 24),

              // Name & email
              Text('Your Details',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Name is required' : null,
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
              const SizedBox(height: 24),

              // Subject & message
              Text('Your Feedback',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subjectCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subject *',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Subject is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Message *',
                  prefixIcon: Icon(Icons.message_outlined),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Message is required' : null,
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: Text(_loading ? 'Submitting...' : 'Submit Feedback'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      );
}

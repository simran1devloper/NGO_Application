import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../models/review.dart';
import '../repositories/review_repository.dart';

/// Drop-in reviews section for any rateable target.
///
/// Usage:
/// ```dart
/// ReviewsSection(
///   targetType: ReviewTargetType.course,
///   targetId: course.id,
///   currentUserId: authVm.userId,
/// )
/// ```
class ReviewsSection extends StatefulWidget {
  const ReviewsSection({
    super.key,
    required this.targetType,
    required this.targetId,
    this.currentUserId,
  });

  final ReviewTargetType targetType;
  final int targetId;
  final int? currentUserId;

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  List<Review> _reviews        = [];
  ReviewSummary? _summary;
  Review? _myReview;
  bool _loading                = true;
  bool _showForm               = false;
  bool _submitting             = false;

  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  int   _formRating = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ReviewRepository.listReviews(
          targetType: widget.targetType,
          targetId:   widget.targetId,
        ),
        ReviewRepository.getSummary(
          targetType: widget.targetType,
          targetId:   widget.targetId,
        ),
      ]);
      final reviews = results[0] as List<Review>;
      final summary = results[1] as ReviewSummary;
      Review? mine;
      if (widget.currentUserId != null) {
        mine = reviews.cast<Review?>().firstWhere(
          (r) => r?.userId == widget.currentUserId,
          orElse: () => null,
        );
      }
      if (mounted) {
        setState(() {
          _reviews  = reviews;
          _summary  = summary;
          _myReview = mine;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _openForm({Review? editing}) {
    if (editing != null) {
      _titleCtrl.text = editing.title ?? '';
      _bodyCtrl.text  = editing.body;
      _formRating     = editing.rating;
    } else {
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _formRating = 5;
    }
    setState(() => _showForm = true);
  }

  Future<void> _submit() async {
    final bodyText = _bodyCtrl.text.trim();
    if (bodyText.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review must be at least 10 characters.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      if (_myReview != null) {
        await ReviewRepository.editReview(
          reviewId: _myReview!.id,
          rating:   _formRating,
          title:    _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
          body:     bodyText,
        );
      } else {
        await ReviewRepository.createReview(
          targetType: widget.targetType,
          targetId:   widget.targetId,
          rating:     _formRating,
          body:       bodyText,
          title:      _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        );
      }
      setState(() => _showForm = false);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete(int reviewId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete review?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ReviewRepository.deleteReview(reviewId);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Summary bar ───────────────────────────────────────────────────────
        _SummaryBar(summary: _summary, loading: _loading),
        const Divider(height: 1),

        // ── My pending review notice ──────────────────────────────────────────
        if (_myReview != null && _myReview!.status == ReviewStatus.pending)
          _StatusBanner(
            message: 'Your review is pending approval by a moderator.',
            color: Colors.orange,
            icon: Icons.hourglass_top_rounded,
          ),
        if (_myReview != null && _myReview!.status == ReviewStatus.rejected)
          _StatusBanner(
            message: 'Your review was rejected: ${_myReview!.rejectionReason ?? "no reason given"}',
            color: Colors.red,
            icon: Icons.cancel_outlined,
          ),

        // ── Write/edit review button ──────────────────────────────────────────
        if (widget.currentUserId != null && !_showForm)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: OutlinedButton.icon(
              onPressed: () => _openForm(editing: _myReview),
              icon: Icon(_myReview == null ? Icons.rate_review_outlined : Icons.edit_outlined, size: 16),
              label: Text(_myReview == null ? 'Write a review' : 'Edit your review'),
            ),
          ),

        // ── Review form ───────────────────────────────────────────────────────
        if (_showForm) _ReviewForm(
          titleCtrl:  _titleCtrl,
          bodyCtrl:   _bodyCtrl,
          rating:     _formRating,
          submitting: _submitting,
          onRating:   (v) => setState(() => _formRating = v),
          onSubmit:   _submit,
          onCancel:   () => setState(() => _showForm = false),
        ),

        // ── Reviews list ──────────────────────────────────────────────────────
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_reviews.isEmpty && !_showForm)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text('No reviews yet.', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reviews.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
            itemBuilder: (_, i) {
              final r = _reviews[i];
              return _ReviewCard(
                review:    r,
                isOwn:     widget.currentUserId == r.userId,
                onEdit:    () => _openForm(editing: r),
                onDelete:  () => _delete(r.id),
              );
            },
          ),
      ],
    );
  }
}

// ── Summary bar ───────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.summary, required this.loading});
  final ReviewSummary? summary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
          const SizedBox(width: 6),
          loading
              ? const SizedBox(width: 60, height: 14, child: LinearProgressIndicator())
              : Text(
                  summary == null || summary!.count == 0
                      ? 'No ratings yet'
                      : '${summary!.averageRating?.toStringAsFixed(1) ?? "-"} · ${summary!.count} review${summary!.count == 1 ? "" : "s"}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
        ],
      ),
    );
  }
}

// ── Status banner ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.color, required this.icon});
  final String message;
  final Color  color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 12))),
        ],
      ),
    );
  }
}

// ── Review form ───────────────────────────────────────────────────────────────

class _ReviewForm extends StatelessWidget {
  const _ReviewForm({
    required this.titleCtrl,
    required this.bodyCtrl,
    required this.rating,
    required this.submitting,
    required this.onRating,
    required this.onSubmit,
    required this.onCancel,
  });

  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;
  final int    rating;
  final bool   submitting;
  final void Function(int) onRating;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your rating', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          RatingBar.builder(
            initialRating: rating.toDouble(),
            minRating: 1,
            itemCount: 5,
            itemSize: 32,
            glowColor: Colors.amber,
            itemBuilder: (_, _) => const Icon(Icons.star_rounded, color: Colors.amber),
            onRatingUpdate: (v) => onRating(v.round()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title (optional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: bodyCtrl,
            maxLines: 4,
            minLines: 2,
            decoration: const InputDecoration(
              labelText: 'Your review (min 10 chars)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: submitting ? null : onSubmit,
                child: submitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Review card ───────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.isOwn,
    required this.onEdit,
    required this.onDelete,
  });

  final Review    review;
  final bool      isOwn;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays >= 30)  return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0)    return '${diff.inDays}d ago';
    if (diff.inHours > 0)   return '${diff.inHours}h ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final name     = review.authorName ?? 'User';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: Colors.deepPurple.shade100,
                child: Text(initials,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.deepPurple, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        if (isOwn) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4)),
                            child: const Text('You',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 14,
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (review.createdAt != null)
                          Text(_timeAgo(review.createdAt!),
                              style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        if (review.isEdited) ...[
                          const SizedBox(width: 4),
                          const Text('(edited)',
                              style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isOwn)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  onSelected: (v) {
                    if (v == 'edit')   onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit, size: 14),
                          SizedBox(width: 6),
                          Text('Edit'),
                        ])),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline, size: 14, color: Colors.red),
                          SizedBox(width: 6),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ])),
                  ],
                ),
            ],
          ),

          // Title + body
          if (review.title != null && review.title!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(review.title!,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
          const SizedBox(height: 4),
          Text(review.body, style: const TextStyle(fontSize: 13)),

          // Moderation transparency badge — shown when review was moderated.
          // No moderator identity is included — only that it was reviewed.
          if (review.moderated) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 11, color: Colors.teal.shade600),
                const SizedBox(width: 4),
                Text(
                  review.moderationLabel ?? 'Reviewed by the moderation team.',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.teal.shade700,
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

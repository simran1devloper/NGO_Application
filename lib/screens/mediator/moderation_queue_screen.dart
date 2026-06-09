import 'package:flutter/material.dart';

import '../../models/review.dart';
import '../../repositories/review_repository.dart';
import '../../repositories/api_client.dart';

/// Three-tab moderation queue for mediators:
///   1. Pending reviews  — approve / reject
///   2. Flagged comments — hide / unhide
///   3. Pending content  — approve / reject posts + events
class ModerationQueueScreen extends StatelessWidget {
  const ModerationQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Moderation Queue'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.rate_review_outlined), text: 'Reviews'),
              Tab(icon: Icon(Icons.flag_outlined),        text: 'Comments'),
              Tab(icon: Icon(Icons.pending_actions),      text: 'Content'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PendingReviewsTab(),
            _FlaggedCommentsTab(),
            _PendingContentTab(),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: Pending Reviews ────────────────────────────────────────────────────

class _PendingReviewsTab extends StatefulWidget {
  const _PendingReviewsTab();

  @override
  State<_PendingReviewsTab> createState() => _PendingReviewsTabState();
}

class _PendingReviewsTabState extends State<_PendingReviewsTab>
    with AutomaticKeepAliveClientMixin {
  List<Review> _reviews = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ReviewRepository.pendingReviews();
      if (mounted) setState(() => _reviews = list);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _approve(Review r) async {
    try {
      await ReviewRepository.approveReview(r.id);
      setState(() => _reviews.removeWhere((x) => x.id == r.id));
      _snack('Review approved');
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  Future<void> _reject(Review r) async {
    final reason = await _promptReason(context, 'Rejection reason');
    if (reason == null) return;
    try {
      await ReviewRepository.rejectReview(r.id, reason);
      setState(() => _reviews.removeWhere((x) => x.id == r.id));
      _snack('Review rejected');
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_reviews.isEmpty) return _empty('No pending reviews');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _reviews.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final r = _reviews[i];
          return _ReviewQueueCard(
            review:    r,
            onApprove: () => _approve(r),
            onReject:  () => _reject(r),
          );
        },
      ),
    );
  }
}

class _ReviewQueueCard extends StatelessWidget {
  const _ReviewQueueCard({
    required this.review,
    required this.onApprove,
    required this.onReject,
  });

  final Review review;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(review.authorName ?? 'User',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                ...List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 14,
                    color: Colors.amber,
                  ),
                ),
                const Spacer(),
                _TargetChip(type: review.targetType.value, id: review.targetId),
              ],
            ),
            if (review.title != null && review.title!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(review.title!,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 4),
            Text(review.body, maxLines: 4, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.cancel_outlined, size: 14, color: Colors.red),
                  label: const Text('Reject', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_circle_outline, size: 14),
                  label: const Text('Approve'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 2: Flagged Comments ───────────────────────────────────────────────────

class _FlaggedCommentsTab extends StatefulWidget {
  const _FlaggedCommentsTab();

  @override
  State<_FlaggedCommentsTab> createState() => _FlaggedCommentsTabState();
}

class _FlaggedCommentsTabState extends State<_FlaggedCommentsTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ApiClient.get('/moderation/comments/flagged') as List<dynamic>;
      if (mounted) {
        setState(() {
          _items = list.cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _hide(int id) async {
    final reason = await _promptReason(context, 'Hide reason (optional)', optional: true);
    if (reason == null) return;
    try {
      await ApiClient.post('/moderation/comments/$id/hide', {'reason': reason});
      await _load();
      _snack('Comment hidden');
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  Future<void> _unhide(int id) async {
    try {
      await ApiClient.post('/moderation/comments/$id/unhide', {});
      await _load();
      _snack('Comment restored');
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return _empty('No flagged comments');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final c  = _items[i];
          final id = c['id'] as int;
          final isHidden = c['is_hidden'] as bool? ?? false;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(c['author_name']?.toString() ?? 'User',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      _FlagBadge(count: c['flag_count'] as int? ?? 0),
                      if (isHidden) ...[
                        const SizedBox(width: 6),
                        const _HiddenBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(c['body']?.toString() ?? '',
                      maxLines: 4, overflow: TextOverflow.ellipsis),
                  if (c['hidden_reason'] != null) ...[
                    const SizedBox(height: 4),
                    Text('Reason: ${c['hidden_reason']}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: isHidden
                        ? OutlinedButton.icon(
                            onPressed: () => _unhide(id),
                            icon: const Icon(Icons.visibility_outlined, size: 14),
                            label: const Text('Restore'),
                          )
                        : FilledButton.icon(
                            onPressed: () => _hide(id),
                            icon: const Icon(Icons.visibility_off_outlined, size: 14),
                            label: const Text('Hide'),
                            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Tab 3: Pending Content ────────────────────────────────────────────────────

class _PendingContentTab extends StatefulWidget {
  const _PendingContentTab();

  @override
  State<_PendingContentTab> createState() => _PendingContentTabState();
}

class _PendingContentTabState extends State<_PendingContentTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _posts  = [];
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.get('/moderation/content/pending') as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _posts  = (data['posts']  as List<dynamic>).cast<Map<String, dynamic>>();
          _events = (data['events'] as List<dynamic>).cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _approvePost(int id) async {
    try {
      await ApiClient.post('/moderation/content/post/$id/approve', {});
      setState(() => _posts.removeWhere((p) => p['id'] == id));
      _snack('Post approved and published');
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  Future<void> _rejectPost(int id) async {
    final reason = await _promptReason(context, 'Rejection reason');
    if (reason == null) return;
    try {
      await ApiClient.post('/moderation/content/post/$id/reject', {'reason': reason});
      setState(() => _posts.removeWhere((p) => p['id'] == id));
      _snack('Post returned to draft');
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  Future<void> _approveEvent(int id) async {
    try {
      await ApiClient.post('/moderation/content/event/$id/approve', {});
      setState(() => _events.removeWhere((e) => e['id'] == id));
      _snack('Event approved and published');
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  Future<void> _rejectEvent(int id) async {
    final reason = await _promptReason(context, 'Rejection reason');
    if (reason == null) return;
    try {
      await ApiClient.post('/moderation/content/event/$id/reject', {'reason': reason});
      setState(() => _events.removeWhere((e) => e['id'] == id));
      _snack('Event returned to draft');
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_posts.isEmpty && _events.isEmpty) return _empty('No pending content');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_posts.isNotEmpty) ...[
            const _SectionHeader(label: 'Posts', icon: Icons.article_outlined),
            const SizedBox(height: 6),
            ..._posts.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ContentCard(
                    title:       p['title']?.toString() ?? 'Untitled',
                    subtitle:    '${p['post_type'] ?? ''} · by ${p['creator_name'] ?? 'Unknown'}',
                    description: p['description']?.toString(),
                    onApprove:   () => _approvePost(p['id'] as int),
                    onReject:    () => _rejectPost(p['id'] as int),
                  ),
                )),
          ],
          if (_events.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _SectionHeader(label: 'Events', icon: Icons.event_outlined),
            const SizedBox(height: 6),
            ..._events.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ContentCard(
                    title:     e['title']?.toString() ?? 'Untitled',
                    subtitle:  '${e['event_type'] ?? ''} · by ${e['creator_name'] ?? 'Unknown'}',
                    onApprove: () => _approveEvent(e['id'] as int),
                    onReject:  () => _rejectEvent(e['id'] as int),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({
    required this.title,
    required this.subtitle,
    this.description,
    required this.onApprove,
    required this.onReject,
  });

  final String title;
  final String subtitle;
  final String? description;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (description != null && description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(description!, maxLines: 3, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13)),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.cancel_outlined, size: 14, color: Colors.red),
                  label: const Text('Reject', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_circle_outline, size: 14),
                  label: const Text('Approve'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
      ],
    );
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({required this.type, required this.id});
  final String type;
  final int    id;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('$type #$id',
          style: TextStyle(fontSize: 10, color: Colors.deepPurple.shade700)),
    );
  }
}

class _FlagBadge extends StatelessWidget {
  const _FlagBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flag_rounded, size: 10, color: Colors.red),
          const SizedBox(width: 2),
          Text('$count', style: const TextStyle(fontSize: 10, color: Colors.red)),
        ],
      ),
    );
  }
}

class _HiddenBadge extends StatelessWidget {
  const _HiddenBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text('hidden',
          style: TextStyle(fontSize: 10, color: Colors.orange)),
    );
  }
}

Widget _empty(String msg) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
          const SizedBox(height: 8),
          Text(msg, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );

/// Shows a dialog prompting for a text reason.
/// Returns null if cancelled.
Future<String?> _promptReason(
  BuildContext context,
  String title, {
  bool optional = false,
}) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: optional ? 'Optional…' : 'Required…',
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final text = ctrl.text.trim();
            if (!optional && text.isEmpty) return;
            Navigator.pop(ctx, text);
          },
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}

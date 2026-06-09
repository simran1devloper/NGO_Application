import 'package:flutter/material.dart';

import 'moderation_queue_screen.dart';

/// Landing screen for mediator-role users.
/// Shows pending-count summary cards + entry point to moderation queue.
class MediatorHomeScreen extends StatelessWidget {
  const MediatorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mediator Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Welcome
          Card(
            color: cs.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 40, color: cs.onPrimaryContainer),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome, Mediator',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          'Review and moderate content, comments, and user reviews submitted by creators and mentors.',
                          style: TextStyle(
                              color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Text('Your responsibilities',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 10),

          // Action tiles
          _ActionTile(
            icon:     Icons.pending_actions_outlined,
            title:    'Moderation Queue',
            subtitle: 'Pending reviews · Flagged comments · Pending content',
            color:    Colors.deepPurple,
            onTap:    () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ModerationQueueScreen(),
              ),
            ),
          ),

          const SizedBox(height: 10),

          _ActionTile(
            icon:     Icons.rate_review_outlined,
            title:    'Approve / Reject Reviews',
            subtitle: 'User-written ratings awaiting approval before publishing',
            color:    Colors.blue,
            onTap:    () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ModerationQueueScreen(),
              ),
            ),
          ),

          const SizedBox(height: 10),

          _ActionTile(
            icon:     Icons.flag_outlined,
            title:    'Flagged Comments',
            subtitle: 'Comments reported by users — hide or restore',
            color:    Colors.orange,
            onTap:    () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ModerationQueueScreen(),
              ),
            ),
          ),

          const SizedBox(height: 10),

          _ActionTile(
            icon:     Icons.article_outlined,
            title:    'Content Approval',
            subtitle: 'Posts and events submitted by creators/mentors for review',
            color:    Colors.teal,
            onTap:    () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ModerationQueueScreen(),
              ),
            ),
          ),

          const SizedBox(height: 24),
          const _MediatorGuidelines(),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String   title;
  final String   subtitle;
  final Color    color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _MediatorGuidelines extends StatelessWidget {
  const _MediatorGuidelines();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey),
                SizedBox(width: 6),
                Text('Moderation guidelines',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        fontSize: 13)),
              ],
            ),
            const SizedBox(height: 10),
            ..._guidelines.map(
              (g) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Colors.grey)),
                    Expanded(
                      child: Text(g,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _guidelines = [
    'Approve reviews that are genuine, constructive, and on-topic.',
    'Reject reviews containing hate speech, spam, or personal attacks.',
    'Hide comments with 3+ flags; investigate before permanent action.',
    'Approve creator content only if it meets community standards.',
    'Always provide a clear rejection reason so the author can improve.',
  ];
}

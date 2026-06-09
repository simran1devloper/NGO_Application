import 'package:flutter/material.dart';

import '../models/reaction.dart';
import '../repositories/reaction_repository.dart';

/// Reusable like / dislike / upvote / downvote bar.
///
/// Usage:
/// ```dart
/// ReactionBar(
///   targetType: TargetType.post,
///   targetId: post.id,
///   showUpvote: false,   // hide upvote/downvote for posts
/// )
/// ```
class ReactionBar extends StatefulWidget {
  const ReactionBar({
    super.key,
    required this.targetType,
    required this.targetId,
    this.showLikeDislike = true,
    this.showUpvoteDownvote = false,
    this.compact = false,
    this.initialCounts,
  });

  final TargetType targetType;
  final int targetId;
  final bool showLikeDislike;
  final bool showUpvoteDownvote;
  final bool compact;
  final ReactionCounts? initialCounts;

  @override
  State<ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<ReactionBar> {
  ReactionCounts? _counts;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCounts != null) {
      _counts = widget.initialCounts;
    } else {
      _loadCounts();
    }
  }

  Future<void> _loadCounts() async {
    try {
      final c = await ReactionRepository.getCounts(
        targetType: widget.targetType,
        targetId: widget.targetId,
      );
      if (mounted) setState(() => _counts = c);
    } catch (_) {}
  }

  Future<void> _toggle(ReactionType type) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final updated = await ReactionRepository.toggle(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reactionType: type,
      );
      if (mounted) setState(() => _counts = updated);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_counts == null) {
      return widget.compact
          ? const SizedBox(height: 28)
          : const SizedBox(height: 36);
    }

    return Wrap(
      spacing: widget.compact ? 6 : 8,
      runSpacing: 4,
      children: [
        if (widget.showLikeDislike) ...[
          _ReactionButton(
            icon: Icons.thumb_up_alt_outlined,
            activeIcon: Icons.thumb_up_alt_rounded,
            label: '${_counts!.like}',
            active: _counts!.userReaction == ReactionType.like,
            activeColor: cs.primary,
            compact: widget.compact,
            onTap: _loading ? null : () => _toggle(ReactionType.like),
          ),
          _ReactionButton(
            icon: Icons.thumb_down_alt_outlined,
            activeIcon: Icons.thumb_down_alt_rounded,
            label: '${_counts!.dislike}',
            active: _counts!.userReaction == ReactionType.dislike,
            activeColor: Colors.redAccent,
            compact: widget.compact,
            onTap: _loading ? null : () => _toggle(ReactionType.dislike),
          ),
        ],
        if (widget.showUpvoteDownvote) ...[
          _ReactionButton(
            icon: Icons.arrow_upward_rounded,
            activeIcon: Icons.arrow_upward_rounded,
            label: '${_counts!.upvote}',
            active: _counts!.userReaction == ReactionType.upvote,
            activeColor: Colors.green,
            compact: widget.compact,
            onTap: _loading ? null : () => _toggle(ReactionType.upvote),
          ),
          _ReactionButton(
            icon: Icons.arrow_downward_rounded,
            activeIcon: Icons.arrow_downward_rounded,
            label: '${_counts!.downvote}',
            active: _counts!.userReaction == ReactionType.downvote,
            activeColor: Colors.orange,
            compact: widget.compact,
            onTap: _loading ? null : () => _toggle(ReactionType.downvote),
          ),
          if (!widget.showLikeDislike)
            _ScorePill(score: _counts!.score),
        ],
      ],
    );
  }
}

// ── Internal widgets ──────────────────────────────────────────────────────────

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.compact,
    this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final Color activeColor;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 16.0 : 18.0;
    final color = active ? activeColor : Colors.grey.shade500;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
            : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? activeColor.withValues(alpha: 0.4) : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? activeIcon : icon, size: size, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 11 : 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score > 0
        ? Colors.green
        : score < 0
            ? Colors.redAccent
            : Colors.grey.shade500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        score > 0 ? '+$score' : '$score',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

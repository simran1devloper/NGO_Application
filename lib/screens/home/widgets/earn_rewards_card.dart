import 'package:flutter/material.dart';

import '../../../app_state.dart';
import '../../../core/colors.dart';
import '../../../models/auth_models.dart';
import '../../../models/reward_models.dart';
import '../../../repositories/reward_repository.dart';
import '../../profile/reward_wallet_screen.dart';

// ── Tip data model ────────────────────────────────────────────────────────────

class _Tip {
  const _Tip({
    required this.icon,
    required this.label,
    required this.points,
    required this.xp,
    this.badge,
  });

  final IconData icon;
  final String label;
  final int points;
  final int xp;
  final String? badge; // e.g. "Hot", "Streak", "x100"
}

// ── Role → tips mapping ───────────────────────────────────────────────────────

const _roleTips = <UserRole, List<_Tip>>{
  UserRole.student: [
    _Tip(icon: Icons.menu_book_rounded,        label: 'Complete a lesson',          points: 10,  xp: 10),
    _Tip(icon: Icons.ondemand_video_rounded,   label: 'Finish a video lesson',      points: 15,  xp: 15),
    _Tip(icon: Icons.school_rounded,           label: 'Complete a full course',     points: 100, xp: 100, badge: 'Big'),
    _Tip(icon: Icons.quiz_rounded,             label: 'Pass a quiz (≥ 60%)',        points: 20,  xp: 20),
    _Tip(icon: Icons.event_available_rounded,  label: 'Register for an event',      points: 10,  xp: 5),
    _Tip(icon: Icons.support_agent_rounded,    label: 'Book a counselling session', points: 5,   xp: 5),
    _Tip(icon: Icons.login_rounded,            label: 'Log in every day',           points: 5,   xp: 5,   badge: 'Streak'),
    _Tip(icon: Icons.local_fire_department_rounded, label: '7-day login streak',    points: 50,  xp: 50,  badge: 'Bonus'),
  ],
  UserRole.contentCreator: [
    _Tip(icon: Icons.add_box_rounded,          label: 'Create a new lesson',        points: 20,  xp: 20),
    _Tip(icon: Icons.library_add_rounded,      label: 'Create a new course',        points: 50,  xp: 50,  badge: 'Big'),
    _Tip(icon: Icons.attach_file_rounded,      label: 'Upload a learning resource', points: 10,  xp: 10),
    _Tip(icon: Icons.verified_rounded,         label: 'Get a post approved',        points: 30,  xp: 20),
    _Tip(icon: Icons.event_rounded,            label: 'Publish an event',           points: 25,  xp: 25),
    _Tip(icon: Icons.login_rounded,            label: 'Log in every day',           points: 5,   xp: 5,   badge: 'Streak'),
    _Tip(icon: Icons.local_fire_department_rounded, label: 'Maintain a 30-day streak', points: 200, xp: 200, badge: 'Epic'),
  ],
  UserRole.mentor: [
    _Tip(icon: Icons.handshake_rounded,        label: 'Conduct a counselling session', points: 40, xp: 30, badge: 'Top'),
    _Tip(icon: Icons.add_box_rounded,          label: 'Create a lesson',            points: 20,  xp: 20),
    _Tip(icon: Icons.library_add_rounded,      label: 'Create a course',            points: 50,  xp: 50,  badge: 'Big'),
    _Tip(icon: Icons.event_rounded,            label: 'Publish an event',           points: 25,  xp: 25),
    _Tip(icon: Icons.login_rounded,            label: 'Log in every day',           points: 5,   xp: 5,   badge: 'Streak'),
    _Tip(icon: Icons.local_fire_department_rounded, label: '14-day streak bonus',   points: 100, xp: 100, badge: 'Bonus'),
  ],
  UserRole.eventManager: [
    _Tip(icon: Icons.event_rounded,            label: 'Publish an event',           points: 25,  xp: 25,  badge: 'Top'),
    _Tip(icon: Icons.verified_rounded,         label: 'Get an event approved',      points: 25,  xp: 25),
    _Tip(icon: Icons.login_rounded,            label: 'Log in every day',           points: 5,   xp: 5,   badge: 'Streak'),
    _Tip(icon: Icons.local_fire_department_rounded, label: '7-day streak bonus',    points: 50,  xp: 50,  badge: 'Bonus'),
  ],
  UserRole.mediator: [
    _Tip(icon: Icons.login_rounded,            label: 'Log in every day',           points: 5,   xp: 5,   badge: 'Streak'),
    _Tip(icon: Icons.local_fire_department_rounded, label: '7-day streak bonus',    points: 50,  xp: 50,  badge: 'Bonus'),
    _Tip(icon: Icons.task_alt_rounded,         label: 'Complete assigned tasks',    points: 50,  xp: 50),
  ],
  UserRole.supportStaff: [
    _Tip(icon: Icons.login_rounded,            label: 'Log in every day',           points: 5,   xp: 5,   badge: 'Streak'),
    _Tip(icon: Icons.local_fire_department_rounded, label: '7-day streak bonus',    points: 50,  xp: 50,  badge: 'Bonus'),
    _Tip(icon: Icons.task_alt_rounded,         label: 'Complete assigned tasks',    points: 50,  xp: 50),
  ],
};

// ── Badge colours ─────────────────────────────────────────────────────────────

Color _badgeColor(String badge) => switch (badge) {
  'Big'    => const Color(0xFF4CAF50),
  'Epic'   => const Color(0xFF9C27B0),
  'Top'    => const Color(0xFF2196F3),
  'Bonus'  => const Color(0xFFFF9800),
  'Streak' => const Color(0xFFFF5722),
  _        => AppColors.accent,
};

// ── Role gradient colours ─────────────────────────────────────────────────────

List<Color> _roleGradient(UserRole role) => switch (role) {
  UserRole.contentCreator => [const Color(0xFF6C63FF), const Color(0xFF9C8FFF)],
  UserRole.mentor         => [const Color(0xFF00897B), const Color(0xFF26A69A)],
  UserRole.eventManager   => [const Color(0xFFE91E63), const Color(0xFFEC407A)],
  UserRole.mediator       => [const Color(0xFF455A64), const Color(0xFF607D8B)],
  UserRole.supportStaff   => [const Color(0xFF5D4037), const Color(0xFF795548)],
  _                       => [const Color(0xFF1565C0), const Color(0xFF1E88E5)],
};

String _roleEmoji(UserRole role) => switch (role) {
  UserRole.contentCreator => '🎬',
  UserRole.mentor         => '🤝',
  UserRole.eventManager   => '🎪',
  UserRole.mediator       => '⚖️',
  UserRole.supportStaff   => '🛡️',
  UserRole.admin          => '👑',
  UserRole.superAdmin     => '👑',
  _                       => '🎓',
};

// ── Main widget ───────────────────────────────────────────────────────────────

class EarnRewardsCard extends StatefulWidget {
  const EarnRewardsCard({super.key});

  @override
  State<EarnRewardsCard> createState() => _EarnRewardsCardState();
}

class _EarnRewardsCardState extends State<EarnRewardsCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _rotate = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  List<_Tip> get _tips {
    final roles = AppState.roles;
    // Union tips from all held roles, deduplicating by label
    final seen = <String>{};
    final result = <_Tip>[];
    for (final role in roles) {
      for (final tip in _roleTips[role] ?? _roleTips[UserRole.student]!) {
        if (seen.add(tip.label)) result.add(tip);
      }
    }
    return result;
  }

  UserRole get _primaryRole {
    for (final r in [
      UserRole.contentCreator, UserRole.mentor, UserRole.eventManager,
      UserRole.mediator, UserRole.supportStaff, UserRole.admin, UserRole.superAdmin,
    ]) {
      if (AppState.roles.contains(r)) return r;
    }
    return UserRole.student;
  }

  Future<void> _goToWallet() async {
    try {
      final results = await Future.wait([
        RewardRepository.getMyRewards(),
        RewardRepository.getMyTasks(),
      ]);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RewardWalletScreen(
          summary: results[0] as RewardSummary,
          tasks: results[1] as List<RewardTask>,
          initialTab: 0,
        ),
      ));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final role = _primaryRole;
    final gradient = _roleGradient(role);
    final tips = _tips;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header row ────────────────────────────────────────────
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Text(_roleEmoji(role), style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'How to Earn Rewards',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${tips.length} ways to earn — tap to ${_expanded ? 'hide' : 'explore'}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _goToWallet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Wallet',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  RotationTransition(
                    turns: _rotate,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable tips list ───────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: _expanded
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Divider(color: Colors.white24, height: 1),
                        ...tips.map((tip) => _TipRow(tip: tip)),
                        _WalletCta(onTap: _goToWallet),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Tip row ───────────────────────────────────────────────────────────────────

class _TipRow extends StatelessWidget {
  const _TipRow({required this.tip});
  final _Tip tip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(tip.icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tip.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (tip.badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _badgeColor(tip.badge!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tip.badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _MiniChip(
                icon: Icons.stars_rounded,
                label: '+${tip.points}',
                color: const Color(0xFFFFD700),
              ),
              const SizedBox(height: 3),
              _MiniChip(
                icon: Icons.bolt_rounded,
                label: '+${tip.xp} XP',
                color: Colors.white70,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ── CTA at bottom of expanded panel ──────────────────────────────────────────

class _WalletCta extends StatelessWidget {
  const _WalletCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white30),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text(
              'Open Reward Wallet',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

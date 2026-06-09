import 'package:flutter/material.dart';

import '../../../models/reward_models.dart';
import '../../../repositories/reward_repository.dart';
import '../../profile/reward_wallet_screen.dart';

class StreakCard extends StatefulWidget {
  const StreakCard({super.key});

  @override
  State<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<StreakCard> {
  UserStreak? _streak;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await RewardRepository.getMyStreak();
      if (mounted) setState(() => _streak = s);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final streak = _streak;
    if (streak == null || streak.currentStreak == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () async {
        final summary = await RewardRepository.getMyRewards();
        final tasks = await RewardRepository.getMyTasks();
        if (!context.mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => RewardWalletScreen(
            summary: summary,
            tasks: tasks,
            initialTab: 3,
          ),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${streak.currentStreak}-Day Streak!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Best: ${streak.longestStreak} days · ${streak.totalActiveDays} total active days',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20),
                const SizedBox(height: 2),
                Text(
                  'View',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

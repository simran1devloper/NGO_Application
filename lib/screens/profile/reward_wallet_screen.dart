import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/colors.dart';
import '../../models/reward_models.dart';
import '../../repositories/reward_repository.dart';

class RewardWalletScreen extends StatefulWidget {
  const RewardWalletScreen({
    required this.summary,
    required this.tasks,
    this.initialTab = 0,
    super.key,
  });

  final RewardSummary summary;
  final List<RewardTask> tasks;
  final int initialTab;

  @override
  State<RewardWalletScreen> createState() => _RewardWalletScreenState();
}

class _RewardWalletScreenState extends State<RewardWalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late RewardSummary _summary;
  late List<RewardTask> _tasks;
  UserStreak? _streak;
  List<UserMilestone> _milestones = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this, initialIndex: widget.initialTab.clamp(0, 3));
    _summary = widget.summary;
    _tasks = widget.tasks;
    _loadExtras();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadExtras() async {
    try {
      final results = await Future.wait([
        RewardRepository.getMyStreak(),
        RewardRepository.getMyMilestones(),
      ]);
      if (mounted) {
        setState(() {
          _streak = results[0] as UserStreak;
          _milestones = results[1] as List<UserMilestone>;
        });
      }
    } catch (_) {}
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        RewardRepository.getMyRewards(),
        RewardRepository.getMyTasks(),
        RewardRepository.getMyStreak(),
        RewardRepository.getMyMilestones(),
      ]);
      setState(() {
        _summary = results[0] as RewardSummary;
        _tasks = results[1] as List<RewardTask>;
        _streak = results[2] as UserStreak;
        _milestones = results[3] as List<UserMilestone>;
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _advanceTask(int taskId) async {
    try {
      final updated = await RewardRepository.advanceTask(taskId);
      setState(() {
        final idx = _tasks.indexWhere((t) => t.id == taskId);
        if (idx != -1) _tasks[idx] = updated;
      });
      await _refresh();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.ink),
        title: const Text(
          'Reward Wallet',
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                  )
                : const Icon(Icons.refresh_rounded, color: AppColors.ink),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.accent,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'History'),
            Tab(text: 'Tasks'),
            Tab(text: 'Send Gift'),
            Tab(text: 'Milestones'),
          ],
        ),
      ),
      body: Column(
        children: [
          _WalletHeader(summary: _summary, streak: _streak),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _HistoryTab(rewards: _summary.rewards),
                _TasksTab(tasks: _tasks, onAdvance: _advanceTask, onRefresh: _refresh),
                _GiftTab(onSent: _refresh),
                _MilestonesTab(milestones: _milestones),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Wallet header ─────────────────────────────────────────────────────────────

class _WalletHeader extends StatelessWidget {
  const _WalletHeader({required this.summary, this.streak});
  final RewardSummary summary;
  final UserStreak? streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded, color: AppColors.accent, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Rewards',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                if (streak != null && streak!.currentStreak > 0)
                  Text(
                    '🔥 ${streak!.currentStreak}-day streak · ${summary.rewards.length} transactions',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  )
                else
                  Text(
                    '${summary.rewards.length} transactions',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Pill(
                icon: Icons.stars_rounded,
                label: '${summary.totalPoints} pts',
                color: AppColors.accent,
              ),
              const SizedBox(height: 6),
              _Pill(
                icon: Icons.bolt_rounded,
                label: '${summary.totalXpFromRewards} XP',
                color: AppColors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ── History tab ───────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.rewards});
  final List<RewardTransaction> rewards;

  @override
  Widget build(BuildContext context) {
    if (rewards.isEmpty) {
      return const _EmptyState(
        icon: Icons.workspace_premium_outlined,
        message: 'No rewards yet.\nComplete lessons, videos, courses, or tasks to earn rewards.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: rewards.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 48),
      itemBuilder: (_, i) => _TransactionTile(reward: rewards[i]),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.reward});
  final RewardTransaction reward;

  static (IconData, Color) _meta(String trigger) => switch (trigger) {
    'gift'             => (Icons.card_giftcard_rounded,      AppColors.accent),
    'lesson_completed' => (Icons.menu_book_rounded,          AppColors.primary),
    'video_completed'  => (Icons.play_circle_rounded,        const Color(0xFFE91E8C)),
    'course_completed' => (Icons.school_rounded,             AppColors.secondary),
    'topic_completed'  => (Icons.check_circle_rounded,       AppColors.secondary),
    'task_completed'   => (Icons.task_alt_rounded,           const Color(0xFF6B48FF)),
    'task_progress'    => (Icons.trending_up_rounded,        AppColors.primary),
    'manual'           => (Icons.stars_rounded,              AppColors.accent),
    _                  => (Icons.workspace_premium_rounded,  AppColors.accent),
  };

  static String _fmt(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _meta(reward.trigger);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (reward.message != null && reward.message!.isNotEmpty)
                  Text(
                    reward.message!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                Text(
                  _fmt(reward.createdAt),
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (reward.points > 0)
                Text(
                  '+${reward.points} pts',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              if (reward.xp > 0)
                Text(
                  '+${reward.xp} XP',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tasks tab ─────────────────────────────────────────────────────────────────

class _TasksTab extends StatelessWidget {
  const _TasksTab({
    required this.tasks,
    required this.onAdvance,
    required this.onRefresh,
  });
  final List<RewardTask> tasks;
  final Future<void> Function(int taskId) onAdvance;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final active = tasks.where((t) => !t.isCompleted).toList();
    final done   = tasks.where((t) => t.isCompleted).toList();

    if (tasks.isEmpty) {
      return const _EmptyState(
        icon: Icons.checklist_rounded,
        message: 'No tasks assigned yet.\nYour mentor or admin will assign reward tasks.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (active.isNotEmpty) ...[
          _SectionHead(title: 'Active Tasks', count: active.length, color: AppColors.primary),
          const SizedBox(height: 8),
          ...active.map((t) => _TaskCard(task: t, onAdvance: () => onAdvance(t.id))),
        ],
        if (done.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionHead(title: 'Completed', count: done.length, color: AppColors.secondary),
          const SizedBox(height: 8),
          ...done.map((t) => _TaskCard(task: t, onAdvance: null)),
        ],
      ],
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.title, required this.count, required this.color});
  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '$count',
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends StatefulWidget {
  const _TaskCard({required this.task, required this.onAdvance});
  final RewardTask task;
  final VoidCallback? onAdvance;

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _busy = false;

  Future<void> _advance() async {
    if (widget.onAdvance == null) return;
    setState(() => _busy = true);
    await Future.microtask(widget.onAdvance!);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final progress = task.progress.clamp(0.0, 1.0);
    final color = task.isCompleted ? AppColors.secondary : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (task.description != null && task.description!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        task.description!,
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!task.isCompleted)
                IconButton.filledTonal(
                  onPressed: _busy ? null : _advance,
                  tooltip: 'Add progress',
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_task_rounded, size: 18),
                )
              else
                const Icon(Icons.task_alt_rounded, color: AppColors.secondary),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${task.currentCount}/${task.targetCount} steps',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              const Spacer(),
              if (task.rewardPoints > 0)
                Text(
                  '+${task.rewardPoints} pts',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              if (task.rewardPoints > 0 && task.rewardXp > 0)
                const Text('  ', style: TextStyle(fontSize: 11)),
              if (task.rewardXp > 0)
                Text(
                  '+${task.rewardXp} XP',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          if (task.dueAt != null) ...[
            const SizedBox(height: 4),
            _DueDateLabel(dueAt: task.dueAt!),
          ],
        ],
      ),
    );
  }
}

class _DueDateLabel extends StatelessWidget {
  const _DueDateLabel({required this.dueAt});
  final DateTime dueAt;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final overdue = dueAt.isBefore(now);
    final color = overdue ? AppColors.softRed : AppColors.muted;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final formatted = '${dueAt.day} ${months[dueAt.month - 1]} ${dueAt.year}';
    return Row(
      children: [
        Icon(Icons.event_outlined, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          'Due $formatted${overdue ? ' · Overdue' : ''}',
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ── Gift tab ──────────────────────────────────────────────────────────────────

class _GiftTab extends StatefulWidget {
  const _GiftTab({required this.onSent});
  final VoidCallback onSent;

  @override
  State<_GiftTab> createState() => _GiftTabState();
}

class _GiftTabState extends State<_GiftTab> {
  final _formKey = GlobalKey<FormState>();
  final _recipientCtrl = TextEditingController();
  final _pointsCtrl    = TextEditingController();
  final _titleCtrl     = TextEditingController(text: 'Gift reward');
  final _messageCtrl   = TextEditingController();
  bool _sending = false;
  String? _successMsg;
  String? _errorMsg;

  @override
  void dispose() {
    _recipientCtrl.dispose();
    _pointsCtrl.dispose();
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final recipientId = int.tryParse(_recipientCtrl.text.trim());
    if (recipientId == null) return;
    if (recipientId == AppState.userId) {
      setState(() => _errorMsg = 'You cannot gift points to yourself.');
      return;
    }
    setState(() { _sending = true; _errorMsg = null; _successMsg = null; });
    try {
      await RewardRepository.sendGift(
        recipientId: recipientId,
        points: int.parse(_pointsCtrl.text.trim()),
        title: _titleCtrl.text.trim().isEmpty ? 'Gift reward' : _titleCtrl.text.trim(),
        message: _messageCtrl.text.trim().isEmpty ? null : _messageCtrl.text.trim(),
      );
      setState(() => _successMsg = 'Gift sent successfully!');
      _recipientCtrl.clear();
      _pointsCtrl.clear();
      _messageCtrl.clear();
      _titleCtrl.text = 'Gift reward';
      widget.onSent();
    } catch (e) {
      setState(() => _errorMsg = 'Failed to send gift. Check the user ID and points amount.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.card_giftcard_rounded, color: AppColors.accent, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send a Gift',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Reward another user with points as a gift. Max 1,000 pts per gift.',
                          style: TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_successMsg != null)
              _FeedbackBanner(message: _successMsg!, isError: false),
            if (_errorMsg != null)
              _FeedbackBanner(message: _errorMsg!, isError: true),
            if (_successMsg != null || _errorMsg != null)
              const SizedBox(height: 12),

            _Field(
              controller: _recipientCtrl,
              label: 'Recipient User ID',
              hint: 'Enter the user\'s numeric ID',
              icon: Icons.person_outline_rounded,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter a user ID';
                if (int.tryParse(v.trim()) == null) return 'Must be a number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _pointsCtrl,
              label: 'Points to Gift',
              hint: '1 – 1000',
              icon: Icons.stars_rounded,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter points amount';
                final pts = int.tryParse(v.trim());
                if (pts == null || pts < 1) return 'Must be at least 1';
                if (pts > 1000) return 'Maximum 1,000 per gift';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _titleCtrl,
              label: 'Title',
              hint: 'Gift reward',
              icon: Icons.title_rounded,
              validator: (v) => v == null || v.trim().isEmpty ? 'Enter a title' : null,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _messageCtrl,
              label: 'Message (optional)',
              hint: 'Add a personal note…',
              icon: Icons.message_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_sending ? 'Sending…' : 'Send Gift'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.message, required this.isError});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.softRed : AppColors.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: AppColors.muted),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.muted.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.muted.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
      ),
    );
  }
}

// ── Milestones tab ────────────────────────────────────────────────────────────

class _MilestonesTab extends StatelessWidget {
  const _MilestonesTab({required this.milestones});
  final List<UserMilestone> milestones;

  static const _triggerIcons = {
    'xp_': Icons.bolt_rounded,
    'lessons_': Icons.menu_book_rounded,
    'courses_': Icons.school_rounded,
    'posts_': Icons.article_rounded,
    'sessions_': Icons.support_agent_rounded,
    'streak_': Icons.local_fire_department_rounded,
  };

  IconData _icon(String key) {
    for (final entry in _triggerIcons.entries) {
      if (key.startsWith(entry.key)) return entry.value;
    }
    return Icons.emoji_events_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (milestones.isEmpty) {
      return const _EmptyState(
        icon: Icons.emoji_events_outlined,
        message: 'No milestones yet.\nKeep learning, creating, and logging in daily to unlock achievements.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: milestones.length,
      separatorBuilder: (context, i) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final m = milestones[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8E0F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon(m.milestoneKey), color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.title,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    if (m.description != null && m.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        m.description!,
                        style: const TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(m.achievedAt),
                      style: const TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (m.points > 0)
                    _Pill(
                      icon: Icons.stars_rounded,
                      label: '+${m.points}',
                      color: AppColors.accent,
                    ),
                  if (m.xp > 0) ...[
                    const SizedBox(height: 4),
                    _Pill(
                      icon: Icons.bolt_rounded,
                      label: '+${m.xp} XP',
                      color: AppColors.secondary,
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

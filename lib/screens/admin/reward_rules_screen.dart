import 'package:flutter/material.dart';

import '../../core/colors.dart';
import '../../models/reward_models.dart';
import '../../repositories/reward_repository.dart';

class RewardRulesScreen extends StatefulWidget {
  const RewardRulesScreen({super.key});

  @override
  State<RewardRulesScreen> createState() => _RewardRulesScreenState();
}

class _RewardRulesScreenState extends State<RewardRulesScreen> {
  List<RewardRule> _rules = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _rules = await RewardRepository.getRewardRules();
    } catch (_) {
      _error = 'Failed to load reward rules.';
    }
    if (mounted) setState(() => _loading = false);
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
          'Reward Rules',
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.ink),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, null),
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Rule', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorBody(message: _error!, onRetry: _load)
              : _rules.isEmpty
                  ? const _EmptyBody()
                  : _RulesList(
                      rules: _rules,
                      onEdit: (rule) => _openForm(context, rule),
                      onToggle: _toggleActive,
                    ),
    );
  }

  Future<void> _openForm(BuildContext context, RewardRule? existing) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RuleForm(existing: existing, onSave: _saveRule),
    );
    if (saved == true) _load();
  }

  Future<void> _saveRule({
    required String role,
    required String trigger,
    required int points,
    required int xp,
    required String title,
    String? description,
    bool isActive = true,
    int? existingId,
  }) async {
    if (existingId != null) {
      await RewardRepository.updateRewardRule(
        existingId,
        points: points,
        xp: xp,
        title: title,
        description: description,
        isActive: isActive,
      );
    } else {
      await RewardRepository.createRewardRule(
        role: role,
        trigger: trigger,
        points: points,
        xp: xp,
        title: title,
        description: description,
        isActive: isActive,
      );
    }
  }

  Future<void> _toggleActive(RewardRule rule) async {
    try {
      await RewardRepository.updateRewardRule(rule.id, isActive: !rule.isActive);
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update rule.')),
        );
      }
    }
  }
}

// ── Rules list ────────────────────────────────────────────────────────────────

class _RulesList extends StatelessWidget {
  const _RulesList({required this.rules, required this.onEdit, required this.onToggle});
  final List<RewardRule> rules;
  final void Function(RewardRule) onEdit;
  final void Function(RewardRule) onToggle;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<RewardRule>>{};
    for (final r in rules) {
      grouped.putIfAbsent(r.role, () => []).add(r);
    }
    final roles = grouped.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 15, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rules override the default reward amounts per role and trigger. If no rule exists, defaults apply.',
                  style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        for (final role in roles) ...[
          _RoleSection(
            role: role,
            rules: grouped[role]!,
            onEdit: onEdit,
            onToggle: onToggle,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _RoleSection extends StatelessWidget {
  const _RoleSection({
    required this.role,
    required this.rules,
    required this.onEdit,
    required this.onToggle,
  });
  final String role;
  final List<RewardRule> rules;
  final void Function(RewardRule) onEdit;
  final void Function(RewardRule) onToggle;

  static (Color, String) _roleMeta(String role) => switch (role) {
    'mentor'          => (AppColors.secondary,     'Counsellor'),
    'content_creator' => (AppColors.accent,         'Content Creator'),
    'mediator'        => (const Color(0xFF009688),  'Mediator'),
    'event_manager'   => (const Color(0xFFE91E8C),  'Event Manager'),
    'support_staff'   => (const Color(0xFF795548),  'Support Staff'),
    'admin'           => (const Color(0xFF6B48FF),  'Admin'),
    'super_admin'     => (const Color(0xFF6B48FF),  'Super Admin'),
    'guest'           => (AppColors.muted,           'Guest'),
    _                 => (AppColors.primary,         _displayRole(role)),
  };

  static String _displayRole(String r) =>
      r.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');

  @override
  Widget build(BuildContext context) {
    final (color, label) = _roleMeta(role);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Text('${rules.length} rule${rules.length == 1 ? '' : 's'}',
                style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 8),
        ...rules.map((r) => _RuleTile(rule: r, onEdit: () => onEdit(r), onToggle: () => onToggle(r))),
      ],
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule, required this.onEdit, required this.onToggle});
  final RewardRule rule;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  static String _triggerLabel(String t) => switch (t) {
    'gift'             => 'Gift',
    'lesson_completed' => 'Lesson Completed',
    'video_completed'  => 'Video Completed',
    'course_completed' => 'Course Completed',
    'topic_completed'  => 'Topic Completed',
    'task_progress'    => 'Task Progress',
    'task_completed'   => 'Task Completed',
    'manual'           => 'Manual Award',
    _                  => t,
  };

  static IconData _triggerIcon(String t) => switch (t) {
    'gift'             => Icons.card_giftcard_rounded,
    'lesson_completed' => Icons.menu_book_rounded,
    'video_completed'  => Icons.play_circle_rounded,
    'course_completed' => Icons.school_rounded,
    'topic_completed'  => Icons.check_circle_rounded,
    'task_progress'    => Icons.trending_up_rounded,
    'task_completed'   => Icons.task_alt_rounded,
    _                  => Icons.stars_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rule.isActive
              ? AppColors.muted.withValues(alpha: 0.15)
              : AppColors.muted.withValues(alpha: 0.08),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: rule.isActive ? 0.12 : 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _triggerIcon(rule.trigger),
            size: 18,
            color: rule.isActive ? AppColors.accent : AppColors.muted,
          ),
        ),
        title: Text(
          rule.title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: rule.isActive ? AppColors.ink : AppColors.muted,
          ),
        ),
        subtitle: Text(
          _triggerLabel(rule.trigger),
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${rule.points} pts',
                  style: TextStyle(
                    color: rule.isActive ? AppColors.accent : AppColors.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '+${rule.xp} XP',
                  style: TextStyle(
                    color: rule.isActive ? AppColors.secondary : AppColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.muted),
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'toggle') onToggle();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: const Text('Edit')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(rule.isActive ? 'Disable' : 'Enable'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Rule form (create / edit) ─────────────────────────────────────────────────

class _RuleForm extends StatefulWidget {
  const _RuleForm({required this.existing, required this.onSave});
  final RewardRule? existing;
  final Future<void> Function({
    required String role,
    required String trigger,
    required int points,
    required int xp,
    required String title,
    String? description,
    bool isActive,
    int? existingId,
  }) onSave;

  @override
  State<_RuleForm> createState() => _RuleFormState();
}

class _RuleFormState extends State<_RuleForm> {
  final _formKey = GlobalKey<FormState>();
  late String _role;
  late String _trigger;
  final _pointsCtrl = TextEditingController();
  final _xpCtrl     = TextEditingController();
  final _titleCtrl  = TextEditingController();
  final _descCtrl   = TextEditingController();
  bool _isActive = true;
  bool _saving = false;
  String? _error;

  static const _roles = [
    ('student',         'Student'),
    ('mentor',          'Counsellor'),
    ('content_creator', 'Content Creator'),
    ('mediator',        'Mediator'),
    ('event_manager',   'Event Manager'),
    ('support_staff',   'Support Staff'),
    ('guest',           'Guest'),
  ];

  static const _triggers = [
    ('lesson_completed', 'Lesson Completed'),
    ('video_completed',  'Video Completed'),
    ('course_completed', 'Course Completed'),
    ('topic_completed',  'Topic Completed'),
    ('task_progress',    'Task Progress'),
    ('task_completed',   'Task Completed'),
    ('gift',             'Gift'),
    ('manual',           'Manual Award'),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _role    = e?.role    ?? 'student';
    _trigger = e?.trigger ?? 'lesson_completed';
    _pointsCtrl.text = '${e?.points ?? 10}';
    _xpCtrl.text     = '${e?.xp ?? 10}';
    _titleCtrl.text  = e?.title ?? '';
    _descCtrl.text   = e?.description ?? '';
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _pointsCtrl.dispose();
    _xpCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await widget.onSave(
        role: _role,
        trigger: _trigger,
        points: int.parse(_pointsCtrl.text.trim()),
        xp: int.parse(_xpCtrl.text.trim()),
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        isActive: _isActive,
        existingId: widget.existing?.id,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      setState(() { _error = 'Failed to save rule.'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6DCEA),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isEdit ? 'Edit Reward Rule' : 'New Reward Rule',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Set custom reward amounts per role and trigger.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 18),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.softRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!, style: const TextStyle(color: AppColors.softRed, fontSize: 12)),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!isEdit) ...[
                  _DropdownField(
                    label: 'Role',
                    value: _role,
                    items: _roles,
                    onChanged: (v) => setState(() => _role = v!),
                  ),
                  const SizedBox(height: 12),
                  _DropdownField(
                    label: 'Trigger',
                    value: _trigger,
                    items: _triggers,
                    onChanged: (v) => setState(() => _trigger = v!),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _titleCtrl,
                  decoration: _deco('Title', Icons.title_rounded),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter a title' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _pointsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _deco('Points', Icons.stars_rounded),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null || n < 0) return 'Enter ≥ 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _xpCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _deco('XP', Icons.bolt_rounded),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null || n < 0) return 'Enter ≥ 0';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: _deco('Description (optional)', Icons.notes_rounded),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  title: const Text('Active', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: const Text('Inactive rules are ignored when awarding rewards.',
                      style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.secondary,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          isEdit ? 'Save Changes' : 'Create Rule',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static InputDecoration _deco(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: AppColors.muted),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
      );
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final String value;
  final List<(String, String)> items;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

// ── Empty / error states ──────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rule_rounded, size: 52, color: AppColors.muted),
            SizedBox(height: 16),
            Text(
              'No custom rules yet.\nTap + to create role-specific reward overrides.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/colors.dart';
import '../../models/api_models.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../viewmodels/view_state.dart';
import 'user_approval_detail_screen.dart';

class PendingApprovalsScreen extends StatefulWidget {
  const PendingApprovalsScreen({super.key});

  @override
  State<PendingApprovalsScreen> createState() => _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState extends State<PendingApprovalsScreen> {
  late final AdminViewModel _vm;
  final Set<int> _selected = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _vm = AdminViewModel();
    _vm.loadPendingUsers();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  void _toggleSelection(int userId) {
    setState(() {
      if (_selected.contains(userId)) {
        _selected.remove(userId);
        if (_selected.isEmpty) _selectionMode = false;
      } else {
        _selected.add(userId);
        _selectionMode = true;
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selected.addAll(_vm.pendingUsers.map((u) => u.id));
      _selectionMode = true;
    });
  }

  void _clearSelection() {
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close, color: AppColors.ink),
                onPressed: _clearSelection,
              )
            : const BackButton(color: AppColors.ink),
        title: _selectionMode
            ? Text(
                '${_selected.length} selected',
                style: const TextStyle(
                    color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 18),
              )
            : const Text(
                'Pending Approvals',
                style: TextStyle(
                    color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 18),
              ),
        actions: _selectionMode
            ? [
                TextButton.icon(
                  onPressed: _selectAll,
                  icon: const Icon(Icons.select_all, size: 18),
                  label: const Text('All'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.ink),
                ),
                FilledButton.icon(
                  onPressed: () => _bulkApprove(),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Approve'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                ),
                const SizedBox(width: 8),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.ink),
                  tooltip: 'Refresh',
                  onPressed: _vm.loadPendingUsers,
                ),
              ],
      ),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          if (_vm.state == ViewState.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_vm.state == ViewState.error) {
            return _ErrorPanel(
              message: _vm.errorMessage ?? 'Failed to load pending users.',
              onRetry: _vm.loadPendingUsers,
            );
          }
          if (_vm.pendingUsers.isEmpty) {
            return const _EmptyPanel();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _vm.pendingUsers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final user = _vm.pendingUsers[i];
              return _PendingUserCard(
                user: user,
                isSelected: _selected.contains(user.id),
                selectionMode: _selectionMode,
                onTap: _selectionMode
                    ? () => _toggleSelection(user.id)
                    : () => _openDetail(user),
                onLongPress: () => _toggleSelection(user.id),
                onApprove: () => _quickApprove(user),
                onReject:  () => _quickReject(user),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _bulkApprove() async {
    if (_selected.isEmpty) return;
    final role = await _pickRole();
    if (role == null || !mounted) return;

    final confirmed = await _showConfirmDialog(
      title: 'Approve ${_selected.length} users as ${_roleLabel(role)}?',
      body: 'All selected users will be granted ${_roleLabel(role)} access.',
      confirmLabel: 'Approve All',
      confirmColor: AppColors.accent,
    );
    if (!confirmed || !mounted) return;

    final result = await _vm.bulkApprove(
      userIds: _selected.toList(),
      role: role,
    );
    _clearSelection();
    if (mounted) {
      final approved = (result['approved'] as List?)?.length ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$approved user(s) approved as ${_roleLabel(role)}.'),
        backgroundColor: AppColors.accent,
      ));
    }
  }

  Future<String?> _pickRole() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Assign Role', style: TextStyle(fontWeight: FontWeight.w800)),
        children: [
          'student', 'mentor', 'content_creator', 'admin',
        ].map((r) => SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r),
              child: Text(_roleLabel(r)),
            )).toList(),
      ),
    );
  }

  Future<void> _openDetail(PendingUserItem user) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            UserApprovalDetailScreen(userId: user.id, vm: _vm),
      ),
    );
    if (changed == true && mounted) setState(() {});
  }

  Future<void> _quickApprove(PendingUserItem user) async {
    final role = user.requestedRole ?? 'student';
    final confirmed = await _showConfirmDialog(
      title: 'Approve as ${_roleLabel(role)}?',
      body: 'This will grant ${user.name} access to the ${_roleLabel(role)} dashboard.',
      confirmLabel: 'Approve',
      confirmColor: AppColors.accent,
    );
    if (!confirmed || !mounted) return;
    final ok = await _vm.assignRole(userId: user.id, role: role);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? '${user.name} approved as ${_roleLabel(role)}.'
                : _vm.errorMessage ?? 'Failed to approve.',
          ),
          backgroundColor: ok ? AppColors.accent : AppColors.softRed,
        ),
      );
    }
  }

  Future<void> _quickReject(PendingUserItem user) async {
    final confirmed = await _showConfirmDialog(
      title: 'Reject ${user.name}\'s request?',
      body: 'Their access request will be marked as rejected.',
      confirmLabel: 'Reject',
      confirmColor: AppColors.softRed,
    );
    if (!confirmed || !mounted) return;
    final ok = await _vm.rejectUser(user.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Request rejected.' : _vm.errorMessage ?? 'Failed to reject.',
          ),
          backgroundColor: ok ? AppColors.muted : AppColors.softRed,
        ),
      );
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Text(body, style: const TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: confirmColor),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static String _roleLabel(String role) => switch (role) {
        'mentor'           => 'Mentor',
        'content_creator'  => 'Content Creator',
        'admin'            => 'Admin',
        _                  => 'Student',
      };
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _PendingUserCard extends StatelessWidget {
  const _PendingUserCard({
    required this.user,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
    this.isSelected = false,
    this.selectionMode = false,
    this.onLongPress,
  });

  final PendingUserItem user;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final requestLabel = _roleChipLabel(user.requestedRole);
    final requestColor = _roleColor(user.requestedRole);
    final dateStr = _formatDate(user.createdAt);

    return Material(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.07)
          : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ────────────────────────────────────────
              Row(
                children: [
                  if (selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: isSelected ? AppColors.primary : AppColors.muted,
                        size: 22,
                      ),
                    ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      user.name.isNotEmpty
                          ? user.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: requestColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      requestLabel,
                      style: TextStyle(
                        color: requestColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),

              // ── Details row ───────────────────────────────────────
              if (user.schoolName != null ||
                  user.className != null ||
                  user.location != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (user.className != null)
                      _InfoChip(
                        icon: Icons.class_outlined,
                        label: 'Class ${user.className}',
                      ),
                    if (user.schoolName != null)
                      _InfoChip(
                        icon: Icons.apartment_outlined,
                        label: user.schoolName!,
                      ),
                    if (user.location != null)
                      _InfoChip(
                        icon: Icons.location_on_outlined,
                        label: user.location!,
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 12,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Registered $dateStr',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),

                  // ── Quick actions ──────────────────────────────────
                  TextButton(
                    onPressed: onReject,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.softRed,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Reject',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: onApprove,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Approve',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _roleChipLabel(String? role) => switch (role) {
        'mentor'           => 'Requests Mentor',
        'content_creator'  => 'Requests Creator',
        _                  => 'Student',
      };

  static Color _roleColor(String? role) => switch (role) {
        'mentor'           => AppColors.secondary,
        'content_creator'  => AppColors.accent,
        _                  => AppColors.primary,
      };

  static String _formatDate(DateTime d) {
    final day   = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppColors.muted),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }
}

// ── Empty / Error states ──────────────────────────────────────────────────────

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 64,
              color: AppColors.accent,
            ),
            SizedBox(height: 16),
            Text(
              'All clear!',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'No users are waiting for approval.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

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
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppColors.muted,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

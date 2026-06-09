import 'package:flutter/material.dart';

import '../../core/colors.dart';
import '../../models/api_models.dart';
import '../../viewmodels/admin_viewmodel.dart';
import 'user_approval_detail_screen.dart';

/// Full user management table with search, filter, and actions.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({required this.vm, super.key});

  final AdminViewModel vm;

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _searchCtrl = TextEditingController();
  String _filterRole   = '';
  String _filterStatus = '';
  bool   _loading      = false;
  final Set<int> _selected = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    await widget.vm.loadAllUsers(
      search: _searchCtrl.text.trim(),
      role:   _filterRole.isEmpty   ? null : _filterRole,
      status: _filterStatus.isEmpty ? null : _filterStatus,
    );
    if (mounted) setState(() => _loading = false);
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

  void _clearSelection() => setState(() { _selected.clear(); _selectionMode = false; });

  Future<void> _bulkDelete() async {
    if (_selected.isEmpty) return;
    final confirmed = await _confirm(
      title: 'Delete ${_selected.length} user(s)?',
      body: 'This cannot be undone. All selected users will be permanently removed.',
      confirmLabel: 'Delete All',
      confirmColor: AppColors.softRed,
    );
    if (!confirmed || !mounted) return;
    final result = await widget.vm.bulkDelete(_selected.toList());
    _clearSelection();
    if (mounted) {
      final deleted = (result['deleted'] as List?)?.length ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$deleted user(s) deleted.'),
        backgroundColor: AppColors.softRed,
      ));
    }
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
            ? Text('${_selected.length} selected',
                style: const TextStyle(
                    color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 18))
            : const Text('User Management',
                style: TextStyle(
                    color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 18)),
        actions: _selectionMode
            ? [
                FilledButton.icon(
                  onPressed: _bulkDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.softRed),
                ),
                const SizedBox(width: 8),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.ink),
                  tooltip: 'Refresh',
                  onPressed: _fetch,
                ),
              ],
      ),
      body: Column(
        children: [
          // ── Search + filters ─────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _fetch(),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email…',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () { _searchCtrl.clear(); _fetch(); },
                          ),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _Chip(label: 'All',        selected: _filterStatus.isEmpty && _filterRole.isEmpty,
                            onTap: () { setState(() { _filterStatus = ''; _filterRole = ''; }); _fetch(); }),
                      _Chip(label: 'Pending',    color: const Color(0xFFFF8C00),
                            selected: _filterStatus == 'pending_verification',
                            onTap: () { setState(() { _filterStatus = 'pending_verification'; _filterRole = ''; }); _fetch(); }),
                      _Chip(label: 'Approved',   color: AppColors.secondary,
                            selected: _filterStatus == 'approved',
                            onTap: () { setState(() { _filterStatus = 'approved'; _filterRole = ''; }); _fetch(); }),
                      _Chip(label: 'Blocked',    color: AppColors.softRed,
                            selected: _filterStatus == 'deactivated',
                            onTap: () { setState(() { _filterStatus = 'deactivated'; _filterRole = ''; }); _fetch(); }),
                      _Chip(label: 'Rejected',   color: AppColors.muted,
                            selected: _filterStatus == 'rejected',
                            onTap: () { setState(() { _filterStatus = 'rejected'; _filterRole = ''; }); _fetch(); }),
                      const SizedBox(width: 12),
                      _Chip(label: 'Students',   color: AppColors.primary,
                            selected: _filterRole == 'student',
                            onTap: () { setState(() { _filterRole = 'student'; _filterStatus = ''; }); _fetch(); }),
                      _Chip(label: 'Counsellors', color: AppColors.secondary,
                            selected: _filterRole == 'mentor',
                            onTap: () { setState(() { _filterRole = 'mentor'; _filterStatus = ''; }); _fetch(); }),
                      _Chip(label: 'Creators',   color: AppColors.accent,
                            selected: _filterRole == 'content_creator',
                            onTap: () { setState(() { _filterRole = 'content_creator'; _filterStatus = ''; }); _fetch(); }),
                      _Chip(label: 'Mediators',  color: const Color(0xFF009688),
                            selected: _filterRole == 'mediator',
                            onTap: () { setState(() { _filterRole = 'mediator'; _filterStatus = ''; }); _fetch(); }),
                      _Chip(label: 'Event Mgrs', color: const Color(0xFFE91E8C),
                            selected: _filterRole == 'event_manager',
                            onTap: () { setState(() { _filterRole = 'event_manager'; _filterStatus = ''; }); _fetch(); }),
                      _Chip(label: 'Support',    color: const Color(0xFF795548),
                            selected: _filterRole == 'support_staff',
                            onTap: () { setState(() { _filterRole = 'support_staff'; _filterStatus = ''; }); _fetch(); }),
                      _Chip(label: 'Admins',     color: const Color(0xFF6B48FF),
                            selected: _filterRole == 'admin',
                            onTap: () { setState(() { _filterRole = 'admin'; _filterStatus = ''; }); _fetch(); }),
                    ].map((w) => Padding(padding: const EdgeInsets.only(right: 6), child: w)).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Table ─────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListenableBuilder(
                    listenable: widget.vm,
                    builder: (_, _) {
                      final users = widget.vm.allUsers;
                      if (users.isEmpty) {
                        return const _EmptyView();
                      }
                      return _UsersTable(
                        users: users,
                        selectedIds:   _selected,
                        selectionMode: _selectionMode,
                        onView:       (u) => _openDetail(u),
                        onBlock:      (u) => _block(u),
                        onUnblock:    (u) => _unblock(u),
                        onDelete:     (u) => _delete(u),
                        onAssign:     (u) => _openDetail(u),
                        onToggleSelect: (u) => _toggleSelection(u.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openDetail(AdminUserItem user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserApprovalDetailScreen(userId: user.id, vm: widget.vm),
      ),
    );
  }

  Future<void> _block(AdminUserItem user) async {
    final confirmed = await _confirm(
      title: 'Block ${user.name}?',
      body: '${user.name} will lose access to the platform.',
      confirmLabel: 'Block',
      confirmColor: AppColors.softRed,
    );
    if (!confirmed || !mounted) return;
    final ok = await widget.vm.blockUser(user.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '${user.name} blocked.' : widget.vm.errorMessage ?? 'Failed.'),
        backgroundColor: ok ? AppColors.softRed : Colors.grey,
      ));
    }
  }

  Future<void> _unblock(AdminUserItem user) async {
    final ok = await widget.vm.unblockUser(user.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '${user.name} unblocked.' : widget.vm.errorMessage ?? 'Failed.'),
        backgroundColor: ok ? AppColors.secondary : Colors.grey,
      ));
    }
  }

  Future<void> _delete(AdminUserItem user) async {
    final confirmed = await _confirm(
      title: 'Delete ${user.name}?',
      body: 'This cannot be undone. All user data will be permanently removed.',
      confirmLabel: 'Delete',
      confirmColor: AppColors.softRed,
    );
    if (!confirmed || !mounted) return;
    final ok = await widget.vm.deleteUser(user.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '${user.name} deleted.' : widget.vm.errorMessage ?? 'Failed.'),
        backgroundColor: ok ? AppColors.muted : Colors.grey,
      ));
    }
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text(body, style: const TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
}

// ── Table ─────────────────────────────────────────────────────────────────────

class _UsersTable extends StatelessWidget {
  const _UsersTable({
    required this.users,
    required this.onView,
    required this.onBlock,
    required this.onUnblock,
    required this.onDelete,
    required this.onAssign,
    required this.onToggleSelect,
    required this.selectedIds,
    required this.selectionMode,
  });

  final List<AdminUserItem>          users;
  final void Function(AdminUserItem) onView;
  final void Function(AdminUserItem) onBlock;
  final void Function(AdminUserItem) onUnblock;
  final void Function(AdminUserItem) onDelete;
  final void Function(AdminUserItem) onAssign;
  final void Function(AdminUserItem) onToggleSelect;
  final Set<int>                     selectedIds;
  final bool                         selectionMode;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Column headers ───────────────────────────────────────────
          Container(
            color: const Color(0xFFF0F4FF),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Row(
              children: [
                _HeaderCell('#',         width: 36),
                _HeaderCell('User',      flex: 3),
                _HeaderCell('Role',      flex: 2),
                _HeaderCell('Location',  flex: 2),
                _HeaderCell('Status',    flex: 2),
                _HeaderCell('Registered', flex: 2),
                _HeaderCell('Approval',  flex: 2),
                _HeaderCell('Actions',   flex: 3),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Rows ─────────────────────────────────────────────────────
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: users.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (_, i) => _UserRow(
              index: i + 1,
              user: users[i],
              isSelected:    selectedIds.contains(users[i].id),
              selectionMode: selectionMode,
              onView:        () => onView(users[i]),
              onBlock:       () => onBlock(users[i]),
              onUnblock:     () => onUnblock(users[i]),
              onDelete:      () => onDelete(users[i]),
              onAssign:      () => onAssign(users[i]),
              onLongPress:   () => onToggleSelect(users[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {this.width, this.flex});
  final String label;
  final double? width;
  final int?    flex;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
    );
    if (width != null) return SizedBox(width: width, child: child);
    return Expanded(flex: flex ?? 1, child: child);
  }
}

// ── Single row ────────────────────────────────────────────────────────────────

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.index,
    required this.user,
    required this.onView,
    required this.onBlock,
    required this.onUnblock,
    required this.onDelete,
    required this.onAssign,
    this.isSelected = false,
    this.selectionMode = false,
    this.onLongPress,
  });

  final int           index;
  final AdminUserItem user;
  final VoidCallback  onView;
  final VoidCallback  onBlock;
  final VoidCallback  onUnblock;
  final VoidCallback  onDelete;
  final VoidCallback  onAssign;
  final bool          isSelected;
  final bool          selectionMode;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(user.accessStatus);
    final statusLabel = _statusLabel(user.accessStatus);
    final approvalColor = _approvalColor(user.accessStatus);
    final approvalLabel = _approvalLabel(user.accessStatus);

    return InkWell(
      onTap: selectionMode ? onLongPress : onView,
      onLongPress: onLongPress,
      child: Container(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.07)
            : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── # / checkbox ───────────────────────────────────────────
            SizedBox(
              width: 36,
              child: selectionMode
                  ? Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: isSelected ? AppColors.primary : AppColors.muted,
                    )
                  : Text(
                      '$index',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),

            // ── User (avatar + name + email) ───────────────────────────
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Role ───────────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final role in user.roles.isNotEmpty
                      ? user.roles
                      : [user.role])
                    _RoleBadge(role: role),
                ],
              ),
            ),

            // ── Location ───────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Text(
                user.location?.isNotEmpty == true ? user.location! : '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),

            // ── Status (active/blocked) ────────────────────────────────
            Expanded(
              flex: 2,
              child: _Badge(
                label: statusLabel,
                color: statusColor,
              ),
            ),

            // ── Registered date ────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Text(
                _fmt(user.createdAt),
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),

            // ── Approval status ────────────────────────────────────────
            Expanded(
              flex: 2,
              child: _Badge(
                label: approvalLabel,
                color: approvalColor,
              ),
            ),

            // ── Actions ────────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: _ActionsCell(
                user: user,
                onView:    onView,
                onBlock:   onBlock,
                onUnblock: onUnblock,
                onDelete:  onDelete,
                onAssign:  onAssign,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(String s) => switch (s) {
        'approved'             => AppColors.secondary,
        'pending_verification' => const Color(0xFFFF8C00),
        'deactivated'          => AppColors.softRed,
        _                      => AppColors.muted,
      };

  static String _statusLabel(String s) => switch (s) {
        'approved'             => 'Active',
        'pending_verification' => 'Pending',
        'deactivated'          => 'Blocked',
        'rejected'             => 'Rejected',
        _                      => s,
      };

  static Color _approvalColor(String s) => switch (s) {
        'approved'             => AppColors.secondary,
        'pending_verification' => const Color(0xFFFF8C00),
        'rejected'             => AppColors.softRed,
        'deactivated'          => AppColors.softRed,
        _                      => AppColors.muted,
      };

  static String _approvalLabel(String s) => switch (s) {
        'approved'             => 'Approved',
        'pending_verification' => 'Waiting',
        'rejected'             => 'Rejected',
        'deactivated'          => 'Blocked',
        _                      => s,
      };

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Actions cell ──────────────────────────────────────────────────────────────

class _ActionsCell extends StatelessWidget {
  const _ActionsCell({
    required this.user,
    required this.onView,
    required this.onBlock,
    required this.onUnblock,
    required this.onDelete,
    required this.onAssign,
  });

  final AdminUserItem user;
  final VoidCallback  onView;
  final VoidCallback  onBlock;
  final VoidCallback  onUnblock;
  final VoidCallback  onDelete;
  final VoidCallback  onAssign;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        _MiniBtn(icon: Icons.visibility_outlined, tooltip: 'View', color: AppColors.primary, onTap: onView),
        if (user.isPending)
          _MiniBtn(icon: Icons.check_circle_outline_rounded, tooltip: 'Approve', color: AppColors.secondary, onTap: onAssign),
        if (user.isBlocked)
          _MiniBtn(icon: Icons.lock_open_rounded, tooltip: 'Unblock', color: AppColors.secondary, onTap: onUnblock)
        else if (!user.isPending)
          _MiniBtn(icon: Icons.block_rounded, tooltip: 'Block', color: AppColors.softRed, onTap: onBlock),
        _MiniBtn(icon: Icons.manage_accounts_rounded, tooltip: 'Assign Role', color: const Color(0xFF6B48FF), onTap: onAssign),
        _MiniBtn(icon: Icons.delete_outline_rounded, tooltip: 'Delete', color: AppColors.muted, onTap: onDelete),
      ],
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData     icon;
  final String       tooltip;
  final Color        color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

// ── Badge ─────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  static final _config = {
    'student':         (AppColors.primary,        'Student'),
    'mentor':          (AppColors.secondary,       'Counsellor'),
    'content_creator': (AppColors.accent,          'Creator'),
    'mediator':        (const Color(0xFF009688),   'Mediator'),
    'event_manager':   (const Color(0xFFE91E8C),   'Event Mgr'),
    'support_staff':   (const Color(0xFF795548),   'Support'),
    'admin':           (const Color(0xFF6B48FF),   'Admin'),
    'super_admin':     (const Color(0xFF6B48FF),   'Super Admin'),
    'guest':           (AppColors.muted,           'Guest'),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _config[role] ?? (AppColors.muted, role);
    return _Badge(label: cfg.$2, color: cfg.$1);
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String       label;
  final bool         selected;
  final VoidCallback onTap;
  final Color?       color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.ink;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c : AppColors.muted.withValues(alpha: 0.3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? c : AppColors.muted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded, size: 56, color: AppColors.muted),
            SizedBox(height: 12),
            Text(
              'No users found yet.',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Registered users will appear here.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

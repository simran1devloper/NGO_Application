import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/colors.dart';
import '../../models/api_models.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../viewmodels/view_state.dart';
import '../events/admin/event_manager_screen.dart';
import '../helping_support/admin/counselling_admin_screen.dart';
import '../helping_support/admin/emergency_contacts_admin_screen.dart';
import '../home/admin/safety_awareness_manager_screen.dart';
import 'google_calendar_setup_screen.dart';
import 'pending_approvals_screen.dart';
import 'reward_rules_screen.dart';
import 'user_approval_detail_screen.dart';
import 'user_management_screen.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  late final AdminViewModel _vm;
  late final TextEditingController _searchCtrl;
  Timer? _searchDebounce;
  String? _roleFilter;
  String? _statusFilter;
  bool _newestFirst = true;
  bool _tableLoading = false;

  @override
  void initState() {
    super.initState();
    _vm = AdminViewModel();
    _searchCtrl = TextEditingController();
    _loadDashboard();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminName = (AppState.studentName ?? 'Admin').split(' ').first;
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final users = _sortedUsers(_vm.allUsers);
        return RefreshIndicator(
          onRefresh: _loadDashboard,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            children: [
              _AdminHeader(
                name: adminName,
                role: AppState.role.displayName,
                unreadCount: _vm.unreadCount,
                onBellTap: _openNotifications,
              ),
              const SizedBox(height: 16),
              _StatsSummary(
                stats: _vm.stats,
                pendingApprovals: _vm.pendingCount,
                unreadNotifications: _vm.unreadCount,
                onPendingTap: _openPendingApprovals,
                onNotificationTap: _openNotifications,
              ),
              const SizedBox(height: 16),
              _NotificationsPanel(
                notifications: _vm.notifications,
                unreadCount: _vm.unreadCount,
                onMarkAllRead: _vm.markAllRead,
                onMarkRead: _vm.markNotificationRead,
                onViewAll: _openNotifications,
              ),
              const SizedBox(height: 16),
              _UserManagementPanel(
                users: users,
                isLoading: _tableLoading || _vm.state == ViewState.loading,
                searchController: _searchCtrl,
                roleFilter: _roleFilter,
                statusFilter: _statusFilter,
                newestFirst: _newestFirst,
                onSearchChanged: _onSearchChanged,
                onRoleChanged: (value) {
                  setState(() => _roleFilter = value);
                  _loadUsers();
                },
                onStatusChanged: (value) {
                  setState(() => _statusFilter = value);
                  _loadUsers();
                },
                onSortChanged: (value) =>
                    setState(() => _newestFirst = value ?? true),
                onRefresh: _loadDashboard,
                onViewAll: _openUserManagement,
                onView: _openDetail,
                onApprove: _approveUser,
                onReject: _rejectUser,
                onBlock: _blockUser,
                onUnblock: _unblockUser,
                onAssignRole: _assignRole,
              ),
              const SizedBox(height: 16),
              _ManagementTools(
                pendingCount: _vm.pendingCount,
                totalUsers: _vm.stats.totalUsers,
                onOpenPending: _openPendingApprovals,
                onOpenUsers: _openUserManagement,
                onOpenEvents: () => _push(const EventManagerScreen()),
                onOpenCounselling: () => _push(const CounsellingAdminScreen()),
                onOpenSafety: () => _push(const SafetyAwarenessManagerScreen()),
                onOpenEmergency: () => _push(const EmergencyContactsAdminScreen()),
                onOpenCalendar: () => _push(const GoogleCalendarSetupScreen()),
                onOpenRewards: () => _push(const RewardRulesScreen()),
              ),
            ],
          ),
        );
      },
    );
  }

  List<AdminUserItem> _sortedUsers(List<AdminUserItem> users) {
    final sorted = [...users]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return _newestFirst ? sorted.reversed.toList() : sorted;
  }

  Future<void> _loadDashboard() async {
    setState(() => _tableLoading = true);
    await _vm.load();
    await _loadUsers(showLoading: false);
  }

  Future<void> _loadUsers({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _tableLoading = true);
    await _vm.loadAllUsers(
      search: _searchCtrl.text.trim(),
      role: _roleFilter,
      status: _statusFilter,
    );
    if (mounted) setState(() => _tableLoading = false);
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadUsers);
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _openUserManagement() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => UserManagementScreen(vm: _vm)));
  }

  void _openPendingApprovals() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PendingApprovalsScreen()));
  }

  Future<void> _openDetail(AdminUserItem user) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UserApprovalDetailScreen(userId: user.id, vm: _vm),
      ),
    );
    if (changed == true) await _loadDashboard();
  }

  void _openNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationsSheet(vm: _vm),
    );
  }

  Future<void> _approveUser(AdminUserItem user) async {
    final role = user.requestedRole ?? user.role;
    final ok = await _vm.assignRole(userId: user.id, role: role);
    _showSnack(
      ok ? '${user.name} approved as ${_roleLabel(role)}.' : _vm.errorMessage,
      ok ? AppColors.secondary : AppColors.softRed,
    );
    if (ok) await _loadDashboard();
  }

  Future<void> _rejectUser(AdminUserItem user) async {
    final confirmed = await _confirm(
      title: 'Reject ${user.name}?',
      body: '${user.name} will not be able to access the platform.',
      confirmLabel: 'Reject',
      confirmColor: AppColors.softRed,
    );
    if (!confirmed) return;
    final ok = await _vm.rejectUser(user.id);
    _showSnack(
      ok ? '${user.name} rejected.' : _vm.errorMessage,
      ok ? AppColors.softRed : AppColors.softRed,
    );
    if (ok) await _loadDashboard();
  }

  Future<void> _blockUser(AdminUserItem user) async {
    final confirmed = await _confirm(
      title: 'Block ${user.name}?',
      body: '${user.name} will lose access until an admin unblocks them.',
      confirmLabel: 'Block',
      confirmColor: AppColors.softRed,
    );
    if (!confirmed) return;
    final ok = await _vm.blockUser(user.id);
    _showSnack(
      ok ? '${user.name} blocked.' : _vm.errorMessage,
      ok ? AppColors.softRed : AppColors.softRed,
    );
    if (ok) await _loadDashboard();
  }

  Future<void> _unblockUser(AdminUserItem user) async {
    final ok = await _vm.unblockUser(user.id);
    _showSnack(
      ok ? '${user.name} unblocked.' : _vm.errorMessage,
      ok ? AppColors.secondary : AppColors.softRed,
    );
    if (ok) await _loadDashboard();
  }

  Future<void> _assignRole(AdminUserItem user) async {
    final role = await showDialog<String>(
      context: context,
      builder: (ctx) => _RoleAssignmentDialog(user: user),
    );
    if (role == null) return;
    final ok = await _vm.assignRole(userId: user.id, role: role);
    _showSnack(
      ok ? '${user.name} updated to ${_roleLabel(role)}.' : _vm.errorMessage,
      ok ? AppColors.primary : AppColors.softRed,
    );
    if (ok) await _loadDashboard();
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
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
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

  void _showSnack(String? message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? 'Action failed.'),
        backgroundColor: color,
      ),
    );
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({
    required this.name,
    required this.role,
    required this.unreadCount,
    required this.onBellTap,
  });

  final String name;
  final String role;
  final int unreadCount;
  final VoidCallback onBellTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi $name',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                role,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton.filledTonal(
              onPressed: onBellTap,
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_rounded),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 3,
                right: 3,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.softRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 17),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StatsSummary extends StatelessWidget {
  const _StatsSummary({
    required this.stats,
    required this.pendingApprovals,
    required this.unreadNotifications,
    required this.onPendingTap,
    required this.onNotificationTap,
  });

  final AdminStats stats;
  final int pendingApprovals;
  final int unreadNotifications;
  final VoidCallback onPendingTap;
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricData(
        icon: Icons.people_alt_rounded,
        label: 'Total Users',
        value: stats.totalUsers,
        color: AppColors.ink,
      ),
      _MetricData(
        icon: Icons.verified_user_rounded,
        label: 'Active Users',
        value: stats.activeUsers,
        color: AppColors.secondary,
      ),
      _MetricData(
        icon: Icons.schedule_rounded,
        label: 'Pending Users',
        value: stats.pendingUsers,
        color: AppColors.accent,
      ),
      _MetricData(
        icon: Icons.block_rounded,
        label: 'Blocked Users',
        value: stats.blockedUsers,
        color: AppColors.softRed,
      ),
      _MetricData(
        icon: Icons.fact_check_rounded,
        label: 'Pending Approvals',
        value: pendingApprovals,
        color: const Color(0xFFFF8C00),
        onTap: onPendingTap,
      ),
      _MetricData(
        icon: Icons.notifications_active_rounded,
        label: 'Unread Notifications',
        value: unreadNotifications,
        color: const Color(0xFF6B48FF),
        onTap: onNotificationTap,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: columns == 1 ? 3.5 : 2.65,
          ),
          itemBuilder: (_, i) => _MetricCard(data: items[i]),
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final VoidCallback? onTap;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: data.color.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: data.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${data.value}',
                      style: TextStyle(
                        color: data.color,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      data.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationsPanel extends StatelessWidget {
  const _NotificationsPanel({
    required this.notifications,
    required this.unreadCount,
    required this.onMarkAllRead,
    required this.onMarkRead,
    required this.onViewAll,
  });

  final List<AdminNotification> notifications;
  final int unreadCount;
  final VoidCallback onMarkAllRead;
  final ValueChanged<int> onMarkRead;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final visible = notifications.take(3).toList();
    return _Panel(
      title: 'Registration Notifications',
      action: unreadCount > 0
          ? TextButton.icon(
              onPressed: onMarkAllRead,
              icon: const Icon(Icons.done_all_rounded, size: 17),
              label: const Text('Mark all read'),
            )
          : TextButton(onPressed: onViewAll, child: const Text('View all')),
      child: visible.isEmpty
          ? const _InlineEmpty(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications yet.',
              subtitle: 'New user registrations will appear here.',
            )
          : Column(
              children: [
                for (final notification in visible)
                  _NotificationTile(
                    notification: notification,
                    onTap: () => onMarkRead(notification.id),
                  ),
                if (notifications.length > visible.length)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onViewAll,
                      child: Text('View ${notifications.length} notifications'),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _UserManagementPanel extends StatelessWidget {
  const _UserManagementPanel({
    required this.users,
    required this.isLoading,
    required this.searchController,
    required this.roleFilter,
    required this.statusFilter,
    required this.newestFirst,
    required this.onSearchChanged,
    required this.onRoleChanged,
    required this.onStatusChanged,
    required this.onSortChanged,
    required this.onRefresh,
    required this.onViewAll,
    required this.onView,
    required this.onApprove,
    required this.onReject,
    required this.onBlock,
    required this.onUnblock,
    required this.onAssignRole,
  });

  final List<AdminUserItem> users;
  final bool isLoading;
  final TextEditingController searchController;
  final String? roleFilter;
  final String? statusFilter;
  final bool newestFirst;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onRoleChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<bool?> onSortChanged;
  final VoidCallback onRefresh;
  final VoidCallback onViewAll;
  final ValueChanged<AdminUserItem> onView;
  final ValueChanged<AdminUserItem> onApprove;
  final ValueChanged<AdminUserItem> onReject;
  final ValueChanged<AdminUserItem> onBlock;
  final ValueChanged<AdminUserItem> onUnblock;
  final ValueChanged<AdminUserItem> onAssignRole;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'User Management',
      action: IconButton(
        onPressed: onRefresh,
        tooltip: 'Refresh users',
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: Column(
        children: [
          _UserTableToolbar(
            searchController: searchController,
            roleFilter: roleFilter,
            statusFilter: statusFilter,
            newestFirst: newestFirst,
            onSearchChanged: onSearchChanged,
            onRoleChanged: onRoleChanged,
            onStatusChanged: onStatusChanged,
            onSortChanged: onSortChanged,
          ),
          const SizedBox(height: 14),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 42),
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else if (users.isEmpty)
            const _InlineEmpty(
              icon: Icons.people_outline_rounded,
              title: 'No users found yet.',
              subtitle: 'Try changing the search or filters.',
            )
          else
            _AdminUsersTable(
              users: users,
              onView: onView,
              onApprove: onApprove,
              onReject: onReject,
              onBlock: onBlock,
              onUnblock: onUnblock,
              onAssignRole: onAssignRole,
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.group_rounded,
                color: AppColors.primary.withValues(alpha: 0.9),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '${users.length} users shown',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onViewAll,
                icon: const Icon(Icons.open_in_full_rounded, size: 16),
                label: const Text('Open full screen'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserTableToolbar extends StatelessWidget {
  const _UserTableToolbar({
    required this.searchController,
    required this.roleFilter,
    required this.statusFilter,
    required this.newestFirst,
    required this.onSearchChanged,
    required this.onRoleChanged,
    required this.onStatusChanged,
    required this.onSortChanged,
  });

  final TextEditingController searchController;
  final String? roleFilter;
  final String? statusFilter;
  final bool newestFirst;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onRoleChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<bool?> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final search = TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search by name or email',
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.muted,
            ),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppColors.muted.withValues(alpha: 0.24),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppColors.muted.withValues(alpha: 0.18),
              ),
            ),
          ),
        );
        final filters = [
          _AdminDropdown<String>(
            value: roleFilter,
            hint: 'Role',
            icon: Icons.admin_panel_settings_outlined,
            items: const [
              DropdownMenuItem(value: null, child: Text('All roles')),
              DropdownMenuItem(value: 'student', child: Text('Student')),
              DropdownMenuItem(
                value: 'content_creator',
                child: Text('Content Creator'),
              ),
              DropdownMenuItem(value: 'mentor', child: Text('Counsellor')),
              DropdownMenuItem(value: 'mediator', child: Text('Mediator')),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
            ],
            onChanged: onRoleChanged,
          ),
          _AdminDropdown<String>(
            value: statusFilter,
            hint: 'Status',
            icon: Icons.tune_rounded,
            items: const [
              DropdownMenuItem(value: null, child: Text('All statuses')),
              DropdownMenuItem(value: 'approved', child: Text('Active')),
              DropdownMenuItem(
                value: 'pending_verification',
                child: Text('Pending'),
              ),
              DropdownMenuItem(value: 'deactivated', child: Text('Blocked')),
            ],
            onChanged: onStatusChanged,
          ),
          _AdminDropdown<bool>(
            value: newestFirst,
            hint: 'Sort',
            icon: Icons.sort_rounded,
            items: const [
              DropdownMenuItem(value: true, child: Text('Newest first')),
              DropdownMenuItem(value: false, child: Text('Oldest first')),
            ],
            onChanged: onSortChanged,
          ),
        ];

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: search),
              const SizedBox(width: 10),
              for (final filter in filters) ...[
                SizedBox(width: 170, child: filter),
                const SizedBox(width: 10),
              ],
            ],
          );
        }

        return Column(
          children: [
            search,
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final filter in filters) ...[
                    SizedBox(width: 168, child: filter),
                    const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AdminDropdown<T> extends StatelessWidget {
  const _AdminDropdown({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  final T? value;
  final String hint;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: AppColors.muted),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.muted.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: AppColors.muted.withValues(alpha: 0.16),
          ),
        ),
      ),
      hint: Text(hint),
      items: items,
      onChanged: onChanged,
    );
  }
}

class _AdminUsersTable extends StatelessWidget {
  const _AdminUsersTable({
    required this.users,
    required this.onView,
    required this.onApprove,
    required this.onReject,
    required this.onBlock,
    required this.onUnblock,
    required this.onAssignRole,
  });

  final List<AdminUserItem> users;
  final ValueChanged<AdminUserItem> onView;
  final ValueChanged<AdminUserItem> onApprove;
  final ValueChanged<AdminUserItem> onReject;
  final ValueChanged<AdminUserItem> onBlock;
  final ValueChanged<AdminUserItem> onUnblock;
  final ValueChanged<AdminUserItem> onAssignRole;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < 1080
            ? 1080.0
            : constraints.maxWidth;
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.muted.withValues(alpha: 0.16),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Column(
                  children: [
                    const _TableHeader(),
                    for (var i = 0; i < users.length; i++)
                      _TableUserRow(
                        user: users[i],
                        tinted: i.isOdd,
                        onView: () => onView(users[i]),
                        onApprove: () => onApprove(users[i]),
                        onReject: () => onReject(users[i]),
                        onBlock: () => onBlock(users[i]),
                        onUnblock: () => onUnblock(users[i]),
                        onAssignRole: () => onAssignRole(users[i]),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F8FF),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: const Row(
        children: [
          _HeaderCell('Name', width: 190),
          _HeaderCell('Email ID', width: 220),
          _HeaderCell('Role', width: 140),
          _HeaderCell('Location', width: 150),
          _HeaderCell('Status', width: 118),
          _HeaderCell('Approval', width: 150),
          _HeaderCell('Registered', width: 112),
          _HeaderCell('Actions', width: 170),
        ],
      ),
    );
  }
}

class _TableUserRow extends StatefulWidget {
  const _TableUserRow({
    required this.user,
    required this.tinted,
    required this.onView,
    required this.onApprove,
    required this.onReject,
    required this.onBlock,
    required this.onUnblock,
    required this.onAssignRole,
  });

  final AdminUserItem user;
  final bool tinted;
  final VoidCallback onView;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onBlock;
  final VoidCallback onUnblock;
  final VoidCallback onAssignRole;

  @override
  State<_TableUserRow> createState() => _TableUserRowState();
}

class _TableUserRowState extends State<_TableUserRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final background = _hovering
        ? AppColors.primary.withValues(alpha: 0.05)
        : widget.tinted
        ? const Color(0xFFFCFDFF)
        : Colors.white;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onView,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: background,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              SizedBox(
                width: 190,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: _roleColor(
                        user.role,
                      ).withValues(alpha: 0.14),
                      child: Text(
                        _initials(user.name),
                        style: TextStyle(
                          color: _roleColor(user.role),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _BodyCell(user.email, width: 220),
              SizedBox(width: 140, child: _RoleBadge(role: user.role)),
              _BodyCell(
                user.location?.isNotEmpty == true ? user.location! : 'Not set',
                width: 150,
              ),
              SizedBox(
                width: 118,
                child: _StatusBadge(status: user.accessStatus),
              ),
              SizedBox(
                width: 150,
                child: _ApprovalBadge(status: user.accessStatus),
              ),
              _BodyCell(_formatDate(user.createdAt), width: 112),
              SizedBox(
                width: 170,
                child: _ActionButtons(
                  user: user,
                  onView: widget.onView,
                  onApprove: widget.onApprove,
                  onReject: widget.onReject,
                  onBlock: widget.onBlock,
                  onUnblock: widget.onUnblock,
                  onAssignRole: widget.onAssignRole,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {required this.width});

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell(this.text, {required this.width});

  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.user,
    required this.onView,
    required this.onApprove,
    required this.onReject,
    required this.onBlock,
    required this.onUnblock,
    required this.onAssignRole,
  });

  final AdminUserItem user;
  final VoidCallback onView;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onBlock;
  final VoidCallback onUnblock;
  final VoidCallback onAssignRole;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        _IconAction(
          icon: Icons.visibility_outlined,
          tooltip: 'View full profile',
          color: AppColors.primary,
          onTap: onView,
        ),
        if (user.isPending) ...[
          _IconAction(
            icon: Icons.check_circle_outline_rounded,
            tooltip: 'Approve user',
            color: AppColors.secondary,
            onTap: onApprove,
          ),
          _IconAction(
            icon: Icons.close_rounded,
            tooltip: 'Reject user',
            color: AppColors.softRed,
            onTap: onReject,
          ),
        ],
        _IconAction(
          icon: Icons.manage_accounts_rounded,
          tooltip: 'Assign or update role',
          color: const Color(0xFF6B48FF),
          onTap: onAssignRole,
        ),
        if (user.isBlocked)
          _IconAction(
            icon: Icons.lock_open_rounded,
            tooltip: 'Unblock user',
            color: AppColors.secondary,
            onTap: onUnblock,
          )
        else if (!user.isPending)
          _IconAction(
            icon: Icons.block_rounded,
            tooltip: 'Block user',
            color: AppColors.softRed,
            onTap: onBlock,
          ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.16)),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }
}

class _RoleAssignmentDialog extends StatefulWidget {
  const _RoleAssignmentDialog({required this.user});

  final AdminUserItem user;

  @override
  State<_RoleAssignmentDialog> createState() => _RoleAssignmentDialogState();
}

class _RoleAssignmentDialogState extends State<_RoleAssignmentDialog> {
  late String _role = widget.user.requestedRole ?? widget.user.role;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Assign role to ${widget.user.name}',
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
      ),
      content: DropdownButtonFormField<String>(
        initialValue: _role,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Role',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: const [
          DropdownMenuItem(value: 'student', child: Text('Student')),
          DropdownMenuItem(
            value: 'content_creator',
            child: Text('Content Creator'),
          ),
          DropdownMenuItem(value: 'mentor', child: Text('Counsellor')),
          DropdownMenuItem(value: 'mediator', child: Text('Mediator')),
          DropdownMenuItem(value: 'admin', child: Text('Admin')),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _role = value);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _role),
          icon: const Icon(Icons.manage_accounts_rounded, size: 18),
          label: const Text('Update role'),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.muted.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AdminNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = notification.isRead
        ? AppColors.muted
        : const Color(0xFF6B48FF);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: notification.isRead
            ? Colors.white
            : const Color(0xFF6B48FF).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    notification.isRead
                        ? Icons.notifications_none_rounded
                        : Icons.person_add_alt_1_rounded,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: notification.isRead
                              ? FontWeight.w700
                              : FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notification.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Registered ${_formatRelative(notification.createdAt)}',
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!notification.isRead)
                  TextButton(onPressed: onTap, child: const Text('Mark read')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet({required this.vm});

  final AdminViewModel vm;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      maxChildSize: 0.92,
      minChildSize: 0.42,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.muted.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Admin Notifications',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  if (vm.unreadCount > 0)
                    TextButton.icon(
                      onPressed: vm.markAllRead,
                      icon: const Icon(Icons.done_all_rounded, size: 17),
                      label: const Text('Mark all read'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListenableBuilder(
                listenable: vm,
                builder: (_, _) {
                  final notes = vm.notifications;
                  if (notes.isEmpty) {
                    return const Center(
                      child: Text(
                        'No notifications yet.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: notes.length,
                    itemBuilder: (_, i) => _NotificationTile(
                      notification: notes[i],
                      onTap: () => vm.markNotificationRead(notes[i].id),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagementTools extends StatelessWidget {
  const _ManagementTools({
    required this.pendingCount,
    required this.totalUsers,
    required this.onOpenPending,
    required this.onOpenUsers,
    required this.onOpenEvents,
    required this.onOpenCounselling,
    required this.onOpenSafety,
    required this.onOpenEmergency,
    required this.onOpenCalendar,
    required this.onOpenRewards,
  });

  final int pendingCount;
  final int totalUsers;
  final VoidCallback onOpenPending;
  final VoidCallback onOpenUsers;
  final VoidCallback onOpenEvents;
  final VoidCallback onOpenCounselling;
  final VoidCallback onOpenSafety;
  final VoidCallback onOpenEmergency;
  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenRewards;

  @override
  Widget build(BuildContext context) {
    final tools = [
      _ToolData(
        icon: Icons.pending_actions_rounded,
        label: 'Approvals',
        subtitle: '$pendingCount waiting',
        color: AppColors.accent,
        onTap: onOpenPending,
      ),
      _ToolData(
        icon: Icons.manage_accounts_rounded,
        label: 'Users',
        subtitle: '$totalUsers records',
        color: AppColors.primary,
        onTap: onOpenUsers,
      ),
      _ToolData(
        icon: Icons.event_rounded,
        label: 'Events',
        subtitle: 'Create and manage',
        color: const Color(0xFF6B48FF),
        onTap: onOpenEvents,
      ),
      _ToolData(
        icon: Icons.psychology_outlined,
        label: 'Counselling',
        subtitle: 'Sessions and schedules',
        color: const Color(0xFF009688),
        onTap: onOpenCounselling,
      ),
      _ToolData(
        icon: Icons.shield_rounded,
        label: 'Safety',
        subtitle: 'Stories and questions',
        color: AppColors.softRed,
        onTap: onOpenSafety,
      ),
      _ToolData(
        icon: Icons.contact_phone_rounded,
        label: 'Emergency',
        subtitle: 'Manage helplines',
        color: AppColors.ink,
        onTap: onOpenEmergency,
      ),
      _ToolData(
        icon: Icons.video_call_rounded,
        label: 'Google Meet',
        subtitle: 'Calendar & Meet setup',
        color: const Color(0xFF1A73E8),
        onTap: onOpenCalendar,
      ),
      _ToolData(
        icon: Icons.card_giftcard_rounded,
        label: 'Reward Rules',
        subtitle: 'Role-based reward config',
        color: AppColors.accent,
        onTap: onOpenRewards,
      ),
    ];

    return _Panel(
      title: 'Management Tools',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 920
              ? 3
              : constraints.maxWidth >= 560
              ? 2
              : 1;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tools.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: columns == 1 ? 4.4 : 3.1,
            ),
            itemBuilder: (_, i) => _ToolTile(data: tools[i]),
          );
        },
      ),
    );
  }
}

class _ToolData {
  const _ToolData({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.data});

  final _ToolData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(data.icon, color: data.color, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      data.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 12),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 44, color: AppColors.muted.withValues(alpha: 0.7)),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return _Badge(label: _roleLabel(role), color: _roleColor(role));
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return _Badge(label: _statusLabel(status), color: _statusColor(status));
  }
}

class _ApprovalBadge extends StatelessWidget {
  const _ApprovalBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return _Badge(label: _approvalLabel(status), color: _approvalColor(status));
  }
}

String _roleLabel(String role) => switch (role) {
  'student' => 'Student',
  'content_creator' => 'Creator',
  'mentor' => 'Counsellor',
  'mediator' => 'Mediator',
  'admin' => 'Admin',
  'super_admin' => 'Super Admin',
  'guest' => 'Guest',
  _ => role,
};

Color _roleColor(String role) => switch (role) {
  'mentor' => AppColors.secondary,
  'content_creator' => AppColors.accent,
  'mediator' => const Color(0xFF009688),
  'admin' || 'super_admin' => const Color(0xFF6B48FF),
  'student' => AppColors.primary,
  _ => AppColors.muted,
};

String _statusLabel(String status) => switch (status) {
  'approved' => 'Active',
  'pending_verification' => 'Pending',
  'deactivated' => 'Blocked',
  'rejected' => 'Rejected',
  _ => status,
};

Color _statusColor(String status) => switch (status) {
  'approved' => AppColors.secondary,
  'pending_verification' => AppColors.accent,
  'deactivated' => AppColors.softRed,
  'rejected' => AppColors.softRed,
  _ => AppColors.muted,
};

String _approvalLabel(String status) => switch (status) {
  'approved' => 'Approved',
  'pending_verification' => 'Waiting Approval',
  'deactivated' => 'Approved',
  'rejected' => 'Rejected',
  _ => status,
};

Color _approvalColor(String status) => switch (status) {
  'approved' => AppColors.secondary,
  'pending_verification' => AppColors.accent,
  'deactivated' => AppColors.secondary,
  'rejected' => AppColors.softRed,
  _ => AppColors.muted,
};

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _formatRelative(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  if (diff.inDays < 7) return '${diff.inDays} day ago';
  return _formatDate(date);
}

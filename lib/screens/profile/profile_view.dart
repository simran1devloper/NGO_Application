import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/colors.dart';
import '../../models/api_models.dart';
import '../../models/auth_models.dart';
import '../../models/reward_models.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/view_state.dart';
import '../../widgets/app_scroll_view.dart';
import 'reward_wallet_screen.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late final ProfileViewModel _vm;
  late final AuthViewModel _authVm;

  @override
  void initState() {
    super.initState();
    _vm = ProfileViewModel()..load();
    _authVm = AuthViewModel();
  }

  @override
  void dispose() {
    _vm.dispose();
    _authVm.dispose();
    super.dispose();
  }

  Future<void> _openChangePassword() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangePasswordSheet(
        onSave: (currentPw, newPw) async {
          final error = await _authVm.changePassword(
            currentPassword: currentPw,
            newPassword: newPw,
          );
          if (!mounted) return;
          if (error == null) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Password changed successfully.'),
                backgroundColor: Color(0xFF18B86D),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: AppColors.softRed,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _logout() async {
    await _authVm.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label will be available soon.')));
  }

  Future<void> _openEditProfile() async {
    final user = _vm.user;
    if (user == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        user: user,
        onSave:
            (
              name,
              className,
              schoolName,
              location,
              age,
              dateOfBirth,
              parentEmail,
              phone,
            ) async {
              final ok = await _vm.updateProfile(
                name: name,
                className: className,
                schoolName: schoolName,
                location: location,
                age: age,
                dateOfBirth: dateOfBirth,
                parentEmail: parentEmail,
                phone: phone,
              );
              if (!mounted) return;
              if (ok) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile updated successfully.'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _vm.updateError ?? 'Failed to update profile.',
                    ),
                    backgroundColor: AppColors.softRed,
                  ),
                );
              }
            },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        if (_vm.state == ViewState.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_vm.state == ViewState.error) {
          return _ProfileError(message: _vm.errorMessage, onRetry: _vm.load);
        }

        final user = _vm.user;
        final stats = _vm.stats;

        return AppScrollView(
          children: [
            _ProfileHeader(
              onNotificationTap: () => _showComingSoon('Notifications'),
              onSettingsTap: () => _showComingSoon('Settings'),
            ),
            _StudentSummaryCard(
              user: user,
              stats: stats,
              badgeCount: _vm.badges.length,
              onEditProfile: _openEditProfile,
            ),
            _RewardWalletCard(
              summary: _vm.rewards,
              tasks: _vm.rewardTasks,
              onAdvanceTask: _vm.advanceRewardTask,
            ),
            _QuickActionBar(
              actions: [
                _QuickAction(
                  icon: Icons.person_outline_rounded,
                  label: 'My Activity',
                  color: const Color(0xFF20BF6B),
                  onTap: () => _showComingSoon('My Activity'),
                ),
                _QuickAction(
                  icon: Icons.bookmark_rounded,
                  label: 'Saved Lessons',
                  color: const Color(0xFF1E6BFF),
                  onTap: () => _showComingSoon('Saved Lessons'),
                ),
                _QuickAction(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Messages',
                  color: const Color(0xFF8B5CF6),
                  onTap: () => _showComingSoon('Messages'),
                ),
                _QuickAction(
                  icon: Icons.calendar_month_rounded,
                  label: 'My Calendar',
                  color: const Color(0xFFFF8800),
                  onTap: () => _showComingSoon('My Calendar'),
                ),
              ],
            ),
            const _SectionTitle('Profile Information'),
            _InfoCard(
              rows: [
                _InfoRowData(
                  icon: Icons.person_outline_rounded,
                  tint: const Color(0xFF126BFF),
                  label: 'Full Name',
                  value: _value(user?.name),
                  onTap: _openEditProfile,
                ),
                _InfoRowData(
                  icon: Icons.school_rounded,
                  tint: const Color(0xFF17B86A),
                  label: 'Class',
                  value: _value(user?.className),
                  onTap: _openEditProfile,
                ),
                _InfoRowData(
                  icon: Icons.account_balance_rounded,
                  tint: const Color(0xFF8B5CF6),
                  label: 'School',
                  value: _value(user?.schoolName),
                  onTap: _openEditProfile,
                ),
                _InfoRowData(
                  icon: Icons.location_on_outlined,
                  tint: const Color(0xFFFF8800),
                  label: 'Location',
                  value: _value(user?.location),
                  onTap: _openEditProfile,
                ),
                _InfoRowData(
                  icon: Icons.mail_outline_rounded,
                  tint: const Color(0xFFFF9800),
                  label: 'Parent Email',
                  value: _value(user?.parentEmail),
                  onTap: _openEditProfile,
                ),
                _InfoRowData(
                  icon: Icons.calendar_month_rounded,
                  tint: const Color(0xFF11B8C9),
                  label: 'Date of Birth',
                  value: _dateOrAge(user),
                  onTap: _openEditProfile,
                ),
              ],
            ),
            if (AppState.roles.length > 1) ...[
              const _SectionTitle('Switch Role'),
              _RoleSwitcherCard(
                roles: AppState.roles,
                activeRole: AppState.activeRole,
                onSwitch: (role) {
                  AppState.setActiveRole(role);
                  Navigator.of(context).pushReplacementNamed('/home');
                },
              ),
            ],
            const _SectionTitle('Preferences & Security'),
            _InfoCard(
              rows: [
                _InfoRowData(
                  icon: Icons.lock_outline_rounded,
                  tint: const Color(0xFF126BFF),
                  label: 'Change Password',
                  onTap: _openChangePassword,
                ),
                _InfoRowData(
                  icon: Icons.logout_rounded,
                  tint: Colors.redAccent,
                  label: 'Logout',
                  labelColor: Colors.red,
                  onTap: _logout,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

String _value(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? 'Not set' : trimmed;
}

String _dateOrAge(AppUser? user) {
  if (user?.dateOfBirth != null) return _formatDate(user!.dateOfBirth!);
  if (user?.age != null) return 'Age ${user!.age}';
  return 'Not set';
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message ?? 'Failed to load profile.',
            style: const TextStyle(color: AppColors.muted),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.onNotificationTap,
    required this.onSettingsTap,
  });

  final VoidCallback onNotificationTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: TextStyle(
                  color: Color(0xFF08164A),
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Manage your account and preferences',
                style: TextStyle(
                  color: Color(0xFF4A587C),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        _RoundIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          onTap: onNotificationTap,
        ),
        const SizedBox(width: 10),
        _RoundIconButton(
          icon: Icons.settings_outlined,
          tooltip: 'Settings',
          onTap: onSettingsTap,
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE9EEF9)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B1B4D).withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF08164A), size: 24),
        ),
      ),
    );
  }
}

class _StudentSummaryCard extends StatelessWidget {
  const _StudentSummaryCard({
    required this.user,
    required this.stats,
    required this.badgeCount,
    required this.onEditProfile,
  });

  final AppUser? user;
  final UserStats? stats;
  final int badgeCount;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFCFE3FF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2B68).withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 460;
              final details = _ProfileIdentity(user: user);
              final editButton = OutlinedButton.icon(
                onPressed: onEditProfile,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Profile'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF126BFF),
                  side: const BorderSide(color: Color(0xFF8FBCFF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    details,
                    const SizedBox(height: 14),
                    Align(alignment: Alignment.centerLeft, child: editButton),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 14),
                  editButton,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _StatsPanel(
            stats: [
              _StatData(
                icon: Icons.school_rounded,
                label: 'Courses Enrolled',
                value: '${stats?.coursesEnrolled ?? 0}',
                color: const Color(0xFF126BFF),
              ),
              _StatData(
                icon: Icons.check_rounded,
                label: 'Lessons Completed',
                value: '${stats?.lessonsCompleted ?? 0}',
                color: const Color(0xFF18B86D),
              ),
              _StatData(
                icon: Icons.local_fire_department_rounded,
                label: 'Study Streak',
                value: '${stats?.studyStreakDays ?? 0}',
                suffix: 'days',
                color: const Color(0xFFFF7A00),
              ),
              _StatData(
                icon: Icons.star_rounded,
                label: 'Badges Earned',
                value: '$badgeCount',
                color: const Color(0xFF8B5CF6),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final classAndSchool = [
      if (user?.className?.trim().isNotEmpty == true)
        'Class ${user!.className!.trim()}',
      if (user?.schoolName?.trim().isNotEmpty == true) user!.schoolName!.trim(),
    ].join('  •  ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                gradient: const LinearGradient(
                  colors: [Color(0xFFEAF7FF), Color(0xFF8ED3FF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: Text(
                  _initials(user?.name),
                  style: const TextStyle(
                    color: Color(0xFF08164A),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 8,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD8E3F5)),
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  size: 17,
                  color: Color(0xFF4A587C),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.name ?? AppState.studentName ?? 'Student',
                style: const TextStyle(
                  color: Color(0xFF08164A),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              if (classAndSchool.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  classAndSchool,
                  style: const TextStyle(
                    color: Color(0xFF4A587C),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (user?.parentEmail?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 12),
                _InlineMeta(
                  icon: Icons.mail_outline_rounded,
                  text: user!.parentEmail!.trim(),
                ),
              ],
              if (user?.phone?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                _InlineMeta(
                  icon: Icons.phone_outlined,
                  text: user!.phone!.trim(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _initials(String? name) {
  final parts = (name ?? 'Student')
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'S';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4A587C), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF4A587C),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.stats});

  final List<_StatData> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF08164A).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 420 ? 2 : 4;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: 112,
            ),
            itemCount: stats.length,
            itemBuilder: (context, index) {
              return _StatTile(
                data: stats[index],
                showDivider: columns == 4 && index != stats.length - 1,
              );
            },
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.data, required this.showDivider});

  final _StatData data;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(right: BorderSide(color: Color(0xFFE8ECF4)))
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(data.icon, color: data.color, size: 30),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              data.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF435174),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.value,
            style: TextStyle(
              color: data.color,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          if (data.suffix != null)
            Text(
              data.suffix!,
              style: const TextStyle(
                color: Color(0xFF08164A),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatData {
  const _StatData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.suffix,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? suffix;
}

class _QuickActionBar extends StatelessWidget {
  const _QuickActionBar({required this.actions});

  final List<_QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF08164A).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 420 ? 2 : 4;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: 82,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return InkWell(
                onTap: action.onTap,
                borderRadius: BorderRadius.circular(14),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: columns == 4 && index != actions.length - 1
                        ? const Border(
                            right: BorderSide(color: Color(0xFFE8ECF4)),
                          )
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(action.icon, color: action.color, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        action.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF08164A),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF08164A),
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<_InfoRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF08164A).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            _InfoRow(data: rows[i], showDivider: i != rows.length - 1),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.data, required this.showDivider});

  final _InfoRowData data;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final labelColor = data.labelColor ?? const Color(0xFF08164A);
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 18),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: Color(0xFFE8ECF4)))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: data.tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: data.tint.withValues(alpha: 0.18)),
              ),
              child: Icon(data.icon, color: data.tint, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                data.label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (data.value != null) ...[
              Flexible(
                child: Text(
                  data.value!,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF3F4D70),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF4A587C)),
          ],
        ),
      ),
    );
  }
}

class _InfoRowData {
  const _InfoRowData({
    required this.icon,
    required this.tint,
    required this.label,
    this.value,
    this.labelColor,
    this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final String? value;
  final Color? labelColor;
  final VoidCallback? onTap;
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.user, required this.onSave});

  final AppUser user;
  final Future<void> Function(
    String? name,
    String? className,
    String? schoolName,
    String? location,
    int? age,
    DateTime? dateOfBirth,
    String? parentEmail,
    String? phone,
  )
  onSave;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _classCtrl;
  late final TextEditingController _schoolCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _parentEmailCtrl;
  late final TextEditingController _phoneCtrl;
  DateTime? _dateOfBirth;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _nameCtrl = TextEditingController(text: user.name);
    _classCtrl = TextEditingController(text: user.className ?? '');
    _schoolCtrl = TextEditingController(text: user.schoolName ?? '');
    _locationCtrl = TextEditingController(text: user.location ?? '');
    _ageCtrl = TextEditingController(text: user.age?.toString() ?? '');
    _parentEmailCtrl = TextEditingController(text: user.parentEmail ?? '');
    _phoneCtrl = TextEditingController(text: user.phone ?? '');
    _dateOfBirth = user.dateOfBirth;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _classCtrl.dispose();
    _schoolCtrl.dispose();
    _locationCtrl.dispose();
    _ageCtrl.dispose();
    _parentEmailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 15, now.month, now.day),
      firstDate: DateTime(now.year - 30),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.onSave(
      _emptyToNull(_nameCtrl.text),
      _emptyToNull(_classCtrl.text),
      _emptyToNull(_schoolCtrl.text),
      _emptyToNull(_locationCtrl.text),
      int.tryParse(_ageCtrl.text.trim()),
      _dateOfBirth,
      _emptyToNull(_parentEmailCtrl.text),
      _emptyToNull(_phoneCtrl.text),
    );
    if (mounted) setState(() => _saving = false);
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6DCEA),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Edit Profile',
                  style: TextStyle(
                    color: Color(0xFF08164A),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Update the details shown on your student profile.',
                  style: TextStyle(
                    color: Color(0xFF4A587C),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                _SheetField(
                  controller: _nameCtrl,
                  label: 'Full Name',
                  icon: Icons.person_outline_rounded,
                  enabled: !_saving,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 12),
                _SheetField(
                  controller: _classCtrl,
                  label: 'Class',
                  icon: Icons.school_outlined,
                  enabled: !_saving,
                ),
                const SizedBox(height: 12),
                _SheetField(
                  controller: _schoolCtrl,
                  label: 'School',
                  icon: Icons.account_balance_outlined,
                  enabled: !_saving,
                ),
                const SizedBox(height: 12),
                _SheetField(
                  controller: _locationCtrl,
                  label: 'Location',
                  icon: Icons.location_on_outlined,
                  enabled: !_saving,
                ),
                const SizedBox(height: 12),
                _SheetField(
                  controller: _parentEmailCtrl,
                  label: 'Parent Email',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_saving,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    if (!RegExp(
                      r'^[^@]+@[^@]+\.[^@]+$',
                    ).hasMatch(value.trim())) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _SheetField(
                  controller: _phoneCtrl,
                  label: 'Phone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  enabled: !_saving,
                ),
                const SizedBox(height: 12),
                _SheetField(
                  controller: _ageCtrl,
                  label: 'Age',
                  icon: Icons.cake_outlined,
                  keyboardType: TextInputType.number,
                  enabled: !_saving,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final age = int.tryParse(value.trim());
                    if (age == null || age < 5 || age > 30) {
                      return 'Enter a valid age';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    _dateOfBirth == null
                        ? 'Add Date of Birth'
                        : _formatDate(_dateOfBirth!),
                  ),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    foregroundColor: const Color(0xFF08164A),
                    side: const BorderSide(color: Color(0xFFDDE6F4)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF126BFF),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.enabled = true,
    this.validator,
    this.obscureText = false,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool enabled;
  final String? Function(String?)? validator;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      obscureText: obscureText,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF4A587C)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF7FAFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF126BFF), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.softRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.softRed, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet({required this.onSave});

  final Future<void> Function(String currentPw, String newPw) onSave;

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

// ── Role Switcher ─────────────────────────────────────────────────────────────

class _RoleSwitcherCard extends StatelessWidget {
  const _RoleSwitcherCard({
    required this.roles,
    required this.activeRole,
    required this.onSwitch,
  });

  final List<UserRole> roles;
  final UserRole activeRole;
  final ValueChanged<UserRole> onSwitch;

  Color _roleColor(UserRole r) => switch (r) {
        UserRole.superAdmin     => const Color(0xFF6B48FF),
        UserRole.admin          => const Color(0xFF6B48FF),
        UserRole.mediator       => const Color(0xFF009688),
        UserRole.mentor         => AppColors.secondary,
        UserRole.contentCreator => AppColors.accent,
        UserRole.student        => AppColors.primary,
        _                       => AppColors.muted,
      };

  IconData _roleIcon(UserRole r) => switch (r) {
        UserRole.superAdmin     => Icons.verified_rounded,
        UserRole.admin          => Icons.admin_panel_settings_rounded,
        UserRole.mediator       => Icons.shield_rounded,
        UserRole.mentor         => Icons.psychology_rounded,
        UserRole.contentCreator => Icons.edit_rounded,
        UserRole.student        => Icons.school_rounded,
        _                       => Icons.person_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.muted.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You have ${roles.length} roles. Tap one to switch your view.',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in roles)
                _RoleChip(
                  role: r,
                  isActive: r == activeRole,
                  color: _roleColor(r),
                  icon: _roleIcon(r),
                  onTap: r == activeRole ? null : () => onSwitch(r),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.role,
    required this.isActive,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final UserRole role;
  final bool isActive;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? color : AppColors.muted.withValues(alpha: 0.28),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isActive ? color : AppColors.muted),
            const SizedBox(width: 6),
            Text(
              role.displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? color : AppColors.muted,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 5),
              Icon(Icons.check_circle_rounded, size: 13, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

class _RewardWalletCard extends StatelessWidget {
  const _RewardWalletCard({
    required this.summary,
    required this.tasks,
    required this.onAdvanceTask,
  });

  final RewardSummary? summary;
  final List<RewardTask> tasks;
  final Future<void> Function(int taskId) onAdvanceTask;

  void _openWallet(BuildContext context) {
    if (summary == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RewardWalletScreen(summary: summary!, tasks: tasks),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rewards = summary?.rewards ?? const <RewardTransaction>[];
    final activeTasks = tasks.where((task) => !task.isCompleted).take(3).toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard_rounded, color: AppColors.accent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Reward Wallet',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              _RewardPill(
                icon: Icons.stars_rounded,
                label: '${summary?.totalPoints ?? 0} pts',
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              _RewardPill(
                icon: Icons.bolt_rounded,
                label: '${summary?.totalXpFromRewards ?? 0} XP',
                color: AppColors.secondary,
              ),
            ],
          ),
          if (activeTasks.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final task in activeTasks)
              _RewardTaskRow(task: task, onAdvance: () => onAdvanceTask(task.id)),
          ],
          if (rewards.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            for (final reward in rewards.take(3)) _RewardHistoryRow(reward: reward),
          ],
          if (activeTasks.isEmpty && rewards.isEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Complete lessons, videos, courses, or assigned tasks to collect rewards.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openWallet(context),
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: const Text('View All'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    if (summary == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RewardWalletScreen(
                          summary: summary!,
                          tasks: tasks,
                          initialTab: 2,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.card_giftcard_rounded, size: 15),
                  label: const Text('Send Gift'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardPill extends StatelessWidget {
  const _RewardPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardTaskRow extends StatelessWidget {
  const _RewardTaskRow({required this.task, required this.onAdvance});

  final RewardTask task;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final progress = task.progress.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: AppColors.secondary,
                    backgroundColor: AppColors.secondary.withValues(alpha: 0.12),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${task.currentCount}/${task.targetCount} • +${task.rewardPoints} pts • +${task.rewardXp} XP',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            onPressed: onAdvance,
            tooltip: 'Add progress',
            icon: const Icon(Icons.add_task_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _RewardHistoryRow extends StatelessWidget {
  const _RewardHistoryRow({required this.reward});

  final RewardTransaction reward;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reward.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '+${reward.points} pts',
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Change Password ───────────────────────────────────────────────────────────

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _saving = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.onSave(_currentCtrl.text, _newCtrl.text);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6DCEA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Change Password',
                style: TextStyle(
                  color: Color(0xFF08164A),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your new password must be at least 8 characters.',
                style: TextStyle(
                  color: Color(0xFF4A587C),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              _SheetField(
                controller: _currentCtrl,
                label: 'Current Password',
                icon: Icons.lock_outline_rounded,
                obscureText: !_showCurrent,
                enabled: !_saving,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showCurrent
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF4A587C),
                  ),
                  onPressed: () => setState(() => _showCurrent = !_showCurrent),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter your current password' : null,
              ),
              const SizedBox(height: 12),
              _SheetField(
                controller: _newCtrl,
                label: 'New Password',
                icon: Icons.lock_reset_rounded,
                obscureText: !_showNew,
                enabled: !_saving,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showNew
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF4A587C),
                  ),
                  onPressed: () => setState(() => _showNew = !_showNew),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter a new password';
                  if (v.length < 8) return 'Must be at least 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _SheetField(
                controller: _confirmCtrl,
                label: 'Confirm New Password',
                icon: Icons.check_circle_outline_rounded,
                obscureText: !_showConfirm,
                enabled: !_saving,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF4A587C),
                  ),
                  onPressed: () =>
                      setState(() => _showConfirm = !_showConfirm),
                ),
                validator: (v) => v != _newCtrl.text
                    ? 'Passwords do not match'
                    : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF126BFF),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Update Password',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

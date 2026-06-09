import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_state.dart';
import '../../core/colors.dart';
import '../../models/course.dart';
import '../../models/event_models.dart';
import '../../models/skill_category.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/view_state.dart';
import '../../utils/navigation_helper.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_scroll_view.dart';
import '../../widgets/section_header.dart';
import '../../widgets/top_header.dart';
import '../admin/pending_approvals_screen.dart';
import '../admin/user_management_screen.dart';
import '../events/admin/event_manager_screen.dart';
import '../helping_support/admin/counselling_admin_screen.dart';
import '../helping_support/admin/emergency_contacts_admin_screen.dart';
import '../helping_support/student/all_slots_screen.dart';
import '../home/admin/safety_awareness_manager_screen.dart';
import 'widgets/counselling_session_card.dart';
import 'widgets/daily_challenge_card.dart';
import 'widgets/daily_motivation_card.dart';
import 'widgets/parent_preview_panel.dart';
import 'widgets/skill_category_card.dart';
import 'widgets/earn_rewards_card.dart';
import 'widgets/streak_card.dart';
import 'widgets/upcoming_counselling_banner.dart';
import 'widgets/welcome_banner.dart';

class HomeView extends StatefulWidget {
  const HomeView({this.onOpenLearn, super.key});

  final ValueChanged<SkillCategory?>? onOpenLearn;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with WidgetsBindingObserver {
  late final HomeViewModel _vm;
  AdminViewModel? _adminVm;
  late final TextEditingController _skillSearchCtrl;
  Timer? _notificationTimer;
  bool _bannerShown = false;
  bool _eventBannerShown = false;
  OverlayEntry? _eventNotificationEntry;
  String _skillQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vm = HomeViewModel();
    _skillSearchCtrl = TextEditingController();
    _vm.addListener(_onVmChanged);
    _vm.load();
    // Check every minute if a session is about to start
    _notificationTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkSessionNotification(),
    );
    // Admins get a live notification + pending-approval count
    if (AppState.role.isAdmin) {
      _adminVm = AdminViewModel();
      _adminVm!.load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _vm.load();
      _adminVm?.load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationTimer?.cancel();
    _eventNotificationEntry?.remove();
    _eventNotificationEntry = null;
    _skillSearchCtrl.dispose();
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    _adminVm?.dispose();
    super.dispose();
  }

  void _onVmChanged() {
    if (_vm.state == ViewState.idle) {
      _checkSessionNotification();
      _checkEventNotification();
    }
  }

  void _checkSessionNotification() {
    if (!mounted) return;
    final session = _vm.upcomingSession;
    if (session == null) return;

    final diffMin = session.scheduledAt.difference(DateTime.now()).inMinutes;
    if (diffMin >= 0 && diffMin <= 15 && !_bannerShown) {
      _bannerShown = true;
      final hasLink = session.hasMeetingLink;
      ScaffoldMessenger.of(context).showMaterialBanner(
        MaterialBanner(
          backgroundColor: AppColors.secondary.withValues(alpha: 0.12),
          leading: const Icon(
            Icons.notifications_active_rounded,
            color: AppColors.secondary,
          ),
          content: Text(
            diffMin == 0
                ? 'Your session with ${session.counsellorName} is starting now!'
                : 'Your session with ${session.counsellorName} starts in $diffMin min.',
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            if (hasLink)
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: session.meetingUrl!));
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Join link copied to clipboard!'),
                    ),
                  );
                },
                child: const Text('Copy Link'),
              ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                _bannerShown = false;
              },
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
    }
  }

  void _checkEventNotification() {
    if (!mounted || _eventBannerShown || _vm.upcomingEvents.isEmpty) return;
    final event = _vm.upcomingEvents.firstWhere(
      (item) => item.canRegister || item.status == EventStatus.live,
      orElse: () => _vm.upcomingEvents.first,
    );
    _eventBannerShown = true;
    final endText = _formatDate(event.registrationEnd);
    final label = event.status == EventStatus.live ? 'Join' : 'Register';

    void dismiss() {
      _eventNotificationEntry?.remove();
      _eventNotificationEntry = null;
    }

    _eventNotificationEntry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        top: MediaQuery.of(overlayContext).padding.top + 12,
        left: 16,
        right: 16,
        child: _EventNotificationToast(
          event: event,
          endText: endText,
          label: label,
          onRegister: () {
            dismiss();
            openEvent(context, event, onRefresh: () => _vm.load());
          },
          onDismiss: dismiss,
        ),
      ),
    );

    Overlay.of(context).insert(_eventNotificationEntry!);
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
          return _ErrorView(
            message: _vm.errorMessage!,
            actionLabel: AppState.isAuthenticated ? 'Retry' : 'Sign In',
            onRetry: AppState.isAuthenticated
                ? _vm.load
                : () => Navigator.of(context).pushReplacementNamed('/login'),
          );
        }
        final visibleSkills = _filteredSkillCategories(_vm.categories);
        final firstName = (_vm.studentProfile?.name ??
                AppState.studentName ??
                'Student')
            .split(' ')
            .first;
        final adminBadge = _adminVm == null
            ? null
            : (_adminVm!.unreadCount + _adminVm!.pendingCount);
        return AppScrollView(
          children: [
            ListenableBuilder(
              listenable: _adminVm ?? _vm,
              builder: (_, _) => TopHeader(
                title: 'Hi $firstName',
                subtitle: AppState.role.isAdmin
                    ? 'Welcome back, ${AppState.role.displayName}'
                    : 'Ready to learn, play, and grow today?',
                actionIcon: Icons.notifications_none_rounded,
                badgeCount: adminBadge == 0 ? null : adminBadge,
                onActionTap: AppState.role.isAdmin
                    ? () => _openAdminNotifications()
                    : null,
              ),
            ),

            // ── Admin: analytics + management tools ───────────────────
            if (AppState.role.isAdmin && _adminVm != null)
              ListenableBuilder(
                listenable: _adminVm!,
                builder: (_, _) => _AdminAnalyticsSection(
                  vm: _adminVm!,
                  onViewPending: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PendingApprovalsScreen(),
                    ),
                  ),
                  onViewNotifications: _openAdminNotifications,
                  onOpenUsers: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserManagementScreen(vm: _adminVm!),
                    ),
                  ),
                  onOpenEvents: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EventManagerScreen(),
                    ),
                  ),
                  onOpenCounselling: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CounsellingAdminScreen(),
                    ),
                  ),
                  onOpenSafety: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SafetyAwarenessManagerScreen(),
                    ),
                  ),
                  onOpenEmergency: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EmergencyContactsAdminScreen(),
                    ),
                  ),
                ),
              ),

            // ── Personalised welcome card ──────────────────────────
            WelcomeBanner(student: _vm.studentProfile),

            // ── Upcoming events ────────────────────────────────────
            UpcomingEventsPanel(
              events: _vm.upcomingEvents,
              onEventTap: (event) =>
                  openEvent(context, event, onRefresh: () => _vm.load()),
            ),

            // ── Next counselling session ───────────────────────────
            UpcomingCounsellingBanner(
              upcomingEvent: _vm.upcomingCounsellingEvent,
              liveSession: _vm.upcomingSession,
              onEventTap: () => _openCounsellingBooking(context),
              onJoinTap: () => _openCounsellingSession(context),
            ),

            const DailyMotivationCard(),

            const StreakCard(),

            const EarnRewardsCard(),

            // ── Continue Learning ──────────────────────────────────
            const SectionHeader(title: 'Continue Learning'),
            _ContinueLearningCard(
              course: _vm.continueLearningCourse,
              onTap: () => widget.onOpenLearn?.call(null),
            ),

            // ── Skill development ──────────────────────────────────
            SectionHeader(
              title: 'Skill Development',
              action: 'View all',
              onTap: () => widget.onOpenLearn?.call(null),
            ),
            TextField(
              controller: _skillSearchCtrl,
              onChanged: (value) => setState(() => _skillQuery = value.trim()),
              decoration: InputDecoration(
                hintText: 'Search skills...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _skillQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _skillSearchCtrl.clear();
                          setState(() => _skillQuery = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Clear search',
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (visibleSkills.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      color: AppColors.muted.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No skill found.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _skillSearchCtrl.clear();
                        setState(() => _skillQuery = '');
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 128,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: visibleSkills.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => SkillCategoryCard(
                    item: visibleSkills[i],
                    onTap: () => widget.onOpenLearn?.call(visibleSkills[i]),
                  ),
                ),
              ),

            // ── Counselling card ───────────────────────────────────
            CounsellingSessionCard(
              upcomingSessions: _vm.allUpcomingSessions,
              availableSlots: _vm.availableSlots,
              onViewAll: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AllSlotsScreen())),
              onBook: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AllSlotsScreen())),
            ),

            // ── Daily Challenge ────────────────────────────────────
            SectionHeader(
              title: 'Daily Challenge',
              action: _vm.dailyChallenge == null ? null : 'Start',
              onTap: _vm.dailyChallenge == null
                  ? null
                  : () => _openDailyChallenge(context),
            ),
            DailyChallengeCard(
              challenge: _vm.dailyChallenge,
              onTap: _vm.dailyChallenge == null
                  ? null
                  : () => _openDailyChallenge(context),
            ),

            // ── Emergency Help shortcut ────────────────────────────
            const SectionHeader(title: 'Emergency Help'),
            const _EmergencyHelpCard(),

            const ParentPreviewPanel(),
          ],
        );
      },
    );
  }

  void _openDailyChallenge(BuildContext context) {
    final challenge = _vm.dailyChallenge;
    if (challenge == null) return;
    if (challenge.id != null) {
      Navigator.of(context).pushNamed('/daily-challenge/${challenge.id}');
      return;
    }
    final quizId = challenge.quizId ?? challenge.quiz?.id;
    if (quizId != null) {
      Navigator.of(context).pushNamed('/quiz/$quizId');
    }
  }

  List<SkillCategory> _filteredSkillCategories(List<SkillCategory> categories) {
    final query = _skillQuery.toLowerCase();
    if (query.isEmpty) return categories;
    return categories
        .where((category) => category.title.toLowerCase().contains(query))
        .toList();
  }

  void _openAdminNotifications() {
    if (_adminVm == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminNotificationsSheet(adminVm: _adminVm!),
    );
  }

  void _openCounsellingBooking(BuildContext context) {
    final event = _vm.upcomingCounsellingEvent;
    if (event != null) {
      openEvent(context, event, onRefresh: () => _vm.load());
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AllSlotsScreen()));
  }

  void _openCounsellingSession(BuildContext context) {
    final event = _vm.upcomingCounsellingEvent;
    if (event != null) {
      openEvent(context, event, onRefresh: () => _vm.load());
      return;
    }
    final session = _vm.upcomingSession;
    if (session?.hasMeetingLink == true) {
      Clipboard.setData(ClipboardData(text: session!.meetingUrl!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join link copied to clipboard!')),
      );
      return;
    }
    final message = session == null
        ? 'No counselling session is ready to join yet.'
        : 'Your counselling session is scheduled for ${session.formattedTime}.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return 'Date not set';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}

class UpcomingEventsPanel extends StatelessWidget {
  const UpcomingEventsPanel({
    required this.events,
    required this.onEventTap,
    super.key,
  });

  final List<EventModel> events;
  final ValueChanged<EventModel> onEventTap;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Upcoming Events'),
        SizedBox(
          height: 172,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _UpcomingEventCard(
              event: events[index],
              onTap: () => onEventTap(events[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _UpcomingEventCard extends StatelessWidget {
  const _UpcomingEventCard({required this.event, required this.onTap});

  final EventModel event;
  final VoidCallback onTap;

  String _formatDate(DateTime? value) {
    if (value == null) return 'Date not set';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final actionLabel = event.status == EventStatus.live ? 'Join' : 'Register';
    return SizedBox(
      width: 284,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: event.themeColorValue.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: event.themeColorValue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.event_available_rounded,
                        color: event.themeColorValue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        event.eventType.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Ends ${_formatDate(event.registrationEnd)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: onTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        actionLabel,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    this.actionLabel = 'Retry',
  });
  final String message;
  final VoidCallback onRetry;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _EventNotificationToast extends StatefulWidget {
  const _EventNotificationToast({
    required this.event,
    required this.endText,
    required this.label,
    required this.onRegister,
    required this.onDismiss,
  });

  final EventModel event;
  final String endText;
  final String label;
  final VoidCallback onRegister;
  final VoidCallback onDismiss;

  @override
  State<_EventNotificationToast> createState() =>
      _EventNotificationToastState();
}

class _EventNotificationToastState extends State<_EventNotificationToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slide = Tween<Offset>(
      begin: const Offset(-1.2, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        shadowColor: Colors.black26,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.endText == 'Date not set'
                      ? '${widget.event.title} is open. Tap to view and participate.'
                      : '${widget.event.title} is open until ${widget.endText}. Tap to register or join.',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: widget.onRegister,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  widget.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: widget.onDismiss,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueLearningCard extends StatelessWidget {
  const _ContinueLearningCard({required this.course, required this.onTap});

  final Course? course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (course == null) {
      return AppCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.school_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start Learning',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Explore beginner courses and pick one to start.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Browse', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
    }

    final progressPct = (course!.progress * 100).round();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: course!.color.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(course!.icon, color: AppColors.ink, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course!.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${course!.level} · ${course!.duration}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Continue', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: course!.progress.clamp(0.0, 1.0),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 7,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$progressPct%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmergencyHelpCard extends StatelessWidget {
  const _EmergencyHelpCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: const Color(0xFFFFF0F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.softRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.emergency_rounded,
                  color: AppColors.softRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency Help',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Reach out anytime — we are here for you.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HelpChip(
                icon: Icons.phone_rounded,
                label: 'Emergency Contacts',
                color: AppColors.softRed,
                onTap: () {},
              ),
              _HelpChip(
                icon: Icons.shield_rounded,
                label: 'Safety Help',
                color: AppColors.accent,
                onTap: () {},
              ),
              _HelpChip(
                icon: Icons.support_agent_rounded,
                label: 'Counselling Support',
                color: AppColors.secondary,
                onTap: () => Navigator.of(context).pushNamed('/helping-support'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HelpChip extends StatelessWidget {
  const _HelpChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Admin analytics section ───────────────────────────────────────────────────

class _AdminAnalyticsSection extends StatelessWidget {
  const _AdminAnalyticsSection({
    required this.vm,
    required this.onViewPending,
    required this.onViewNotifications,
    required this.onOpenUsers,
    required this.onOpenEvents,
    required this.onOpenCounselling,
    required this.onOpenSafety,
    required this.onOpenEmergency,
  });

  final AdminViewModel vm;
  final VoidCallback onViewPending;
  final VoidCallback onViewNotifications;
  final VoidCallback onOpenUsers;
  final VoidCallback onOpenEvents;
  final VoidCallback onOpenCounselling;
  final VoidCallback onOpenSafety;
  final VoidCallback onOpenEmergency;

  @override
  Widget build(BuildContext context) {
    final stats = vm.stats;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Analytics',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Platform overview & management',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Notification bell with badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton.filledTonal(
                    onPressed: onViewNotifications,
                    tooltip: 'Notifications',
                    icon: const Icon(Icons.notifications_rounded),
                  ),
                  if (vm.unreadCount > 0)
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
                            vm.unreadCount > 99 ? '99+' : '${vm.unreadCount}',
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
          ),
          const SizedBox(height: 14),

          // Stats grid: 2×2
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: [
              _StatTile(
                icon: Icons.people_alt_rounded,
                label: 'Total Users',
                value: stats.totalUsers,
                color: AppColors.ink,
                onTap: onOpenUsers,
              ),
              _StatTile(
                icon: Icons.verified_user_rounded,
                label: 'Active Users',
                value: stats.activeUsers,
                color: AppColors.secondary,
                onTap: onOpenUsers,
              ),
              _StatTile(
                icon: Icons.schedule_rounded,
                label: 'Pending Approvals',
                value: vm.pendingCount,
                color: const Color(0xFFFF8C00),
                onTap: onViewPending,
              ),
              _StatTile(
                icon: Icons.block_rounded,
                label: 'Blocked Users',
                value: stats.blockedUsers,
                color: AppColors.softRed,
                onTap: onOpenUsers,
              ),
            ],
          ),

          if (vm.pendingCount > 0) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onViewPending,
              icon: const Icon(Icons.fact_check_outlined, size: 16),
              label: Text(
                'Review ${vm.pendingCount} pending ${vm.pendingCount == 1 ? "request" : "requests"}',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF8C00),
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          const Text(
            'Management Tools',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),

          // Tools grid: 2×3
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 3.2,
            children: [
              _ToolTileHome(
                icon: Icons.pending_actions_rounded,
                label: 'Approvals',
                subtitle: '${vm.pendingCount} waiting',
                color: AppColors.accent,
                onTap: onViewPending,
              ),
              _ToolTileHome(
                icon: Icons.manage_accounts_rounded,
                label: 'Users',
                subtitle: '${stats.totalUsers} records',
                color: AppColors.primary,
                onTap: onOpenUsers,
              ),
              _ToolTileHome(
                icon: Icons.event_rounded,
                label: 'Events',
                subtitle: 'Create & manage',
                color: const Color(0xFF6B48FF),
                onTap: onOpenEvents,
              ),
              _ToolTileHome(
                icon: Icons.psychology_outlined,
                label: 'Counselling',
                subtitle: 'Sessions',
                color: const Color(0xFF009688),
                onTap: onOpenCounselling,
              ),
              _ToolTileHome(
                icon: Icons.shield_rounded,
                label: 'Safety',
                subtitle: 'Stories & questions',
                color: AppColors.softRed,
                onTap: onOpenSafety,
              ),
              _ToolTileHome(
                icon: Icons.contact_phone_rounded,
                label: 'Emergency',
                subtitle: 'Helplines',
                color: AppColors.ink,
                onTap: onOpenEmergency,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$value',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      height: 1,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolTileHome extends StatelessWidget {
  const _ToolTileHome({
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Admin notifications bottom sheet ─────────────────────────────────────────

class _AdminNotificationsSheet extends StatelessWidget {
  const _AdminNotificationsSheet({required this.adminVm});

  final AdminViewModel adminVm;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.muted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  if (adminVm.unreadCount > 0)
                    TextButton(
                      onPressed: adminVm.markAllRead,
                      child: const Text('Mark all read'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListenableBuilder(
                listenable: adminVm,
                builder: (_, _) {
                  final notes = adminVm.notifications;
                  if (notes.isEmpty) {
                    return const Center(
                      child: Text(
                        'No notifications yet.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: notes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _NotificationTile(
                      notification: notes[i],
                      onTap: () => adminVm.markNotificationRead(notes[i].id),
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

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final dynamic notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRead = notification.isRead as bool;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRead
                ? AppColors.muted.withValues(alpha: 0.15)
                : AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isRead
                    ? Icons.notifications_none_rounded
                    : Icons.notifications_active_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title as String,
                    style: TextStyle(
                      fontWeight:
                          isRead ? FontWeight.w600 : FontWeight.w800,
                      color: AppColors.ink,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.message as String,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

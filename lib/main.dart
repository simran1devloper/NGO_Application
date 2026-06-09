import 'package:flutter/material.dart';

import 'app_state.dart';
import 'core/colors.dart';
import 'core/config.dart';
import 'models/auth_models.dart';
import 'models/skill_category.dart';
import 'repositories/auth0_strategy.dart';
import 'repositories/auth_repository.dart';
import 'screens/admin/pending_approvals_screen.dart';
import 'screens/auth/auth_page.dart';
import 'screens/auth/pending_approval_screen.dart';
import 'screens/auth/rejected_screen.dart';
import 'screens/auth/student_register_screen.dart';
import 'screens/creator/content_creator_shell.dart';
import 'screens/mediator/mediator_shell.dart';
import 'screens/events/events_view.dart';
import 'screens/events/student/event_detail_screen.dart';
import 'screens/home/home_view.dart';
import 'screens/learn/learn_view.dart';
import 'screens/profile/profile_view.dart';
import 'screens/quiz/quiz_play_screen.dart';
import 'screens/helping_support/helping_support_view.dart';
import 'services/screen_security.dart';
import 'widgets/secure_app_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initializes the Auth0 JS client on web (no-op on Android/iOS).
  await initAuth0(AppConfig.auth0Domain, AppConfig.auth0ClientId);
  AppState.restore();
  // Apply FLAG_SECURE immediately for any restored session.
  await ScreenSecurity.apply();

  // Web only: if Auth0 just redirected back with a code, exchange it now.
  // On Android/iOS this always returns null (login completes in loginWithAuth0).
  try {
    final result = await AuthRepository.handleAuth0RedirectCallback();
    if (result != null) {
      AppState.setFromLogin(
        result.userId,
        result.accessToken,
        UserRole.fromString(result.role),
      );
    }
  } catch (_) {
    // Ignore — user will see the login screen and can retry.
  }

  runApp(const SecureAppWrapper(child: CareSkillApp()));
}

String _resolveInitialRoute() {
  if (!AppState.isAuthenticated) return '/login';
  return switch (AppState.accessStatus) {
    AccessStatus.approved => '/home',
    AccessStatus.pendingVerification => '/pending-approval',
    AccessStatus.rejected => '/rejected',
    AccessStatus.deactivated => '/rejected',
  };
}

class CareSkillApp extends StatelessWidget {
  const CareSkillApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: Colors.white,
        ),
        fontFamily: AppConfig.fontFamily,
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.w800),
          headlineMedium: TextStyle(fontWeight: FontWeight.w800),
          titleLarge: TextStyle(fontWeight: FontWeight.w800),
          titleMedium: TextStyle(fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      // Route on startup based on both auth state and access status.
      initialRoute: _resolveInitialRoute(),
      routes: {
        '/login': (_) => const AuthPage(),
        '/home': (_) => switch (AppState.activeRole) {
              UserRole.contentCreator => const ContentCreatorShell(),
              UserRole.mediator       => const MediatorShell(),
              _                      => const AppShell(),
            },
        '/register/student': (_) => const StudentRegisterScreen(),
        '/pending-approval': (_) => const PendingApprovalScreen(),
        '/rejected': (_) => const RejectedScreen(),
        '/admin/pending-approvals': (_) => const PendingApprovalsScreen(),
      },
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        final uri = Uri.parse(name);
        if (uri.pathSegments.length == 2) {
          final id = int.tryParse(uri.pathSegments[1]);
          if (id != null && uri.pathSegments[0] == 'quiz') {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => QuizPlayScreen(quizId: id),
            );
          }
          const eventPrefixes = {
            'event',
            'quiz-event',
            'daily-challenge',
            'workshop',
            'competition',
            'scholarship',
            'counselling-drive',
            'talent-hunt',
            'awareness-campaign',
            'cyber-security',
          };
          if (id != null && eventPrefixes.contains(uri.pathSegments[0])) {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => EventDetailScreen(eventId: id),
            );
          }
        }
        return null;
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  SkillCategory? _selectedLearnCategory;
  int _learnOpenVersion = 0;

  void _openLearn([SkillCategory? category]) {
    setState(() {
      _selectedIndex = 1;
      _selectedLearnCategory = category;
      _learnOpenVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeView(onOpenLearn: _openLearn),
      LearnView(
        key: ValueKey('learn-$_learnOpenVersion'),
        initialCategory: _selectedLearnCategory,
      ),
      const EventsView(),
      const HelpingSupportView(),
      const ProfileView(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: _selectedIndex,
        indicatorColor: AppColors.primary.withValues(alpha: 0.16),
        onDestinationSelected: (index) => setState(() {
          _selectedIndex = index;
          if (index != 1) _selectedLearnCategory = null;
          if (index == 1) _learnOpenVersion++;
        }),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school_rounded),
            label: 'Learn',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Calendar',
          ),
          const NavigationDestination(
            icon: Icon(Icons.support_agent_outlined),
            selectedIcon: Icon(Icons.support_agent_rounded),
            label: 'Helping Support',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

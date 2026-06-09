import 'package:flutter/material.dart';

import '../../core/colors.dart';
import '../profile/profile_view.dart';
import 'mediator_home_screen.dart';
import 'moderation_queue_screen.dart';

class MediatorShell extends StatefulWidget {
  const MediatorShell({super.key});

  @override
  State<MediatorShell> createState() => _MediatorShellState();
}

class _MediatorShellState extends State<MediatorShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const MediatorHomeScreen(),
      const ModerationQueueScreen(),
      const ProfileView(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: _selectedIndex,
        indicatorColor: const Color(0xFF009688).withValues(alpha: 0.16),
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.gavel_outlined),
            selectedIcon: Icon(Icons.gavel_rounded),
            label: 'Queue',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

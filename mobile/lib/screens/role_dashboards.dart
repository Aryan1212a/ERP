import 'package:flutter/material.dart';

import 'admin_dashboard_screen.dart';
import 'profile_screen.dart';
import 'student_academics_screen.dart';
import 'student_dashboard_screen.dart';
import 'student_notices_screen.dart';
import 'student_schedule_screen.dart';
import 'teacher_dashboard_screen.dart';

class StudentDashboardRoute extends StatelessWidget {
  const StudentDashboardRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const _StudentShell();
  }
}

class TeacherDashboardRoute extends StatelessWidget {
  const TeacherDashboardRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const TeacherDashboardScreen();
  }
}

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminDashboardShell();
  }
}

class _StudentShell extends StatefulWidget {
  const _StudentShell();

  @override
  State<_StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<_StudentShell> {
  int _selectedIndex = 0;

  late final List<Widget> _screens = [
    const StudentDashboardScreen(showNavigation: false),
    const StudentAcademicsScreen(showScaffold: false),
    const StudentScheduleScreen(showScaffold: false),
    const StudentNoticesScreen(showScaffold: false),
    const ProfileScreen(showAppBar: false, showLogoutTile: true),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: isDark ? const Color(0xFF0D1724) : Colors.white,
        indicatorColor: isDark ? const Color(0xFF203554) : const Color(0xFFDCE7FF),
        selectedIndex: _selectedIndex,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.school_outlined), label: 'Academics'),
          NavigationDestination(icon: Icon(Icons.schedule_outlined), label: 'Schedule'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), label: 'Notices'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }
}

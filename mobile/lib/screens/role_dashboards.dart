import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'student_dashboard_screen.dart';
import 'teacher_dashboard_screen.dart';

class StudentDashboardRoute extends StatelessWidget {
  const StudentDashboardRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const StudentDashboardScreen();
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
    return DashboardScreen(
      title: 'Admin Dashboard',
      subtitle: 'Operations summary',
      roleTag: 'Admin view',
      roleColor: const Color(0xFFF97316),
      extraActions: [
        DashboardActionData(
          label: 'Create User',
          subtitle: 'Add student/teacher',
          icon: Icons.person_add_alt_1_rounded,
          color: const Color(0xFF0EA5E9),
          onTap: () => Navigator.pushNamed(context, '/admin/users/create'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/role_dashboards.dart';
import 'screens/attendance_screen.dart';
import 'screens/timetable_screen.dart';
import 'screens/fees_screen.dart';
import 'screens/notices_screen.dart';
import 'screens/attendance_form_screen.dart';
import 'screens/admin_create_user_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/upload_marks_screen.dart';
import 'screens/upload_assignment_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/send_notice_screen.dart';
import 'screens/student_notices_screen.dart';
import 'screens/student_academics_screen.dart';
import 'screens/teacher_assignments_manage_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SchoolERPApp());
}

class SchoolERPApp extends StatelessWidget {
  const SchoolERPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'School ERP',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2563EB),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF60A5FA),
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/dashboard/student': (_) => const StudentDashboardRoute(),
        '/dashboard/teacher': (_) => const TeacherDashboardRoute(),
        '/dashboard/admin': (_) => const AdminDashboardScreen(),
        '/attendance': (_) => const AttendanceScreen(),
        '/attendance/form': (_) => const AttendanceFormScreen(),
        '/admin/users/create': (_) => const AdminCreateUserScreen(),
        '/auth/change-password': (_) => const ChangePasswordScreen(),
        '/teacher/marks/upload': (_) => const UploadMarksScreen(),
        '/teacher/assignments/upload': (_) => const UploadAssignmentScreen(),
        '/timetable': (_) => const TimetableScreen(),
        '/fees': (_) => const FeesScreen(),
        '/notices': (_) => const NoticesScreen(),
        '/notices/send': (_) => const SendNoticeScreen(),
        '/student/academics': (_) => const StudentAcademicsScreen(),
        '/student/notices': (_) => const StudentNoticesScreen(),
        '/teacher/assignments/manage': (_) => const TeacherAssignmentsManageScreen(),
        '/profile': (_) => const ProfileScreen(),
      },
    );
  }
}

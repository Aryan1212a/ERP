import 'package:flutter/material.dart';
import 'services/service_locator.dart';
import 'services/theme_service.dart';
import 'ui/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/role_dashboards.dart';
import 'screens/attendance_screen.dart';
import 'screens/timetable_screen.dart';
import 'screens/fees_screen.dart';
import 'screens/notices_screen.dart';
import 'screens/attendance_form_screen.dart';
import 'screens/student_attendance_screen.dart';
import 'screens/admin_create_user_screen.dart';
import 'screens/admin_classes_screen.dart';
import 'screens/admin_users_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/upload_marks_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/send_notice_screen.dart';
import 'screens/student_notices_screen.dart';
import 'screens/student_academics_screen.dart';
import 'screens/student_schedule_screen.dart';
import 'screens/teacher_students_screen.dart';
import 'screens/student_assignment_detail_screen.dart';
import 'screens/teacher_student_detail_screen.dart';
import 'screens/teacher_assignments_manage_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService.initialize();
  await Services.auth.initialize();
  runApp(const SchoolERPApp());
}

class SchoolERPApp extends StatelessWidget {
  const SchoolERPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Acadian',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          initialRoute: '/login',
          routes: {
            '/login': (_) => const LoginScreen(),
            '/dashboard': (_) => const DashboardScreen(),
            '/dashboard/student': (_) => const StudentDashboardRoute(),
            '/dashboard/teacher': (_) => const TeacherDashboardRoute(),
            '/dashboard/admin': (_) => const AdminDashboardScreen(),
            '/attendance': (_) => const AttendanceScreen(),
            '/student/attendance': (_) => const StudentAttendanceScreen(),
            '/attendance/form': (_) => const AttendanceFormScreen(),
            '/admin/classes': (_) => const AdminClassesScreen(),
            '/admin/users': (_) => const AdminUsersScreen(),
            '/admin/users/create': (_) => const AdminCreateUserScreen(),
            '/auth/change-password': (_) => const ChangePasswordScreen(),
            '/teacher/marks/upload': (_) => const UploadMarksScreen(),
            '/teacher/assignments/upload': (_) => const TeacherAssignmentsManageScreen(),
            '/timetable': (_) => const TimetableScreen(),
            '/fees': (_) => const FeesScreen(),
            '/notices': (_) => const NoticesScreen(),
            '/notices/send': (_) => const SendNoticeScreen(),
            '/student/academics': (_) => const StudentAcademicsScreen(),
            '/student/schedule': (_) => const StudentScheduleScreen(),
            '/student/notices': (_) => const StudentNoticesScreen(),
            '/teacher/assignments/manage': (_) => const TeacherAssignmentsManageScreen(),
            '/teacher/students': (_) => const TeacherStudentsScreen(),
            '/profile': (_) => const ProfileScreen(),
            '/student/assignment-detail': (context) => StudentAssignmentDetailScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/teacher/students/detail') {
              final studentId = settings.arguments as int;
              return MaterialPageRoute(
                builder: (_) => TeacherStudentDetailScreen(studentId: studentId),
              );
            }
            return null;
          },
        );
      },
    );
  }
}

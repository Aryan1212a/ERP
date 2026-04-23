import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:acadian/ui/app_theme.dart';

import '../services/service_locator.dart';
import '../ui/app_components.dart';
import 'admin_users_screen.dart';
import 'profile_screen.dart';
import 'admin_classes_screen.dart';

class AdminDashboardShell extends StatefulWidget {
  const AdminDashboardShell({super.key});

  @override
  State<AdminDashboardShell> createState() => _AdminDashboardShellState();
}

class _AdminDashboardShellState extends State<AdminDashboardShell> {
  int _selectedIndex = 0;

  late final List<Widget> _pages = [
    const AdminHomeScreen(),
    const AdminUsersScreen(),
    const AdminClassesScreen(),
    const ProfileScreen(showAppBar: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        destinations: const [
          NavigationDestination(
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            icon: Icon(Icons.space_dashboard_outlined),
            label: 'Overview',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.manage_accounts_rounded),
            icon: Icon(Icons.manage_accounts_outlined),
            label: 'Users',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.class_rounded),
            icon: Icon(Icons.class_outlined),
            label: 'Classes',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.person_rounded),
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
        onDestinationSelected: (index) {
          if (_selectedIndex == index) return;
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }
}

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  bool _loading = true;
  String? _error;
  List<_AdminUser> _users = [];
  List<_AdminClass> _classes = [];
  int _timetableEntries = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final responses = await Future.wait([
        Services.api.get('/api/v1/admin/users'),
        Services.api.get('/api/v1/classes'),
        Services.api.get('/api/v1/timetable'),
      ]);

      if (responses.any((response) => response.statusCode != 200)) {
        throw Exception('Unable to load dashboard');
      }

      final usersJson = jsonDecode(responses[0].body) as List<dynamic>;
      final classesJson = jsonDecode(responses[1].body) as List<dynamic>;
      final timetableJson = jsonDecode(responses[2].body) as List<dynamic>;

      if (!mounted) return;
      setState(() {
        _users = usersJson
            .map((item) => _AdminUser.fromJson(item as Map<String, dynamic>))
            .toList();
        _classes = classesJson
            .map((item) => _AdminClass.fromJson(item as Map<String, dynamic>))
            .toList();
        _timetableEntries = timetableJson.length;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load admin dashboard';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacherCount = _users.where((user) => user.role == 'teacher').length;
    final studentCount = _users.where((user) => user.role == 'student').length;
    final inactiveCount = _users.where((user) => !user.isActive).length;
    final passwordResetCount = _users.where((user) => user.mustChangePassword).length;
    final unassignedClasses = _classes.where((item) => item.classTeacherName == null).length;

    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _AdminHeader(
                totalUsers: _users.length,
                totalClasses: _classes.length,
                timetableEntries: _timetableEntries,
              ),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(title: 'Quick Actions'),
              const SizedBox(height: AppSpacing.lg),
              _ResponsiveDashboardGrid(
                mainAxisExtent: 132,
                children: [
                  _QuickActionCard(
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Create User',
                    onTap: () => Navigator.pushNamed(context, '/admin/users/create'),
                  ),
                  _QuickActionCard(
                    icon: Icons.manage_accounts_rounded,
                    label: 'Manage Users',
                    onTap: () => Navigator.pushNamed(context, '/admin/users'),
                  ),
                  _QuickActionCard(
                    icon: Icons.class_rounded,
                    label: 'Manage Classes',
                    onTap: () => Navigator.pushNamed(context, '/admin/classes'),
                  ),
                  _QuickActionCard(
                    icon: Icons.calendar_month_rounded,
                    label: 'Timetable',
                    onTap: () => Navigator.pushNamed(context, '/timetable'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(title: 'Key Metrics'),
              const SizedBox(height: AppSpacing.lg),
              if (_loading)
                const Center(child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: CircularProgressIndicator(),
                ))
              else if (_error != null)
                AppStateCard(
                  title: 'Dashboard unavailable',
                  message: _error!,
                  icon: Icons.error_outline_rounded,
                  action: AppButton.secondary(
                    onPressed: _load,
                    label: 'Retry',
                  ),
                )
              else
                _ResponsiveDashboardGrid(
                  mainAxisExtent: 148,
                  children: [
                    AppMetricCard(
                      label: 'Teachers',
                      value: teacherCount.toString(),
                      icon: Icons.school_rounded,
                    ),
                    AppMetricCard(
                      label: 'Students',
                      value: studentCount.toString(),
                      icon: Icons.groups_rounded,
                      accent: AppColors.secondary,
                    ),
                    AppMetricCard(
                      label: 'Inactive Accounts',
                      value: inactiveCount.toString(),
                      icon: Icons.person_off_rounded,
                      accent: AppColors.warning,
                    ),
                    AppMetricCard(
                      label: 'Pending Password Change',
                      value: passwordResetCount.toString(),
                      icon: Icons.lock_reset_rounded,
                      accent: AppColors.danger,
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(title: 'Operational Summary'),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  children: [
                    InfoTile(
                      icon: Icons.class_outlined,
                      label: 'Classes without teacher',
                      value: '$unassignedClasses class(es)',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Divider(),
                    const SizedBox(height: AppSpacing.lg),
                    InfoTile(
                      icon: Icons.calendar_month_outlined,
                      label: 'Timetable blocks',
                      value: '$_timetableEntries active entries',
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

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({
    required this.totalUsers,
    required this.totalClasses,
    required this.timetableEntries,
  });

  final int totalUsers;
  final int totalClasses;
  final int timetableEntries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.surfaceAlt,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin Dashboard', style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Track users, classes, and timetable readiness from one place.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _HeaderChip(label: '$totalUsers users'),
              _HeaderChip(label: '$totalClasses classes'),
              _HeaderChip(label: '$timetableEntries timetable blocks'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResponsiveDashboardGrid extends StatelessWidget {
  const _ResponsiveDashboardGrid({
    required this.children,
    required this.mainAxisExtent,
  });

  final List<Widget> children;
  final double mainAxisExtent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1100
            ? 4
            : width >= 720
                ? 3
                : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: children.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSpacing.lg,
            mainAxisSpacing: AppSpacing.lg,
            mainAxisExtent: mainAxisExtent,
          ),
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(label),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const Spacer(),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _AdminUser {
  const _AdminUser({
    required this.role,
    required this.isActive,
    required this.mustChangePassword,
  });

  final String role;
  final bool isActive;
  final bool mustChangePassword;

  factory _AdminUser.fromJson(Map<String, dynamic> json) {
    return _AdminUser(
      role: json['role'] as String? ?? 'student',
      isActive: json['is_active'] == true,
      mustChangePassword: json['must_change_password'] == true,
    );
  }
}

class _AdminClass {
  const _AdminClass({
    required this.classTeacherName,
  });

  final String? classTeacherName;

  factory _AdminClass.fromJson(Map<String, dynamic> json) {
    return _AdminClass(
      classTeacherName: json['class_teacher_name'] as String?,
    );
  }
}

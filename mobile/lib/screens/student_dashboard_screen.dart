import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/service_locator.dart';
import '../ui/app_components.dart';
import '../ui/app_theme.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({
    super.key,
    this.showNavigation = true,
  });

  final bool showNavigation;

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  bool _loading = true;
  String? _error;
  _StudentProfile? _profile;
  _StudentSummary? _summary;
  List<_ScheduleItem> _schedule = [];
  List<_AssignmentItem> _assignments = [];
  List<_NoticeItem> _notices = [];
  Map<int, String> _classNames = {};

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
        Services.api.get('/api/v1/me'),
        Services.api.get('/api/v1/student/summary'),
        Services.api.get('/api/v1/student/timetable/today'),
        Services.api.get('/api/v1/student/assignments'),
        Services.api.get('/api/v1/student/notices/unread'),
        Services.api.get('/api/v1/classes'),
      ]);

      if (responses.any((response) => response.statusCode != 200)) {
        throw Exception('Unable to load dashboard');
      }

      if (!mounted) return;

      final classesJson = jsonDecode(responses[5].body) as List<dynamic>;
      setState(() {
        _profile = _StudentProfile.fromJson(
          jsonDecode(responses[0].body) as Map<String, dynamic>,
        );
        _summary = _StudentSummary.fromJson(
          jsonDecode(responses[1].body) as Map<String, dynamic>,
        );
        _schedule = (jsonDecode(responses[2].body)['timetable'] as List<dynamic>)
            .map((item) => _ScheduleItem.fromJson(item as Map<String, dynamic>))
            .toList();
        _assignments = (jsonDecode(responses[3].body)['assignments'] as List<dynamic>)
            .map((item) => _AssignmentItem.fromJson(item as Map<String, dynamic>))
            .toList();
        _notices = (jsonDecode(responses[4].body)['notices'] as List<dynamic>)
            .map((item) => _NoticeItem.fromJson(item as Map<String, dynamic>))
            .toList();
        _classNames = {
          for (final item in classesJson)
            (item['id'] as int): (item['name'] as String? ?? 'Class')
        };
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load student dashboard';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final className = _profile?.classId == null
        ? 'No class assigned'
        : _classNames[_profile!.classId] ?? 'Class ${_profile!.classId}';
    final pendingAssignments = _assignments
        .where((assignment) => assignment.status == 'pending' || assignment.status == 'missing')
        .length;

    final content = RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _StudentHeader(
            name: _profile?.fullName ?? 'Student',
            className: className,
            attendancePct: _summary?.attendancePct ?? 0,
          ),
          const SizedBox(height: AppSpacing.xl),
          const AppSectionHeader(title: 'Quick Actions'),
          const SizedBox(height: AppSpacing.lg),
          _QuickActionsGrid(
            actions: [
              _QuickActionItem(
                icon: Icons.fact_check_outlined,
                label: 'Attendance',
                onTap: () => Navigator.pushNamed(context, '/student/attendance'),
              ),
              _QuickActionItem(
                icon: Icons.school_outlined,
                label: 'Academics',
                onTap: () => Navigator.pushNamed(context, '/student/academics'),
              ),
              _QuickActionItem(
                icon: Icons.schedule_outlined,
                label: 'Schedule',
                onTap: () => Navigator.pushNamed(context, '/student/schedule'),
              ),
              _QuickActionItem(
                icon: Icons.notifications_outlined,
                label: 'Notices',
                onTap: () => Navigator.pushNamed(context, '/student/notices'),
              ),
              _QuickActionItem(
                icon: Icons.person_outline,
                label: 'Profile',
                onTap: () => Navigator.pushNamed(context, '/profile'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const AppSectionHeader(title: 'Key Metrics'),
          const SizedBox(height: AppSpacing.lg),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null || _summary == null)
            AppStateCard(
              title: 'Dashboard unavailable',
              message: _error ?? 'No student summary available.',
              icon: Icons.error_outline_rounded,
              action: AppButton.secondary(label: 'Retry', onPressed: _load),
            )
          else
            _ResponsiveDashboardGrid(
              desktopColumns: 4,
              tabletColumns: 3,
              mobileColumns: 2,
              mainAxisExtent: 148,
              children: [
                AppMetricCard(
                  label: 'Attendance',
                  value: '${_summary!.attendancePct.toStringAsFixed(0)}%',
                  icon: Icons.fact_check_outlined,
                  onTap: () => Navigator.pushNamed(context, '/student/attendance'),
                ),
                AppMetricCard(
                  label: 'Pending Tasks',
                  value: '${_summary!.pendingTasks}',
                  icon: Icons.pending_actions_outlined,
                  accent: AppColors.secondary,
                ),
                AppMetricCard(
                  label: 'Assignments',
                  value: '$pendingAssignments',
                  icon: Icons.assignment_outlined,
                  accent: AppColors.warning,
                ),
                AppMetricCard(
                  label: 'Unread Notices',
                  value: '${_notices.length}',
                  icon: Icons.markunread_outlined,
                  accent: AppColors.danger,
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.xl),
          const AppSectionHeader(title: 'Today’s Schedule'),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: _schedule.isEmpty
                ? Text(
                    _loading ? 'Loading schedule...' : 'No classes scheduled today.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : Column(
                    children: [
                      for (final item in _schedule) ...[
                        InfoTile(
                          icon: Icons.schedule_rounded,
                          label: item.subject,
                          value: '${item.startTime} - ${item.endTime}',
                        ),
                        if (item != _schedule.last) ...[
                          const SizedBox(height: AppSpacing.lg),
                          const Divider(),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const AppSectionHeader(title: 'Upcoming Work'),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: _assignments.isEmpty
                ? Text(
                    _loading ? 'Loading assignments...' : 'No assignments available.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : Column(
                    children: [
                      for (final assignment in _assignments.take(3)) ...[
                        InfoTile(
                          icon: Icons.assignment_outlined,
                          label: assignment.title,
                          value: '${assignment.status.toUpperCase()}  •  Due ${assignment.dueDate}',
                        ),
                        if (assignment != _assignments.take(3).last) ...[
                          const SizedBox(height: AppSpacing.lg),
                          const Divider(),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const AppSectionHeader(title: 'Alerts'),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: (_summary?.alerts.isNotEmpty ?? false)
                ? Column(
                    children: [
                      for (final alert in _summary!.alerts) ...[
                        InfoTile(
                          icon: Icons.info_outline,
                          label: 'Notice',
                          value: alert,
                        ),
                        if (alert != _summary!.alerts.last) ...[
                          const SizedBox(height: AppSpacing.lg),
                          const Divider(),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ],
                    ],
                  )
                : Text(
                    'No urgent alerts right now.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
          ),
        ],
      ),
    );

    if (!widget.showNavigation) {
      return Scaffold(body: SafeArea(child: content));
    }

    return Scaffold(
      body: SafeArea(child: content),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            selectedIcon: Icon(Icons.dashboard_rounded),
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.school_rounded),
            icon: Icon(Icons.school_outlined),
            label: 'Academics',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.schedule_rounded),
            icon: Icon(Icons.schedule_outlined),
            label: 'Schedule',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.notifications_rounded),
            icon: Icon(Icons.notifications_outlined),
            label: 'Notices',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.person_rounded),
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
        onDestinationSelected: (index) {
          switch (index) {
            case 1:
              Navigator.pushNamed(context, '/student/academics');
              break;
            case 2:
              Navigator.pushNamed(context, '/student/schedule');
              break;
            case 3:
              Navigator.pushNamed(context, '/student/notices');
              break;
            case 4:
              Navigator.pushNamed(context, '/profile');
              break;
            default:
              break;
          }
        },
      ),
    );
  }
}

class _StudentHeader extends StatelessWidget {
  const _StudentHeader({
    required this.name,
    required this.className,
    required this.attendancePct,
  });

  final String name;
  final String className;
  final double attendancePct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.surfaceAlt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            className,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text('Attendance ${attendancePct.toStringAsFixed(0)}%'),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
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
            width: 42,
            height: 42,
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

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.actions});

  final List<_QuickActionItem> actions;

  @override
  Widget build(BuildContext context) {
    return _ResponsiveDashboardGrid(
      desktopColumns: 4,
      tabletColumns: 3,
      mobileColumns: 2,
      mainAxisExtent: 132,
      children: actions
          .map(
            (action) => _ActionCard(
              icon: action.icon,
              label: action.label,
              onTap: action.onTap,
            ),
          )
          .toList(),
    );
  }
}

class _ResponsiveDashboardGrid extends StatelessWidget {
  const _ResponsiveDashboardGrid({
    required this.children,
    required this.mainAxisExtent,
    this.desktopColumns = 4,
    this.tabletColumns = 3,
    this.mobileColumns = 2,
  });

  final List<Widget> children;
  final double mainAxisExtent;
  final int desktopColumns;
  final int tabletColumns;
  final int mobileColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1100
            ? desktopColumns
            : width >= 720
                ? tabletColumns
                : mobileColumns;

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

class _QuickActionItem {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _StudentProfile {
  const _StudentProfile({
    required this.fullName,
    required this.classId,
  });

  final String fullName;
  final int? classId;

  factory _StudentProfile.fromJson(Map<String, dynamic> json) {
    return _StudentProfile(
      fullName: json['full_name'] as String? ?? 'Student',
      classId: json['class_id'] as int?,
    );
  }
}

class _StudentSummary {
  const _StudentSummary({
    required this.attendancePct,
    required this.pendingTasks,
    required this.alerts,
  });

  final double attendancePct;
  final int pendingTasks;
  final List<String> alerts;

  factory _StudentSummary.fromJson(Map<String, dynamic> json) {
    return _StudentSummary(
      attendancePct: (json['attendance_pct'] as num?)?.toDouble() ?? 0,
      pendingTasks: json['pending_tasks'] as int? ?? 0,
      alerts: (json['alerts'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
    );
  }
}

class _ScheduleItem {
  const _ScheduleItem({
    required this.subject,
    required this.startTime,
    required this.endTime,
  });

  final String subject;
  final String startTime;
  final String endTime;

  factory _ScheduleItem.fromJson(Map<String, dynamic> json) {
    return _ScheduleItem(
      subject: json['subject'] as String? ?? 'Class',
      startTime: json['start_time'] as String? ?? '--:--',
      endTime: json['end_time'] as String? ?? '--:--',
    );
  }
}

class _AssignmentItem {
  const _AssignmentItem({
    required this.title,
    required this.status,
    required this.dueDate,
  });

  final String title;
  final String status;
  final String dueDate;

  factory _AssignmentItem.fromJson(Map<String, dynamic> json) {
    return _AssignmentItem(
      title: json['title'] as String? ?? 'Assignment',
      status: json['status'] as String? ?? 'pending',
      dueDate: json['due_date'] as String? ?? '--',
    );
  }
}

class _NoticeItem {
  const _NoticeItem({required this.title});

  final String title;

  factory _NoticeItem.fromJson(Map<String, dynamic> json) {
    return _NoticeItem(title: json['title'] as String? ?? 'Notice');
  }
}

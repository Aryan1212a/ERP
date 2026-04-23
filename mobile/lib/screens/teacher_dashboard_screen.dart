import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/service_locator.dart';
import '../ui/app_components.dart';
import '../ui/app_theme.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({
    super.key,
    this.showNavigation = true,
  });

  final bool showNavigation;

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  _TeacherSummary? _summary;
  List<_ScheduleItem> _schedule = [];
  _StudentInsights? _insights;
  bool _loading = true;
  String? _error;

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
        Services.api.get('/api/v1/teacher/summary'),
        Services.api.get('/api/v1/teacher/schedule/today'),
        Services.api.get('/api/v1/teacher/students/insights'),
      ]);
      if (responses.any((response) => response.statusCode != 200)) {
        throw Exception('Unable to load dashboard');
      }

      if (!mounted) return;
      setState(() {
        _summary = _TeacherSummary.fromJson(
          jsonDecode(responses[0].body) as Map<String, dynamic>,
        );
        _schedule = (jsonDecode(responses[1].body)['schedule'] as List<dynamic>)
            .map((item) => _ScheduleItem.fromJson(item as Map<String, dynamic>))
            .toList();
        _insights = _StudentInsights.fromJson(
          jsonDecode(responses[2].body) as Map<String, dynamic>,
        );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load teacher dashboard';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final content = SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _TeacherHeader(summary: summary),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(title: 'Quick Actions'),
              const SizedBox(height: AppSpacing.lg),
              _ResponsiveDashboardGrid(
                mainAxisExtent: 132,
                children: [
                  _ActionCard(
                    icon: Icons.fact_check_outlined,
                    label: 'Attendance',
                    onTap: () => Navigator.pushNamed(context, '/attendance/form'),
                  ),
                  _ActionCard(
                    icon: Icons.notifications_active_outlined,
                    label: 'Send Notice',
                    onTap: () => Navigator.pushNamed(context, '/notices/send'),
                  ),
                  _ActionCard(
                    icon: Icons.edit_note_outlined,
                    label: 'Marks',
                    onTap: () => Navigator.pushNamed(context, '/teacher/marks/upload'),
                  ),
                  _ActionCard(
                    icon: Icons.upload_file_outlined,
                    label: 'Assignments',
                    onTap: () => Navigator.pushNamed(context, '/teacher/assignments/manage'),
                  ),
                  _ActionCard(
                    icon: Icons.people_alt_outlined,
                    label: 'Students',
                    onTap: () => Navigator.pushNamed(context, '/teacher/students'),
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
              else if (_error != null || summary == null)
                AppStateCard(
                  title: 'Dashboard unavailable',
                  message: _error ?? 'No teacher summary available.',
                  icon: Icons.error_outline_rounded,
                  action: AppButton.secondary(label: 'Retry', onPressed: _load),
                )
              else
                _ResponsiveDashboardGrid(
                  mainAxisExtent: 148,
                  children: [
                    AppMetricCard(
                      label: 'Classes Today',
                      value: '${summary.todayClasses}',
                      icon: Icons.class_outlined,
                    ),
                    AppMetricCard(
                      label: 'Pending Attendance',
                      value: '${summary.pendingAttendance}',
                      icon: Icons.schedule_outlined,
                      accent: AppColors.warning,
                    ),
                    AppMetricCard(
                      label: 'Assignments to Review',
                      value: '${summary.assignmentsToReview}',
                      icon: Icons.assignment_outlined,
                      accent: AppColors.secondary,
                    ),
                    AppMetricCard(
                      label: 'Low Attendance Alerts',
                      value: '${summary.lowAttendanceAlerts}',
                      icon: Icons.warning_amber_rounded,
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
                              value: '${item.startTime} - ${item.endTime}  •  Class ${item.classId}',
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
              const AppSectionHeader(title: 'Student Insights'),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  children: [
                    InfoTile(
                      icon: Icons.trending_down_rounded,
                      label: 'Attendance below threshold',
                      value: '${_insights?.belowAttendanceThreshold.length ?? 0} student(s)',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Divider(),
                    const SizedBox(height: AppSpacing.lg),
                    InfoTile(
                      icon: Icons.assignment_late_outlined,
                      label: 'Missing assignments',
                      value: '${_insights?.missingAssignments.length ?? 0} student(s)',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    );

    if (!widget.showNavigation) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Dashboard')),
      body: content,
    );
  }
}

class _TeacherHeader extends StatelessWidget {
  const _TeacherHeader({required this.summary});

  final _TeacherSummary? summary;

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
          Text('Teaching Overview', style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Review your classes, teaching workload, and follow-up items for today.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _HeaderChip(label: '${summary?.todayClasses ?? 0} classes'),
              _HeaderChip(label: '${summary?.pendingAttendance ?? 0} pending'),
              _HeaderChip(label: '${summary?.assignmentsToReview ?? 0} to review'),
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

class _TeacherSummary {
  const _TeacherSummary({
    required this.todayClasses,
    required this.pendingAttendance,
    required this.assignmentsToReview,
    required this.lowAttendanceAlerts,
  });

  final int todayClasses;
  final int pendingAttendance;
  final int assignmentsToReview;
  final int lowAttendanceAlerts;

  factory _TeacherSummary.fromJson(Map<String, dynamic> json) {
    return _TeacherSummary(
      todayClasses: json['today_classes'] as int? ?? 0,
      pendingAttendance: json['pending_attendance'] as int? ?? 0,
      assignmentsToReview: json['assignments_to_review'] as int? ?? 0,
      lowAttendanceAlerts: json['low_attendance_alerts'] as int? ?? 0,
    );
  }
}

class _StudentInsights {
  const _StudentInsights({
    required this.belowAttendanceThreshold,
    required this.missingAssignments,
  });

  final List<dynamic> belowAttendanceThreshold;
  final List<dynamic> missingAssignments;

  factory _StudentInsights.fromJson(Map<String, dynamic> json) {
    return _StudentInsights(
      belowAttendanceThreshold:
          json['below_attendance_threshold'] as List<dynamic>? ?? const [],
      missingAssignments:
          json['missing_assignments'] as List<dynamic>? ?? const [],
    );
  }
}

class _ScheduleItem {
  const _ScheduleItem({
    required this.subject,
    required this.classId,
    required this.startTime,
    required this.endTime,
  });

  final String subject;
  final int classId;
  final String startTime;
  final String endTime;

  factory _ScheduleItem.fromJson(Map<String, dynamic> json) {
    return _ScheduleItem(
      subject: json['subject'] as String? ?? 'Class',
      classId: json['class_id'] as int? ?? 0,
      startTime: json['start_time'] as String? ?? '--:--',
      endTime: json['end_time'] as String? ?? '--:--',
    );
  }
}

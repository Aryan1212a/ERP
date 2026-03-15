import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/service_locator.dart';

/// Teacher Dashboard (Material 3, mobile-first)
/// Live data is pulled from the backend teacher endpoints.
class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

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
      final res = await Future.wait([
        Services.api.get('/api/v1/teacher/summary'),
        Services.api.get('/api/v1/teacher/schedule/today'),
        Services.api.get('/api/v1/teacher/students/insights'),
      ]);

      if (res.any((r) => r.statusCode != 200)) {
        throw Exception('Failed to load dashboard');
      }

      final summaryJson = jsonDecode(res[0].body) as Map<String, dynamic>;
      final scheduleJson = jsonDecode(res[1].body) as Map<String, dynamic>;
      final insightsJson = jsonDecode(res[2].body) as Map<String, dynamic>;

      setState(() {
        _summary = _TeacherSummary.fromJson(summaryJson);
        _schedule = (scheduleJson['schedule'] as List<dynamic>)
            .map((item) => _ScheduleItem.fromJson(item as Map<String, dynamic>))
            .toList();
        _insights = _StudentInsights.fromJson(insightsJson);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Unable to load dashboard';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Greeting section
              _GreetingSection(
                teacherName: 'Teacher',
                dateText: _formatDate(DateTime.now()),
              ),
              const SizedBox(height: 16),

              // Summary cards
              _SectionHeader(title: 'Today Summary'),
              const SizedBox(height: 8),
              if (_loading)
                const _SummarySkeleton()
              else if (_summary != null)
                _SummaryGrid(
                  cards: [
                    _SummaryCardData(
                      title: 'Classes Today',
                      value: _summary!.todayClasses.toString(),
                      icon: Icons.class_outlined,
                      color: const Color(0xFF3B82F6),
                    ),
                    _SummaryCardData(
                      title: 'Pending Attendance',
                      value: _summary!.pendingAttendance.toString(),
                      icon: Icons.fact_check_outlined,
                      color: const Color(0xFFF59E0B),
                    ),
                    _SummaryCardData(
                      title: 'Assignments to Review',
                      value: _summary!.assignmentsToReview.toString(),
                      icon: Icons.assignment_outlined,
                      color: const Color(0xFF8B5CF6),
                    ),
                    _SummaryCardData(
                      title: 'Low Attendance Alerts',
                      value: _summary!.lowAttendanceAlerts.toString(),
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFEF4444),
                    ),
                  ],
                )
              else
                _ErrorState(message: _error ?? 'No summary data'),
              const SizedBox(height: 20),

              // Schedule timeline
              _SectionHeader(title: 'Today’s Schedule'),
              const SizedBox(height: 8),
              _CardContainer(
                child: _loading
                    ? const _ScheduleSkeleton()
                    : _schedule.isEmpty
                        ? const _EmptyText('No classes scheduled today.')
                        : Column(
                            children: _schedule
                                .map(
                                  (item) => _TimelineItem(
                                    time: '${item.startTime} - ${item.endTime}',
                                    title: item.subject,
                                    subtitle: 'Class ${item.classId}',
                                    color: theme.colorScheme.primary,
                                  ),
                                )
                                .toList(),
                          ),
              ),
              const SizedBox(height: 20),

              // Student insights
              _SectionHeader(title: 'Student Insights'),
              const SizedBox(height: 8),
              _CardContainer(
                child: _loading
                    ? const _InsightsSkeleton()
                    : _insights == null
                        ? _ErrorState(message: _error ?? 'No insights')
                        : Column(
                            children: [
                              _InsightRow(
                                icon: Icons.trending_down_rounded,
                                title: 'Below attendance threshold',
                                value: '${_insights!.belowAttendanceThreshold.length} students',
                                color: const Color(0xFFEF4444),
                              ),
                              const Divider(height: 24),
                              _InsightRow(
                                icon: Icons.assignment_late_outlined,
                                title: 'Missing assignments',
                                value: '${_insights!.missingAssignments.length} students',
                                color: const Color(0xFFF59E0B),
                              ),
                            ],
                          ),
              ),
              const SizedBox(height: 20),

              // Quick actions
              _SectionHeader(title: 'Quick Actions'),
              const SizedBox(height: 8),
              _QuickActionsGrid(
                actions: [
                  _QuickActionData(
                    label: 'Mark Attendance',
                    icon: Icons.fact_check_outlined,
                    color: const Color(0xFF3B82F6),
                    onTap: () => Navigator.pushNamed(context, '/attendance/form'),
                  ),
                  _QuickActionData(
                    label: 'Upload Assignment',
                    icon: Icons.upload_file_outlined,
                    color: const Color(0xFF8B5CF6),
                    onTap: () => Navigator.pushNamed(context, '/teacher/assignments/upload'),
                  ),
                  _QuickActionData(
                    label: 'Enter Marks',
                    icon: Icons.edit_note_outlined,
                    color: const Color(0xFF10B981),
                    onTap: () => Navigator.pushNamed(context, '/teacher/marks/upload'),
                  ),
                  _QuickActionData(
                    label: 'Send Notice',
                    icon: Icons.campaign_outlined,
                    color: const Color(0xFFF59E0B),
                    onTap: () => Navigator.pushNamed(context, '/notices/send'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      // Bottom navigation for primary app areas
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.class_outlined), label: 'Classes'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), label: 'Assignments'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Students'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
        onDestinationSelected: (index) {
          switch (index) {
            case 1:
              Navigator.pushNamed(context, '/attendance/form');
              break;
            case 2:
              Navigator.pushNamed(context, '/teacher/assignments/manage');
              break;
            case 3:
              Navigator.pushNamed(context, '/attendance');
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

/// Greeting section with teacher name and date
class _GreetingSection extends StatelessWidget {
  const _GreetingSection({
    required this.teacherName,
    required this.dateText,
  });

  final String teacherName;
  final String dateText;

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            child: Icon(Icons.person_outline),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Good morning,', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  teacherName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(dateText, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

/// Summary grid (2 columns on mobile)
class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.cards});

  final List<_SummaryCardData> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((card) => SizedBox(width: itemWidth, child: _SummaryCard(data: card)))
              .toList(),
        );
      },
    );
  }
}

/// Summary card
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});

  final _SummaryCardData data;

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: data.color.withOpacity(0.12),
            child: Icon(data.icon, color: data.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  data.value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Timeline item for schedule
class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final String time;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              height: 10,
              width: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Container(width: 2, height: 36, color: Colors.grey.shade300),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(time, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Student insight row
class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

/// Quick actions grid
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.actions});

  final List<_QuickActionData> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions
              .map((action) => SizedBox(width: itemWidth, child: _QuickActionCard(data: action)))
              .toList(),
        );
      },
    );
  }
}

/// Quick action card
class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.data});

  final _QuickActionData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: data.onTap,
      child: _CardContainer(
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: data.color.withOpacity(0.12),
              child: Icon(data.icon, color: data.color),
            ),
            const SizedBox(height: 10),
            Text(
              data.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable card container (Material 3)
class _CardContainer extends StatelessWidget {
  const _CardContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: Text(message, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.bodySmall);
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(
            4,
            (_) => SizedBox(
              width: itemWidth,
              child: _CardContainer(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.withOpacity(0.2),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScheduleSkeleton extends StatelessWidget {
  const _ScheduleSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.withOpacity(0.2),
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightsSkeleton extends StatelessWidget {
  const _InsightsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.withOpacity(0.2),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.withOpacity(0.2),
          ),
        ),
      ],
    );
  }
}

class _SummaryCardData {
  const _SummaryCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
}

class _QuickActionData {
  const _QuickActionData({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _TeacherSummary {
  _TeacherSummary({
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
      todayClasses: json['today_classes'] as int,
      pendingAttendance: json['pending_attendance'] as int,
      assignmentsToReview: json['assignments_to_review'] as int,
      lowAttendanceAlerts: json['low_attendance_alerts'] as int,
    );
  }
}

class _ScheduleItem {
  _ScheduleItem({
    required this.period,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.classId,
  });

  final int period;
  final String startTime;
  final String endTime;
  final String subject;
  final int classId;

  factory _ScheduleItem.fromJson(Map<String, dynamic> json) {
    return _ScheduleItem(
      period: json['period'] as int,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      subject: json['subject'] as String,
      classId: json['class_id'] as int,
    );
  }
}

class _StudentInsights {
  _StudentInsights({
    required this.belowAttendanceThreshold,
    required this.missingAssignments,
  });

  final List<_StudentInsight> belowAttendanceThreshold;
  final List<_StudentInsight> missingAssignments;

  factory _StudentInsights.fromJson(Map<String, dynamic> json) {
    return _StudentInsights(
      belowAttendanceThreshold: (json['below_attendance_threshold'] as List<dynamic>)
          .map((item) => _StudentInsight.fromJson(item as Map<String, dynamic>))
          .toList(),
      missingAssignments: (json['missing_assignments'] as List<dynamic>)
          .map((item) => _StudentInsight.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class _StudentInsight {
  _StudentInsight({
    required this.studentId,
    required this.name,
    required this.reason,
  });

  final int studentId;
  final String name;
  final String reason;

  factory _StudentInsight.fromJson(Map<String, dynamic> json) {
    return _StudentInsight(
      studentId: json['student_id'] as int,
      name: json['name'] as String,
      reason: json['reason'] as String,
    );
  }
}

String _formatDate(DateTime date) {
  const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  final weekday = weekdays[date.weekday - 1];
  final month = months[date.month - 1];
  return '$weekday, $month ${date.day}, ${date.year}';
}

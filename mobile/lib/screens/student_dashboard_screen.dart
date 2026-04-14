import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/service_locator.dart';

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

  _Me? _me;
  _StudentSummary? _summary;
  List<_ScheduleItem> _schedule = [];
  List<_StudentAssignment> _assignments = [];
  List<_PerformanceItem> _performance = [];
  List<_StudentNotice> _notices = [];
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
        Services.api.get('/api/v1/student/performance'),
        Services.api.get('/api/v1/student/notices/unread'),
        Services.api.get('/api/v1/classes'),
      ]);
      if (responses.any((r) => r.statusCode != 200)) {
        throw Exception('Failed to load');
      }

      final meJson = jsonDecode(responses[0].body) as Map<String, dynamic>;
      final summaryJson = jsonDecode(responses[1].body) as Map<String, dynamic>;
      final scheduleJson = jsonDecode(responses[2].body) as Map<String, dynamic>;
      final assignmentsJson = jsonDecode(responses[3].body) as Map<String, dynamic>;
      final performanceJson = jsonDecode(responses[4].body) as Map<String, dynamic>;
      final noticesJson = jsonDecode(responses[5].body) as Map<String, dynamic>;
      final classesJson = jsonDecode(responses[6].body) as List<dynamic>;

      if (!mounted) return;
      setState(() {
        _me = _Me.fromJson(meJson);
        _summary = _StudentSummary.fromJson(summaryJson);
        _schedule = (scheduleJson['timetable'] as List<dynamic>)
            .map((e) => _ScheduleItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _assignments = (assignmentsJson['assignments'] as List<dynamic>)
            .map((e) => _StudentAssignment.fromJson(e as Map<String, dynamic>))
            .toList();
        _performance = (performanceJson['performance'] as List<dynamic>)
            .map((e) => _PerformanceItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _notices = (noticesJson['notices'] as List<dynamic>)
            .map((e) => _StudentNotice.fromJson(e as Map<String, dynamic>))
            .toList();
        _classNames = {
          for (final c in classesJson) (c['id'] as int): (c['name'] as String)
        };
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _me = null;
        _summary = null;
        _schedule = [];
        _assignments = [];
        _performance = [];
        _notices = [];
        _classNames = {};
        _loading = false;
        _error = 'Unable to load dashboard';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final className = _me?.classId != null ? _classNames[_me!.classId] : null;
    final attendancePct = _summary?.attendancePct ?? 0;
    final pendingCount = _assignments
        .where((a) => a.status == 'pending' || a.status == 'missing')
        .length;
    final overdueCount = _assignments
        .where((a) => (a.status == 'pending' || a.status == 'missing') && a.dueDate.isBefore(_today()))
        .length;
    final performanceValues = _performance.take(5).map((e) => e.percentage.round()).toList();
    final averageScore = _performance.isEmpty
        ? 0
        : (_performance.map((e) => e.percentage).reduce((a, b) => a + b) / _performance.length).round();
    final nextClass = _schedule.isNotEmpty ? _schedule.first : null;
    final upcomingAssignments = _assignments
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final palette = _StudentDashboardPalette.fromBrightness(isDark);

    final content = SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        color: palette.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _DashboardHero(
                palette: palette,
                studentName: _me?.fullName ?? 'Student',
                className: className ?? 'Class',
                attendancePercent: attendancePct.round(),
                nextClass: nextClass,
                loading: _loading,
                error: _error,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: _SectionLabel(
                  title: 'Student Pulse',
                  subtitle: 'Academic health, tasks, and trend at a glance',
                  palette: palette,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _MetricsGrid(
                  palette: palette,
                  loading: _loading,
                  error: _error,
                  attendancePercent: attendancePct.round(),
                  pendingAssignments: pendingCount,
                  overdueAssignments: overdueCount,
                  averageScore: averageScore,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 26, 16, 0),
                child: _SectionLabel(
                  title: 'Today',
                  subtitle: 'Classes and submissions you should watch first',
                  palette: palette,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _DashboardPanel(
                  palette: palette,
                  child: _loading
                      ? const _ScheduleSkeleton()
                      : _error != null
                          ? _ErrorState(message: _error!)
                          : _schedule.isEmpty
                              ? const _EmptyText('No classes scheduled today.')
                              : Column(
                                  children: _schedule
                                      .asMap()
                                      .entries
                                      .map(
                                        (entry) => _ScheduleRailItem(
                                          item: entry.value,
                                          palette: palette,
                                          isLast: entry.key == _schedule.length - 1,
                                        ),
                                      )
                                      .toList(),
                                ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _DashboardPanel(
                  palette: palette,
                  child: _loading
                      ? const _SkeletonCard(height: 144)
                      : _error != null
                          ? _ErrorState(message: _error!)
                          : _AssignmentsFocus(
                              palette: palette,
                              assignments: upcomingAssignments.take(3).toList(),
                            ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 26, 16, 0),
                child: _SectionLabel(
                  title: 'Performance',
                  subtitle: 'Recent academic signal from your latest evaluations',
                  palette: palette,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _DashboardPanel(
                  palette: palette,
                  child: _loading
                      ? const _SkeletonCard(height: 160)
                      : _error != null
                          ? _ErrorState(message: _error!)
                          : _PerformancePanel(
                              palette: palette,
                              averageScore: averageScore,
                              chartValues: performanceValues.isEmpty ? [0] : performanceValues,
                              performance: _performance.take(3).toList(),
                            ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 26, 16, 0),
                child: _SectionLabel(
                  title: 'Alerts & Notices',
                  subtitle: 'Unread notices and things that need attention',
                  palette: palette,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: _DashboardPanel(
                  palette: palette,
                  child: _loading
                      ? const _AlertsSkeleton()
                      : _error != null
                          ? _ErrorState(message: _error!)
                          : _AlertsPanel(
                              palette: palette,
                              alerts: _summary?.alerts ?? const [],
                              notices: _notices.take(3).toList(),
                            ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Theme(
      data: theme.copyWith(
        textTheme: GoogleFonts.dmSansTextTheme(theme.textTheme),
      ),
      child: Scaffold(
      backgroundColor: palette.scaffold,
      body: content,
      bottomNavigationBar: widget.showNavigation ? NavigationBar(
        backgroundColor: palette.navBackground,
        indicatorColor: palette.navIndicator,
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.school_outlined), label: 'Academics'),
          NavigationDestination(icon: Icon(Icons.schedule_outlined), label: 'Schedule'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), label: 'Notices'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
        onDestinationSelected: (index) async {
          switch (index) {
            case 1:
              Navigator.pushNamed(context, '/student/academics');
              break;
            case 2:
              Navigator.pushNamed(context, '/student/schedule');
              break;
            case 3:
              await Navigator.pushNamed(context, '/student/notices');
              if (!mounted) return;
              _load();
              break;
            case 4:
              Navigator.pushNamed(context, '/profile');
              break;
            default:
              break;
          }
        },
      ) : null,
    ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    required this.subtitle,
    required this.palette,
  });

  final String title;
  final String subtitle;
  final _StudentDashboardPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: palette.sectionTitle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: palette.sectionSubtitle,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.palette,
    required this.studentName,
    required this.className,
    required this.attendancePercent,
    required this.nextClass,
    required this.loading,
    required this.error,
  });

  final _StudentDashboardPalette palette;
  final String studentName;
  final String className;
  final int attendancePercent;
  final _ScheduleItem? nextClass;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.heroGradient,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: palette.heroShadow,
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -22,
            right: -16,
            child: Container(
              width: 138,
              height: 138,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -36,
            right: 40,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Student Dashboard',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.74),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          studentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Text(
                  'Class $className',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Track attendance, upcoming periods, notices, and your academic momentum from one clear student view.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _HeroMetric(
                      label: 'Attendance',
                      value: loading ? '--' : '$attendancePercent%',
                      caption: 'Current record',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HeroMetric(
                      label: 'Next Class',
                      value: loading
                          ? '--'
                          : error != null
                              ? 'Issue'
                              : nextClass?.subject ?? 'Free',
                      caption: loading
                          ? 'Loading'
                          : nextClass == null
                              ? 'No more periods'
                              : '${nextClass!.startTime} - ${nextClass!.endTime}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({
    required this.palette,
    required this.loading,
    required this.error,
    required this.attendancePercent,
    required this.pendingAssignments,
    required this.overdueAssignments,
    required this.averageScore,
  });

  final _StudentDashboardPalette palette;
  final bool loading;
  final String? error;
  final int attendancePercent;
  final int pendingAssignments;
  final int overdueAssignments;
  final int averageScore;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.16,
      children: [
        _MetricCard(
          palette: palette,
          title: 'Attendance',
          value: loading ? '--' : '$attendancePercent%',
          detail: 'Current presence rate',
          icon: Icons.fact_check_rounded,
          accent: const Color(0xFF2563EB),
        ),
        _MetricCard(
          palette: palette,
          title: 'Pending Work',
          value: loading ? '--' : '$pendingAssignments',
          detail: 'Assignments awaiting submission',
          icon: Icons.assignment_outlined,
          accent: const Color(0xFF7C3AED),
        ),
        _MetricCard(
          palette: palette,
          title: 'Overdue',
          value: loading ? '--' : '$overdueAssignments',
          detail: error != null ? error! : 'Items that already crossed due date',
          icon: Icons.alarm_rounded,
          accent: const Color(0xFFDC2626),
        ),
        _MetricCard(
          palette: palette,
          title: 'Average Score',
          value: loading ? '--' : '$averageScore%',
          detail: 'Recent academic performance',
          icon: Icons.insights_rounded,
          accent: const Color(0xFF059669),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.palette,
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.accent,
  });

  final _StudentDashboardPalette palette;
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow,
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              color: palette.cardMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: palette.cardTitle,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.cardMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleRailItem extends StatelessWidget {
  const _ScheduleRailItem({
    required this.item,
    required this.palette,
    required this.isLast,
  });

  final _ScheduleItem item;
  final _StudentDashboardPalette palette;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: palette.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: palette.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 74,
                  color: palette.railLine,
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.innerPanel,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.innerBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: palette.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Period ${item.period}',
                          style: TextStyle(
                            color: palette.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${item.startTime} - ${item.endTime}',
                        style: TextStyle(
                          color: palette.cardMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.subject,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: palette.cardTitle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Class ${item.classId}',
                    style: TextStyle(
                      color: palette.cardMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentsFocus extends StatelessWidget {
  const _AssignmentsFocus({
    required this.palette,
    required this.assignments,
  });

  final _StudentDashboardPalette palette;
  final List<_StudentAssignment> assignments;

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) {
      return const _EmptyText('No assignments are pending right now.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assignment Focus',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.cardTitle,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'The nearest due items are surfaced first so you can act quickly.',
          style: TextStyle(
            color: palette.cardMuted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        ...assignments.asMap().entries.map(
              (entry) => Padding(
                padding: EdgeInsets.only(bottom: entry.key == assignments.length - 1 ? 0 : 12),
                child: _AssignmentTile(
                  assignment: entry.value,
                  palette: palette,
                ),
              ),
            ),
      ],
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({
    required this.assignment,
    required this.palette,
  });

  final _StudentAssignment assignment;
  final _StudentDashboardPalette palette;

  @override
  Widget build(BuildContext context) {
    final overdue = assignment.dueDate.isBefore(_today());
    final statusColor = overdue
        ? const Color(0xFFDC2626)
        : assignment.status == 'submitted'
            ? const Color(0xFF059669)
            : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.innerPanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.innerBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              overdue ? Icons.priority_high_rounded : Icons.assignment_turned_in_outlined,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.cardTitle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Due ${_formatDate(assignment.dueDate)}',
                  style: TextStyle(
                    color: palette.cardMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              overdue ? 'Overdue' : _titleCase(assignment.status),
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformancePanel extends StatelessWidget {
  const _PerformancePanel({
    required this.palette,
    required this.averageScore,
    required this.chartValues,
    required this.performance,
  });

  final _StudentDashboardPalette palette;
  final int averageScore;
  final List<int> chartValues;
  final List<_PerformanceItem> performance;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Average Score',
                    style: TextStyle(
                      color: palette.cardMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$averageScore%',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: palette.cardTitle,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${performance.length} recent',
                style: TextStyle(
                  color: palette.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _MiniLineChart(values: chartValues, palette: palette),
        if (performance.isNotEmpty) ...[
          const SizedBox(height: 18),
          ...performance.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.subject,
                      style: TextStyle(
                        color: palette.cardTitle,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _titleCase(item.assessmentType),
                    style: TextStyle(
                      color: palette.cardMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${item.percentage.round()}%',
                    style: TextStyle(
                      color: palette.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel({
    required this.palette,
    required this.alerts,
    required this.notices,
  });

  final _StudentDashboardPalette palette;
  final List<String> alerts;
  final List<_StudentNotice> notices;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty && notices.isEmpty) {
      return const _EmptyText('No new alerts.');
    }
    return Column(
      children: [
        ...alerts.map(
          (alert) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _NoticeTile(
              palette: palette,
              icon: Icons.warning_amber_rounded,
              title: alert,
              accent: const Color(0xFFF59E0B),
            ),
          ),
        ),
        ...notices.map(
          (notice) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _NoticeTile(
              palette: palette,
              icon: Icons.notifications_active_outlined,
              title: notice.title,
              accent: palette.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({
    required this.palette,
    required this.icon,
    required this.title,
    required this.accent,
  });

  final _StudentDashboardPalette palette;
  final IconData icon;
  final String title;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.innerPanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.innerBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: palette.cardTitle,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.palette,
    required this.child,
  });

  final _StudentDashboardPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow,
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MiniLineChart extends StatelessWidget {
  const _MiniLineChart({
    required this.values,
    required this.palette,
  });
  final List<int> values;
  final _StudentDashboardPalette palette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      width: double.infinity,
      child: CustomPaint(
        painter: _LineChartPainter(values, palette),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter(this.values, this.palette);
  final List<int> values;
  final _StudentDashboardPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final gridPaint = Paint()
      ..color = palette.chartGrid
      ..strokeWidth = 1;
    for (int i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final paint = Paint()
      ..color = palette.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          palette.primary.withValues(alpha: 0.28),
          palette.primary.withValues(alpha: 0.02),
        ],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    final maxVal = values.reduce(math.max).toDouble();
    final minVal = values.reduce(math.min).toDouble();
    final range = (maxVal - minVal).clamp(1, double.infinity);

    final path = Path();
    final fillPath = Path();
    for (int i = 0; i < values.length; i++) {
      final x = values.length == 1 ? size.width / 2 : size.width * (i / (values.length - 1));
      final y = size.height - ((values[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    final lastX = values.length == 1 ? size.width / 2 : size.width;
    fillPath.lineTo(lastX, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.grey.withValues(alpha: 0.16),
      ),
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
              borderRadius: BorderRadius.circular(14),
              color: Colors.grey.withValues(alpha: 0.2),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertsSkeleton extends StatelessWidget {
  const _AlertsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.withValues(alpha: 0.2),
            ),
          ),
        ),
      ),
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

class _StudentDashboardPalette {
  const _StudentDashboardPalette({
    required this.scaffold,
    required this.heroGradient,
    required this.heroShadow,
    required this.primary,
    required this.cardBackground,
    required this.cardBorder,
    required this.cardShadow,
    required this.innerPanel,
    required this.innerBorder,
    required this.sectionTitle,
    required this.sectionSubtitle,
    required this.cardTitle,
    required this.cardMuted,
    required this.railLine,
    required this.chartGrid,
    required this.navBackground,
    required this.navIndicator,
  });

  final Color scaffold;
  final List<Color> heroGradient;
  final Color heroShadow;
  final Color primary;
  final Color cardBackground;
  final Color cardBorder;
  final Color cardShadow;
  final Color innerPanel;
  final Color innerBorder;
  final Color sectionTitle;
  final Color sectionSubtitle;
  final Color cardTitle;
  final Color cardMuted;
  final Color railLine;
  final Color chartGrid;
  final Color navBackground;
  final Color navIndicator;

  factory _StudentDashboardPalette.fromBrightness(bool isDark) {
    return isDark
        ? const _StudentDashboardPalette(
            scaffold: Color(0xFF08111C),
            heroGradient: [Color(0xFF15355F), Color(0xFF3C2A88), Color(0xFF111C34)],
            heroShadow: Color(0x55000000),
            primary: Color(0xFF7EA6FF),
            cardBackground: Color(0xFF111C2A),
            cardBorder: Color(0xFF1E3145),
            cardShadow: Color(0x33000000),
            innerPanel: Color(0xFF0D1724),
            innerBorder: Color(0xFF1B2B3D),
            sectionTitle: Color(0xFFF4F8FF),
            sectionSubtitle: Color(0xFFA0B0C4),
            cardTitle: Color(0xFFF4F8FF),
            cardMuted: Color(0xFFA0B0C4),
            railLine: Color(0xFF2C4560),
            chartGrid: Color(0x1FFFFFFF),
            navBackground: Color(0xFF0D1724),
            navIndicator: Color(0xFF203554),
          )
        : const _StudentDashboardPalette(
            scaffold: Color(0xFFF4F7FC),
            heroGradient: [Color(0xFF103A71), Color(0xFF4B4ACF), Color(0xFF16A3B7)],
            heroShadow: Color(0x26103A71),
            primary: Color(0xFF345BFF),
            cardBackground: Color(0xFFFFFFFF),
            cardBorder: Color(0xFFE4EBF5),
            cardShadow: Color(0x120F172A),
            innerPanel: Color(0xFFF7FAFF),
            innerBorder: Color(0xFFE4EBF5),
            sectionTitle: Color(0xFF0F172A),
            sectionSubtitle: Color(0xFF5E7087),
            cardTitle: Color(0xFF122033),
            cardMuted: Color(0xFF6A7C92),
            railLine: Color(0xFFD7E2F2),
            chartGrid: Color(0x140F172A),
            navBackground: Color(0xFFFFFFFF),
            navIndicator: Color(0xFFDCE7FF),
          );
  }
}

class _Me {
  _Me({required this.fullName, required this.classId});
  final String fullName;
  final int? classId;

  factory _Me.fromJson(Map<String, dynamic> json) {
    return _Me(
      fullName: json['full_name'] as String,
      classId: json['class_id'] as int?,
    );
  }
}

class _StudentSummary {
  _StudentSummary({required this.attendancePct, required this.alerts});
  final double attendancePct;
  final List<String> alerts;

  factory _StudentSummary.fromJson(Map<String, dynamic> json) {
    return _StudentSummary(
      attendancePct: (json['attendance_pct'] as num).toDouble(),
      alerts: (json['alerts'] as List<dynamic>).map((e) => e.toString()).toList(),
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

class _StudentAssignment {
  _StudentAssignment({
    required this.assignmentId,
    required this.title,
    required this.dueDate,
    required this.status,
  });

  final int assignmentId;
  final String title;
  final DateTime dueDate;
  final String status;

  factory _StudentAssignment.fromJson(Map<String, dynamic> json) {
    return _StudentAssignment(
      assignmentId: json['assignment_id'] as int,
      title: json['title'] as String,
      dueDate: DateTime.parse(json['due_date'] as String),
      status: json['status'] as String,
    );
  }
}

class _PerformanceItem {
  _PerformanceItem({
    required this.subject,
    required this.assessmentType,
    required this.percentage,
  });
  final String subject;
  final String assessmentType;
  final double percentage;

  factory _PerformanceItem.fromJson(Map<String, dynamic> json) {
    return _PerformanceItem(
      subject: json['subject'] as String? ?? 'General',
      assessmentType: json['assessment_type'] as String? ?? 'test',
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

class _StudentNotice {
  _StudentNotice({required this.title});
  final String title;

  factory _StudentNotice.fromJson(Map<String, dynamic> json) {
    return _StudentNotice(
      title: json['title'] as String,
    );
  }
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

String _titleCase(String value) {
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../services/service_locator.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

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
      setState(() {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _GreetingSection(
                studentName: _me?.fullName ?? 'Student',
                className: className ?? 'Class',
              ),
              const SizedBox(height: 16),

              const _SectionHeader(title: 'Attendance'),
              const SizedBox(height: 8),
              _loading
                  ? const _SkeletonCard(height: 90)
                  : _AttendanceOverviewCard(
                      attendancePercent: attendancePct.round(),
                      trendUp: true,
                      trendDelta: 1.6,
                    ),
              const SizedBox(height: 20),

              const _SectionHeader(title: 'Today’s Classes'),
              const SizedBox(height: 8),
              _CardContainer(
                child: _loading
                    ? const _ScheduleSkeleton()
                    : _schedule.isEmpty
                        ? const _EmptyText('No classes scheduled today.')
                        : Column(
                            children: _schedule
                                .map((item) => _TimelineItem(
                                      time: '${item.startTime} - ${item.endTime}',
                                      title: item.subject,
                                      subtitle: 'Class ${item.classId}',
                                      color: Theme.of(context).colorScheme.primary,
                                    ))
                                .toList(),
                          ),
              ),
              const SizedBox(height: 20),

              const _SectionHeader(title: 'Assignments'),
              const SizedBox(height: 8),
              _loading
                  ? const _SkeletonCard(height: 90)
                  : _AssignmentsSummaryCard(
                      pending: pendingCount,
                      overdue: overdueCount,
                    ),
              const SizedBox(height: 20),

              const _SectionHeader(title: 'Performance'),
              const SizedBox(height: 8),
              _loading
                  ? const _SkeletonCard(height: 120)
                  : _PerformanceSnapshotCard(
                      averageScore: _performance.isEmpty
                          ? 0
                          : (_performance.map((e) => e.percentage).reduce((a, b) => a + b) /
                                  _performance.length)
                              .round(),
                      chartValues: performanceValues.isEmpty ? [0] : performanceValues,
                    ),
              const SizedBox(height: 20),

              const _SectionHeader(title: 'Alerts'),
              const SizedBox(height: 8),
              _CardContainer(
                child: _loading
                    ? const _AlertsSkeleton()
                    : _notices.isEmpty && (_summary?.alerts.isEmpty ?? true)
                        ? const _EmptyText('No new alerts.')
                        : Column(
                            children: [
                              ..._summary?.alerts.map(
                                    (a) => Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: _AlertRow(
                                        icon: Icons.warning_amber_outlined,
                                        title: a,
                                      ),
                                    ),
                                  ) ??
                                  [],
                              ..._notices.take(3).map(
                                    (n) => Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: _AlertRow(
                                        icon: Icons.notifications_outlined,
                                        title: n.title,
                                      ),
                                    ),
                                  ),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
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
      ),
    );
  }
}

class _GreetingSection extends StatelessWidget {
  const _GreetingSection({required this.studentName, required this.className});
  final String studentName;
  final String className;

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: Row(
        children: [
          const CircleAvatar(radius: 24, child: Icon(Icons.person_outline)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back,', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  studentName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(className, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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

class _AttendanceOverviewCard extends StatelessWidget {
  const _AttendanceOverviewCard({
    required this.attendancePercent,
    required this.trendUp,
    required this.trendDelta,
  });

  final int attendancePercent;
  final bool trendUp;
  final double trendDelta;

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: Row(
        children: [
          _CircularProgress(
            percent: attendancePercent / 100,
            label: '$attendancePercent%',
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overall attendance', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      trendUp ? Icons.trending_up : Icons.trending_down,
                      color: trendUp ? Colors.green : Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${trendUp ? '+' : '-'}${trendDelta.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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

class _AssignmentsSummaryCard extends StatelessWidget {
  const _AssignmentsSummaryCard({
    required this.pending,
    required this.overdue,
  });

  final int pending;
  final int overdue;

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MetricChip(
            label: 'Pending',
            value: pending.toString(),
            color: const Color(0xFF3B82F6),
          ),
          _MetricChip(
            label: 'Overdue',
            value: overdue.toString(),
            color: const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }
}

class _PerformanceSnapshotCard extends StatelessWidget {
  const _PerformanceSnapshotCard({
    required this.averageScore,
    required this.chartValues,
  });

  final int averageScore;
  final List<int> chartValues;

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Average score', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            '$averageScore%',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          _MiniLineChart(values: chartValues),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(title)),
      ],
    );
  }
}

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

class _CircularProgress extends StatelessWidget {
  const _CircularProgress({required this.percent, required this.label});
  final double percent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      width: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: percent,
            strokeWidth: 6,
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _MiniLineChart extends StatelessWidget {
  const _MiniLineChart({required this.values});
  final List<int> values;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      width: double.infinity,
      child: CustomPaint(
        painter: _LineChartPainter(values),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter(this.values);
  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final paint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final maxVal = values.reduce(math.max).toDouble();
    final minVal = values.reduce(math.min).toDouble();
    final range = (maxVal - minVal).clamp(1, double.infinity);

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height - ((values[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
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
    return _CardContainer(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.withOpacity(0.2),
        ),
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
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.withOpacity(0.2),
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
              color: Colors.grey.withOpacity(0.2),
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
  _PerformanceItem({required this.percentage});
  final double percentage;

  factory _PerformanceItem.fromJson(Map<String, dynamic> json) {
    return _PerformanceItem(
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

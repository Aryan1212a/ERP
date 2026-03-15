import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/service_locator.dart';

class StudentAcademicsScreen extends StatefulWidget {
  const StudentAcademicsScreen({super.key});

  @override
  State<StudentAcademicsScreen> createState() => _StudentAcademicsScreenState();
}

class _StudentAcademicsScreenState extends State<StudentAcademicsScreen> {
  bool _loading = true;
  String? _error;
  List<_ScheduleItem> _schedule = [];
  List<_AssignmentItem> _assignments = [];
  List<_PerformanceItem> _performance = [];

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
        Services.api.get('/api/v1/student/timetable/today'),
        Services.api.get('/api/v1/student/assignments'),
        Services.api.get('/api/v1/student/performance'),
      ]);

      if (responses.any((res) => res.statusCode != 200)) {
        throw Exception('Failed to load academics');
      }

      final timetableJson = jsonDecode(responses[0].body) as Map<String, dynamic>;
      final assignmentsJson = jsonDecode(responses[1].body) as Map<String, dynamic>;
      final performanceJson = jsonDecode(responses[2].body) as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _schedule = (timetableJson['timetable'] as List<dynamic>)
            .map((e) => _ScheduleItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _assignments = (assignmentsJson['assignments'] as List<dynamic>)
            .map((e) => _AssignmentItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _performance = (performanceJson['performance'] as List<dynamic>)
            .map((e) => _PerformanceItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load academics';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final avgScore = _performance.isEmpty
        ? 0
        : (_performance.map((e) => e.percentage).reduce((a, b) => a + b) / _performance.length)
            .round();
    final pendingCount = _assignments.where((a) => a.status != 'submitted').length;

    return Scaffold(
      appBar: AppBar(title: const Text('Academics')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _error!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _SummaryStrip(
                          classesToday: _schedule.length,
                          pendingAssignments: pendingCount,
                          averageScore: avgScore,
                        ),
                        const SizedBox(height: 16),
                        _SectionTitle(text: 'Today Schedule'),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: _schedule.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: Text('No classes scheduled today.'),
                                )
                              : Column(
                                  children: _schedule
                                      .map(
                                        (item) => ListTile(
                                          leading: CircleAvatar(
                                            radius: 14,
                                            child: Text(item.period.toString()),
                                          ),
                                          title: Text(item.subject),
                                          subtitle: Text('${item.startTime} - ${item.endTime}'),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                        const SizedBox(height: 16),
                        _SectionTitle(text: 'Assignments'),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: _assignments.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: Text('No assignments yet.'),
                                )
                              : Column(
                                  children: _assignments
                                      .map(
                                        (item) => ListTile(
                                          title: Text(item.title),
                                          subtitle: Text('Due: ${item.dueDate}'),
                                          trailing: _StatusChip(status: item.status),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                        const SizedBox(height: 16),
                        _SectionTitle(text: 'Performance'),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: _performance.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: Text('No performance records yet.'),
                                )
                              : Column(
                                  children: _performance
                                      .map(
                                        (item) => ListTile(
                                          title: Text(item.assessmentName),
                                          subtitle: Text('Marks: ${item.marks}/${item.maxMarks}'),
                                          trailing: Text('${item.percentage.round()}%'),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.classesToday,
    required this.pendingAssignments,
    required this.averageScore,
  });

  final int classesToday;
  final int pendingAssignments;
  final int averageScore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SummaryCard(label: 'Classes', value: classesToday.toString())),
        const SizedBox(width: 8),
        Expanded(child: _SummaryCard(label: 'Pending', value: pendingAssignments.toString())),
        const SizedBox(width: 8),
        Expanded(child: _SummaryCard(label: 'Avg Score', value: '$averageScore%')),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'submitted' => Colors.green,
      'pending' => Colors.orange,
      'missing' => Colors.red,
      _ => Colors.blueGrey,
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(status),
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color.withOpacity(0.25)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}

class _ScheduleItem {
  _ScheduleItem({
    required this.period,
    required this.startTime,
    required this.endTime,
    required this.subject,
  });

  final int period;
  final String startTime;
  final String endTime;
  final String subject;

  factory _ScheduleItem.fromJson(Map<String, dynamic> json) {
    return _ScheduleItem(
      period: json['period'] as int,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      subject: json['subject'] as String,
    );
  }
}

class _AssignmentItem {
  _AssignmentItem({
    required this.title,
    required this.dueDate,
    required this.status,
  });

  final String title;
  final String dueDate;
  final String status;

  factory _AssignmentItem.fromJson(Map<String, dynamic> json) {
    return _AssignmentItem(
      title: json['title'] as String,
      dueDate: json['due_date'] as String,
      status: json['status'] as String,
    );
  }
}

class _PerformanceItem {
  _PerformanceItem({
    required this.assessmentName,
    required this.marks,
    required this.maxMarks,
    required this.percentage,
  });

  final String assessmentName;
  final int marks;
  final int maxMarks;
  final double percentage;

  factory _PerformanceItem.fromJson(Map<String, dynamic> json) {
    return _PerformanceItem(
      assessmentName: json['assessment_name'] as String,
      marks: json['marks'] as int,
      maxMarks: json['max_marks'] as int,
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

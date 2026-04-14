import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/service_locator.dart';

class TeacherStudentDetailScreen extends StatefulWidget {
  const TeacherStudentDetailScreen({super.key, required this.studentId});

  final int studentId;

  @override
  State<TeacherStudentDetailScreen> createState() => _TeacherStudentDetailScreenState();
}

class _TeacherStudentDetailScreenState extends State<TeacherStudentDetailScreen> {
  bool _loading = true;
  String? _error;
  _TeacherStudentDetail? _detail;

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
      final res = await Services.api.get('/api/v1/teacher/students/${widget.studentId}');
      if (res.statusCode != 200) {
        throw Exception('Failed to load student details');
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _detail = _TeacherStudentDetail.fromJson(json);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load student details';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      appBar: AppBar(title: const Text('Student Details')),
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
                  : detail == null
                      ? const SizedBox.shrink()
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Card(
                              elevation: 0,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    CircleAvatar(radius: 28, child: Text(_initials(detail.fullName))),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            detail.fullName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(fontWeight: FontWeight.w700),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(detail.email),
                                          const SizedBox(height: 4),
                                          Text(detail.className ?? 'Class not assigned'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SectionCard(
                              title: 'Attendance',
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _InfoChip(label: 'Attendance', value: '${detail.attendance.attendancePct.toStringAsFixed(0)}%'),
                                  _InfoChip(label: 'Present', value: detail.attendance.present.toString()),
                                  _InfoChip(label: 'Absent', value: detail.attendance.absent.toString()),
                                  _InfoChip(label: 'Late', value: detail.attendance.late.toString()),
                                  _InfoChip(label: 'Total', value: detail.attendance.totalRecords.toString()),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SectionCard(
                              title: 'Assignments',
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _InfoChip(label: 'Pending', value: detail.assignments.pending.toString()),
                                  _InfoChip(label: 'Submitted', value: detail.assignments.submitted.toString()),
                                  _InfoChip(label: 'Late', value: detail.assignments.late.toString()),
                                  _InfoChip(label: 'Missing', value: detail.assignments.missing.toString()),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SectionCard(
                              title: 'Performance',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _InfoChip(
                                    label: 'Average',
                                    value: '${detail.performance.averageScore.toStringAsFixed(0)}%',
                                  ),
                                  const SizedBox(height: 12),
                                  ...detail.performance.bySubject.entries.map(
                                    (entry) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text('${entry.key}: ${entry.value.toStringAsFixed(0)}%'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SectionCard(
                              title: 'Recent Marks',
                              child: detail.recentMarks.isEmpty
                                  ? const Text('No marks available')
                                  : Column(
                                      children: detail.recentMarks
                                          .map(
                                            (mark) => ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(mark.assessmentName),
                                              subtitle: Text(
                                                '${mark.subject} • ${mark.assessmentType.toUpperCase()} • ${mark.marks}/${mark.maxMarks}',
                                              ),
                                              trailing: Text('${mark.percentage.toStringAsFixed(0)}%'),
                                            ),
                                          )
                                          .toList(),
                                    ),
                            ),
                            const SizedBox(height: 12),
                            _SectionCard(
                              title: 'Recent Notices',
                              child: detail.recentNotices.isEmpty
                                  ? const Text('No notices available')
                                  : Column(
                                      children: detail.recentNotices
                                          .map(
                                            (notice) => ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(notice.title),
                                              subtitle: Text(_formatDate(notice.createdAt)),
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

class _TeacherStudentDetail {
  _TeacherStudentDetail({
    required this.fullName,
    required this.email,
    required this.className,
    required this.attendance,
    required this.assignments,
    required this.performance,
    required this.recentMarks,
    required this.recentNotices,
  });

  final String fullName;
  final String email;
  final String? className;
  final _AttendanceSummary attendance;
  final _AssignmentSummary assignments;
  final _PerformanceSummary performance;
  final List<_MarkItem> recentMarks;
  final List<_NoticeItem> recentNotices;

  factory _TeacherStudentDetail.fromJson(Map<String, dynamic> json) {
    return _TeacherStudentDetail(
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      className: json['class_name'] as String?,
      attendance: _AttendanceSummary.fromJson(json['attendance'] as Map<String, dynamic>),
      assignments: _AssignmentSummary.fromJson(json['assignments'] as Map<String, dynamic>),
      performance: _PerformanceSummary.fromJson(json['performance'] as Map<String, dynamic>),
      recentMarks: (json['recent_marks'] as List<dynamic>)
          .map((e) => _MarkItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentNotices: (json['recent_notices'] as List<dynamic>)
          .map((e) => _NoticeItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class _AttendanceSummary {
  _AttendanceSummary({
    required this.totalRecords,
    required this.present,
    required this.absent,
    required this.late,
    required this.attendancePct,
  });

  final int totalRecords;
  final int present;
  final int absent;
  final int late;
  final double attendancePct;

  factory _AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return _AttendanceSummary(
      totalRecords: json['total_records'] as int,
      present: json['present'] as int,
      absent: json['absent'] as int,
      late: json['late'] as int,
      attendancePct: (json['attendance_pct'] as num).toDouble(),
    );
  }
}

class _AssignmentSummary {
  _AssignmentSummary({
    required this.pending,
    required this.submitted,
    required this.late,
    required this.missing,
  });

  final int pending;
  final int submitted;
  final int late;
  final int missing;

  factory _AssignmentSummary.fromJson(Map<String, dynamic> json) {
    return _AssignmentSummary(
      pending: json['pending'] as int,
      submitted: json['submitted'] as int,
      late: json['late'] as int,
      missing: json['missing'] as int,
    );
  }
}

class _PerformanceSummary {
  _PerformanceSummary({required this.averageScore, required this.bySubject});

  final double averageScore;
  final Map<String, double> bySubject;

  factory _PerformanceSummary.fromJson(Map<String, dynamic> json) {
    return _PerformanceSummary(
      averageScore: (json['average_score'] as num).toDouble(),
      bySubject: {
        for (final entry in (json['by_subject'] as Map<String, dynamic>).entries)
          entry.key: (entry.value as num).toDouble(),
      },
    );
  }
}

class _MarkItem {
  _MarkItem({
    required this.subject,
    required this.assessmentType,
    required this.assessmentName,
    required this.marks,
    required this.maxMarks,
    required this.percentage,
  });

  final String subject;
  final String assessmentType;
  final String assessmentName;
  final int marks;
  final int maxMarks;
  final double percentage;

  factory _MarkItem.fromJson(Map<String, dynamic> json) {
    return _MarkItem(
      subject: json['subject'] as String,
      assessmentType: json['assessment_type'] as String,
      assessmentName: json['assessment_name'] as String,
      marks: json['marks'] as int,
      maxMarks: json['max_marks'] as int,
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

class _NoticeItem {
  _NoticeItem({required this.title, required this.createdAt});

  final String title;
  final DateTime createdAt;

  factory _NoticeItem.fromJson(Map<String, dynamic> json) {
    return _NoticeItem(
      title: json['title'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$label: $value'),
    );
  }
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

String _formatDate(DateTime dt) {
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/service_locator.dart';

class TeacherStudentsScreen extends StatefulWidget {
  const TeacherStudentsScreen({super.key});

  @override
  State<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen> {
  bool _loading = true;
  String? _error;
  String _query = '';
  List<_TeacherStudentListItem> _students = [];

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
      final res = await Services.api.get('/api/v1/teacher/students');
      if (res.statusCode != 200) {
        throw Exception('Failed to load students');
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final students = (json['students'] as List<dynamic>)
          .map((e) => _TeacherStudentListItem.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _students = students;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load students';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visibleStudents = _students.where((student) {
      if (query.isEmpty) return true;
      return student.fullName.toLowerCase().contains(query) ||
          student.email.toLowerCase().contains(query) ||
          (student.className ?? '').toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Students')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  labelText: 'Search students',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
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
                        : visibleStudents.isEmpty
                            ? ListView(
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text('No students found.'),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                itemCount: visibleStudents.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final student = visibleStudents[index];
                                  return Card(
                                    elevation: 0,
                                    child: ListTile(
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        '/teacher/students/detail',
                                        arguments: student.studentId,
                                      ),
                                      leading: CircleAvatar(
                                        child: Text(_initials(student.fullName)),
                                      ),
                                      title: Text(student.fullName),
                                      subtitle: Text(
                                        '${student.className ?? 'Unassigned'}\n${student.email}',
                                      ),
                                      isThreeLine: true,
                                      trailing: SizedBox(
                                        width: 112,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text('${student.attendancePct.toStringAsFixed(0)}% attendance'),
                                            Text(
                                              '${student.pendingAssignments} pending',
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                            Text(
                                              '${student.averageScore.toStringAsFixed(0)}% avg',
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherStudentListItem {
  _TeacherStudentListItem({
    required this.studentId,
    required this.fullName,
    required this.email,
    required this.className,
    required this.attendancePct,
    required this.pendingAssignments,
    required this.averageScore,
  });

  final int studentId;
  final String fullName;
  final String email;
  final String? className;
  final double attendancePct;
  final int pendingAssignments;
  final double averageScore;

  factory _TeacherStudentListItem.fromJson(Map<String, dynamic> json) {
    return _TeacherStudentListItem(
      studentId: json['student_id'] as int,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      className: json['class_name'] as String?,
      attendancePct: (json['attendance_pct'] as num).toDouble(),
      pendingAssignments: json['pending_assignments'] as int,
      averageScore: (json['average_score'] as num).toDouble(),
    );
  }
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

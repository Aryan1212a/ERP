import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/service_locator.dart';

class TeacherAssignmentsManageScreen extends StatefulWidget {
  const TeacherAssignmentsManageScreen({super.key});

  @override
  State<TeacherAssignmentsManageScreen> createState() => _TeacherAssignmentsManageScreenState();
}

class _TeacherAssignmentsManageScreenState extends State<TeacherAssignmentsManageScreen> {
  bool _loading = true;
  String? _error;
  List<_AssignmentItem> _items = [];
  final Set<String> _updatingKeys = {};

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
      final res = await Services.api.get('/api/v1/teacher/assignments/manage');
      if (res.statusCode != 200) {
        throw Exception('Failed');
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final assignments = (json['assignments'] as List<dynamic>)
          .map((e) => _AssignmentItem.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = assignments;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load assignments';
      });
    }
  }

  Future<void> _setStatus({
    required int assignmentId,
    required int studentId,
    required String status,
  }) async {
    final key = '$assignmentId:$studentId';
    setState(() => _updatingKeys.add(key));
    try {
      final res = await Services.api.put(
        '/api/v1/teacher/assignments/$assignmentId/students/$studentId/status',
        {'status': status},
      );
      if (res.statusCode != 200) {
        throw Exception('Failed');
      }
      if (!mounted) return;
      setState(() {
        for (final assignment in _items) {
          if (assignment.assignmentId != assignmentId) continue;
          for (final student in assignment.students) {
            if (student.studentId == studentId) {
              student.status = status;
            }
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update status')),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingKeys.remove(key));
      }
    }
  }

  Future<void> _markDueDateOver(int assignmentId) async {
    final res = await Services.api.post(
      '/api/v1/teacher/assignments/$assignmentId/mark-overdue',
      {},
    );
    if (!mounted) return;
    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked pending students as late')),
      );
      _load();
      return;
    }
    final msg = _extractError(res.body) ?? 'Unable to mark due date over';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Assignments')),
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
                  : _items.isEmpty
                      ? ListView(
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No assignments found.'),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemBuilder: (context, index) {
                            final assignment = _items[index];
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ExpansionTile(
                                title: Text(assignment.title),
                                subtitle: Text(
                                  '${assignment.className ?? "Class ${assignment.classId}"}  •  Due ${assignment.dueDate}',
                                ),
                                trailing: _AssignmentBadge(overdue: assignment.overdue),
                                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                children: [
                                  if (assignment.overdue)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _markDueDateOver(assignment.assignmentId),
                                        icon: const Icon(Icons.event_busy_outlined),
                                        label: const Text('Mark Due Date Over'),
                                      ),
                                    ),
                                  if (assignment.students.isEmpty)
                                    const ListTile(
                                      title: Text('No students found in this class'),
                                    )
                                  else
                                    ...assignment.students.map((student) {
                                      final key = '${assignment.assignmentId}:${student.studentId}';
                                      final isUpdating = _updatingKeys.contains(key);
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(student.name),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Student ID: ${student.studentId}',
                                                    style: Theme.of(context).textTheme.bodySmall,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 250,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Wrap(
                                                    alignment: WrapAlignment.end,
                                                    spacing: 6,
                                                    runSpacing: 6,
                                                    children: [
                                                      _StatusActionButton(
                                                        text: 'Done',
                                                        color: Colors.green,
                                                        selected: student.status == 'submitted',
                                                        onPressed: isUpdating
                                                            ? null
                                                            : () => _setStatus(
                                                                  assignmentId: assignment.assignmentId,
                                                                  studentId: student.studentId,
                                                                  status: 'submitted',
                                                                ),
                                                      ),
                                                      _StatusActionButton(
                                                        text: 'Pending',
                                                        color: Colors.blue,
                                                        selected: student.status == 'pending',
                                                        onPressed: isUpdating
                                                            ? null
                                                            : () => _setStatus(
                                                                  assignmentId: assignment.assignmentId,
                                                                  studentId: student.studentId,
                                                                  status: 'pending',
                                                                ),
                                                      ),
                                                      _StatusActionButton(
                                                        text: 'Late',
                                                        color: Colors.amber,
                                                        selected: student.status == 'late',
                                                        onPressed: isUpdating
                                                            ? null
                                                            : () => _setStatus(
                                                                  assignmentId: assignment.assignmentId,
                                                                  studentId: student.studentId,
                                                                  status: 'late',
                                                                ),
                                                      ),
                                                      _StatusActionButton(
                                                        text: 'Missing',
                                                        color: Colors.red,
                                                        selected: student.status == 'missing',
                                                        onPressed: isUpdating
                                                            ? null
                                                            : () => _setStatus(
                                                                  assignmentId: assignment.assignmentId,
                                                                  studentId: student.studentId,
                                                                  status: 'missing',
                                                                ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (isUpdating)
                                                    const Padding(
                                                      padding: EdgeInsets.only(top: 6),
                                                      child: SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            );
                          },
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemCount: _items.length,
                        ),
        ),
      ),
    );
  }
}

class _AssignmentBadge extends StatelessWidget {
  const _AssignmentBadge({required this.overdue});

  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final color = overdue ? Colors.red : Colors.green;
    final text = overdue ? 'Overdue' : 'Active';
    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      label: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatusActionButton extends StatelessWidget {
  const _StatusActionButton({
    required this.text,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final String text;
  final MaterialColor color;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : color.shade700;
    final bg = selected ? color.shade700 : color.withValues(alpha: 0.08);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        backgroundColor: bg,
        side: BorderSide(
          color: selected ? color.shade900 : color.withValues(alpha: 0.35),
          width: selected ? 1.5 : 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            const Icon(Icons.check, size: 14, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AssignmentItem {
  _AssignmentItem({
    required this.assignmentId,
    required this.classId,
    required this.className,
    required this.title,
    required this.dueDate,
    required this.overdue,
    required this.students,
  });

  final int assignmentId;
  final int classId;
  final String? className;
  final String title;
  final String dueDate;
  final bool overdue;
  final List<_AssignmentStudent> students;

  factory _AssignmentItem.fromJson(Map<String, dynamic> json) {
    return _AssignmentItem(
      assignmentId: json['assignment_id'] as int,
      classId: json['class_id'] as int,
      className: json['class_name'] as String?,
      title: json['title'] as String,
      dueDate: json['due_date'] as String,
      overdue: json['overdue'] == true,
      students: (json['students'] as List<dynamic>)
          .map((e) => _AssignmentStudent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class _AssignmentStudent {
  _AssignmentStudent({
    required this.studentId,
    required this.name,
    required this.status,
  });

  final int studentId;
  final String name;
  String status;

  factory _AssignmentStudent.fromJson(Map<String, dynamic> json) {
    return _AssignmentStudent(
      studentId: json['student_id'] as int,
      name: json['name'] as String,
      status: json['status'] as String,
    );
  }
}

String? _extractError(String body) {
  try {
    final data = jsonDecode(body) as Map<String, dynamic>;
    return data['detail'] as String?;
  } catch (_) {
    return null;
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/service_locator.dart';
import '../ui/app_theme.dart';

class AttendanceFormScreen extends StatefulWidget {
  const AttendanceFormScreen({super.key});

  @override
  State<AttendanceFormScreen> createState() => _AttendanceFormScreenState();
}

class _AttendanceFormScreenState extends State<AttendanceFormScreen> {
  bool _loading = true;
  String? _error;
  DateTime _date = DateTime.now();
  List<_ClassItem> _classes = [];
  List<_StudentItem> _students = [];
  int? _selectedClassId;
  final Map<int, String> _statusByStudent = {};
  int _studentsRequestId = 0;

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
      final classesRes = await Services.api.get('/api/v1/classes');
      if (classesRes.statusCode != 200) {
        throw Exception('Failed to load classes');
      }

      final classesJson = jsonDecode(classesRes.body) as List<dynamic>;
      final classes = classesJson
          .map((item) => _ClassItem.fromJson(item as Map<String, dynamic>))
          .toList();

      _classes = classes;
      _selectedClassId = classes.isNotEmpty ? classes.first.id : null;
      await _loadStudentsForClass();

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load attendance data';
      });
    }
  }

  Future<void> _loadStudentsForClass() async {
    final requestId = ++_studentsRequestId;
    _students = [];
    _statusByStudent.clear();

    final classId = _selectedClassId;
    if (classId == null) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final res = await Services.api.get('/api/v1/students?class_id=$classId');
    if (res.statusCode != 200) {
      throw Exception('Failed to load students');
    }

    final studentsJson = jsonDecode(res.body) as List<dynamic>;
    final students = studentsJson
        .map((item) => _StudentItem.fromJson(item as Map<String, dynamic>))
        .toList();

    if (!mounted || requestId != _studentsRequestId || classId != _selectedClassId) {
      return;
    }

    setState(() {
      _students = students;
      for (final student in students) {
        _statusByStudent.putIfAbsent(student.id, () => 'present');
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final classId = _selectedClassId;
    if (classId == null) {
      _showSnack(context, 'Please select a class');
      return;
    }

    final records = _students
        .map(
          (student) => {
            'student_id': student.id,
            'status': _statusByStudent[student.id] ?? 'present',
          },
        )
        .toList();

    final res = await Services.api.post('/api/v1/teacher/attendance', {
      'class_id': classId,
      'date': _formatDateForApi(_date),
      'records': records,
    });

    if (!mounted) return;
    if (res.statusCode == 200) {
      _showSnack(context, 'Attendance saved');
      Navigator.pop(context, true);
      return;
    }

    _showSnack(context, 'Failed to save attendance');
  }

  int _countStatus(String status) {
    return _statusByStudent.values.where((value) => value == status).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mark Attendance'),
      ),
      body: Stack(
        children: [
          const _AttendanceBackground(),
          SafeArea(
            child: _loading
                ? const _LoadingState()
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _load)
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: [
                          _HeaderCard(dateText: _formatDate(_date)),
                          const SizedBox(height: AppSpacing.lg),
                          _FormCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Class & Date',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                DropdownButtonFormField<int>(
                                  initialValue: _selectedClassId,
                                  items: _classes
                                      .map(
                                        (item) => DropdownMenuItem<int>(
                                          value: item.id,
                                          child: Text(item.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) async {
                                    setState(() => _selectedClassId = value);
                                    await _loadStudentsForClass();
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Class',
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                OutlinedButton.icon(
                                  onPressed: _pickDate,
                                  icon: const Icon(Icons.calendar_month_outlined),
                                  label: Text(_formatDate(_date)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _FormCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Students',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                if (_students.isEmpty)
                                  Text(
                                    'No students found for this class.',
                                    style: theme.textTheme.bodySmall,
                                  )
                                else
                                  ..._students.map(
                                    (student) => _StudentRow(
                                      student: student,
                                      status: _statusByStudent[student.id] ?? 'present',
                                      onStatusChanged: (value) {
                                        setState(() => _statusByStudent[student.id] = value);
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _SummaryPills(
                            present: _countStatus('present'),
                            absent: _countStatus('absent'),
                            late: _countStatus('late'),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          FilledButton(
                            onPressed: _students.isEmpty ? null : _submit,
                            child: const Text('Save Attendance'),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceBackground extends StatelessWidget {
  const _AttendanceBackground();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark
        ? const [Color(0xFF0B1120), Color(0xFF0F172A), Color(0xFF111827)]
        : const [Color(0xFFF8FAFC), Color(0xFFE2E8F0), Color(0xFFF8FAFC)];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: const [
          Positioned(
            top: -70,
            right: -40,
            child: _BlurBubble(color: Color(0xFF38BDF8), size: 210),
          ),
          Positioned(
            bottom: -90,
            left: -50,
            child: _BlurBubble(color: Color(0xFF6366F1), size: 240),
          ),
        ],
      ),
    );
  }
}

class _BlurBubble extends StatelessWidget {
  const _BlurBubble({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.dateText});

  final String dateText;

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
            ),
            child: const Icon(Icons.fact_check_rounded, color: Color(0xFF0EA5E9)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mark Attendance', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  dateText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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

class _SummaryPills extends StatelessWidget {
  const _SummaryPills({
    required this.present,
    required this.absent,
    required this.late,
  });

  final int present;
  final int absent;
  final int late;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Pill(label: 'Present', value: present, color: const Color(0xFF22C55E)),
        const SizedBox(width: 8),
        _Pill(label: 'Absent', value: absent, color: const Color(0xFFEF4444)),
        const SizedBox(width: 8),
        _Pill(label: 'Late', value: late, color: const Color(0xFFF59E0B)),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.student,
    required this.status,
    required this.onStatusChanged,
  });

  final _StudentItem student;
  final String status;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              student.name,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(value: 'present', label: Text('Present')),
              ButtonSegment<String>(value: 'absent', label: Text('Absent')),
              ButtonSegment<String>(value: 'late', label: Text('Late')),
            ],
            selected: {status},
            onSelectionChanged: (selection) => onStatusChanged(selection.first),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ClassItem {
  _ClassItem({required this.id, required this.name});

  final int id;
  final String name;

  factory _ClassItem.fromJson(Map<String, dynamic> json) {
    return _ClassItem(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class _StudentItem {
  _StudentItem({required this.id, required this.name});

  final int id;
  final String name;

  factory _StudentItem.fromJson(Map<String, dynamic> json) {
    return _StudentItem(
      id: json['id'] as int,
      name: json['full_name'] as String,
    );
  }
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
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _formatDateForApi(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

void _showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

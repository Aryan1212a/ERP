import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/service_locator.dart';

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
        throw Exception('Failed to load');
      }
      final classesJson = jsonDecode(classesRes.body) as List<dynamic>;
      final classes = classesJson.map((e) => _ClassItem.fromJson(e)).toList();
      _classes = classes;
      _selectedClassId = classes.isNotEmpty ? classes.first.id : null;
      await _loadStudentsForClass();
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Unable to load data';
      });
    }
  }

  Future<void> _loadStudentsForClass() async {
    _students = [];
    _statusByStudent.clear();
    if (_selectedClassId == null) {
      return;
    }
    final res = await Services.api.get('/api/v1/students?class_id=$_selectedClassId');
    if (res.statusCode != 200) {
      throw Exception('Failed to load students');
    }
    final studentsJson = jsonDecode(res.body) as List<dynamic>;
    final students = studentsJson.map((e) => _StudentItem.fromJson(e)).toList();
    setState(() {
      _students = students;
      for (final s in students) {
        _statusByStudent.putIfAbsent(s.id, () => 'present');
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedClassId == null) {
      _showSnack(context, 'Please select a class');
      return;
    }
    final dateStr = _formatDateForApi(_date);
    final records = _students
        .map((s) => {
              'student_id': s.id,
              'status': _statusByStudent[s.id] ?? 'present',
            })
        .toList();
    final res = await Services.api.post('/api/v1/teacher/attendance', {
      'class_id': _selectedClassId,
      'date': dateStr,
      'records': records,
    });
    if (!mounted) return;
    if (res.statusCode == 200) {
      _showSnack(context, 'Attendance saved');
    } else {
      _showSnack(context, 'Failed to save attendance');
    }
  }

  int _countStatus(String status) {
    return _statusByStudent.values.where((s) => s == status).length;
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
                        padding: const EdgeInsets.all(16),
                        children: [
                          _HeaderCard(dateText: _formatDate(_date)),
                          const SizedBox(height: 16),
                          _FormCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Class & Date',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  value: _selectedClassId,
                                  items: _classes
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c.id,
                                          child: Text(c.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedClassId = value);
                                    _loadStudentsForClass();
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Class',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _date,
                                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                      lastDate: DateTime.now().add(const Duration(days: 30)),
                                    );
                                    if (picked != null) {
                                      setState(() => _date = picked);
                                    }
                                  },
                                  icon: const Icon(Icons.calendar_month_outlined),
                                  label: Text(_formatDate(_date)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SummaryPills(
                            present: _countStatus('present'),
                            absent: _countStatus('absent'),
                            late: _countStatus('late'),
                          ),
                          const SizedBox(height: 12),
                          _FormCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Students',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                ..._students.map((s) => _StudentRow(
                                      student: s,
                                      status: _statusByStudent[s.id] ?? 'present',
                                      onStatusChanged: (value) {
                                        setState(() => _statusByStudent[s.id] = value);
                                      },
                                    )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _submit,
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Save Attendance'),
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
        color: color.withOpacity(0.18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
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
              color: const Color(0xFF0EA5E9).withOpacity(0.12),
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
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
          color: color.withOpacity(0.12),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                  ),
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
              ButtonSegment(value: 'present', label: Text('Present')),
              ButtonSegment(value: 'absent', label: Text('Absent')),
              ButtonSegment(value: 'late', label: Text('Late')),
            ],
            selected: {status},
            onSelectionChanged: (value) => onStatusChanged(value.first),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _formatDateForApi(DateTime date) {
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '${date.year}-$m-$d';
}

void _showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/service_locator.dart';

class UploadMarksScreen extends StatefulWidget {
  const UploadMarksScreen({super.key});

  @override
  State<UploadMarksScreen> createState() => _UploadMarksScreenState();
}

class _UploadMarksScreenState extends State<UploadMarksScreen> {
  final _assessmentName = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  DateTime _date = DateTime.now();
  List<_ClassItem> _classes = [];
  List<_StudentItem> _students = [];
  int? _selectedClassId;
  final Map<int, String> _marks = {};
  final Map<int, String> _maxMarks = {};

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
      final res = await Services.api.get('/api/v1/classes');
      if (res.statusCode != 200) throw Exception('Failed to load classes');
      final json = jsonDecode(res.body) as List<dynamic>;
      _classes = json.map((e) => _ClassItem.fromJson(e)).toList();
      _selectedClassId = _classes.isNotEmpty ? _classes.first.id : null;
      await _loadStudents();
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Unable to load data';
      });
    }
  }

  Future<void> _loadStudents() async {
    _students = [];
    _marks.clear();
    _maxMarks.clear();
    if (_selectedClassId == null) return;
    final res = await Services.api.get('/api/v1/students?class_id=$_selectedClassId');
    if (res.statusCode != 200) throw Exception('Failed to load students');
    final json = jsonDecode(res.body) as List<dynamic>;
    _students = json.map((e) => _StudentItem.fromJson(e)).toList();
    for (final s in _students) {
      _marks[s.id] = '';
      _maxMarks[s.id] = '';
    }
  }

  Future<void> _submit() async {
    if (_selectedClassId == null) {
      _showSnack(context, 'Select a class');
      return;
    }
    if (_assessmentName.text.trim().isEmpty) {
      _showSnack(context, 'Assessment name required');
      return;
    }

    final records = <Map<String, dynamic>>[];
    for (final s in _students) {
      final marks = int.tryParse(_marks[s.id] ?? '');
      final maxMarks = int.tryParse(_maxMarks[s.id] ?? '');
      if (marks == null || maxMarks == null) continue;
      records.add({
        'student_id': s.id,
        'marks': marks,
        'max_marks': maxMarks,
      });
    }
    if (records.isEmpty) {
      _showSnack(context, 'Enter marks for at least one student');
      return;
    }

    setState(() => _submitting = true);
    final res = await Services.api.post('/api/v1/teacher/marks', {
      'class_id': _selectedClassId,
      'assessment_name': _assessmentName.text.trim(),
      'date': _formatDateForApi(_date),
      'records': records,
    });
    setState(() => _submitting = false);
    if (!mounted) return;
    if (res.statusCode == 200) {
      _showSnack(context, 'Marks uploaded');
    } else {
      _showSnack(context, 'Failed to upload marks');
    }
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
        title: const Text('Upload Marks'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _FormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Assessment details',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              value: _selectedClassId,
                              items: _classes
                                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                                  .toList(),
                              onChanged: (value) async {
                                setState(() => _selectedClassId = value);
                                await _loadStudents();
                                setState(() {});
                              },
                              decoration: const InputDecoration(
                                labelText: 'Class',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _assessmentName,
                              decoration: const InputDecoration(
                                labelText: 'Assessment name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _date,
                                  firstDate: DateTime.now().subtract(const Duration(days: 90)),
                                  lastDate: DateTime.now().add(const Duration(days: 90)),
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
                      _FormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Student marks',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            ..._students.map((s) => _MarksRow(
                                  student: s,
                                  marks: _marks[s.id] ?? '',
                                  maxMarks: _maxMarks[s.id] ?? '',
                                  onMarksChanged: (v) => _marks[s.id] = v,
                                  onMaxChanged: (v) => _maxMarks[s.id] = v,
                                )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: _submitting ? const Text('Uploading...') : const Text('Upload Marks'),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _MarksRow extends StatelessWidget {
  const _MarksRow({
    required this.student,
    required this.marks,
    required this.maxMarks,
    required this.onMarksChanged,
    required this.onMaxChanged,
  });

  final _StudentItem student;
  final String marks;
  final String maxMarks;
  final ValueChanged<String> onMarksChanged;
  final ValueChanged<String> onMaxChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(student.name, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Marks', border: OutlineInputBorder()),
              onChanged: onMarksChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Max', border: OutlineInputBorder()),
              onChanged: onMaxChanged,
            ),
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
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
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
    return _ClassItem(id: json['id'] as int, name: json['name'] as String);
  }
}

class _StudentItem {
  _StudentItem({required this.id, required this.name});
  final int id;
  final String name;

  factory _StudentItem.fromJson(Map<String, dynamic> json) {
    return _StudentItem(id: json['id'] as int, name: json['full_name'] as String);
  }
}

String _formatDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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

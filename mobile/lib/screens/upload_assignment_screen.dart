import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/service_locator.dart';

class UploadAssignmentScreen extends StatefulWidget {
  const UploadAssignmentScreen({super.key});

  @override
  State<UploadAssignmentScreen> createState() => _UploadAssignmentScreenState();
}

class _UploadAssignmentScreenState extends State<UploadAssignmentScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  DateTime _dueDate = DateTime.now();
  List<_ClassItem> _classes = [];
  int? _selectedClassId;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
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
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Unable to load classes';
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedClassId == null) {
      _showSnack(context, 'Select a class');
      return;
    }
    if (_title.text.trim().isEmpty) {
      _showSnack(context, 'Title required');
      return;
    }
    setState(() => _submitting = true);

    final uri = Uri.parse('${Services.api.baseUrl}/api/v1/teacher/assignments');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer ${Services.api.token}';
    request.fields['class_id'] = _selectedClassId.toString();
    request.fields['title'] = _title.text.trim();
    request.fields['description'] = _description.text.trim();
    request.fields['due_date'] = _formatDateForApi(_dueDate);
    final res = await request.send();

    setState(() => _submitting = false);
    if (!mounted) return;

    if (res.statusCode == 200 || res.statusCode == 201) {
      _showSnack(context, 'Assignment uploaded');
    } else {
      _showSnack(context, 'Failed to upload assignment');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Upload Assignment'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _loadClasses)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _FormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Assignment details',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    )),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              initialValue: _selectedClassId,
                              items: _classes
                                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                                  .toList(),
                              onChanged: (value) => setState(() => _selectedClassId = value),
                              decoration: const InputDecoration(
                                labelText: 'Class',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _title,
                              decoration: const InputDecoration(
                                labelText: 'Title',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _description,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _dueDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setState(() => _dueDate = picked);
                                }
                              },
                              icon: const Icon(Icons.calendar_month_outlined),
                              label: Text(_formatDate(_dueDate)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: _submitting ? const Text('Uploading...') : const Text('Upload Assignment'),
                      ),
                    ],
                  ),
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

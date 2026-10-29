import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/service_locator.dart';

class AdminCreateUserScreen extends StatefulWidget {
  const AdminCreateUserScreen({super.key});

  @override
  State<AdminCreateUserScreen> createState() => _AdminCreateUserScreenState();
}

class _AdminCreateUserScreenState extends State<AdminCreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  String _role = 'student';
  bool _loading = false;
  bool _loadingCohorts = true;
  String? _error;
  List<_CohortItem> _classes = [];
  int? _selectedCohortId;

  @override
  void initState() {
    super.initState();
    _loadCohorts();
  }

  Future<void> _loadCohorts() async {
    setState(() {
      _loadingCohorts = true;
      _error = null;
    });
    try {
      final res = await Services.api.get('/api/v1/classes');
      if (res.statusCode != 200) {
        throw Exception('Failed to load cohorts');
      }
      final json = jsonDecode(res.body) as List<dynamic>;
      final classes = json.map((e) => _CohortItem.fromJson(e)).toList();
      setState(() {
        _classes = classes;
        _selectedCohortId = classes.isNotEmpty ? classes.first.id : null;
        _loadingCohorts = false;
      });
    } catch (e) {
      setState(() {
        _loadingCohorts = false;
        _error = 'Unable to load cohorts';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final body = {
      'role': _role,
      'full_name': _fullName.text.trim(),
      'email': _email.text.trim(),
      if (_role == 'student' || (_role == 'teacher' && _selectedCohortId != null))
        'class_id': _selectedCohortId,
    };

    final res = await Services.api.post('/api/v1/admin/users', body);
    setState(() => _loading = false);
    if (!mounted) return;

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      _showCredentialsDialog(
        context,
        title: 'User Created',
        username: data['username'],
        tempPassword: data['temporary_password'],
      );
      _formKey.currentState!.reset();
      _fullName.clear();
      _email.clear();
    } else {
      _showSnack(context, 'Failed to create user');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create User')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _fullName,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || !v.contains('@') ? 'Enter valid email' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        items: const [
                          DropdownMenuItem(value: 'student', child: Text('Student')),
                          DropdownMenuItem(value: 'teacher', child: Text('Faculty')),
                        ],
                        onChanged: (value) => setState(() => _role = value ?? 'student'),
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_role == 'student' || _role == 'teacher')
                        _loadingCohorts
                            ? const LinearProgressIndicator()
                            : _error != null
                                ? Row(
                                    children: [
                                      Expanded(child: Text(_error!)),
                                      TextButton(
                                        onPressed: _loadCohorts,
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  )
                                : DropdownButtonFormField<int>(
                                    initialValue: _selectedCohortId,
                                    items: _classes
                                        .map((c) => DropdownMenuItem(
                                              value: c.id,
                                              child: Text(c.name),
                                            ))
                                        .toList(),
                                    onChanged: (value) => setState(() => _selectedCohortId = value),
                                    decoration: InputDecoration(
                                      labelText: _role == 'student' ? 'Cohort' : 'Assigned Cohort',
                                      helperText: _role == 'teacher'
                                          ? 'Optional: assign the faculty member to a cohort now'
                                          : null,
                                      border: const OutlineInputBorder(),
                                    ),
                                    validator: (v) =>
                                        _role == 'student' && v == null ? 'Cohort required' : null,
                                  ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Create User'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CohortItem {
  _CohortItem({required this.id, required this.name});
  final int id;
  final String name;

  factory _CohortItem.fromJson(Map<String, dynamic> json) {
    return _CohortItem(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

void _showCredentialsDialog(BuildContext context,
    {required String title, required String username, required String tempPassword}) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Username: '),
              Expanded(child: Text(username, style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Temp Password: '),
              Expanded(child: Text(tempPassword, style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void _showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

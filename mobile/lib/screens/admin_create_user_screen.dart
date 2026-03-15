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
  bool _loadingClasses = true;
  String? _error;
  List<_ClassItem> _classes = [];
  int? _selectedClassId;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() {
      _loadingClasses = true;
      _error = null;
    });
    try {
      final res = await Services.api.get('/api/v1/classes');
      if (res.statusCode != 200) {
        throw Exception('Failed to load classes');
      }
      final json = jsonDecode(res.body) as List<dynamic>;
      final classes = json.map((e) => _ClassItem.fromJson(e)).toList();
      setState(() {
        _classes = classes;
        _selectedClassId = classes.isNotEmpty ? classes.first.id : null;
        _loadingClasses = false;
      });
    } catch (e) {
      setState(() {
        _loadingClasses = false;
        _error = 'Unable to load classes';
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
      if (_role == 'student') 'class_id': _selectedClassId,
    };

    final res = await Services.api.post('/api/v1/admin/users', body);
    setState(() => _loading = false);
    if (!mounted) return;

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      _showCredentialsDialog(
        context,
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
                        value: _role,
                        items: const [
                          DropdownMenuItem(value: 'student', child: Text('Student')),
                          DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                        ],
                        onChanged: (value) => setState(() => _role = value ?? 'student'),
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_role == 'student')
                        _loadingClasses
                            ? const LinearProgressIndicator()
                            : _error != null
                                ? Row(
                                    children: [
                                      Expanded(child: Text(_error!)),
                                      TextButton(
                                        onPressed: _loadClasses,
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  )
                                : DropdownButtonFormField<int>(
                                    value: _selectedClassId,
                                    items: _classes
                                        .map((c) => DropdownMenuItem(
                                              value: c.id,
                                              child: Text(c.name),
                                            ))
                                        .toList(),
                                    onChanged: (value) => setState(() => _selectedClassId = value),
                                    decoration: const InputDecoration(
                                      labelText: 'Class',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (v) =>
                                        _role == 'student' && v == null ? 'Class required' : null,
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

void _showCredentialsDialog(BuildContext context,
    {required String username, required String tempPassword}) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('User Created'),
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

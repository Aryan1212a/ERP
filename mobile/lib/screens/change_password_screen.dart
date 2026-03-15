import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/service_locator.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPassword = TextEditingController();
  final _newPassword = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (Services.api.token == null) {
      setState(() => _error = 'Session expired. Please log in again.');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await Services.api.post('/api/v1/auth/change-password', {
      'old_password': _oldPassword.text.trim(),
      'new_password': _newPassword.text.trim(),
    });

    if (!mounted) return;
    setState(() => _loading = false);
    if (res.statusCode == 200) {
      Services.auth.mustChangePassword = false;
      final role = Services.auth.role;
      final route = switch (role) {
        'admin' => '/dashboard/admin',
        'teacher' => '/dashboard/teacher',
        'student' => '/dashboard/student',
        _ => '/dashboard',
      };
      Navigator.pushReplacementNamed(context, route);
    } else if (res.statusCode == 401 || res.statusCode == 403) {
      setState(() => _error = 'Session expired. Please log in again.');
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      String message = 'Failed to change password';
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body['detail'] is String) {
          message = body['detail'] as String;
        }
      } catch (_) {
        // Keep default message if the response isn't JSON.
      }
      setState(() => _error = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
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
                      Text(
                        'You must change your password before continuing.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _oldPassword,
                        decoration: const InputDecoration(
                          labelText: 'Current Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newPassword,
                        decoration: const InputDecoration(
                          labelText: 'New Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (v) => v == null || v.length < 8 ? 'Min 8 chars' : null,
                      ),
                      const SizedBox(height: 12),
                      if (_error != null)
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Update Password'),
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

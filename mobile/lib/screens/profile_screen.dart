import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/service_locator.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  String? _error;
  _ProfileData? _profile;
  String? _className;

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
      final meRes = await Services.api.get('/api/v1/me');
      if (meRes.statusCode != 200) {
        throw Exception('Failed to load profile');
      }
      final meJson = jsonDecode(meRes.body) as Map<String, dynamic>;
      final profile = _ProfileData.fromJson(meJson);

      String? className;
      if (profile.classId != null) {
        final classRes = await Services.api.get('/api/v1/classes');
        if (classRes.statusCode == 200) {
          final classes = jsonDecode(classRes.body) as List<dynamic>;
          for (final item in classes) {
            final classJson = item as Map<String, dynamic>;
            if (classJson['id'] == profile.classId) {
              className = classJson['name'] as String?;
              break;
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _className = className;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load profile';
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await Services.auth.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = _profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_loading)
                const _LoadingState()
              else if (_error != null)
                _ErrorCard(message: _error!)
              else if (profile != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: theme.colorScheme.primaryContainer,
                              child: Text(
                                _initials(profile.fullName),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.fullName,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(profile.email, style: theme.textTheme.bodyMedium),
                                  const SizedBox(height: 8),
                                  _RoleChip(role: profile.role),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _InfoCard(
                      title: 'Account Details',
                      rows: [
                        _InfoRow(label: 'User ID', value: profile.id.toString()),
                        _InfoRow(label: 'School ID', value: profile.schoolId.toString()),
                        _InfoRow(label: 'Role', value: _titleCase(profile.role)),
                        if (profile.username != null)
                          _InfoRow(label: 'Username', value: profile.username!),
                        if (profile.classId != null)
                          _InfoRow(
                            label: 'Class',
                            value: _className ?? 'Class ${profile.classId}',
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.password_outlined),
                              title: const Text('Change Password'),
                              subtitle: const Text('Update your account password'),
                              onTap: () => Navigator.pushNamed(context, '/auth/change-password'),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: Icon(Icons.logout, color: theme.colorScheme.error),
                              title: Text(
                                'Logout',
                                style: TextStyle(color: theme.colorScheme.error),
                              ),
                              onTap: _logout,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              else
                const _ErrorCard(message: 'Profile unavailable'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileData {
  _ProfileData({
    required this.id,
    required this.schoolId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.classId,
    required this.username,
  });

  final int id;
  final int schoolId;
  final String fullName;
  final String email;
  final String role;
  final int? classId;
  final String? username;

  factory _ProfileData.fromJson(Map<String, dynamic> json) {
    return _ProfileData(
      id: json['id'] as int,
      schoolId: json['school_id'] as int,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      classId: json['class_id'] as int?,
      username: json['username'] as String?,
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      'admin' => const Color(0xFFF97316),
      'teacher' => const Color(0xFF3B82F6),
      'student' => const Color(0xFF22C55E),
      _ => Colors.grey,
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color.withOpacity(0.2)),
      label: Text(
        _titleCase(role),
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
      ),
    );
  }
}

String _initials(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}

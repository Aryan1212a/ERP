import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/service_locator.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _loading = true;
  String? _error;
  String _roleFilter = 'all';
  String _searchQuery = '';
  String _statusFilter = 'all';
  bool _selectionMode = false;
  List<_AdminUserItem> _users = [];
  List<_ClassItem> _classes = [];
  final Set<int> _busyIds = {};
  final Set<int> _selectedIds = {};

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
      final userPath = _roleFilter == 'all' ? '/api/v1/admin/users' : '/api/v1/admin/users?role=$_roleFilter';
      final responses = await Future.wait([
        Services.api.get(userPath),
        Services.api.get('/api/v1/classes'),
      ]);
      if (responses.any((res) => res.statusCode != 200)) {
        throw Exception('Failed to load users');
      }
      final usersJson = jsonDecode(responses[0].body) as List<dynamic>;
      final classesJson = jsonDecode(responses[1].body) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _users = usersJson.map((e) => _AdminUserItem.fromJson(e as Map<String, dynamic>)).toList();
        _classes = classesJson.map((e) => _ClassItem.fromJson(e as Map<String, dynamic>)).toList();
        _selectedIds.removeWhere((id) => !_users.any((user) => user.id == id));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load users';
      });
    }
  }

  Future<void> _resetPassword(_AdminUserItem user) async {
    await _runBusy(user.id, () async {
      final res = await Services.api.post('/api/v1/admin/users/${user.id}/reset-password', {});
      if (!mounted) return;
      if (res.statusCode != 200) {
        _showSnack(context, _messageFromResponse(res, fallback: 'Failed to reset password'));
        return;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      await _showCredentialsDialog(
        context,
        title: 'Temporary Password Reset',
        username: user.username ?? user.email,
        tempPassword: data['temporary_password'] as String,
      );
      await _load();
    });
  }

  Future<void> _openCreateUser() async {
    await Navigator.pushNamed(context, '/admin/users/create');
    if (!mounted) return;
    _load();
  }

  Future<void> _editUser(_AdminUserItem user) async {
    final fullNameController = TextEditingController(text: user.fullName);
    final emailController = TextEditingController(text: user.email);
    int? selectedClassId = user.classId;
    bool isActive = user.isActive;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final classItems = [
              const DropdownMenuItem<int?>(value: null, child: Text('No class')),
              ..._classes.map(
                (item) => DropdownMenuItem<int?>(
                  value: item.id,
                  child: Text(item.name),
                ),
              ),
            ];
            return AlertDialog(
              title: Text('Edit ${user.role[0].toUpperCase()}${user.role.substring(1)}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (user.role != 'admin') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        initialValue: selectedClassId,
                        items: classItems,
                        onChanged: (value) => setModalState(() => selectedClassId = value),
                        decoration: InputDecoration(
                          labelText: user.role == 'student' ? 'Class' : 'Assigned Class',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: isActive,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active account'),
                      subtitle: const Text('Turn this off when the user leaves school but records must remain.'),
                      onChanged: user.role == 'admin' ? null : (value) => setModalState(() => isActive = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    final body = {
                      'full_name': fullNameController.text.trim(),
                      'email': emailController.text.trim(),
                      'class_id': user.role == 'admin' ? null : selectedClassId,
                      'is_active': user.role == 'admin' ? true : isActive,
                    };
                    final res = await Services.api.put('/api/v1/admin/users/${user.id}', body);
                    if (res.statusCode == 200) {
                      navigator.pop(true);
                    } else {
                      messenger.showSnackBar(
                        SnackBar(content: Text(_messageFromResponse(res, fallback: 'Failed to update user'))),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    fullNameController.dispose();
    emailController.dispose();
    if (saved == true) {
      await _load();
      if (!mounted) return;
      _showSnack(context, 'User updated');
    }
  }

  Future<void> _toggleActive(_AdminUserItem user) async {
    final nextIsActive = !user.isActive;
    await _runBusy(user.id, () async {
      final res = await Services.api.put('/api/v1/admin/users/${user.id}', {
        'full_name': user.fullName,
        'email': user.email,
        'class_id': user.classId,
        'is_active': nextIsActive,
      });
      if (!mounted) return;
      if (res.statusCode != 200) {
        _showSnack(context, _messageFromResponse(res, fallback: 'Failed to update account status'));
        return;
      }
      await _load();
      if (!mounted) return;
      _showSnack(context, nextIsActive ? 'User reactivated' : 'User deactivated');
    });
  }

  Future<void> _transferTeacherData(_AdminUserItem user) async {
    final candidateTeachers = _users
        .where((item) => item.role == 'teacher' && item.id != user.id && item.isActive)
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    if (candidateTeachers.isEmpty) {
      _showSnack(context, 'Create or reactivate another teacher before transferring data');
      return;
    }
    int? targetTeacherId = candidateTeachers.first.id;
    final transferred = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            title: const Text('Transfer Teacher Data'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Move classes, assignments and marks from ${user.fullName} to:'),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: targetTeacherId,
                  items: candidateTeachers
                      .map(
                        (teacher) => DropdownMenuItem<int>(
                          value: teacher.id,
                          child: Text(teacher.fullName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setModalState(() => targetTeacherId = value),
                  decoration: const InputDecoration(
                    labelText: 'Target Teacher',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final res = await Services.api.post('/api/v1/admin/users/${user.id}/transfer-data', {
                    'target_user_id': targetTeacherId,
                  });
                  if (res.statusCode == 200) {
                    navigator.pop(true);
                  } else {
                    messenger.showSnackBar(
                      SnackBar(content: Text(_messageFromResponse(res, fallback: 'Failed to transfer data'))),
                    );
                  }
                },
                child: const Text('Transfer'),
              ),
            ],
          ),
        );
      },
    );
    if (transferred == true) {
      await _load();
      if (!mounted) return;
      _showSnack(context, 'Teacher data transferred');
    }
  }

  Future<void> _deleteUser(_AdminUserItem user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove User'),
        content: Text(
          'Delete ${user.fullName}? This only works when the account has no linked records. '
          'Use deactivate for former staff or students when history must remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runBusy(user.id, () async {
      final res = await Services.api.delete('/api/v1/admin/users/${user.id}');
      if (!mounted) return;
      if (res.statusCode != 200) {
        _showSnack(context, _messageFromResponse(res, fallback: 'Failed to delete user'));
        return;
      }
      await _load();
      if (!mounted) return;
      _showSnack(context, 'User deleted');
    });
  }

  Future<void> _runBusy(int userId, Future<void> Function() action) async {
    setState(() => _busyIds.add(userId));
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(userId));
      }
    }
  }

  Future<void> _bulkSetActive(bool nextIsActive) async {
    final selectedUsers = _users.where((user) => _selectedIds.contains(user.id)).toList();
    if (selectedUsers.isEmpty) {
      _showSnack(context, 'Select at least one user');
      return;
    }
    final blockedAdmins = selectedUsers.where((user) => user.role == 'admin' && nextIsActive == false).toList();
    final eligibleUsers = selectedUsers
        .where((user) => user.role != 'admin' || nextIsActive)
        .toList();
    if (eligibleUsers.isEmpty) {
      _showSnack(context, 'Selected admin users cannot be deactivated');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(nextIsActive ? 'Reactivate Users' : 'Deactivate Users'),
        content: Text(
          nextIsActive
              ? 'Reactivate ${eligibleUsers.length} selected user(s)?'
              : 'Deactivate ${eligibleUsers.length} selected user(s)? Their records will stay in the ERP.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    int successCount = 0;
    final errors = <String>[];
    setState(() => _busyIds.addAll(eligibleUsers.map((user) => user.id)));
    try {
      for (final user in eligibleUsers) {
        final res = await Services.api.put('/api/v1/admin/users/${user.id}', {
          'full_name': user.fullName,
          'email': user.email,
          'class_id': user.classId,
          'is_active': nextIsActive,
        });
        if (res.statusCode == 200) {
          successCount += 1;
        } else {
          errors.add('${user.fullName}: ${_messageFromResponse(res, fallback: 'Failed')}');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _busyIds.removeAll(eligibleUsers.map((user) => user.id)));
      }
    }
    await _load();
    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
    final adminNote = blockedAdmins.isEmpty ? '' : ' ${blockedAdmins.length} admin user(s) were skipped.';
    if (errors.isEmpty) {
      _showSnack(
        context,
        '${nextIsActive ? 'Reactivated' : 'Deactivated'} $successCount user(s).$adminNote',
      );
      return;
    }
    _showSnack(
      context,
      '${nextIsActive ? 'Reactivated' : 'Deactivated'} $successCount user(s). ${errors.first}$adminNote',
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _selectedIds.clear();
      }
    });
  }

  void _toggleSelected(int userId, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(userId);
      } else {
        _selectedIds.remove(userId);
      }
    });
  }

  String? _classNameById(int? classId) {
    if (classId == null) return null;
    for (final item in _classes) {
      if (item.id == classId) return item.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    final visibleUsers = _users.where((user) {
      final className = _classNameById(user.classId)?.toLowerCase() ?? '';
      final matchesQuery = normalizedQuery.isEmpty ||
          user.fullName.toLowerCase().contains(normalizedQuery) ||
          user.email.toLowerCase().contains(normalizedQuery) ||
          (user.username?.toLowerCase().contains(normalizedQuery) ?? false) ||
          className.contains(normalizedQuery);
      final matchesStatus = switch (_statusFilter) {
        'needs-password' => user.mustChangePassword,
        'inactive' => !user.isActive,
        'unassigned' => user.classId == null,
        _ => true,
      };
      return matchesQuery && matchesStatus;
    }).toList();
    final activeCount = _users.where((user) => user.isActive).length;
    final needsPasswordCount = _users.where((user) => user.mustChangePassword).length;
    final unassignedCount = _users.where((user) => user.classId == null).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectionMode ? '${_selectedIds.length} Selected' : 'Manage Users'),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              tooltip: 'Deactivate selected',
              onPressed: _selectedIds.isEmpty ? null : () => _bulkSetActive(false),
              icon: const Icon(Icons.person_off_rounded),
            ),
            IconButton(
              tooltip: 'Reactivate selected',
              onPressed: _selectedIds.isEmpty ? null : () => _bulkSetActive(true),
              icon: const Icon(Icons.person_rounded),
            ),
          ],
          IconButton(
            tooltip: _selectionMode ? 'Cancel selection' : 'Bulk select',
            onPressed: _loading ? null : _toggleSelectionMode,
            icon: Icon(_selectionMode ? Icons.close_rounded : Icons.checklist_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin_users_fab',
        onPressed: _openCreateUser,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Create User'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                children: [
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, username, or class',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () => setState(() => _searchQuery = ''),
                              icon: const Icon(Icons.close_rounded),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _AdminSummaryChip(
                          label: 'Total',
                          value: _users.length.toString(),
                        ),
                        const SizedBox(width: 8),
                        _AdminSummaryChip(
                          label: 'Active',
                          value: activeCount.toString(),
                          color: const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 8),
                        _AdminSummaryChip(
                          label: 'Password Reset',
                          value: needsPasswordCount.toString(),
                          color: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 8),
                        _AdminSummaryChip(
                          label: 'No Class',
                          value: unassignedCount.toString(),
                          color: const Color(0xFF2563EB),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('All')),
                      ButtonSegment(value: 'student', label: Text('Students')),
                      ButtonSegment(value: 'teacher', label: Text('Teachers')),
                    ],
                    selected: {_roleFilter},
                    onSelectionChanged: (selection) {
                      final next = selection.first;
                      if (next == _roleFilter) return;
                      setState(() => _roleFilter = next);
                      _load();
                    },
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChipButton(
                          label: 'Everything',
                          selected: _statusFilter == 'all',
                          onTap: () => setState(() => _statusFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChipButton(
                          label: 'Needs Password Change',
                          selected: _statusFilter == 'needs-password',
                          onTap: () => setState(() => _statusFilter = 'needs-password'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChipButton(
                          label: 'Inactive',
                          selected: _statusFilter == 'inactive',
                          onTap: () => setState(() => _statusFilter = 'inactive'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChipButton(
                          label: 'No Class',
                          selected: _statusFilter == 'unassigned',
                          onTap: () => setState(() => _statusFilter = 'unassigned'),
                        ),
                      ],
                    ),
                  ),
                ],
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
                        : visibleUsers.isEmpty
                            ? ListView(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      _users.isEmpty
                                          ? 'No users found for this role filter.'
                                          : 'No users match the current search and quick filters.',
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                                itemCount: visibleUsers.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final user = visibleUsers[index];
                                  final isBusy = _busyIds.contains(user.id);
                                  final className = _classNameById(user.classId);
                                  return Card(
                                    elevation: 0,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              if (_selectionMode)
                                                Checkbox(
                                                  value: _selectedIds.contains(user.id),
                                                  onChanged: isBusy
                                                      ? null
                                                      : (value) => _toggleSelected(user.id, value == true),
                                                ),
                                              CircleAvatar(
                                                child: Text(_initials(user.fullName)),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      user.fullName,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium
                                                          ?.copyWith(fontWeight: FontWeight.w700),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(user.email),
                                                  ],
                                                ),
                                              ),
                                              if (isBusy)
                                                const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                )
                                              else if (_selectionMode)
                                                const SizedBox(width: 20, height: 20)
                                              else
                                                PopupMenuButton<String>(
                                                  onSelected: (value) {
                                                    if (value == 'edit') {
                                                      _editUser(user);
                                                    } else if (value == 'reset') {
                                                      _resetPassword(user);
                                                    } else if (value == 'transfer') {
                                                      _transferTeacherData(user);
                                                    } else if (value == 'toggle') {
                                                      _toggleActive(user);
                                                    } else if (value == 'delete') {
                                                      _deleteUser(user);
                                                    }
                                                  },
                                                  itemBuilder: (context) => [
                                                    const PopupMenuItem(
                                                      value: 'edit',
                                                      child: Text('Edit Information'),
                                                    ),
                                                    const PopupMenuItem(
                                                      value: 'reset',
                                                      child: Text('Reset Password'),
                                                    ),
                                                    if (user.role == 'teacher')
                                                      const PopupMenuItem(
                                                        value: 'transfer',
                                                        child: Text('Transfer Teacher Data'),
                                                      ),
                                                    if (user.role != 'admin')
                                                      PopupMenuItem(
                                                        value: 'toggle',
                                                        child: Text(user.isActive ? 'Deactivate User' : 'Reactivate User'),
                                                      ),
                                                    if (user.role != 'admin')
                                                      const PopupMenuItem(
                                                        value: 'delete',
                                                        child: Text('Delete User'),
                                                      ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _RoleChip(role: user.role),
                                              _StateChip(
                                                label: user.isActive ? 'Active' : 'Inactive',
                                                active: user.isActive,
                                              ),
                                              _InfoChip(label: 'Username', value: user.username ?? 'Not set'),
                                              if (user.classId != null)
                                                _InfoChip(label: 'Class', value: className ?? 'ID ${user.classId}'),
                                              _InfoChip(
                                                label: 'Password Change',
                                                value: user.mustChangePassword ? 'Required' : 'Not required',
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            user.role == 'teacher'
                                                ? 'Use transfer before removal if this teacher owns classes, assignments or marks.'
                                                : 'Deactivate instead of deleting when student history must remain in the ERP.',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
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

class _AdminUserItem {
  _AdminUserItem({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.username,
    required this.classId,
    required this.mustChangePassword,
    required this.isActive,
  });

  final int id;
  final String fullName;
  final String email;
  final String role;
  final String? username;
  final int? classId;
  final bool mustChangePassword;
  final bool isActive;

  factory _AdminUserItem.fromJson(Map<String, dynamic> json) {
    return _AdminUserItem(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      username: json['username'] as String?,
      classId: json['class_id'] as int?,
      mustChangePassword: json['must_change_password'] == true,
      isActive: json['is_active'] != false,
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

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (role) {
      'admin' => const Color(0xFFF97316),
      'teacher' => const Color(0xFF2563EB),
      _ => const Color(0xFF16A34A),
    };
    return Chip(
      label: Text(role[0].toUpperCase() + role.substring(1)),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF16A34A) : const Color(0xFFB45309);
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$label: $value'),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

class _AdminSummaryChip extends StatelessWidget {
  const _AdminSummaryChip({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: resolvedColor.withValues(alpha: 0.16)),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: resolvedColor,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

Future<void> _showCredentialsDialog(
  BuildContext context, {
  required String title,
  required String username,
  required String tempPassword,
}) {
  return showDialog<void>(
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

String _messageFromResponse(Object response, {required String fallback}) {
  try {
    final dynamic body = jsonDecode((response as dynamic).body as String);
    if (body is Map<String, dynamic> && body['detail'] is String && (body['detail'] as String).isNotEmpty) {
      return body['detail'] as String;
    }
  } catch (_) {
    return fallback;
  }
  return fallback;
}

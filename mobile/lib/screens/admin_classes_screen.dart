import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/service_locator.dart';

class AdminClassesScreen extends StatefulWidget {
  const AdminClassesScreen({super.key});

  @override
  State<AdminClassesScreen> createState() => _AdminClassesScreenState();
}

class _AdminClassesScreenState extends State<AdminClassesScreen> {
  bool _loading = true;
  String? _error;
  List<_ClassItem> _classes = [];
  List<_UserItem> _teachers = [];
  List<_UserItem> _students = [];

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
      final responses = await Future.wait([
        Services.api.get('/api/v1/classes'),
        Services.api.get('/api/v1/admin/users?role=teacher'),
        Services.api.get('/api/v1/admin/users?role=student'),
      ]);
      if (responses.any((res) => res.statusCode != 200)) {
        throw Exception('Failed to load class data');
      }
      final classesJson = jsonDecode(responses[0].body) as List<dynamic>;
      final teachersJson = jsonDecode(responses[1].body) as List<dynamic>;
      final studentsJson = jsonDecode(responses[2].body) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _classes = classesJson.map((e) => _ClassItem.fromJson(e as Map<String, dynamic>)).toList();
        _teachers = teachersJson.map((e) => _UserItem.fromJson(e as Map<String, dynamic>)).toList();
        _students = studentsJson.map((e) => _UserItem.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load classes';
      });
    }
  }

  String? _classNameById(int? classId) {
    if (classId == null) return null;
    for (final item in _classes) {
      if (item.id == classId) return item.name;
    }
    return null;
  }

  Future<void> _createClass() async {
    final nameController = TextEditingController();
    int? classTeacherId;
    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            title: const Text('Create Class'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Class Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: classTeacherId,
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('No class teacher')),
                      ..._teachers.map(
                        (teacher) => DropdownMenuItem<int?>(
                          value: teacher.id,
                          child: Text(teacher.fullName),
                        ),
                      ),
                    ],
                    onChanged: (value) => setModalState(() => classTeacherId = value),
                    decoration: const InputDecoration(
                      labelText: 'Class Teacher',
                      border: OutlineInputBorder(),
                    ),
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
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final body = <String, dynamic>{'name': name, 'class_teacher_id': classTeacherId};
                  final res = await Services.api.post('/api/v1/classes', body);
                  if (res.statusCode == 200) {
                    navigator.pop(true);
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Failed to create class')),
                    );
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
        );
      },
    );
    nameController.dispose();
    if (created == true) {
      await _load();
    }
  }

  Future<void> _manageClass(_ClassItem item) async {
    String className = item.name;
    final selectedTeacherIds = _teachers.where((teacher) => teacher.classId == item.id).map((e) => e.id).toSet();
    final selectedStudentIds = _students.where((student) => student.classId == item.id).map((e) => e.id).toSet();
    int? selectedClassTeacherId = item.classTeacherId;
    String manageQuery = '';
    String manageFilter = 'all';

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            List<_UserItem> filterUsers(List<_UserItem> users) {
              final query = manageQuery.trim().toLowerCase();
              return users.where((user) {
                final matchesQuery = query.isEmpty || user.fullName.toLowerCase().contains(query);
                final matchesClass = switch (manageFilter) {
                  'assigned' => user.classId == item.id,
                  'unassigned' => user.classId == null,
                  _ => true,
                };
                return matchesQuery && matchesClass;
              }).toList();
            }

            Widget buildUserCheckbox(_UserItem user, Set<int> selectedIds) {
              final currentClassName = _classNameById(user.classId);
              return CheckboxListTile(
                value: selectedIds.contains(user.id),
                contentPadding: EdgeInsets.zero,
                title: Text(user.fullName),
                subtitle: Text(currentClassName == null ? 'Unassigned' : 'Current: $currentClassName'),
                onChanged: (checked) {
                  setModalState(() {
                    if (checked == true) {
                      selectedIds.add(user.id);
                    } else {
                      selectedIds.remove(user.id);
                    }
                  });
                },
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Manage Class', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      TextField(
                        controller: TextEditingController(text: className)
                          ..selection = TextSelection.collapsed(offset: className.length),
                        onChanged: (value) => className = value,
                        decoration: const InputDecoration(
                          labelText: 'Class Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        initialValue: selectedClassTeacherId,
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('No class teacher')),
                          ..._teachers.map(
                            (teacher) => DropdownMenuItem<int?>(
                              value: teacher.id,
                              child: Text(teacher.fullName),
                            ),
                          ),
                        ],
                        onChanged: (value) => setModalState(() => selectedClassTeacherId = value),
                        decoration: const InputDecoration(
                          labelText: 'Class Teacher',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        onChanged: (value) => setModalState(() => manageQuery = value),
                        decoration: const InputDecoration(
                          labelText: 'Search users',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'all', label: Text('All')),
                          ButtonSegment(value: 'assigned', label: Text('In Class')),
                          ButtonSegment(value: 'unassigned', label: Text('Unassigned')),
                        ],
                        selected: {manageFilter},
                        onSelectionChanged: (selection) {
                          setModalState(() => manageFilter = selection.first);
                        },
                      ),
                      const SizedBox(height: 16),
                      Text('Teachers', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...filterUsers(_teachers)
                          .map((teacher) => buildUserCheckbox(teacher, selectedTeacherIds)),
                      const SizedBox(height: 16),
                      Text('Students', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...filterUsers(_students)
                          .map((student) => buildUserCheckbox(student, selectedStudentIds)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (saved != true) return;

    final normalizedName = className.trim();
    if (normalizedName.isEmpty) {
      _showSnack('Class name is required');
      return;
    }

    if (selectedClassTeacherId != null) {
      selectedTeacherIds.add(selectedClassTeacherId!);
    }

    final currentTeacherIds = _teachers.where((teacher) => teacher.classId == item.id).map((e) => e.id).toSet();
    final currentStudentIds = _students.where((student) => student.classId == item.id).map((e) => e.id).toSet();

    final classRes = await Services.api.put('/api/v1/classes/${item.id}', {
      'name': normalizedName,
      'class_teacher_id': selectedClassTeacherId,
    });
    if (classRes.statusCode != 200) {
      _showSnack('Failed to update class');
      return;
    }

    Future<bool> syncAssignments(Set<int> selectedIds, Set<int> currentIds, List<_UserItem> allUsers) async {
      final toAssign = selectedIds.difference(currentIds);
      final toUnassign = currentIds.difference(selectedIds);

      for (final userId in toAssign) {
        final res = await Services.api.put('/api/v1/admin/users/$userId/class-assignment', {
          'class_id': item.id,
        });
        if (res.statusCode != 200) return false;
      }

      for (final userId in toUnassign) {
        final user = allUsers.firstWhere((entry) => entry.id == userId);
        if (user.id == selectedClassTeacherId) {
          continue;
        }
        final res = await Services.api.put('/api/v1/admin/users/$userId/class-assignment', {
          'class_id': null,
        });
        if (res.statusCode != 200) return false;
      }

      return true;
    }

    final teachersOk = await syncAssignments(selectedTeacherIds, currentTeacherIds, _teachers);
    if (!teachersOk) {
      _showSnack('Failed to update teacher assignments');
      return;
    }
    final studentsOk = await syncAssignments(selectedStudentIds, currentStudentIds, _students);
    if (!studentsOk) {
      _showSnack('Failed to update student assignments');
      return;
    }

    await _load();
    _showSnack('Class updated');
  }

  Future<void> _deleteClass(_ClassItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text('Delete ${item.name}? This will fail if users or records are still assigned.'),
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

    final res = await Services.api.delete('/api/v1/classes/${item.id}');
    if (!mounted) return;
    if (res.statusCode == 200) {
      await _load();
      _showSnack('Class deleted');
      return;
    }
    String message = 'Failed to delete class';
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['detail'] is String) {
        message = body['detail'] as String;
      }
    } catch (_) {}
    _showSnack(message);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Classes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createClass,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Class'),
      ),
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
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      children: [
                        if (_classes.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text('No classes available yet.'),
                          )
                        else
                          ..._classes.map((item) {
                            final teacherCount =
                                _teachers.where((teacher) => teacher.classId == item.id).length;
                            final studentCount =
                                _students.where((student) => student.classId == item.id).length;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Card(
                                elevation: 0,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                          OutlinedButton(
                                            onPressed: () => _manageClass(item),
                                            child: const Text('Manage'),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            tooltip: 'Delete class',
                                            onPressed: () => _deleteClass(item),
                                            icon: const Icon(Icons.delete_outline_rounded),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item.classTeacherName == null
                                            ? 'Class Teacher: Not assigned'
                                            : 'Class Teacher: ${item.classTeacherName}',
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _CountChip(label: 'Teachers', count: teacherCount),
                                          _CountChip(label: 'Students', count: studentCount),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _ClassItem {
  _ClassItem({
    required this.id,
    required this.name,
    required this.classTeacherId,
    required this.classTeacherName,
  });

  final int id;
  final String name;
  final int? classTeacherId;
  final String? classTeacherName;

  factory _ClassItem.fromJson(Map<String, dynamic> json) {
    return _ClassItem(
      id: json['id'] as int,
      name: json['name'] as String,
      classTeacherId: json['class_teacher_id'] as int?,
      classTeacherName: json['class_teacher_name'] as String?,
    );
  }
}

class _UserItem {
  _UserItem({
    required this.id,
    required this.fullName,
    required this.classId,
  });

  final int id;
  final String fullName;
  final int? classId;

  factory _UserItem.fromJson(Map<String, dynamic> json) {
    return _UserItem(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      classId: json['class_id'] as int?,
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $count'),
    );
  }
}

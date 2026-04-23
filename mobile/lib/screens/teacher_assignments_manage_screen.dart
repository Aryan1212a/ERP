import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/service_locator.dart';
import '../ui/app_components.dart';
import '../ui/app_theme.dart';

class TeacherAssignmentsManageScreen extends StatefulWidget {
  const TeacherAssignmentsManageScreen({
    super.key,
    this.showScaffold = true,
  });

  final bool showScaffold;

  @override
  State<TeacherAssignmentsManageScreen> createState() => _TeacherAssignmentsManageScreenState();
}

class _TeacherAssignmentsManageScreenState extends State<TeacherAssignmentsManageScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  List<_ClassItem> _classes = [];
  List<_AssignmentItem> _items = [];
  int? _selectedClassId;
  PlatformFile? _selectedFile;
  final Set<int> _deletingAssignments = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final responses = await Future.wait([
        Services.api.get('/api/v1/classes'),
        Services.api.get('/api/v1/teacher/assignments/manage'),
      ]);
      if (responses.any((response) => response.statusCode != 200)) {
        throw Exception('Failed');
      }

      final classesJson = jsonDecode(responses[0].body) as List<dynamic>;
      final manageJson = jsonDecode(responses[1].body) as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _classes = classesJson
            .map((item) => _ClassItem.fromJson(item as Map<String, dynamic>))
            .toList();
        _selectedClassId ??= _classes.isNotEmpty ? _classes.first.id : null;
        _items = (manageJson['assignments'] as List<dynamic>)
            .map((item) => _AssignmentItem.fromJson(item as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load assignments';
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    setState(() => _selectedFile = result.files.single);
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    if (_selectedClassId == null) {
      _showSnack('Select a class');
      return;
    }
    if (_title.text.trim().isEmpty) {
      _showSnack('Assignment title is required');
      return;
    }

    setState(() => _submitting = true);

    try {
      final uri = Uri.parse('${Services.api.baseUrl}/api/v1/teacher/assignments');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer ${Services.api.token}';
      request.headers['ngrok-skip-browser-warning'] = 'true';
      request.fields['class_id'] = _selectedClassId.toString();
      request.fields['title'] = _title.text.trim();
      request.fields['description'] = _description.text.trim();
      request.fields['due_date'] = _formatDateForApi(_dueDate);

      final file = _selectedFile;
      if (file != null && file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            file.bytes!,
            filename: file.name,
          ),
        );
      }

      final response = await request.send();
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        _title.clear();
        _description.clear();
        setState(() {
          _selectedFile = null;
          _dueDate = DateTime.now().add(const Duration(days: 7));
        });
        _showSnack('Assignment created');
        await _load();
      } else {
        _showSnack('Failed to create assignment');
      }
    } catch (_) {
      if (mounted) {
        _showSnack('Failed to create assignment');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _deleteAssignment(_AssignmentItem assignment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove assignment?'),
          content: Text(
            'This will delete "${assignment.title}" and its submission statuses.',
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
        );
      },
    );

    if (confirm != true || !mounted) return;

    setState(() => _deletingAssignments.add(assignment.assignmentId));
    try {
      final res = await Services.api.delete(
        '/api/v1/teacher/assignments/${assignment.assignmentId}',
      );
      if (!mounted) return;

      if (res.statusCode == 200) {
        setState(() {
          _items.removeWhere((item) => item.assignmentId == assignment.assignmentId);
        });
        _showSnack('Assignment removed');
      } else {
        _showSnack('Failed to remove assignment');
      }
    } catch (_) {
      if (mounted) {
        _showSnack('Failed to remove assignment');
      }
    } finally {
      if (mounted) {
        setState(() => _deletingAssignments.remove(assignment.assignmentId));
      }
    }
  }

  Future<bool> _updateStudentStatus(_AssignmentItem assignment, int studentId, String status) async {
    try {
      final res = await Services.api.put(
        '/api/v1/teacher/assignments/${assignment.assignmentId}/students/$studentId/status',
        {'status': status},
      );
      if (res.statusCode == 200) {
        setState(() {
          final student = assignment.students.firstWhere((s) => s.studentId == studentId);
          student.status = status;
        });
        return true;
      } else {
        _showSnack('Failed to update status');
        return false;
      }
    } catch (_) {
      _showSnack('Failed to update status');
      return false;
    }
  }

  void _showStudents(_AssignmentItem assignment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return _AssignmentStudentsSheet(
              assignment: assignment,
              scrollController: scrollController,
              onStatusChanged: (studentId, status) => _updateStudentStatus(assignment, studentId, status),
            );
          },
        );
      },
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (widget.showScaffold) ...[
              Text(
                'Assignments',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Create assignments, upload attachments, and correct mistakes quickly.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            _ComposerCard(
              classes: _classes,
              selectedClassId: _selectedClassId,
              titleController: _title,
              descriptionController: _description,
              dueDate: _dueDate,
              selectedFile: _selectedFile,
              submitting: _submitting,
              onClassChanged: (value) => setState(() => _selectedClassId = value),
              onPickDate: _pickDueDate,
              onPickFile: _pickFile,
              onClearFile: () => setState(() => _selectedFile = null),
              onSubmit: _submit,
            ),
            const SizedBox(height: AppSpacing.xl),
            const AppSectionHeader(title: 'Published Assignments'),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              AppStateCard(
                title: 'Assignments unavailable',
                message: _error!,
                icon: Icons.error_outline_rounded,
                action: AppButton.secondary(
                  label: 'Retry',
                  onPressed: _load,
                ),
              )
            else if (_items.isEmpty)
              const AppStateCard(
                title: 'No assignments yet',
                message: 'Create your first assignment to publish work for your class.',
                icon: Icons.assignment_outlined,
              )
            else
              ..._items.map(
                (assignment) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: _AssignmentOverviewCard(
                    assignment: assignment,
                    deleting: _deletingAssignments.contains(assignment.assignmentId),
                    onDelete: () => _deleteAssignment(assignment),
                    onCheck: () => _showStudents(assignment),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (!widget.showScaffold) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Assignments')),
      body: body,
    );
  }
}

class _ComposerCard extends StatelessWidget {
  const _ComposerCard({
    required this.classes,
    required this.selectedClassId,
    required this.titleController,
    required this.descriptionController,
    required this.dueDate,
    required this.selectedFile,
    required this.submitting,
    required this.onClassChanged,
    required this.onPickDate,
    required this.onPickFile,
    required this.onClearFile,
    required this.onSubmit,
  });

  final List<_ClassItem> classes;
  final int? selectedClassId;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final DateTime dueDate;
  final PlatformFile? selectedFile;
  final bool submitting;
  final ValueChanged<int?> onClassChanged;
  final VoidCallback onPickDate;
  final VoidCallback onPickFile;
  final VoidCallback onClearFile;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.9),
            AppColors.surfaceAlt.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Assignment',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Publish coursework with a due date and optional attachment.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          DropdownButtonFormField<int>(
            initialValue: selectedClassId,
            items: classes
                .map(
                  (item) => DropdownMenuItem<int>(
                    value: item.id,
                    child: Text(item.name),
                  ),
                )
                .toList(),
            onChanged: onClassChanged,
            decoration: const InputDecoration(labelText: 'Class'),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Assignment title'),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              OutlinedButton.icon(
                onPressed: onPickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(_formatDate(dueDate)),
              ),
              OutlinedButton.icon(
                onPressed: onPickFile,
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(
                  selectedFile == null ? 'Attach file' : 'Change file',
                ),
              ),
            ],
          ),
          if (selectedFile != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.card),
                color: Colors.white.withValues(alpha: 0.08),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined, color: Colors.white),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      selectedFile!.name,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    onPressed: onClearFile,
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: submitting ? null : onSubmit,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(submitting ? 'Publishing...' : 'Publish Assignment'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentOverviewCard extends StatelessWidget {
  const _AssignmentOverviewCard({
    required this.assignment,
    required this.deleting,
    required this.onDelete,
    required this.onCheck,
  });

  final _AssignmentItem assignment;
  final bool deleting;
  final VoidCallback onDelete;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final submitted = assignment.students.where((student) => student.status == 'submitted').length;
    final pending = assignment.students.where((student) => student.status == 'pending').length;
    final late = assignment.students.where((student) => student.status == 'late').length;
    final missing = assignment.students.where((student) => student.status == 'missing').length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${assignment.className ?? "Class ${assignment.classId}"} • Due ${_formatDateLabel(assignment.dueDate)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      onPressed: onDelete,
                      tooltip: 'Delete assignment',
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
            ],
          ),
          if ((assignment.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              assignment.description!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _AssignmentStatPill(
                label: 'Submitted',
                value: submitted,
                color: AppColors.success,
              ),
              _AssignmentStatPill(
                label: 'Pending',
                value: pending,
                color: AppColors.primary,
              ),
              _AssignmentStatPill(
                label: 'Late',
                value: late,
                color: AppColors.warning,
              ),
              _AssignmentStatPill(
                label: 'Missing',
                value: missing,
                color: AppColors.danger,
              ),
            ],
          ),
          if (assignment.fileUrl != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.card),
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_file_rounded, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      assignment.fileUrl!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: onCheck,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Check Submissions'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentStatPill extends StatelessWidget {
  const _AssignmentStatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ClassItem {
  const _ClassItem({required this.id, required this.name});

  final int id;
  final String name;

  factory _ClassItem.fromJson(Map<String, dynamic> json) {
    return _ClassItem(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class _AssignmentItem {
  const _AssignmentItem({
    required this.assignmentId,
    required this.classId,
    required this.className,
    required this.title,
    required this.description,
    required this.fileUrl,
    required this.dueDate,
    required this.students,
  });

  final int assignmentId;
  final int classId;
  final String? className;
  final String title;
  final String? description;
  final String? fileUrl;
  final String dueDate;
  final List<_AssignmentStudentItem> students;

  factory _AssignmentItem.fromJson(Map<String, dynamic> json) {
    return _AssignmentItem(
      assignmentId: json['assignment_id'] as int,
      classId: json['class_id'] as int,
      className: json['class_name'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      fileUrl: json['file_url'] as String?,
      dueDate: json['due_date'] as String,
      students: (json['students'] as List<dynamic>)
          .map((item) => _AssignmentStudentItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class _AssignmentStudentItem {
  _AssignmentStudentItem({
    required this.studentId,
    required this.name,
    required this.status,
  });

  final int studentId;
  final String name;
  String status;

  factory _AssignmentStudentItem.fromJson(Map<String, dynamic> json) {
    return _AssignmentStudentItem(
      studentId: json['student_id'] as int,
      name: json['name'] as String,
      status: json['status'] as String,
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

String _formatDateLabel(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return _formatDate(parsed);
}

class _AssignmentStudentsSheet extends StatefulWidget {
  const _AssignmentStudentsSheet({
    required this.assignment,
    required this.scrollController,
    required this.onStatusChanged,
  });

  final _AssignmentItem assignment;
  final ScrollController scrollController;
  final Future<bool> Function(int studentId, String status) onStatusChanged;

  @override
  State<_AssignmentStudentsSheet> createState() => _AssignmentStudentsSheetState();
}

class _AssignmentStudentsSheetState extends State<_AssignmentStudentsSheet> {
  String _selectedStatus = 'submitted';
  final Set<int> _updating = {};

  @override
  Widget build(BuildContext context) {
    final filteredStudents = widget.assignment.students
        .where((s) => s.status == _selectedStatus)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Check Submissions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.assignment.title,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                'submitted',
                'pending',
                'late',
                'missing',
              ].map((status) {
                final isSelected = _selectedStatus == status;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(status[0].toUpperCase() + status.substring(1)),
                    selected: isSelected,
                    onSelected: (v) {
                      if (v) setState(() => _selectedStatus = status);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: filteredStudents.isEmpty
                ? Center(
                    child: Text(
                      'No students found with status "$_selectedStatus"',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    controller: widget.scrollController,
                    itemCount: filteredStudents.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final student = filteredStudents[index];
                      final isUpdating = _updating.contains(student.studentId);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          foregroundColor: AppColors.primary,
                          child: Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : '?'),
                        ),
                        title: Text(student.name),
                        trailing: isUpdating
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: student.status,
                                  isDense: true,
                                  items: ['submitted', 'pending', 'late', 'missing']
                                      .map((s) => DropdownMenuItem(
                                            value: s,
                                            child: Text(s[0].toUpperCase() + s.substring(1)),
                                          ))
                                      .toList(),
                                  onChanged: (newStatus) async {
                                    if (newStatus == null || newStatus == student.status) return;
                                    setState(() => _updating.add(student.studentId));
                                    final success = await widget.onStatusChanged(student.studentId, newStatus);
                                    if (mounted) {
                                      setState(() {
                                        _updating.remove(student.studentId);
                                      });
                                    }
                                  },
                                ),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

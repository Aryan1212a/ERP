import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/service_locator.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  bool _loading = true;
  String? _error;
  List<_TimetableItem> _items = [];
  List<_ClassItem> _classes = [];
  final _subject = TextEditingController();
  int? _selectedClassId;
  int _dayOfWeek = 0;
  int _period = 1;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subject.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final responses = await Future.wait([
        Services.api.get('/api/v1/timetable'),
        Services.api.get('/api/v1/classes'),
      ]);
      if (responses.any((res) => res.statusCode != 200)) {
        throw Exception('Failed to load timetable');
      }
      final timetableJson = jsonDecode(responses[0].body) as List<dynamic>;
      final classesJson = jsonDecode(responses[1].body) as List<dynamic>;
      if (!mounted) return;
      final classes =
          classesJson.map((e) => _ClassItem.fromJson(e as Map<String, dynamic>)).toList();
      setState(() {
        _classes = classes;
        _selectedClassId ??= classes.isNotEmpty ? classes.first.id : null;
        _items = timetableJson
            .map((e) => _TimetableItem.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) {
            final dayCompare = a.dayOfWeek.compareTo(b.dayOfWeek);
            if (dayCompare != 0) return dayCompare;
            return a.period.compareTo(b.period);
          });
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load timetable';
      });
    }
  }

  Future<void> _createEntry() async {
    if (_selectedClassId == null) {
      _showSnack('Create a class first');
      return;
    }
    if (_subject.text.trim().isEmpty) {
      _showSnack('Subject is required');
      return;
    }
    setState(() => _submitting = true);
    final res = await Services.api.post('/api/v1/timetable', {
      'class_id': _selectedClassId,
      'day_of_week': _dayOfWeek,
      'period': _period,
      'subject': _subject.text.trim(),
    });
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res.statusCode == 200) {
      _subject.clear();
      await _load();
      _showSnack('Timetable entry created');
    } else {
      _showSnack('Failed to create timetable entry');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _className(int classId) {
    for (final c in _classes) {
      if (c.id == classId) return c.name;
    }
    return 'Class $classId';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Timetable')),
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
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Create Timetable Entry',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  initialValue: _selectedClassId,
                                  items: _classes
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c.id,
                                          child: Text(c.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) => setState(() => _selectedClassId = value),
                                  decoration: const InputDecoration(
                                    labelText: 'Class',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _subject,
                                  decoration: const InputDecoration(
                                    labelText: 'Subject',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  initialValue: _dayOfWeek,
                                  items: List.generate(
                                    _weekdays.length,
                                    (index) => DropdownMenuItem(
                                      value: index,
                                      child: Text(_weekdays[index]),
                                    ),
                                  ),
                                  onChanged: (value) => setState(() => _dayOfWeek = value ?? 0),
                                  decoration: const InputDecoration(
                                    labelText: 'Day',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  initialValue: _period,
                                  items: List.generate(
                                    8,
                                    (index) => DropdownMenuItem(
                                      value: index + 1,
                                      child: Text('Period ${index + 1}'),
                                    ),
                                  ),
                                  onChanged: (value) => setState(() => _period = value ?? 1),
                                  decoration: const InputDecoration(
                                    labelText: 'Period',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _submitting ? null : _createEntry,
                                  icon: const Icon(Icons.add_rounded),
                                  label: Text(_submitting ? 'Saving...' : 'Add Entry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Existing Entries',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        if (_items.isEmpty)
                          const Card(
                            elevation: 0,
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No timetable entries yet.'),
                            ),
                          )
                        else
                          ..._items.map(
                            (item) => Card(
                              elevation: 0,
                              child: ListTile(
                                title: Text(item.subject),
                                subtitle: Text(
                                  '${_className(item.classId)} • ${_weekdays[item.dayOfWeek]} • Period ${item.period}',
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
        ),
      ),
    );
  }
}

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

class _TimetableItem {
  _TimetableItem({
    required this.classId,
    required this.dayOfWeek,
    required this.period,
    required this.subject,
  });

  final int classId;
  final int dayOfWeek;
  final int period;
  final String subject;

  factory _TimetableItem.fromJson(Map<String, dynamic> json) {
    return _TimetableItem(
      classId: json['class_id'] as int,
      dayOfWeek: json['day_of_week'] as int,
      period: json['period'] as int,
      subject: json['subject'] as String,
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

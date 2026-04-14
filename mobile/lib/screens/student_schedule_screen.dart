import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/service_locator.dart';

class StudentScheduleScreen extends StatefulWidget {
  const StudentScheduleScreen({
    super.key,
    this.showScaffold = true,
  });

  final bool showScaffold;

  @override
  State<StudentScheduleScreen> createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> {
  bool _loading = true;
  String? _error;
  List<_ScheduleItem> _items = [];

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
      final res = await Services.api.get('/api/v1/student/timetable/today');
      if (res.statusCode != 200) {
        throw Exception('Failed to load schedule');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (data['timetable'] as List<dynamic>)
          .map((e) => _ScheduleItem.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load schedule';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
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
                : _items.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No classes scheduled today.'),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Card(
                            elevation: 0,
                            child: ListTile(
                              leading: CircleAvatar(child: Text(item.period.toString())),
                              title: Text(item.subject),
                              subtitle: Text('${item.startTime} - ${item.endTime}'),
                            ),
                          );
                        },
                      ),
      ),
    );
    if (!widget.showScaffold) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Today Schedule')),
      body: content,
    );
  }
}

class _ScheduleItem {
  _ScheduleItem({
    required this.period,
    required this.startTime,
    required this.endTime,
    required this.subject,
  });

  final int period;
  final String startTime;
  final String endTime;
  final String subject;

  factory _ScheduleItem.fromJson(Map<String, dynamic> json) {
    return _ScheduleItem(
      period: json['period'] as int,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      subject: json['subject'] as String,
    );
  }
}

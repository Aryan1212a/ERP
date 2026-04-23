import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/service_locator.dart';

class StudentNoticesScreen extends StatefulWidget {
  const StudentNoticesScreen({
    super.key,
    this.showScaffold = true,
  });

  final bool showScaffold;

  @override
  State<StudentNoticesScreen> createState() => _StudentNoticesScreenState();
}

class _StudentNoticesScreenState extends State<StudentNoticesScreen> {
  bool _loading = true;
  String? _error;
  List<_StudentNoticeItem> _items = [];
  final Set<String> _pinnedNoticeIds = {};

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
      await Services.api.post('/api/v1/student/notices/mark-read', {});
      final res = await Services.api.get('/api/v1/student/notices');
      if (res.statusCode != 200) {
        throw Exception('Failed');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final notices = (data['notices'] as List<dynamic>)
          .map((e) => _StudentNoticeItem.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = notices;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load notices';
      });
    }
  }

  void _clearNotices() {
    setState(() {
      _items.clear();
      _pinnedNoticeIds.clear();
    });
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
                            child: Text('No notices available.'),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text(
                                      item.title,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'From: ${item.senderName}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.body,
                                            style: Theme.of(context).textTheme.bodyMedium,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            _pinnedNoticeIds.contains(item.createdAt.toIso8601String())
                                                ? Icons.push_pin
                                                : Icons.push_pin_outlined,
                                            color: _pinnedNoticeIds.contains(item.createdAt.toIso8601String())
                                                ? Theme.of(context).colorScheme.primary
                                                : null,
                                          ),
                                          tooltip: _pinnedNoticeIds.contains(item.createdAt.toIso8601String())
                                              ? 'Unpin notice'
                                              : 'Pin notice',
                                          onPressed: () {
                                            setState(() {
                                              final noticeId = item.createdAt.toIso8601String();
                                              if (_pinnedNoticeIds.contains(noticeId)) {
                                                _pinnedNoticeIds.remove(noticeId);
                                              } else {
                                                _pinnedNoticeIds.add(noticeId);
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _formatDate(item.createdAt),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.7),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemCount: _items.length,
                      ),
      ),
    );
    if (!widget.showScaffold) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Student Notices'), actions: [IconButton(icon: const Icon(Icons.clear_all), tooltip: 'Clear notices', onPressed: () {
                    setState(() {
                      _items.clear();
                      _pinnedNoticeIds.clear();
                    });
                  })]),
      body: content,
    );
  }
}

class _StudentNoticeItem {
  _StudentNoticeItem({
    required this.title,
    required this.body,
    required this.createdAt,
    required this.senderName,
  });

  final String title;
  final String body;
  final DateTime createdAt;
  final String senderName;

  factory _StudentNoticeItem.fromJson(Map<String, dynamic> json) {
    return _StudentNoticeItem(
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      senderName: json['sender_name'] as String,
    );
  }
}

String _formatDate(DateTime dt) {
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

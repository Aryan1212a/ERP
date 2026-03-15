import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/service_locator.dart';

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Services.api.get('/api/v1/notices');
    if (res.statusCode == 200) {
      setState(() => _items = jsonDecode(res.body));
    }
  }

  Future<void> _openSendNotice() async {
    final created = await Navigator.pushNamed(context, '/notices/send');
    if (created == true) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notices'),
        actions: [
          IconButton(
            tooltip: 'Send notice',
            onPressed: _openSendNotice,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final it = _items[i];
          return ListTile(
            title: Text(it['title']),
            subtitle: Text(it['body']),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSendNotice,
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('Send Notice'),
      ),
    );
  }
}

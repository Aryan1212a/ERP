import 'package:flutter/material.dart';
import '../services/service_locator.dart';
import 'dart:convert';

class SendNoticeScreen extends StatefulWidget {
  const SendNoticeScreen({super.key});

  @override
  State<SendNoticeScreen> createState() => _SendNoticeScreenState();
}

class _SendNoticeScreenState extends State<SendNoticeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();

  bool _loading = false;
  String? _error;

  List<dynamic> _notices = [];
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadNotices();
    _loadUser();
  }

  Future<void> _loadUser() async {
  final res = await Services.api.get('/api/v1/auth/me');

  if (res.statusCode == 200) {
    final data = jsonDecode(res.body);

    setState(() {
      _currentUserId = data['id'];
    });
  }
}


  Future<void> _loadNotices() async {
  final res = await Services.api.get('/api/v1/notices');

  if (res.statusCode == 200) {
    final data = jsonDecode(res.body);

    setState(() {
      _notices = data;
    });
  }
}

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await Services.api.post('/api/v1/notices', {
        'title': _title.text.trim(),
        'body': _body.text.trim(),
      });

      if (!mounted) return;

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notice sent')),
        );

        _title.clear();
        _body.clear();

        await _loadNotices(); // refresh list

        setState(() => _loading = false);
      } else {
        setState(() {
          _loading = false;
          _error = 'Failed to send notice';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Something went wrong';
      });
    }
  }

  Future<void> _deleteNotice(int id) async {
    try {
      final res = await Services.api.delete('/api/v1/notices/$id');

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deleted successfully')),
        );

        await _loadNotices();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Notice'),
        centerTitle: true,
      ),

      body: SafeArea(
        child: Column(
          children: [
            /// FORM
            Expanded(
              flex: 2,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _title,
                          decoration: const InputDecoration(labelText: 'Title'),
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _body,
                          maxLines: 4,
                          decoration:
                              const InputDecoration(labelText: 'Message'),
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 10),

                        if (_error != null)
                          Text(_error!,
                              style: const TextStyle(color: Colors.red)),

                        const SizedBox(height: 10),

                        FilledButton(
                          onPressed: _loading ? null : _submit,
                          child: Text(_loading ? 'Sending...' : 'Send'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            /// NOTICE LIST
            Expanded(
              flex: 3,
              child: _notices.isEmpty
                  ? const Center(child: Text("No notices"))
                  : ListView.builder(
                      itemCount: _notices.length,
                      itemBuilder: (context, index) {
                        final notice = _notices[index];

                        final isOwner =
                            notice['sender_id'] == _currentUserId;

                        return Card(
                          margin: const EdgeInsets.all(8),
                          child: ListTile(
                            title: Text(notice['title']),
                            subtitle: Text(notice['body']),
                            trailing: isOwner
                                ? IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () =>
                                        _deleteNotice(notice['id']),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

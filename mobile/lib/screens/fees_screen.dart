import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/service_locator.dart';

class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key});

  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Services.api.get('/api/v1/fees');
    if (res.statusCode == 200) {
      setState(() => _items = jsonDecode(res.body));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fees')),
      body: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final it = _items[i];
          return ListTile(
            title: Text('Student ${it['student_id']} - ${it['amount']}'),
            subtitle: Text('Due: ${it['due_date']} (${it['status']})'),
          );
        },
      ),
    );
  }
}

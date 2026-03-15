import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/service_locator.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Services.api.get('/api/v1/timetable');
    if (res.statusCode == 200) {
      setState(() => _items = jsonDecode(res.body));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Timetable')),
      body: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final it = _items[i];
          return ListTile(
            title: Text(it['subject']),
            subtitle: Text('Day ${it['day_of_week']} - Period ${it['period']}'),
          );
        },
      ),
    );
  }
}

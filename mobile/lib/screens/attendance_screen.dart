import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/service_locator.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Services.api.get('/api/v1/attendance');
    if (res.statusCode == 200) {
      setState(() {
        _items = jsonDecode(res.body);
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final today = DateTime.now();
    final res = await Services.api.post('/api/v1/attendance', {
      'class_id': 1,
      'student_id': 1,
      'date': '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
      'status': 'present'
    });
    if (res.statusCode == 200) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.spaceGroteskTextTheme(baseTheme.textTheme);
    final presentCount = _items.where((it) => (it['status'] ?? '').toString().toLowerCase() == 'present').length;
    final absentCount = _items.where((it) => (it['status'] ?? '').toString().toLowerCase() == 'absent').length;
    final lateCount = _items.where((it) => (it['status'] ?? '').toString().toLowerCase() == 'late').length;

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Mark attendance'),
        ),
        body: Stack(
          children: [
            const _AttendanceBackground(),
            SafeArea(
              child: RefreshIndicator(
                onRefresh: _load,
                color: const Color(0xFF0F172A),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: _Header(onBack: () => Navigator.pop(context)),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _SummaryRow(
                          present: presentCount,
                          absent: absentCount,
                          late: lateCount,
                          loading: _loading,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                        child: _SectionTitle(
                          title: 'Recent records',
                          subtitle: 'Latest updates across classes',
                        ),
                      ),
                    ),
                    if (_loading)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: List.generate(4, (_) => const _AttendanceSkeleton()),
                          ),
                        ),
                      )
                    else if (_items.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _EmptyState(onAction: _add),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          childCount: _items.length,
                          (context, i) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            child: _AttendanceCard(item: _items[i]),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 90)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceBackground extends StatelessWidget {
  const _AttendanceBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF8FAFC),
            Color(0xFFE2E8F0),
            Color(0xFFF8FAFC),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: const [
          Positioned(
            top: -70,
            right: -40,
            child: _BlurBubble(color: Color(0xFF38BDF8), size: 210),
          ),
          Positioned(
            bottom: -90,
            left: -50,
            child: _BlurBubble(color: Color(0xFF6366F1), size: 240),
          ),
          Positioned(
            top: 160,
            left: 26,
            child: _BlurBubble(color: Color(0xFFF97316), size: 140),
          ),
        ],
      ),
    );
  }
}

class _BlurBubble extends StatelessWidget {
  const _BlurBubble({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.75),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF0F172A),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Monitor daily class activity',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                ),
              ],
            ),
          ),
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0EA5E9).withOpacity(0.12),
            ),
            child: const Icon(Icons.fact_check_rounded, color: Color(0xFF0EA5E9)),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.present,
    required this.absent,
    required this.late,
    required this.loading,
  });

  final int present;
  final int absent;
  final int late;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final data = [
      _SummaryData('Present', present, const Color(0xFF22C55E)),
      _SummaryData('Absent', absent, const Color(0xFFEF4444)),
      _SummaryData('Late', late, const Color(0xFFF59E0B)),
    ];

    return Row(
      children: data
          .map(
            (item) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _SummaryCard(data: item, loading: loading),
              ),
            ),
          )
          .toList()
        ..removeLast(),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data, required this.loading});

  final _SummaryData data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.8),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: data.color.withOpacity(0.12),
            ),
            child: Icon(Icons.circle, size: 16, color: data.color),
          ),
          const SizedBox(height: 10),
          loading
              ? Container(
                  height: 18,
                  width: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: data.color.withOpacity(0.1),
                  ),
                )
              : Text(
                  data.value.toString(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                ),
          const SizedBox(height: 6),
          Text(
            data.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF64748B),
              ),
        ),
      ],
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.item});

  final dynamic item;

  @override
  Widget build(BuildContext context) {
    final status = (item['status'] ?? 'unknown').toString();
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.82),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.12),
            ),
            child: Icon(Icons.person_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student ${item['student_id']}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Date: ${item['date']}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceSkeleton extends StatelessWidget {
  const _AttendanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.7),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.05),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.black.withOpacity(0.05),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 12,
                  width: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.black.withOpacity(0.04),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAction});

  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.8),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF38BDF8).withOpacity(0.15),
            ),
            child: const Icon(Icons.fact_check_rounded, color: Color(0xFF38BDF8)),
          ),
          const SizedBox(height: 14),
          Text(
            'No attendance records yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start by marking today’s attendance so your summary cards update automatically.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Mark attendance'),
          ),
        ],
      ),
    );
  }
}

class _SummaryData {
  const _SummaryData(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'present':
      return const Color(0xFF22C55E);
    case 'absent':
      return const Color(0xFFEF4444);
    case 'late':
      return const Color(0xFFF59E0B);
    default:
      return const Color(0xFF64748B);
  }
}

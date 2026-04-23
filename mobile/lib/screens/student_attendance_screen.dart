import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/service_locator.dart';
import '../ui/app_components.dart';
import '../ui/app_theme.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

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
      final res = await Services.api.get('/api/v1/student/attendance');
      if (!mounted) return;
      if (res.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Unable to load attendance records.';
        });
        return;
      }

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final attendance = (decoded['attendance'] as List<dynamic>? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      setState(() {
        _items = attendance;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load attendance records.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentCount = _countByStatus('present');
    final absentCount = _countByStatus('absent');
    final lateCount = _countByStatus('late');
    final totalCount = _items.length;
    final attendanceRate = totalCount == 0
        ? 0.0
        : ((presentCount + lateCount) / totalCount) * 100;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A1224),
              Color(0xFF101A33),
              Color(0xFF13203C),
            ],
          ),
        ),
        child: Stack(
          children: [
            const _AttendanceBackground(),
            SafeArea(
              child: RefreshIndicator(
                onRefresh: _load,
                color: AppColors.primary,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.md,
                        ),
                        child: _AttendanceHeader(
                          attendanceRate: attendanceRate,
                          totalCount: totalCount,
                          onBack: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: _SummaryGrid(
                          loading: _loading,
                          cards: [
                            _SummaryCardData(
                              label: 'Present',
                              value: presentCount.toString(),
                              icon: Icons.check_circle_outline_rounded,
                              color: AppColors.success,
                            ),
                            _SummaryCardData(
                              label: 'Absent',
                              value: absentCount.toString(),
                              icon: Icons.cancel_outlined,
                              color: AppColors.danger,
                            ),
                            _SummaryCardData(
                              label: 'Late',
                              value: lateCount.toString(),
                              icon: Icons.schedule_rounded,
                              color: AppColors.warning,
                            ),
                            _SummaryCardData(
                              label: 'Records',
                              value: totalCount.toString(),
                              icon: Icons.fact_check_outlined,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.xl,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: const AppSectionHeader(title: 'Attendance Timeline'),
                      ),
                    ),
                    if (_loading)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            childCount: 5,
                            (context, index) => const Padding(
                              padding: EdgeInsets.only(bottom: AppSpacing.md),
                              child: _AttendanceRecordSkeleton(),
                            ),
                          ),
                        ),
                      )
                    else if (_error != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          child: AppStateCard(
                            title: 'Attendance unavailable',
                            message: _error!,
                            icon: Icons.error_outline_rounded,
                            action: AppButton.secondary(
                              label: 'Retry',
                              onPressed: _load,
                            ),
                          ),
                        ),
                      )
                    else if (_items.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          child: const _EmptyAttendanceState(),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.xxl,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            childCount: _items.length,
                            (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: _AttendanceRecordCard(item: _items[index]),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _countByStatus(String status) {
    return _items
        .where((item) => (item['status'] ?? '').toString().toLowerCase() == status)
        .length;
  }
}

class _AttendanceBackground extends StatelessWidget {
  const _AttendanceBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -90,
            left: -70,
            child: _GlowOrb(
              size: 240,
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          Positioned(
            top: 120,
            right: -50,
            child: _GlowOrb(
              size: 220,
              color: AppColors.secondary.withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            bottom: -120,
            left: 80,
            child: _GlowOrb(
              size: 300,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: color.a * 0.35),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _AttendanceHeader extends StatelessWidget {
  const _AttendanceHeader({
    required this.attendanceRate,
    required this.totalCount,
    required this.onBack,
  });

  final double attendanceRate;
  final int totalCount;
  final VoidCallback onBack;

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
            AppColors.primary.withValues(alpha: 0.92),
            AppColors.surfaceAlt.withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                child: Text(
                  '$totalCount record${totalCount == 1 ? '' : 's'}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Attendance',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Track your recent attendance and overall consistency.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: attendanceRate / 100,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '${attendanceRate.toStringAsFixed(0)}%',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.cards,
    required this.loading,
  });

  final List<_SummaryCardData> cards;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1100 ? 4 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSpacing.lg,
            mainAxisSpacing: AppSpacing.lg,
            mainAxisExtent: 124,
          ),
          itemBuilder: (context, index) {
            return _SummaryMetricCard(data: cards[index], loading: loading);
          },
        );
      },
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  const _SummaryMetricCard({
    required this.data,
    required this.loading,
  });

  final _SummaryCardData data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              color: data.color.withValues(alpha: 0.16),
            ),
            child: Icon(data.icon, color: data.color),
          ),
          const Spacer(),
          loading
              ? Container(
                  width: 48,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                )
              : Text(
                  data.value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
          const SizedBox(height: AppSpacing.xs),
          Text(data.label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _AttendanceRecordCard extends StatelessWidget {
  const _AttendanceRecordCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final status = (item['status'] ?? 'unknown').toString();
    final color = _statusColor(status);
    final date = _formatDate(item['date']?.toString());
    final classId = item['class_id']?.toString();
    final subtitle = classId == null || classId.isEmpty
        ? 'Attendance entry recorded'
        : 'Class $classId';
    final icon = switch (status.toLowerCase()) {
      'present' => Icons.check_circle_rounded,
      'absent' => Icons.cancel_rounded,
      'late' => Icons.schedule_rounded,
      _ => Icons.help_outline_rounded,
    };

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: color.withValues(alpha: 0.12),
            ),
            child: Text(
              _statusLabel(status),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceRecordSkeleton extends StatelessWidget {
  const _AttendanceRecordSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 140,
                  height: 16,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 100,
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 76,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAttendanceState extends StatelessWidget {
  const _EmptyAttendanceState();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.14),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No attendance records yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Attendance records will appear here once entries are published for your account.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SummaryCardData {
  const _SummaryCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

String _formatDate(String? input) {
  if (input == null || input.isEmpty) return 'Unknown date';
  final parsed = DateTime.tryParse(input);
  if (parsed == null) return input;

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
  return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
}

String _statusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'present':
      return 'Present';
    case 'absent':
      return 'Absent';
    case 'late':
      return 'Late';
    default:
      return 'Unknown';
  }
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'present':
      return AppColors.success;
    case 'absent':
      return AppColors.danger;
    case 'late':
      return AppColors.warning;
    default:
      return AppColors.textSecondary;
  }
}

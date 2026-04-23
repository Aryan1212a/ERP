import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/service_locator.dart';
import '../ui/app_theme.dart';
import '../ui/app_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.title = 'School ERP Dashboard',
    this.subtitle = 'Welcome back',
    this.roleTag = 'Student view',
    this.roleColor = AppColors.primary,
    this.extraActions = const [],
  });

  final String title;
  final String subtitle;
  final String roleTag;
  final Color roleColor;
  final List<DashboardActionData> extraActions;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await Services.api.get('/api/v1/dashboard');
    if (!mounted) return;
    if (res.statusCode == 200) {
      setState(() => _data = jsonDecode(res.body));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = <_StatData>[
      _StatData(
        label: 'Attendance Records',
        value: _data == null ? null : _data!['attendance_records'].toString(),
        subtitle: 'Total captured',
        icon: Icons.fact_check_rounded,
        color: AppColors.secondary,
      ),
      _StatData(
        label: 'Timetable Entries',
        value: _data == null ? null : _data!['timetable_entries'].toString(),
        subtitle: 'Active sessions',
        icon: Icons.calendar_month_rounded,
        color: AppColors.primary,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: theme.colorScheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                  child: _Header(
                    title: widget.title,
                    subtitle: widget.subtitle,
                    roleTag: widget.roleTag,
                    roleColor: widget.roleColor,
                    onProfileTap: () => Navigator.pushNamed(context, '/profile'),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _SectionReveal(
                  delay: 100,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: SectionHeader(
                      title: 'Overview',
                      onActionPressed: () {},
                      actionText: 'View All',
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _SectionReveal(
                  delay: 100,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: _StatsGrid(stats: stats),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _SectionReveal(
                  delay: 220,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                    child: SectionHeader(
                      title: 'Quick Actions',
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _SectionReveal(
                  delay: 220,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: _QuickActions(
                      onAttendance: () => Navigator.pushNamed(context, '/attendance'),
                      onTimetable: () => Navigator.pushNamed(context, '/timetable'),
                      onFees: () => Navigator.pushNamed(context, '/fees'),
                      onNotices: () => Navigator.pushNamed(context, '/notices'),
                      extraActions: widget.extraActions,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _SectionReveal(
                  delay: 320,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
                    child: SectionHeader(
                      title: 'Today at a glance',
                      actionText: 'View All',
                      onActionPressed: () {},
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _SectionReveal(
                  delay: 320,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                    child: _Highlights(
                      isLoading: _data == null,
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

class _Header extends StatelessWidget {
  const _Header({
    required this.onProfileTap,
    required this.title,
    required this.subtitle,
    required this.roleTag,
    required this.roleColor,
  });

  final VoidCallback onProfileTap;
  final String title;
  final String subtitle;
  final String roleTag;
  final Color roleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  title,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _Pill(
                      icon: Icons.verified_rounded,
                      label: roleTag,
                      color: roleColor,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _Pill(
                      icon: Icons.sync_rounded,
                      label: 'Tap to refresh',
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          InkWell(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: const Icon(Icons.person_rounded, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Highlights extends StatelessWidget {
  const _Highlights({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          _HighlightRow(
            label: 'Attendance logs sync',
            value: isLoading ? 'Syncing…' : 'Up to date',
            color: AppColors.success,
          ),
          const SizedBox(height: AppSpacing.md),
          _HighlightRow(
            label: 'Next timetable review',
            value: 'Open timetable',
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          _HighlightRow(
            label: 'Pending fee actions',
            value: 'Check fees module',
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.card),
        color: theme.colorScheme.surface,
      ),
      child: Row(
        children: [
          Container(
            height: AppSpacing.sm,
            width: AppSpacing.sm,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      width: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        color: color.withValues(alpha: 0.2),
      ),
    );
  }
}

class _SectionReveal extends StatefulWidget {
  const _SectionReveal({required this.child, required this.delay});

  final Widget child;
  final int delay;

  @override
  State<_SectionReveal> createState() => _SectionRevealState();
}

class _SectionRevealState extends State<_SectionReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Opacity(
          opacity: _fade.value,
          child: Transform.translate(
            offset: Offset(0, _slide.value),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _StatData {
  const _StatData({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String label;
  final String? value;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final List<_StatData> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 640;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: stats
              .map(
                (stat) => SizedBox(
                  width: isWide ? (constraints.maxWidth - AppSpacing.md) / 2 : constraints.maxWidth,
                  child: _StatCard(stat: stat),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final _StatData stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: stat.color.withValues(alpha: 0.1),
            ),
            child: Icon(stat.icon, color: stat.color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                stat.value == null
                    ? _LoadingBar(color: stat.color)
                    : Text(
                        stat.value!,
                        style: theme.textTheme.headlineMedium,
                      ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  stat.subtitle,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardActionData {
  const DashboardActionData({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onAttendance,
    required this.onTimetable,
    required this.onFees,
    required this.onNotices,
    required this.extraActions,
  });

  final VoidCallback onAttendance;
  final VoidCallback onTimetable;
  final VoidCallback onFees;
  final VoidCallback onNotices;
  final List<DashboardActionData> extraActions;

  @override
  Widget build(BuildContext context) {
    final actions = <DashboardActionData>[
      DashboardActionData(
        label: 'Attendance',
        subtitle: 'Daily logs',
        icon: Icons.fact_check_rounded,
        color: AppColors.secondary,
        onTap: onAttendance,
      ),
      DashboardActionData(
        label: 'Timetable',
        subtitle: 'Class schedule',
        icon: Icons.event_available_rounded,
        color: AppColors.primary,
        onTap: onTimetable,
      ),
      DashboardActionData(
        label: 'Fees',
        subtitle: 'Payments',
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.warning,
        onTap: onFees,
      ),
      DashboardActionData(
        label: 'Notices',
        subtitle: 'Announcements',
        icon: Icons.notifications_active_rounded,
        color: AppColors.secondary,
        onTap: onNotices,
      ),
      ...extraActions,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 640;
        final itemWidth = isWide ? (constraints.maxWidth - AppSpacing.md) / 2 : (constraints.maxWidth - AppSpacing.md) / 2;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: actions
              .map(
                (action) => SizedBox(
                  width: itemWidth,
                  child: _ActionCard(action: action),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action});

  final DashboardActionData action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: action.onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: action.color.withValues(alpha: 0.12),
            ),
            child: Icon(action.icon, color: action.color),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            action.label,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            action.subtitle,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

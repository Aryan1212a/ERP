import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/service_locator.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.title = 'School ERP Dashboard',
    this.subtitle = 'Welcome back',
    this.roleTag = 'Student view',
    this.roleColor = const Color(0xFF22C55E),
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
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.spaceGroteskTextTheme(baseTheme.textTheme);
    final stats = <_StatData>[
      _StatData(
        label: 'Attendance Records',
        value: _data == null ? null : _data!['attendance_records'].toString(),
        subtitle: 'Total captured',
        icon: Icons.fact_check_rounded,
        accent: const Color(0xFF2DD4BF),
      ),
      _StatData(
        label: 'Timetable Entries',
        value: _data == null ? null : _data!['timetable_entries'].toString(),
        subtitle: 'Active sessions',
        icon: Icons.calendar_month_rounded,
        accent: const Color(0xFF60A5FA),
      ),
    ];

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: Scaffold(
        body: Stack(
          children: [
            const _DashboardBackground(),
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
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _StatsGrid(stats: stats),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _SectionReveal(
                        delay: 220,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
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
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
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
          ],
        ),
      ),
    );
  }
}

class _DashboardBackground extends StatelessWidget {
  const _DashboardBackground();

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
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _BlurBubble(
              color: Color(0xFF22D3EE),
              size: 220,
            ),
          ),
          Positioned(
            bottom: -90,
            left: -40,
            child: _BlurBubble(
              color: Color(0xFF6366F1),
              size: 240,
            ),
          ),
          Positioned(
            top: 160,
            left: 30,
            child: _BlurBubble(
              color: Color(0xFFF97316),
              size: 140,
            ),
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
        color: color.withValues(alpha: 0.18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.7),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.2,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Pill(
                      icon: Icons.verified_rounded,
                      label: roleTag,
                      color: roleColor,
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                      icon: Icons.sync_rounded,
                      label: 'Tap to refresh',
                      color: const Color(0xFF3B82F6),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF334155)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final List<_StatData> stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 640;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: stats
                  .map(
                    (stat) => SizedBox(
                      width: isWide ? (constraints.maxWidth - 14) / 2 : constraints.maxWidth,
                      child: _StatCard(stat: stat),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final _StatData stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.78),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [stat.accent.withValues(alpha: 0.2), stat.accent.withValues(alpha: 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(stat.icon, color: stat.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 6),
                stat.value == null
                    ? _LoadingBar(color: stat.accent)
                    : Text(
                        stat.value!,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                      ),
                const SizedBox(height: 6),
                Text(
                  stat.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF94A3B8),
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
        color: const Color(0xFF14B8A6),
        onTap: onAttendance,
      ),
      DashboardActionData(
        label: 'Timetable',
        subtitle: 'Class schedule',
        icon: Icons.event_available_rounded,
        color: const Color(0xFF3B82F6),
        onTap: onTimetable,
      ),
      DashboardActionData(
        label: 'Fees',
        subtitle: 'Payments',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFFF97316),
        onTap: onFees,
      ),
      DashboardActionData(
        label: 'Notices',
        subtitle: 'Announcements',
        icon: Icons.notifications_active_rounded,
        color: const Color(0xFF8B5CF6),
        onTap: onNotices,
      ),
      ...extraActions,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 640;
            final itemWidth = isWide ? (constraints.maxWidth - 14) / 2 : (constraints.maxWidth - 14) / 2;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
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
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action});

  final DashboardActionData action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withValues(alpha: 0.82),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
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
            const SizedBox(height: 14),
            Text(
              action.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              action.subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Highlights extends StatelessWidget {
  const _Highlights({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF0F172A),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Today at a glance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Icon(Icons.north_east_rounded, color: Colors.white.withValues(alpha: 0.7)),
            ],
          ),
          const SizedBox(height: 14),
          _HighlightRow(
            label: 'Attendance logs sync',
            value: isLoading ? 'Syncing…' : 'Up to date',
            color: const Color(0xFF22C55E),
          ),
          const SizedBox(height: 10),
          _HighlightRow(
            label: 'Next timetable review',
            value: 'Open timetable',
            color: const Color(0xFF38BDF8),
          ),
          const SizedBox(height: 10),
          _HighlightRow(
            label: 'Pending fee actions',
            value: 'Check fees module',
            color: const Color(0xFFFACC15),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.06),
      ),
      child: Row(
        children: [
          Container(
            height: 10,
            width: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.8),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
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
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
            color.withValues(alpha: 0.15),
          ],
        ),
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
    required this.accent,
  });

  final String label;
  final String? value;
  final String subtitle;
  final IconData icon;
  final Color accent;
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

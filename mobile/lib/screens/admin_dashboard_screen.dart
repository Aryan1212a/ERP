import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/service_locator.dart';
import '../services/theme_service.dart';
import 'profile_screen.dart';

class AdminDashboardShell extends StatefulWidget {
  const AdminDashboardShell({super.key});

  @override
  State<AdminDashboardShell> createState() => _AdminDashboardShellState();
}

class _AdminDashboardShellState extends State<AdminDashboardShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const AdminHomeScreen(),
      const ProfileScreen(showAppBar: false),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
        onDestinationSelected: (index) {
          if (_selectedIndex == index) return;
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }
}

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  bool _loading = true;
  String? _error;
  List<_AdminUser> _users = [];
  List<_AdminClass> _classes = [];
  int _timetableEntries = 0;

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
      final responses = await Future.wait([
        Services.api.get('/api/v1/admin/users'),
        Services.api.get('/api/v1/classes'),
        Services.api.get('/api/v1/timetable'),
      ]);
      if (responses.any((res) => res.statusCode != 200)) {
        throw Exception('Failed to load admin dashboard');
      }
      final usersJson = jsonDecode(responses[0].body) as List<dynamic>;
      final classesJson = jsonDecode(responses[1].body) as List<dynamic>;
      final timetableJson = jsonDecode(responses[2].body) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _users = usersJson
            .map((e) => _AdminUser.fromJson(e as Map<String, dynamic>))
            .toList();
        _classes = classesJson
            .map((e) => _AdminClass.fromJson(e as Map<String, dynamic>))
            .toList();
        _timetableEntries = timetableJson.length;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load admin dashboard';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminCount = _users.where((user) => user.role == 'admin').length;
    final studentCount = _users.where((user) => user.role == 'student').length;
    final teacherCount = _users.where((user) => user.role == 'teacher').length;
    final inactiveCount = _users.where((user) => !user.isActive).length;
    final pendingPasswordChanges = _users
        .where((user) => user.mustChangePassword)
        .length;
    final unassignedClasses = _classes
        .where((item) => item.classTeacherName == null)
        .length;
    final chartSections = [
      _PieSection(
        label: 'Students',
        value: studentCount,
        color: const Color(0xFF16A34A),
      ),
      _PieSection(
        label: 'Teachers',
        value: teacherCount,
        color: const Color(0xFF2563EB),
      ),
      _PieSection(
        label: 'Admins',
        value: adminCount,
        color: const Color(0xFFF97316),
      ),
    ].where((section) => section.value > 0).toList();
    final highlightCards = [
      _DashboardHighlight(
        title: 'Users',
        value: _users.length.toString(),
        note: '$inactiveCount inactive accounts',
        icon: Icons.groups_2_rounded,
        color: const Color(0xFF2563EB),
      ),
      _DashboardHighlight(
        title: 'Classes',
        value: _classes.length.toString(),
        note: '$unassignedClasses awaiting class teachers',
        icon: Icons.meeting_room_rounded,
        color: const Color(0xFF14B8A6),
      ),
      _DashboardHighlight(
        title: 'Timetable',
        value: _timetableEntries.toString(),
        note: 'Scheduled teaching blocks',
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF7C3AED),
      ),
      _DashboardHighlight(
        title: 'Security',
        value: pendingPasswordChanges.toString(),
        note: 'Accounts pending password change',
        icon: Icons.verified_user_outlined,
        color: const Color(0xFFF97316),
      ),
    ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _StateCard(
                        icon: Icons.error_outline_rounded,
                        title: 'Dashboard unavailable',
                        message: _error!,
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _AdminHeroCard(
                        totalUsers: _users.length,
                        classCount: _classes.length,
                        timetableEntries: _timetableEntries,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 184,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: highlightCards.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            return SizedBox(
                              width: 188,
                              child: _HighlightCard(
                                data: highlightCards[index],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SectionTitle(
                        title: 'School Health',
                        subtitle:
                            'A quick view of user distribution and staffing coverage.',
                      ),
                      const SizedBox(height: 10),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              _OverviewPieCard(
                                sections: chartSections,
                                total: _users.length,
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _MetricChip(
                                    label: 'Teachers',
                                    value: teacherCount.toString(),
                                  ),
                                  _MetricChip(
                                    label: 'Students',
                                    value: studentCount.toString(),
                                  ),
                                  _MetricChip(
                                    label: 'Admins',
                                    value: adminCount.toString(),
                                  ),
                                  _MetricChip(
                                    label: 'Inactive',
                                    value: inactiveCount.toString(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SectionTitle(
                        title: 'Management Areas',
                        subtitle:
                            'Jump into the systems admins use most often.',
                      ),
                      const SizedBox(height: 10),
                      _AdminActionCard(
                        title: 'User Control Center',
                        subtitle:
                            'Create accounts, adjust roles, reset passwords, and activate users',
                        icon: Icons.manage_accounts_rounded,
                        color: const Color(0xFF7C3AED),
                        onTap: () =>
                            Navigator.pushNamed(context, '/admin/users'),
                      ),
                      _AdminActionCard(
                        title: 'Class Operations',
                        subtitle:
                            'Create classes and manage student and teacher assignments',
                        icon: Icons.class_rounded,
                        color: const Color(0xFF14B8A6),
                        onTap: () =>
                            Navigator.pushNamed(context, '/admin/classes'),
                      ),
                      _AdminActionCard(
                        title: 'Timetable Planner',
                        subtitle:
                            'Review and update schedules by class, day, and period',
                        icon: Icons.calendar_month_rounded,
                        color: const Color(0xFF2563EB),
                        onTap: () => Navigator.pushNamed(context, '/timetable'),
                      ),
                      const SizedBox(height: 20),
                      _SectionTitle(
                        title: 'Operational Notes',
                        subtitle:
                            'Current issues that may need admin attention.',
                      ),
                      const SizedBox(height: 10),
                      _StatusLineCard(
                        title: pendingPasswordChanges == 0
                            ? 'Credential updates are clear'
                            : 'Credential changes pending',
                        description: pendingPasswordChanges == 0
                            ? 'Every active user has already rotated their initial password.'
                            : '$pendingPasswordChanges account(s) still need to change their password.',
                        tone: pendingPasswordChanges == 0
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFF59E0B),
                        icon: pendingPasswordChanges == 0
                            ? Icons.verified_rounded
                            : Icons.lock_clock_outlined,
                      ),
                      const SizedBox(height: 10),
                      _StatusLineCard(
                        title: _classes.isEmpty
                            ? 'Class setup has not started'
                            : 'Class staffing snapshot',
                        description: _classes.isEmpty
                            ? 'No classes are configured yet.'
                            : unassignedClasses == 0
                            ? 'Every class has an assigned class teacher.'
                            : '$unassignedClasses class(es) still need a class teacher.',
                        tone: _classes.isEmpty || unassignedClasses > 0
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF16A34A),
                        icon: _classes.isEmpty || unassignedClasses > 0
                            ? Icons.assignment_late_outlined
                            : Icons.fact_check_rounded,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ValueListenableBuilder<ThemeMode>(
                          valueListenable: ThemeService.themeMode,
                          builder: (context, mode, _) {
                            final icon = switch (mode) {
                              ThemeMode.system => Icons.brightness_auto_rounded,
                              ThemeMode.dark => Icons.light_mode_rounded,
                              ThemeMode.light => Icons.dark_mode_rounded,
                            };
                            final label = switch (mode) {
                              ThemeMode.system => 'Use Dark Mode',
                              ThemeMode.dark => 'Use Light Mode',
                              ThemeMode.light => 'Use Auto Mode',
                            };
                            return OutlinedButton.icon(
                              onPressed: ThemeService.toggle,
                              icon: Icon(icon),
                              label: Text(label),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _DashboardHighlight {
  const _DashboardHighlight({
    required this.title,
    required this.value,
    required this.note,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String note;
  final IconData icon;
  final Color color;
}

class _AdminUser {
  _AdminUser({
    required this.role,
    required this.mustChangePassword,
    required this.isActive,
  });

  final String role;
  final bool mustChangePassword;
  final bool isActive;

  factory _AdminUser.fromJson(Map<String, dynamic> json) {
    return _AdminUser(
      role: json['role'] as String,
      mustChangePassword: json['must_change_password'] == true,
      isActive: json['is_active'] != false,
    );
  }
}

class _AdminClass {
  _AdminClass({required this.classTeacherName});

  final String? classTeacherName;

  factory _AdminClass.fromJson(Map<String, dynamic> json) {
    return _AdminClass(classTeacherName: json['class_teacher_name'] as String?);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ],
      ],
    );
  }
}

class _AdminHeroCard extends StatelessWidget {
  const _AdminHeroCard({
    required this.totalUsers,
    required this.classCount,
    required this.timetableEntries,
  });

  final int totalUsers;
  final int classCount;
  final int timetableEntries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8), Color(0xFF14B8A6)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Admin Command',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Run the school from one place.',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track people, classes, and schedules with a cleaner operational dashboard.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.84),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _HeroStatPill(label: 'Users', value: '$totalUsers'),
                _HeroStatPill(label: 'Classes', value: '$classCount'),
                _HeroStatPill(label: 'Periods', value: '$timetableEntries'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStatPill extends StatelessWidget {
  const _HeroStatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white),
          children: [
            TextSpan(
              text: '$value\n',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(text: label),
          ],
        ),
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.data});

  final _DashboardHighlight data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.1),
        border: Border.all(color: data.color.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: data.color.withValues(alpha: 0.16),
            child: Icon(data.icon, color: data.color),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  data.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.68),
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

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$value\n',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: label),
          ],
        ),
      ),
    );
  }
}

class _PieSection {
  const _PieSection({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

class _OverviewPieCard extends StatelessWidget {
  const _OverviewPieCard({required this.sections, required this.total});

  final List<_PieSection> sections;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty || total == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('No user data available yet.'),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 148,
            height: 148,
            child: CustomPaint(
              painter: _PieChartPainter(
                sections: sections,
                dividerColor: Theme.of(context).colorScheme.surface,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      total.toString(),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text('Users', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sections
                  .map(
                    (section) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: section.color,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(section.label)),
                          Text(
                            '${section.value}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  const _PieChartPainter({required this.sections, required this.dividerColor});

  final List<_PieSection> sections;
  final Color dividerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final total = sections.fold<int>(0, (sum, section) => sum + section.value);
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = dividerColor;
    var startAngle = -math.pi / 2;
    for (final section in sections) {
      final sweep = (section.value / total) * math.pi * 2;
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = section.color;
      canvas.drawArc(rect, startAngle, sweep, true, fillPaint);
      canvas.drawArc(rect, startAngle, sweep, true, strokePaint);
      startAngle += sweep;
    }

    final holePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = dividerColor.withValues(alpha: 0.9);
    canvas.drawCircle(center, radius * 0.52, holePaint);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.sections != sections ||
        oldDelegate.dividerColor != dividerColor;
  }
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.arrow_forward_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusLineCard extends StatelessWidget {
  const _StatusLineCard({
    required this.title,
    required this.description,
    required this.tone,
    required this.icon,
  });

  final String title;
  final String description;
  final Color tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: tone.withValues(alpha: 0.14),
              child: Icon(icon, color: tone),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
      ),
    );
  }
}

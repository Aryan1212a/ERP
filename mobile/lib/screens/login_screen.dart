import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/service_locator.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  static const _rememberKey = AuthService.rememberKey;
  static const _rememberEmailKey = AuthService.rememberEmailKey;
  static const _rememberPasswordKey = AuthService.rememberPasswordKey;

  final _identifier = TextEditingController();
  final _password = TextEditingController();
  late final AnimationController _introController;
  late final AnimationController _floatController;
  late final Animation<double> _panelSlide;
  late final Animation<double> _panelFade;

  bool _loading = false;
  String? _error;
  bool _obscure = true;
  bool _rememberLogin = false;
  bool _attemptingAutoLogin = false;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _panelSlide = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOutCubic,
    );
    _panelFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.15, 1, curve: Curves.easeOut),
    );
    _introController.forward();
    _loadRemembered();
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _introController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _loadRemembered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool(_rememberKey) ?? false;
      if (!remember) return;
      final email = prefs.getString(_rememberEmailKey) ?? '';
      final password = prefs.getString(_rememberPasswordKey) ?? '';
      if (!mounted) return;
      setState(() {
        _rememberLogin = true;
        _identifier.text = email;
        _password.text = password;
      });
      if (email.isNotEmpty && password.isNotEmpty) {
        await _autoLogin();
      }
    } catch (_) {
      // Keep login available even if persistence fails.
    }
  }

  Future<void> _persistRemembered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_rememberKey, _rememberLogin);
      if (_rememberLogin) {
        await prefs.setString(_rememberEmailKey, _identifier.text.trim());
        await prefs.setString(_rememberPasswordKey, _password.text);
        return;
      }
      await prefs.remove(_rememberEmailKey);
      await prefs.remove(_rememberPasswordKey);
    } catch (_) {
      // Ignore local storage failures and continue sign-in flow.
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final role = await Services.auth.login(
      _identifier.text.trim(),
      _password.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (role != null) {
      await _persistRemembered();
      _navigateAfterLogin(role);
    } else {
      setState(() => _error = 'Invalid username/email or password');
    }
  }

  Future<void> _autoLogin() async {
    if (_attemptingAutoLogin) return;
    setState(() {
      _attemptingAutoLogin = true;
      _loading = true;
      _error = null;
    });
    final role = await Services.auth.login(
      _identifier.text.trim(),
      _password.text,
    );
    if (!mounted) return;
    setState(() {
      _attemptingAutoLogin = false;
      _loading = false;
    });
    if (role != null) {
      _navigateAfterLogin(role);
    }
  }

  void _navigateAfterLogin(String role) {
    if (Services.auth.mustChangePassword) {
      Navigator.pushReplacementNamed(context, '/auth/change-password');
      return;
    }
    final route = switch (role) {
      'admin' => '/dashboard/admin',
      'teacher' => '/dashboard/teacher',
      'student' => '/dashboard/student',
      _ => '/dashboard',
    };
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _LoginPalette.of(context);

    return Scaffold(
      backgroundColor: palette.scaffold,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              return _LoginBackground(
                progress: _floatController.value,
                palette: palette,
              );
            },
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 920;
                final isMobile = constraints.maxWidth < 680;
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 40 : (isMobile ? 16 : 20),
                    vertical: isDesktop ? 28 : (isMobile ? 12 : 20),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - (isDesktop ? 56 : 24),
                    ),
                    child: isDesktop
                        ? Row(
                            children: [
                              Expanded(child: _buildHero(palette: palette)),
                              const SizedBox(width: 36),
                              SizedBox(
                                width: 430,
                                child: _buildLoginCard(
                                  palette: palette,
                                  isMobile: false,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHero(
                                compact: true,
                                mobile: isMobile,
                                palette: palette,
                              ),
                              SizedBox(height: isMobile ? 18 : 24),
                              _buildLoginCard(
                                palette: palette,
                                isMobile: isMobile,
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero({
    bool compact = false,
    bool mobile = false,
    required _LoginPalette palette,
  }) {
    final titleStyle = GoogleFonts.spaceGrotesk(
      fontSize: mobile ? 30 : (compact ? 34 : 56),
      fontWeight: FontWeight.w700,
      height: 0.95,
      color: palette.heroTitle,
      letterSpacing: -1.2,
    );

    return FadeTransition(
      opacity: _panelFade,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-0.08, 0.04),
          end: Offset.zero,
        ).animate(_panelSlide),
        child: Align(
          alignment: compact ? Alignment.centerLeft : Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: mobile ? double.infinity : 520),
            child: Column(
              mainAxisAlignment: compact ? MainAxisAlignment.start : MainAxisAlignment.center,
              crossAxisAlignment: mobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: mobile ? 14 : 18,
                    vertical: mobile ? 12 : 14,
                  ),
                  decoration: BoxDecoration(
                    color: palette.pillBackground,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: palette.pillBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/branding/acadian_app_icon.png',
                          width: mobile ? 42 : 52,
                          height: mobile ? 42 : 52,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(width: mobile ? 12 : 14),
                      Column(
                        crossAxisAlignment:
                            mobile ? CrossAxisAlignment.start : CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Acadian',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: mobile ? 24 : 28,
                              fontWeight: FontWeight.w700,
                              color: palette.heroTitle,
                              letterSpacing: -0.6,
                            ),
                          ),
                          Text(
                            'ERP Platform',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.6,
                              color: palette.heroTag,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: mobile ? 18 : 26),
                Text(
                  mobile ? 'Welcome Back' : 'Welcome Back',
                  style: titleStyle,
                  textAlign: mobile ? TextAlign.center : TextAlign.start,
                ),
                SizedBox(height: mobile ? 12 : 18),
                Text(
                  mobile
                      ? 'Sign in to manage academics, attendance, notices, fees, and day-to-day campus workflows from your phone.'
                      : 'Manage operations across students, staff, academics, attendance, notices, fees, and institutional workflows from one production-ready platform.',
                  style: GoogleFonts.dmSans(
                    fontSize: mobile ? 14 : (compact ? 15 : 17),
                    height: 1.6,
                    color: palette.heroBody,
                  ),
                  textAlign: mobile ? TextAlign.center : TextAlign.start,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard({
    required _LoginPalette palette,
    required bool isMobile,
  }) {
    return FadeTransition(
      opacity: _panelFade,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.08, 0.04),
          end: Offset.zero,
        ).animate(_panelSlide),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isMobile ? 28 : 32),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: isMobile ? 14 : 18,
              sigmaY: isMobile ? 14 : 18,
            ),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 18 : 24),
              decoration: BoxDecoration(
                color: palette.cardBackground,
                borderRadius: BorderRadius.circular(isMobile ? 28 : 32),
                border: Border.all(color: palette.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: palette.cardShadow,
                    blurRadius: isMobile ? 28 : 40,
                    offset: Offset(0, isMobile ? 16 : 24),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sign In',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: isMobile ? 26 : 30,
                      fontWeight: FontWeight.w700,
                      color: palette.cardTitle,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use your registered username or email to continue.',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      height: 1.5,
                      color: palette.cardBody,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _ModernField(
                    controller: _identifier,
                    label: 'Username or Email',
                    hint: 'Enter your username or email',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 14),
                  _ModernField(
                    controller: _password,
                    label: 'Password',
                    hint: 'Enter your password',
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (_loading) return;
                      _submit();
                    },
                    icon: Icons.lock_outline_rounded,
                    trailing: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: const Color(0xFF4B5F75),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 340;
                      final remember = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.translate(
                            offset: const Offset(-10, 0),
                            child: Checkbox(
                              value: _rememberLogin,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              onChanged: (value) {
                                setState(() => _rememberLogin = value ?? false);
                              },
                            ),
                          ),
                          Flexible(
                            child: Text(
                              'Remember me',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: palette.cardMuted,
                              ),
                            ),
                          ),
                        ],
                      );
                      final forgot = TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            color: palette.action,
                          ),
                        ),
                      );
                      if (narrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            remember,
                            const SizedBox(height: 2),
                            forgot,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: remember),
                          forgot,
                        ],
                      );
                    },
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: _error == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: palette.errorBackground,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: palette.errorBorder),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    color: palette.errorText,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: GoogleFonts.dmSans(
                                        color: palette.errorText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  SizedBox(
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: palette.buttonGradient,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: palette.buttonShadow,
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Continue',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Student login uses the registered account credentials from the ERP.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      height: 1.5,
                      color: palette.cardMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground({
    required this.progress,
    required this.palette,
  });

  final double progress;
  final _LoginPalette palette;

  @override
  Widget build(BuildContext context) {
    final drift = (progress - 0.5) * 36;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.backgroundGradient,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -70 + drift,
            left: -20,
            child: _GlowOrb(
              size: 230,
              color: palette.orbPrimary,
            ),
          ),
          Positioned(
            top: 120 - drift,
            right: -40,
            child: _GlowOrb(
              size: 260,
              color: palette.orbSecondary,
            ),
          ),
          Positioned(
            bottom: -90 + drift,
            left: 30,
            child: _GlowOrb(
              size: 220,
              color: palette.orbAccent,
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(
                lineColor: palette.gridLine,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernField extends StatelessWidget {
  const _ModernField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.trailing,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? trailing;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final fieldPalette = _LoginPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: fieldPalette.fieldLabel,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dmSans(
              color: fieldPalette.fieldHint,
            ),
            prefixIcon: Icon(icon, color: fieldPalette.fieldIcon),
            suffixIcon: trailing,
            filled: true,
            fillColor: fieldPalette.fieldFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: fieldPalette.fieldBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: fieldPalette.action,
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginPalette {
  const _LoginPalette({
    required this.scaffold,
    required this.backgroundGradient,
    required this.orbPrimary,
    required this.orbSecondary,
    required this.orbAccent,
    required this.gridLine,
    required this.heroTitle,
    required this.heroBody,
    required this.heroTag,
    required this.pillBackground,
    required this.pillBorder,
    required this.cardBackground,
    required this.cardBorder,
    required this.cardShadow,
    required this.cardTitle,
    required this.cardBody,
    required this.cardMuted,
    required this.action,
    required this.buttonGradient,
    required this.buttonShadow,
    required this.fieldLabel,
    required this.fieldHint,
    required this.fieldIcon,
    required this.fieldFill,
    required this.fieldBorder,
    required this.errorBackground,
    required this.errorBorder,
    required this.errorText,
  });

  final Color scaffold;
  final List<Color> backgroundGradient;
  final Color orbPrimary;
  final Color orbSecondary;
  final Color orbAccent;
  final Color gridLine;
  final Color heroTitle;
  final Color heroBody;
  final Color heroTag;
  final Color pillBackground;
  final Color pillBorder;
  final Color cardBackground;
  final Color cardBorder;
  final Color cardShadow;
  final Color cardTitle;
  final Color cardBody;
  final Color cardMuted;
  final Color action;
  final List<Color> buttonGradient;
  final Color buttonShadow;
  final Color fieldLabel;
  final Color fieldHint;
  final Color fieldIcon;
  final Color fieldFill;
  final Color fieldBorder;
  final Color errorBackground;
  final Color errorBorder;
  final Color errorText;

  static _LoginPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const _LoginPalette(
            scaffold: Color(0xFF08111D),
            backgroundGradient: [
              Color(0xFF08111D),
              Color(0xFF0E1726),
              Color(0xFF111B2E),
            ],
            orbPrimary: Color(0xFF4F46E5),
            orbSecondary: Color(0xFF0891B2),
            orbAccent: Color(0xFFF59E0B),
            gridLine: Color(0x1FFFFFFF),
            heroTitle: Color(0xFFF5F7FB),
            heroBody: Color(0xFFAFBDD2),
            heroTag: Color(0xFFD6E7FF),
            pillBackground: Color(0x263C5D84),
            pillBorder: Color(0x335E7EA8),
            cardBackground: Color(0xCC111C2A),
            cardBorder: Color(0x3387A4C5),
            cardShadow: Color(0x66000000),
            cardTitle: Color(0xFFF7FAFC),
            cardBody: Color(0xFFAEBFD3),
            cardMuted: Color(0xFF95A7BD),
            action: Color(0xFF9BA8FF),
            buttonGradient: [Color(0xFF6D5EF9), Color(0xFF3B82F6)],
            buttonShadow: Color(0x554A5DFF),
            fieldLabel: Color(0xFFE5EDF7),
            fieldHint: Color(0xFF7F92A8),
            fieldIcon: Color(0xFF9AAEC3),
            fieldFill: Color(0xFF162334),
            fieldBorder: Color(0xFF24384E),
            errorBackground: Color(0xFF34161D),
            errorBorder: Color(0xFF6B2734),
            errorText: Color(0xFFFF9AA8),
          )
        : const _LoginPalette(
            scaffold: Color(0xFFF4F7FB),
            backgroundGradient: [
              Color(0xFFF6F4FF),
              Color(0xFFEAF4FF),
              Color(0xFFFFFBF3),
            ],
            orbPrimary: Color(0xFF8E7DFF),
            orbSecondary: Color(0xFF5FC0FF),
            orbAccent: Color(0xFFFFB86B),
            gridLine: Color(0x223F5E7A),
            heroTitle: Color(0xFF16314F),
            heroBody: Color(0xFF35516D),
            heroTag: Color(0xFF345B84),
            pillBackground: Color(0xA6FFFFFF),
            pillBorder: Color(0xD9FFFFFF),
            cardBackground: Color(0xB8FFFFFF),
            cardBorder: Color(0xD9FFFFFF),
            cardShadow: Color(0x1A22466A),
            cardTitle: Color(0xFF10263B),
            cardBody: Color(0xFF51667C),
            cardMuted: Color(0xFF6C7B8A),
            action: Color(0xFF5C4DFF),
            buttonGradient: [Color(0xFF7B61FF), Color(0xFF5B7CFF)],
            buttonShadow: Color(0x337B61FF),
            fieldLabel: Color(0xFF17314D),
            fieldHint: Color(0xFF90A0B0),
            fieldIcon: Color(0xFF54697D),
            fieldFill: Color(0xE6FFFFFF),
            fieldBorder: Color(0xFFD9E4EF),
            errorBackground: Color(0xFFFFF1F1),
            errorBorder: Color(0xFFFFD0D0),
            errorText: Color(0xFFB6364A),
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
        color: color.withValues(alpha: 0.22),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.26),
            blurRadius: 90,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.lineColor});

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;

    const gap = 48.0;
    for (double dx = 0; dx < size.width; dx += gap) {
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
    }
    for (double dy = 0; dy < size.height; dy += gap) {
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}

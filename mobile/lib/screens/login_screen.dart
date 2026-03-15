import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/service_locator.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _rememberKey = AuthService.rememberKey;
  static const _rememberEmailKey = AuthService.rememberEmailKey;
  static const _rememberPasswordKey = AuthService.rememberPasswordKey;

  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;
  bool _rememberLogin = false;
  bool _attemptingAutoLogin = false;

  @override
  void initState() {
    super.initState();
    _loadRemembered();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
        _email.text = email;
        _password.text = password;
      });
      if (email.isNotEmpty && password.isNotEmpty) {
        await _autoLogin();
      }
    } catch (_) {
      // Ignore storage issues and keep login usable.
    }
  }

  Future<void> _persistRemembered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_rememberKey, _rememberLogin);
      if (_rememberLogin) {
        await prefs.setString(_rememberEmailKey, _email.text.trim());
        await prefs.setString(_rememberPasswordKey, _password.text);
        return;
      }
      await prefs.remove(_rememberEmailKey);
      await prefs.remove(_rememberPasswordKey);
    } catch (_) {
      // Ignore storage issues and continue login flow.
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final role = await Services.auth.login(_email.text, _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (role != null) {
      await _persistRemembered();
      _navigateAfterLogin(role);
    } else {
      setState(() => _error = 'Invalid credentials');
    }
  }

  Future<void> _autoLogin() async {
    if (_attemptingAutoLogin) return;
    setState(() {
      _attemptingAutoLogin = true;
      _loading = true;
      _error = null;
    });
    final role = await Services.auth.login(_email.text, _password.text);
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
    final theme = Theme.of(context);
    final baseUrl = Services.api.baseUrl;
    return Scaffold(
      body: Stack(
        children: [
          const _LoginBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 16),
                Text(
                  'Welcome back',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign in to your School ERP account',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'name@school.edu',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _password,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        CheckboxListTile(
                          value: _rememberLogin,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('Remember me'),
                          onChanged: (value) {
                            setState(() => _rememberLogin = value ?? false);
                          },
                        ),
                        const SizedBox(height: 12),
                        if (_error != null)
                          Text(
                            _error!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Sign in'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'API: $baseUrl',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 18),
                _HelpRow(
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? const [Color(0xFF0B1120), Color(0xFF0F172A), Color(0xFF111827)]
        : const [Color(0xFFF8FAFC), Color(0xFFE2E8F0), Color(0xFFF8FAFC)];
    final bubbleA = isDark ? const Color(0xFF38BDF8) : const Color(0xFF3B82F6);
    final bubbleB = isDark ? const Color(0xFF8B5CF6) : const Color(0xFF6366F1);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -50,
            child: _BlurBubble(color: bubbleA, size: 220),
          ),
          Positioned(
            bottom: -90,
            left: -60,
            child: _BlurBubble(color: bubbleB, size: 240),
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

class _HelpRow extends StatelessWidget {
  const _HelpRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Need help signing in?',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        TextButton(
          onPressed: onTap,
          child: const Text('Contact admin'),
        ),
      ],
    );
  }
}

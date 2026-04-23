import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class AuthService {
  AuthService(this.client);
  final ApiClient client;
  String? role;
  int? userId;
  bool mustChangePassword = false;
  String? lastErrorMessage;

  static const rememberKey = 'remember_login';
  static const rememberEmailKey = 'remember_login_email';
  static const sessionTokenKey = 'session_token';
  static const sessionRoleKey = 'session_role';
  static const sessionUserIdKey = 'session_user_id';
  static const sessionMustChangePasswordKey = 'session_must_change_password';

  bool get hasSession => client.token != null && role != null;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(sessionTokenKey);
      if (token == null || token.isEmpty) {
        return;
      }
      client.token = token;
      role = prefs.getString(sessionRoleKey);
      userId = prefs.getInt(sessionUserIdKey);
      mustChangePassword = prefs.getBool(sessionMustChangePasswordKey) ?? false;
    } catch (_) {
      client.token = null;
      role = null;
      userId = null;
      mustChangePassword = false;
    }
  }

  Future<String?> login(String email, String password) async {
    lastErrorMessage = null;
    final res = await client.post('/api/v1/auth/login', {
      'email': email,
      'password': password,
    });
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      client.token = data['access_token'];
      role = data['role'];
      userId = data['user_id'];
      mustChangePassword = data['must_change_password'] == true;
      await _persistSession();
      return role;
    }
    lastErrorMessage = client.extractError(res);
    return null;
  }

  Future<bool> validateSession() async {
    if (client.token == null) {
      return false;
    }
    try {
      final res = await client.get('/api/v1/me');
      if (res.statusCode != 200) {
        await clearSession();
        return false;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      role = data['role'] as String?;
      userId = data['id'] as int?;
      mustChangePassword = data['must_change_password'] == true;
      await _persistSession();
      return true;
    } catch (_) {
      await clearSession();
      return false;
    }
  }

  Future<void> _persistSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (client.token != null) {
        await prefs.setString(sessionTokenKey, client.token!);
      }
      if (role != null) {
        await prefs.setString(sessionRoleKey, role!);
      }
      if (userId != null) {
        await prefs.setInt(sessionUserIdKey, userId!);
      }
      await prefs.setBool(sessionMustChangePasswordKey, mustChangePassword);
    } catch (_) {
      // Keep the active session in memory even if persistence fails.
    }
  }

  Future<void> clearSession() async {
    client.token = null;
    role = null;
    userId = null;
    mustChangePassword = false;
    lastErrorMessage = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(sessionTokenKey);
      await prefs.remove(sessionRoleKey);
      await prefs.remove(sessionUserIdKey);
      await prefs.remove(sessionMustChangePasswordKey);
    } catch (_) {
      // Ignore persistence issues while clearing session.
    }
  }

  Future<void> logout({bool clearRememberedLogin = true}) async {
    await clearSession();
    if (!clearRememberedLogin) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(rememberKey, false);
      await prefs.remove(rememberEmailKey);
    } catch (_) {
      // Ignore storage issues during logout.
    }
  }
}

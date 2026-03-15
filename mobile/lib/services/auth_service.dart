import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class AuthService {
  AuthService(this.client);
  final ApiClient client;
  String? role;
  int? userId;
  bool mustChangePassword = false;

  static const rememberKey = 'remember_login';
  static const rememberEmailKey = 'remember_login_email';
  static const rememberPasswordKey = 'remember_login_password';

  Future<String?> login(String email, String password) async {
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
      return role;
    }
    return null;
  }

  Future<void> logout({bool clearRememberedLogin = true}) async {
    client.token = null;
    role = null;
    userId = null;
    mustChangePassword = false;
    if (!clearRememberedLogin) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(rememberKey, false);
      await prefs.remove(rememberEmailKey);
      await prefs.remove(rememberPasswordKey);
    } catch (_) {
      // Ignore storage issues during logout.
    }
  }
}

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(String baseUrl)
    : baseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
  final String baseUrl;
  String? token;
  static const Duration _timeout = Duration(seconds: 15);

  Map<String, String> _headers() {
    final headers = {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> get(String path) {
    return http
        .get(Uri.parse('$baseUrl$path'), headers: _headers())
        .timeout(_timeout);
  }

  Future<http.Response> post(String path, Map<String, dynamic> body) {
    return http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
      body: jsonEncode(body),
    ).timeout(_timeout);
  }

  Future<http.Response> put(String path, Map<String, dynamic> body) {
    return http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
      body: jsonEncode(body),
    ).timeout(_timeout);
  }

  Future<http.Response> delete(String path) {
    return http
        .delete(Uri.parse('$baseUrl$path'), headers: _headers())
        .timeout(_timeout);
  }

  String extractError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
        final error = data['error'];
        if (error is String && error.isNotEmpty) {
          return error;
        }
      }
    } catch (_) {
      // Fall back to generic message if the backend response is not JSON.
    }
    return 'Request failed (${response.statusCode})';
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient(this.baseUrl);
  final String baseUrl;
  String? token;

  Map<String, String> _headers() {
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> get(String path) {
    return http.get(Uri.parse('$baseUrl$path'), headers: _headers());
  }

  Future<http.Response> post(String path, Map<String, dynamic> body) {
    return http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
  }

  Future<http.Response> put(String path, Map<String, dynamic> body) {
    return http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
  }
}

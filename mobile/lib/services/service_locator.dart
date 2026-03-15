import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'auth_service.dart';

String _defaultBaseUrl() {
  if (kIsWeb) return 'http://127.0.0.1:8000';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'http://10.0.2.2:8000';
    default:
      return 'http://127.0.0.1:8000';
  }
}

class Services {
  static final String _envBaseUrl = const String.fromEnvironment('API_BASE_URL');
  static final ApiClient api = ApiClient(
    _envBaseUrl.isNotEmpty ? _envBaseUrl : _defaultBaseUrl(),
  );
  static final AuthService auth = AuthService(api);
}

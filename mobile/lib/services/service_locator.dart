import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'auth_service.dart';

const String _defaultRemoteBaseUrl =
    'https://bronzy-undissonantly-madelene.ngrok-free.dev';

String _defaultBaseUrl() {
  if (kIsWeb) return _defaultRemoteBaseUrl;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return _defaultRemoteBaseUrl;
    default:
      return _defaultRemoteBaseUrl;
  }
}

class Services {
  static final String _envBaseUrl = const String.fromEnvironment('API_BASE_URL');
  static final ApiClient api = ApiClient(
    _envBaseUrl.isNotEmpty ? _envBaseUrl : _defaultBaseUrl(),
  );
  static final AuthService auth = AuthService(api);
}

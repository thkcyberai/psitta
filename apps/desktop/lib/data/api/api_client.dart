import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import '../../core/constants.dart';
import '../services/auth_service.dart';

/// Psitta API client — centralized HTTP layer.
///
/// All API calls go through this client. Handles:
/// - Base URL configuration
/// - Request/response timeouts
/// - Auth token injection from secure storage (falls back to dev bypass)
/// - Error interceptor for consistent error handling
class ApiClient {
  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: AppConstants.httpTimeout,
      receiveTimeout: AppConstants.httpTimeout,
      headers: {
        'Accept': 'application/json',
      },
    ));

    // Inject auth token on every request.
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _authService.getAccessToken();
        options.headers['Authorization'] =
            'Bearer ${token ?? 'dev-bypass-token'}';
        handler.next(options);
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (msg) => developer.log('$msg', name: 'API'),
    ));
  }

  final AuthService _authService = AuthService();
  late final Dio _dio;

  Dio get dio => _dio;

  /// Set auth token for authenticated requests.
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }
}

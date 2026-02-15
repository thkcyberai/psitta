import 'package:dio/dio.dart';
import '../../core/constants.dart';

/// Psitta API client — centralized HTTP layer.
///
/// All API calls go through this client. Handles:
/// - Base URL configuration
/// - Request/response timeouts
/// - Auth token injection (TODO: wire to auth provider)
/// - Error interceptor for consistent error handling
class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: AppConstants.httpTimeout,
      receiveTimeout: AppConstants.httpTimeout,
      headers: {
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (msg) => print('[API] $msg'), // TODO: Use proper logger
    ));
  }

  Dio get dio => _dio;

  /// Set auth token for authenticated requests.
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }
}

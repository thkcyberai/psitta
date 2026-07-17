import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import '../../core/app_version.dart';
import '../../core/constants.dart';
import '../services/auth_service.dart';

/// Psitta API client — centralized HTTP layer.
///
/// All API calls go through this client. Responsibilities:
/// - Base URL configuration
/// - Request/response timeouts
/// - Auth token injection from secure storage (NO fallback to a bypass
///   string — if storage returns null the request is sent without an
///   Authorization header and the backend returns 401; the response
///   interceptor handles refresh+retry and, if that fails,
///   notifies the caller via [onUnauthorized] so the UI can force
///   re-authentication)
/// - One-shot 401 recovery: refresh the access token and retry
class ApiClient {
  /// Constructs an [ApiClient].
  ///
  /// Callers (e.g. the Riverpod [apiClientProvider]) can pass a custom
  /// [authService] to share state with the rest of the app; if omitted,
  /// a new [AuthService] is created. [onUnauthorized] is invoked when a
  /// 401 cannot be recovered from (refresh-token flow failed AND a single
  /// retry of the original request still 401s). The callback typically
  /// invalidates auth-dependent Riverpod providers and routes the user
  /// back to login.
  ApiClient({
    AuthService? authService,
    this.onUnauthorized,
    this.currentLanguage,
  }) : _authService = authService ?? AuthService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: AppConstants.httpTimeout,
      receiveTimeout: AppConstants.httpTimeout,
      headers: {
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      // ── Request: inject the real access token or no header at all ────
      onRequest: (options, handler) async {
        final token = await _authService.getAccessToken();
        if (token == null || token.isEmpty) {
          // No valid token — do NOT send an Authorization header.
          // Backend will return 401; the onError branch below handles
          // refresh+retry and escalation via [onUnauthorized]. Do not
          // forge any bypass string here: the production backend
          // correctly rejects all non-JWT tokens, and forging one would
          // defeat the client-side defence-in-depth that keeps a
          // misconfigured server-side environment flag from becoming a
          // silent auth-bypass.
          options.headers.remove('Authorization');
        } else {
          options.headers['Authorization'] = 'Bearer $token';
        }
        final lang = currentLanguage?.call();
        if (lang != null && lang.isNotEmpty) {
          options.headers['X-Psitta-Language'] = lang;
        }
        // Client-version telemetry + control plane: every request carries the
        // running app version so the backend can observe installed versions
        // (and, with GET /config, enforce a minimum).
        options.headers['X-Client-Version'] = clientVersion;
        handler.next(options);
      },

      // ── Response error: one-shot 401 recovery ────────────────────────
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        final original = error.requestOptions;
        // Sentinel on extra[] prevents unbounded retry loops: if the
        // retried request also 401s, original.extra[_retriedKey] is true
        // so we skip the recovery branch on the second pass.
        final alreadyRetried = original.extra[_retriedKey] == true;
        if (status != 401 || alreadyRetried) {
          handler.next(error);
          return;
        }

        final refreshed = await _authService.refreshAccessToken();
        if (refreshed != null && refreshed.isNotEmpty) {
          original.extra[_retriedKey] = true;
          original.headers['Authorization'] = 'Bearer $refreshed';
          try {
            final retry = await _dio.fetch(original);
            handler.resolve(retry);
            return;
          } catch (retryError) {
            // Retry failed — fall through to escalation. Do not hide
            // the original failure from callers.
          }
        }

        // Refresh impossible or retry still unauthorized — escalate.
        // The callback typically invalidates auth-dependent providers
        // and routes the user to /login. Intentionally fire-and-forget
        // so the Dio error still propagates to the caller.
        try {
          onUnauthorized?.call();
        } catch (_) {
          // A misbehaving callback must not swallow the real error.
        }
        handler.next(error);
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (msg) => developer.log('$msg', name: 'API'),
    ));
  }

  // Extras key for loop-break sentinel on retried requests.
  static const _retriedKey = 'psittaAuthRetry';

  final AuthService _authService;

  /// Invoked when a 401 cannot be recovered via token refresh + retry.
  /// Callers use this to invalidate auth-dependent providers and force
  /// re-authentication.
  final void Function()? onUnauthorized;

  /// Supplies the writer's current working-language name (e.g. "French") for
  /// the X-Psitta-Language header, so AI features (Summarize, Story-Coach,
  /// Structure Analyzer) reply in that language. Returns null to omit the
  /// header (English default).
  final String? Function()? currentLanguage;

  late final Dio _dio;

  Dio get dio => _dio;

  /// Current Cognito access token, for flows that must pass the Bearer header
  /// themselves (e.g. just_audio streaming sources, which don't go through the
  /// Dio interceptor). Returns null when no valid token is available.
  Future<String?> accessToken() => _authService.getAccessToken();

  /// Manually set the Authorization header (used by specialized flows
  /// that already possess a fresh token). Kept for backward compatibility
  /// with any caller that bypasses the request interceptor.
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }
}

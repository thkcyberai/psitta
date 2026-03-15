import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

// ── Auth0 Configuration ──────────────────────────────────────────────
const auth0Domain = 'dev-8wmplwcxsoyhlcw1.us.auth0.com';
const auth0ClientId = 'o4YisrJYWrsPMSiNZ6o2yuUpn0lgulyh';
const auth0Audience = 'https://api.psitta.app';
const auth0RedirectUri = 'http://localhost:8080/callback';
const auth0Scopes = 'openid profile email offline_access';

// ── Secure Storage Keys ──────────────────────────────────────────────
const _accessTokenKey = 'access_token';
const _idTokenKey = 'id_token';
const _refreshTokenKey = 'refresh_token';

/// Manages Auth0 authentication for Windows desktop.
///
/// The login UI is handled by an embedded WebView (see LoginScreen).
/// This service provides PKCE helpers, token exchange, session restore,
/// logout, and token access.
class AuthService {
  AuthService() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  // ── PKCE Helpers (public — used by LoginScreen) ────────────────────

  /// Generate a cryptographically random string for PKCE code_verifier.
  static String generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// Derive the S256 code_challenge from a code_verifier.
  static String generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// Generate a random state string for CSRF protection.
  static String generateState() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// Build the Auth0 /authorize URL with PKCE parameters.
  static Uri buildAuthorizeUrl({
    required String codeChallenge,
    required String state,
  }) {
    return Uri.https(auth0Domain, '/authorize', {
      'response_type': 'code',
      'client_id': auth0ClientId,
      'redirect_uri': auth0RedirectUri,
      'scope': auth0Scopes,
      'audience': auth0Audience,
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    });
  }

  // ── Token Exchange ─────────────────────────────────────────────────

  /// Exchange an authorization code for tokens.
  ///
  /// Called by LoginScreen after the WebView intercepts the callback URL.
  /// Validates the returned state, then POSTs to Auth0 /oauth/token.
  Future<void> exchangeCodeForTokens({
    required String code,
    required String state,
    required String expectedState,
    required String codeVerifier,
  }) async {
    if (state != expectedState) {
      throw Exception('OAuth state mismatch — possible CSRF attack');
    }

    final dio = Dio();
    try {
      final response = await dio.post(
        'https://$auth0Domain/oauth/token',
        data: {
          'grant_type': 'authorization_code',
          'client_id': auth0ClientId,
          'code': code,
          'redirect_uri': auth0RedirectUri,
          'code_verifier': codeVerifier,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final body = response.data as Map<String, dynamic>;
      final accessToken = body['access_token'] as String?;
      final idToken = body['id_token'] as String?;
      final refreshToken = body['refresh_token'] as String?;

      if (accessToken == null) {
        throw Exception('No access_token in token response');
      }

      await _storage.write(key: _accessTokenKey, value: accessToken);
      if (idToken != null) {
        await _storage.write(key: _idTokenKey, value: idToken);
      }
      if (refreshToken != null) {
        await _storage.write(key: _refreshTokenKey, value: refreshToken);
      }
    } finally {
      dio.close();
    }
  }

  // ── Session Restore ────────────────────────────────────────────────

  /// Attempt to restore a session from stored credentials.
  ///
  /// Returns true if a valid (non-expired) access token exists.
  /// If the access token is expired but a refresh token is available,
  /// attempts a refresh_token grant to get a new access token.
  Future<bool> tryRestoreSession() async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token == null) return false;

    // Token still valid — session restored.
    if (!JwtDecoder.isExpired(token)) return true;

    // Token expired — try refresh.
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null) {
      await _clearStorage();
      return false;
    }

    try {
      final dio = Dio();
      try {
        final response = await dio.post(
          'https://$auth0Domain/oauth/token',
          data: {
            'grant_type': 'refresh_token',
            'client_id': auth0ClientId,
            'refresh_token': refreshToken,
          },
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
          ),
        );

        final body = response.data as Map<String, dynamic>;
        final newAccessToken = body['access_token'] as String?;
        final newIdToken = body['id_token'] as String?;
        final newRefreshToken = body['refresh_token'] as String?;

        if (newAccessToken == null) {
          await _clearStorage();
          return false;
        }

        await _storage.write(key: _accessTokenKey, value: newAccessToken);
        if (newIdToken != null) {
          await _storage.write(key: _idTokenKey, value: newIdToken);
        }
        if (newRefreshToken != null) {
          await _storage.write(key: _refreshTokenKey, value: newRefreshToken);
        }
        return true;
      } finally {
        dio.close();
      }
    } catch (_) {
      await _clearStorage();
      return false;
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────

  /// Clear stored credentials.
  ///
  /// Navigation to /login is handled by the AuthStateNotifier listener
  /// in the router, so no browser or URL launch is needed here.
  Future<void> logout() async {
    await _clearStorage();
  }

  // ── Token Access ───────────────────────────────────────────────────

  /// Read the current access token from secure storage.
  Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  /// Read the current ID token from secure storage.
  /// Contains user profile claims (name, email, picture).
  Future<String?> getIdToken() async {
    return _storage.read(key: _idTokenKey);
  }

  // ── Helpers ────────────────────────────────────────────────────────

  Future<void> _clearStorage() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _idTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}

// ── Riverpod Providers ───────────────────────────────────────────────

/// Riverpod provider for the auth service singleton.
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Provider that tracks authentication state.
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>(
  (ref) => AuthStateNotifier(ref.read(authServiceProvider)),
);

/// Authentication state.
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({required this.status});

  final AuthStatus status;
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier(this._authService)
      : super(const AuthState(status: AuthStatus.unknown)) {
    _init();
  }

  final AuthService _authService;

  Future<void> _init() async {
    final restored = await _authService.tryRestoreSession();
    state = AuthState(
      status: restored
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
    );
  }

  Future<void> login() async {
    state = const AuthState(status: AuthStatus.authenticated);
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

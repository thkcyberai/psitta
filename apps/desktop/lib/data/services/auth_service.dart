import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

// ── Amazon Cognito Configuration ─────────────────────────────────────
const cognitoRegion     = 'us-east-1';
const cognitoUserPoolId = 'us-east-1_zdbJm5EyI';
const cognitoClientId   = '1mtmn45trougr6oqpr1afhekp4';
const cognitoDomain     = 'psitta-auth-prod.auth.us-east-1.amazoncognito.com';
const cognitoRedirectUri = 'http://localhost:8080/callback';
const cognitoScopes     = 'openid profile email';

// ── Secure Storage Keys ──────────────────────────────────────────────
const _accessTokenKey  = 'access_token';
const _idTokenKey      = 'id_token';
const _refreshTokenKey = 'refresh_token';

/// Manages Amazon Cognito authentication for Windows desktop.
///
/// Uses PKCE authorization code flow via the Cognito Hosted UI.
/// Token exchange and refresh hit Cognito's /oauth2/token endpoint.
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

  /// Build the Cognito /oauth2/authorize URL with PKCE parameters.
  static Uri buildAuthorizeUrl({
    required String codeChallenge,
    required String state,
  }) {
    return Uri.https(cognitoDomain, '/oauth2/authorize', {
      'response_type':         'code',
      'client_id':             cognitoClientId,
      'redirect_uri':          cognitoRedirectUri,
      'scope':                 cognitoScopes,
      'state':                 state,
      'code_challenge':        codeChallenge,
      'code_challenge_method': 'S256',
    });
  }

  // ── Token Exchange ─────────────────────────────────────────────────

  /// Exchange an authorization code for tokens.
  ///
  /// Called by LoginScreen after the WebView intercepts the callback URL.
  /// Validates the returned state, then POSTs to Cognito /oauth2/token.
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
        'https://$cognitoDomain/oauth2/token',
        data: {
          'grant_type':    'authorization_code',
          'client_id':     cognitoClientId,
          'code':          code,
          'redirect_uri':  cognitoRedirectUri,
          'code_verifier': codeVerifier,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final body = response.data as Map<String, dynamic>;
      final accessToken  = body['access_token']  as String?;
      final idToken      = body['id_token']      as String?;
      final refreshToken = body['refresh_token'] as String?;

      if (accessToken == null) {
        throw Exception('No access_token in token response');
      }

      // Debug: log JWT claims to verify issuer, audience, and scope
      try {
        final claims = JwtDecoder.decode(accessToken);
        debugPrint('[AUTH] === ACCESS TOKEN CLAIMS ===');
        debugPrint('[AUTH] iss: ${claims['iss']}');
        debugPrint('[AUTH] aud: ${claims['aud']}');
        debugPrint('[AUTH] client_id: ${claims['client_id']}');
        debugPrint('[AUTH] sub: ${claims['sub']}');
        debugPrint('[AUTH] scope: ${claims['scope']}');
        debugPrint('[AUTH] exp: ${claims['exp']}');
        if (idToken != null) {
          final idClaims = JwtDecoder.decode(idToken);
          debugPrint('[AUTH] === ID TOKEN CLAIMS ===');
          debugPrint('[AUTH] iss: ${idClaims['iss']}');
          debugPrint('[AUTH] name: ${idClaims['name']}');
          debugPrint('[AUTH] email: ${idClaims['email']}');
        }
      } catch (e) {
        debugPrint('[AUTH] JWT decode debug failed: $e');
      }

      await _storage.write(key: _accessTokenKey, value: accessToken);
      if (idToken      != null) await _storage.write(key: _idTokenKey,      value: idToken);
      if (refreshToken != null) await _storage.write(key: _refreshTokenKey, value: refreshToken);
    } finally {
      dio.close();
    }
  }

  // ── Session Restore ────────────────────────────────────────────────

  /// Attempt to restore a session from stored credentials.
  ///
  /// Returns true if a valid (non-expired) access token exists.
  /// If expired but a refresh token is available, attempts refresh.
  Future<bool> tryRestoreSession() async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token == null) return false;

    if (!JwtDecoder.isExpired(token)) return true;

    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null) {
      await _clearStorage();
      return false;
    }

    try {
      final dio = Dio();
      try {
        final response = await dio.post(
          'https://$cognitoDomain/oauth2/token',
          data: {
            'grant_type':    'refresh_token',
            'client_id':     cognitoClientId,
            'refresh_token': refreshToken,
          },
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
          ),
        );

        final body = response.data as Map<String, dynamic>;
        final newAccessToken  = body['access_token']  as String?;
        final newIdToken      = body['id_token']      as String?;
        final newRefreshToken = body['refresh_token'] as String?;

        if (newAccessToken == null) {
          await _clearStorage();
          return false;
        }

        await _storage.write(key: _accessTokenKey, value: newAccessToken);
        if (newIdToken      != null) await _storage.write(key: _idTokenKey,      value: newIdToken);
        if (newRefreshToken != null) await _storage.write(key: _refreshTokenKey, value: newRefreshToken);
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

  /// Clear stored credentials and revoke the refresh token with Cognito.
  Future<void> logout() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken != null) {
      try {
        final dio = Dio();
        await dio.post(
          'https://$cognitoDomain/oauth2/revoke',
          data: {
            'token':     refreshToken,
            'client_id': cognitoClientId,
          },
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
        dio.close();
      } catch (_) {
        // Best-effort revocation — clear local storage regardless
      }
    }
    await _clearStorage();
  }

  // ── Token Access ───────────────────────────────────────────────────

  /// Read the current access token from secure storage.
  Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  /// Read the current ID token from secure storage.
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

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>(
  (ref) => AuthStateNotifier(ref.read(authServiceProvider)),
);

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
      status: restored ? AuthStatus.authenticated : AuthStatus.unauthenticated,
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

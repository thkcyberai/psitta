import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../core/state/now_reading.dart';
import '../../features/shell/widgets/player_bar.dart';
import '../providers/providers.dart';
import 'audio_service.dart';

// Keys used to persist the player-bar "what was I listening to" snapshot
// per user. Kept here rather than in preferences_service because they are
// managed by the auth flow on login/logout, not by a user-facing notifier.
const String _kBaseLastDocIdKey       = 'last_doc_id';
const String _kBaseLastDocTitleKey    = 'last_doc_title';
const String _kBaseLastChunkIndexKey  = 'last_chunk_index';
const String _kBaseLastTotalChunksKey = 'last_total_chunks';

String _userKey(String userId, String baseKey) => 'user_${userId}_$baseKey';

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

    final newAccess = await refreshAccessToken();
    return newAccess != null;
  }

  /// Exchange the stored refresh token for a fresh access token.
  ///
  /// Shared by [tryRestoreSession] (on boot) and the [ApiClient]
  /// response interceptor (on a mid-session 401). Behavior:
  /// - Returns `null` if no refresh token is stored, if Cognito rejects
  ///   the refresh, or on any network/parse error. In every failure
  ///   path, stored tokens are wiped so subsequent [getAccessToken]
  ///   calls also return null and the UI is forced back to login.
  /// - On success, writes the new access_token (plus id_token and
  ///   refresh_token when Cognito rotates them) to secure storage and
  ///   returns the new access_token string.
  ///
  /// Intentionally swallows exceptions: callers must handle null
  /// gracefully. Logging a stacktrace on a routine refresh miss would
  /// spam the console during the normal "access token expired" path.
  Future<String?> refreshAccessToken() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null) {
      await _clearStorage();
      return null;
    }

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
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      final body = response.data as Map<String, dynamic>;
      final newAccessToken  = body['access_token']  as String?;
      final newIdToken      = body['id_token']      as String?;
      final newRefreshToken = body['refresh_token'] as String?;

      if (newAccessToken == null) {
        await _clearStorage();
        return null;
      }

      await _storage.write(key: _accessTokenKey, value: newAccessToken);
      if (newIdToken      != null) await _storage.write(key: _idTokenKey,      value: newIdToken);
      if (newRefreshToken != null) await _storage.write(key: _refreshTokenKey, value: newRefreshToken);
      return newAccessToken;
    } catch (_) {
      await _clearStorage();
      return null;
    } finally {
      dio.close();
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────

  /// Clear stored credentials and revoke the refresh token with Cognito.
  Future<void> logout() async {
    debugPrint('[LOGOUT] logout() called');
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
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            sendTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 3),
          ),
        );
        dio.close();
      } catch (_) {
        // Best-effort revocation — clear local storage regardless
      }
    }

    // Wipe the WebView2 cookie + cache store so the Cognito Hosted UI session
    // cookie is invalidated. All WebviewControllers in this process share the
    // default WebView2 user data folder, so clearing on a throwaway controller
    // also clears the one the LoginScreen will create on next mount —
    // forcing the user to re-enter credentials. Best-effort: never block logout.
    try {
      final webview = WebviewController();
      await webview.initialize();
      await webview.clearCookies();
      await webview.clearCache();
      await webview.dispose();
    } catch (e) {
      debugPrint('[LOGOUT] WebView session clear failed: $e');
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

  /// Decode the Cognito `sub` claim (user id) from the access token.
  /// Returns null if no token is stored or the token is malformed.
  Future<String?> getUserIdFromAccessToken() async {
    final token = await getAccessToken();
    if (token == null) return null;
    try {
      final claims = JwtDecoder.decode(token);
      final sub = claims['sub'];
      return sub is String ? sub : null;
    } catch (_) {
      return null;
    }
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
  (ref) => AuthStateNotifier(ref),
);

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({required this.status, this.userId});
  final AuthStatus status;

  /// Cognito `sub` claim of the authenticated user. Null when
  /// unauthenticated or before tokens have been decoded. All user-scoped
  /// SharedPreferences keys and Riverpod providers are keyed off of this.
  final String? userId;
}

/// Exposes the current user id to any provider that needs to scope state
/// per-account. When this flips, user-scoped preference providers rebuild
/// automatically (they `ref.watch` this), so no manual invalidation is
/// required for them during login/logout transitions.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider.select((s) => s.userId));
});

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier(this._ref)
      : _authService = _ref.read(authServiceProvider),
        super(const AuthState(status: AuthStatus.unknown)) {
    _init();
  }

  final Ref _ref;
  final AuthService _authService;

  Future<void> _init() async {
    final restored = await _authService.tryRestoreSession();
    if (!restored) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    final userId = await _authService.getUserIdFromAccessToken();
    state = AuthState(status: AuthStatus.authenticated, userId: userId);
    await _restoreLastSession(userId);
  }

  Future<void> login() async {
    final userId = await _authService.getUserIdFromAccessToken();
    state = AuthState(status: AuthStatus.authenticated, userId: userId);
    await _restoreLastSession(userId);
  }

  Future<void> logout() async {
    // Grab the user id BEFORE we revoke tokens — we need it to persist
    // the last-session snapshot under the correct scoped keys.
    final previousUserId = state.userId;
    await _saveLastSession(previousUserId);
    await _authService.logout();
    await _clearTransientUserState();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Clear in-memory state that would leak between accounts on the same
  /// device. Does NOT touch user-scoped SharedPreferences keys — those
  /// are the user's saved settings and must survive logout so the same
  /// account restoring on re-login sees their theme/voice/etc. intact.
  ///
  /// Preference notifiers themselves rebuild automatically when
  /// currentUserIdProvider flips to null after the state change below,
  /// so they are NOT invalidated here — the user_id watch handles it.
  Future<void> _clearTransientUserState() async {
    try {
      await _ref.read(audioServiceProvider).clearUserSession();
    } catch (e) {
      debugPrint('[LOGOUT] audio clear failed: $e');
    }

    _ref.invalidate(currentDocTitleProvider);
    _ref.invalidate(activeDocumentIdProvider);
    _ref.invalidate(currentChunkIndexProvider);
    _ref.invalidate(totalChunksProvider);
    _ref.invalidate(activeChunkIdsProvider);
    _ref.invalidate(nowReadingTextProvider);

    _ref.invalidate(showArchivedProvider);
    _ref.invalidate(activeProjectIdProvider);
    _ref.invalidate(isInlineEditingProvider);
  }

  /// Persist the player-bar snapshot so re-login restores exactly what
  /// the user was last listening to. Writes the active doc id + title
  /// + chunk position under the previous user's scoped keys, or clears
  /// them if nothing was playing.
  Future<void> _saveLastSession(String? userId) async {
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final docId = _ref.read(activeDocumentIdProvider);
      final docTitle = _ref.read(currentDocTitleProvider);
      final chunkIndex = _ref.read(currentChunkIndexProvider);
      final totalChunks = _ref.read(totalChunksProvider);

      if (docId != null && docTitle != null) {
        await prefs.setString(_userKey(userId, _kBaseLastDocIdKey), docId);
        await prefs.setString(_userKey(userId, _kBaseLastDocTitleKey), docTitle);
        await prefs.setInt(_userKey(userId, _kBaseLastChunkIndexKey), chunkIndex);
        await prefs.setInt(_userKey(userId, _kBaseLastTotalChunksKey), totalChunks);
      } else {
        await prefs.remove(_userKey(userId, _kBaseLastDocIdKey));
        await prefs.remove(_userKey(userId, _kBaseLastDocTitleKey));
        await prefs.remove(_userKey(userId, _kBaseLastChunkIndexKey));
        await prefs.remove(_userKey(userId, _kBaseLastTotalChunksKey));
      }
    } catch (e) {
      debugPrint('[LOGOUT] last-session save failed: $e');
    }
  }

  /// On login, populate the player-bar providers from the user's saved
  /// snapshot so they land on the library already showing "last read".
  /// Does NOT auto-play — the user clicks play to resume.
  Future<void> _restoreLastSession(String? userId) async {
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final docId = prefs.getString(_userKey(userId, _kBaseLastDocIdKey));
      final docTitle = prefs.getString(_userKey(userId, _kBaseLastDocTitleKey));
      if (docId == null || docTitle == null) return;

      final chunkIndex = prefs.getInt(_userKey(userId, _kBaseLastChunkIndexKey)) ?? 0;
      final totalChunks = prefs.getInt(_userKey(userId, _kBaseLastTotalChunksKey)) ?? 0;

      _ref.read(activeDocumentIdProvider.notifier).state = docId;
      _ref.read(currentDocTitleProvider.notifier).state = docTitle;
      _ref.read(currentChunkIndexProvider.notifier).state = chunkIndex;
      _ref.read(totalChunksProvider.notifier).state = totalChunks;
    } catch (e) {
      debugPrint('[LOGIN] last-session restore failed: $e');
    }
  }
}

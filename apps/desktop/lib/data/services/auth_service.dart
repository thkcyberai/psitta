import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Auth0 configuration constants.
const _auth0Domain = 'dev-8wmplwcxsoyhlcw1.us.auth0.com';
const _auth0ClientId = 'o4YisrJYWrsPMSiNZ6o2yuUpn0lgulyh';
const _auth0Audience = 'https://api.psitta.app';

/// Manages Auth0 authentication lifecycle.
///
/// Handles login, logout, token refresh, and secure storage
/// of credentials. Tokens are persisted in flutter_secure_storage
/// so users don't need to log in on every app start.
class AuthService {
  AuthService()
      : _auth0 = Auth0(_auth0Domain, _auth0ClientId),
        _storage = const FlutterSecureStorage();

  final Auth0 _auth0;
  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'psitta_access_token';
  static const _refreshTokenKey = 'psitta_refresh_token';

  Credentials? _credentials;

  /// The current access token, or null if not authenticated.
  String? get accessToken => _credentials?.accessToken;

  /// The current user's ID token claims.
  UserProfile? get userProfile => _credentials?.user;

  /// Whether the user is currently authenticated.
  bool get isAuthenticated => _credentials != null;

  /// Attempt to restore a session from stored credentials.
  ///
  /// Returns true if a valid session was restored.
  Future<bool> tryRestoreSession() async {
    final storedToken = await _storage.read(key: _accessTokenKey);
    if (storedToken == null) return false;

    try {
      _credentials = await _auth0.api.renewCredentials(
        refreshToken: await _storage.read(key: _refreshTokenKey) ?? '',
      );
      await _persistCredentials();
      return true;
    } catch (_) {
      await _clearCredentials();
      return false;
    }
  }

  /// Launch the Auth0 Universal Login flow.
  ///
  /// Returns the authenticated user's credentials.
  Future<Credentials> login() async {
    _credentials = await _auth0.webAuthentication().login(
      audience: _auth0Audience,
      scopes: {'openid', 'profile', 'email', 'offline_access'},
    );
    await _persistCredentials();
    return _credentials!;
  }

  /// Log the user out and clear stored credentials.
  Future<void> logout() async {
    try {
      await _auth0.webAuthentication().logout();
    } catch (_) {
      // Best-effort: clear local state even if Auth0 logout fails
    }
    _credentials = null;
    await _clearCredentials();
  }

  Future<void> _persistCredentials() async {
    if (_credentials == null) return;
    await _storage.write(
      key: _accessTokenKey,
      value: _credentials!.accessToken,
    );
    if (_credentials!.refreshToken != null) {
      await _storage.write(
        key: _refreshTokenKey,
        value: _credentials!.refreshToken!,
      );
    }
  }

  Future<void> _clearCredentials() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}

/// Riverpod provider for the auth service singleton.
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Provider that tracks authentication state.
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>(
  (ref) => AuthStateNotifier(ref.read(authServiceProvider)),
);

/// Authentication state.
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.accessToken,
    this.userProfile,
  });

  final AuthStatus status;
  final String? accessToken;
  final UserProfile? userProfile;
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier(this._authService)
      : super(const AuthState(status: AuthStatus.unknown)) {
    _init();
  }

  final AuthService _authService;

  Future<void> _init() async {
    final restored = await _authService.tryRestoreSession();
    if (restored) {
      state = AuthState(
        status: AuthStatus.authenticated,
        accessToken: _authService.accessToken,
        userProfile: _authService.userProfile,
      );
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login() async {
    final credentials = await _authService.login();
    state = AuthState(
      status: AuthStatus.authenticated,
      accessToken: credentials.accessToken,
      userProfile: credentials.user,
    );
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

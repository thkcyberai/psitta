import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../data/services/auth_service.dart';

/// Login screen — embedded WebView that loads the Cognito Hosted UI.
///
/// On initState the screen generates PKCE credentials, builds the
/// Cognito /oauth2/authorize URL, and loads it in a WebviewController.
/// The URL stream is monitored; when the redirect to
/// http://localhost:8080/callback is detected the code is extracted
/// and exchanged for tokens without the URL actually being fetched.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _controller = WebviewController();
  bool _isLoading = true;
  bool _isExchanging = false;

  // PKCE parameters — generated once per login attempt.
  late final String _codeVerifier;
  late final String _codeChallenge;
  late final String _state;

  @override
  void initState() {
    super.initState();
    _codeVerifier = AuthService.generateCodeVerifier();
    _codeChallenge = AuthService.generateCodeChallenge(_codeVerifier);
    _state = AuthService.generateState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    await _controller.initialize();

    // Clear cookies and cache to ensure Cognito session is fully cleared on logout.
    await _controller.clearCache();
    await _controller.clearCookies();

    // Prevent the WebView from opening popup windows.
    await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);

    // Listen for navigation — intercept the callback URL.
    _controller.url.listen(_onUrlChanged);

    // Track loading state.
    _controller.loadingState.listen((state) {
      if (!mounted) return;
      setState(() {
        _isLoading = state == LoadingState.loading;
      });
    });

    final authorizeUrl = AuthService.buildAuthorizeUrl(
      codeChallenge: _codeChallenge,
      state: _state,
    );

    await _controller.loadUrl(authorizeUrl.toString());

    if (mounted) setState(() {});
  }

  void _onUrlChanged(String url) {
    if (_isExchanging) return;
    if (!url.startsWith('http://localhost:8080/callback')) return;

    // Prevent double-processing.
    _isExchanging = true;

    // Immediately stop and redirect WebView away from localhost
    // to prevent the system browser from opening the callback URL.
    _controller.stop();
    _controller.loadUrl('about:blank');

    // Extract query parameters from the callback URL.
    final uri = Uri.parse(url);
    final code          = uri.queryParameters['code'];
    final returnedState = uri.queryParameters['state'];
    final error         = uri.queryParameters['error'];

    if (error != null) {
      final description =
          uri.queryParameters['error_description'] ?? error;
      _showError('Cognito error: $description');
      _isExchanging = false;
      return;
    }

    if (code == null || returnedState == null) {
      _showError('Invalid callback — missing code or state');
      _isExchanging = false;
      return;
    }

    _exchangeCode(code, returnedState);
  }

  Future<void> _exchangeCode(String code, String returnedState) async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.exchangeCodeForTokens(
        code:          code,
        state:         returnedState,
        expectedState: _state,
        codeVerifier:  _codeVerifier,
      );

      // Mark as authenticated in Riverpod state.
      await ref.read(authStateProvider.notifier).login();

      if (mounted) context.go('/');
    } catch (e) {
      _showError('Login failed: $e');
      _isExchanging = false;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // WebView fills the entire screen.
          if (_controller.value.isInitialized)
            Webview(_controller)
          else
            const Center(child: CircularProgressIndicator()),

          // Loading overlay while pages load or token exchange runs.
          if (_isLoading || _isExchanging)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x80FFFFFF),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/auth_service.dart';
import '../../shared/widgets/psitta_logo.dart';

/// First screen shown on cold app launch. Renders the Psitta
/// horizontal logo on a cream background for 1.5 seconds, then
/// routes to /library or /login based on auth state. Only shown
/// once per process — subsequent login/logout transitions bypass
/// the splash via the router's redirect guard.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final status = ref.read(authStateProvider).status;
      final target =
          status == AuthStatus.authenticated ? '/library' : '/login';
      context.go(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFAFAF7),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PsittaLogo(
              width: 320,
              height: 120,
            ),
            SizedBox(height: 24),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                color: Color(0xFF4338CA),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

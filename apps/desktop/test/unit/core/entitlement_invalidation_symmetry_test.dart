// Entitlement invalidation symmetry guard (Option B).
//
// The "Billing = Writing Nook Pro / Capabilities = Free" divergence was caused
// by an ASYMMETRY: billingStatusProvider was invalidated in many places, but
// capabilitiesProvider in only two. Any billing-only invalidation can strand
// capabilitiesProvider in a stale/errored state, which capabilitiesSnapshot-
// Provider (core/capabilities.dart) fails CLOSED to Free -- so billing shows
// Pro while every gated feature behaves as Free. At the auth boundary the same
// gap lets one signed-in user's cached capabilities survive into another
// user's session.
//
// This is a STRUCTURAL drift guard -- same spirit as capabilities_test.dart's
// backend-vocabulary guard. It reads the source and asserts that every site
// that invalidates billingStatusProvider also invalidates capabilitiesProvider,
// with ONE documented exception: the checkout poll-exhausted/pending branch in
// plan_selection_screen.dart, where entitlement has NOT changed and a
// capabilities refetch would be pure waste.
//
// It complements (does not replace) the behavioral scenarios in the validation
// plan (auth A->B, retry, manual refresh, checkout/portal return), which run as
// the Windows manual matrix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String rel) {
  for (final base in ['', 'apps/desktop/']) {
    final f = File('$base$rel');
    if (f.existsSync()) return f.readAsStringSync();
  }
  fail('Could not locate $rel from ${Directory.current.path}');
}

/// Source with whole-line `//` comments removed, so commented references
/// (doc comments that merely mention a provider) never count.
String _code(String rel) => _read(rel)
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

int _count(String hay, String needle) => needle.allMatches(hay).length;

void main() {
  const billing = 'invalidate(billingStatusProvider)';
  const caps = 'invalidate(capabilitiesProvider)';

  group('entitlement invalidation symmetry', () {
    test('auth boundary invalidates capabilities (cross-account leak guard)',
        () {
      final src = _code('lib/data/services/auth_service.dart');
      expect(src.contains('_invalidateUserScopedFetches'), isTrue,
          reason: 'the auth-boundary invalidation helper must still exist');
      expect(_count(src, caps), greaterThanOrEqualTo(1),
          reason: 'capabilitiesProvider MUST be invalidated at the auth '
              'boundary so one user\'s cached capabilities cannot survive '
              'into another user\'s session');
    });

    test('onUnauthorized (401) path pairs billing + capabilities', () {
      final src = _code('lib/data/providers/providers.dart');
      expect(_count(src, billing), greaterThanOrEqualTo(1));
      expect(_count(src, caps), greaterThanOrEqualTo(1));
    });

    test('resume handler invalidates capabilities', () {
      final src = _code('lib/app.dart');
      expect(_count(src, caps), greaterThanOrEqualTo(1),
          reason: 'the AppLifecycleState.resumed handler must recover '
              'capabilities in lockstep with billing');
    });

    test('settings: every billing invalidation is paired with capabilities',
        () {
      final src = _code('lib/features/settings/settings_screen.dart');
      expect(_count(src, caps), equals(_count(src, billing)));
    });

    test('app_shell manual refresh pairs billing + capabilities', () {
      final src = _code('lib/features/shell/app_shell.dart');
      expect(_count(src, billing), greaterThanOrEqualTo(1));
      expect(_count(src, caps), equals(_count(src, billing)));
    });

    test(
        'plan_selection pairs all billing invalidations EXCEPT the '
        'poll-exhausted/pending branch', () {
      final src = _code('lib/features/auth/plan_selection_screen.dart');
      // Exactly ONE billing invalidation is intentionally unpaired: the
      // checkout poll-exhausted branch, where entitlement has not changed.
      // Every entitlement-CHANGING/recovery site must pair.
      expect(_count(src, billing) - _count(src, caps), equals(1),
          reason: 'only the poll-exhausted/pending branch may invalidate '
              'billing without capabilities');
    });
  });
}

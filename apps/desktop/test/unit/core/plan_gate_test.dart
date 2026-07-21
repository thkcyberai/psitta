// Entitlement tests for core/plan_gate.dart (PAC-2A).
//
// Locks in the client-side entitlement contract so the legacy PlanStatus
// gates cannot drift from the backend resolver again:
//   - active AND trialing are entitled (A4 contract: status IN
//     ('active','trialing'))
//   - every other status is denied
//   - Free / unavailable are never entitled
//   - isStripeSubscribed (Customer Portal gate) accepts trialing Stripe
//     subscribers but stays hidden for non-Stripe sources
//
// These tests guard the temporary compatibility shim until PAC-2B replaces
// legacy isPro gating with server-resolved capabilities.

// PAC-2B commit 6: PlanStatus.isPro is @Deprecated with zero production
// consumers — these tests intentionally keep exercising it as the guard
// on the /billing/status entitlement contract until PAC-6 removes
// PlanStatus gating wholesale.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter_test/flutter_test.dart';
import 'package:psitta/core/plan_gate.dart';

void main() {
  group('PlanStatus.isPro — entitled statuses', () {
    test('Writing Nook + active → entitled', () {
      const s = PlanStatus(plan: 'writing_nook_pro', status: 'active');
      expect(s.isPro, isTrue);
      expect(s.isFree, isFalse);
    });

    test('Writing Nook + trialing → entitled (PAC-2A trial fix)', () {
      const s = PlanStatus(plan: 'writing_nook_pro', status: 'trialing');
      expect(s.isPro, isTrue);
      expect(s.isFree, isFalse);
    });

    test('grandfathered plan id + trialing → entitled', () {
      // The backend canonicalizes legacy ids, but the client contract is
      // simply plan != free — any non-free plan with an entitled status
      // passes.
      const s = PlanStatus(plan: 'reading_nook_pro', status: 'trialing');
      expect(s.isPro, isTrue);
    });
  });

  group('PlanStatus.isPro — denied statuses', () {
    for (final denied in [
      'canceled',
      'past_due',
      'incomplete',
      'incomplete_expired',
      'unpaid',
      'paused',
      'none',
      '',
    ]) {
      test("Writing Nook + '$denied' → denied", () {
        final s = PlanStatus(plan: 'writing_nook_pro', status: denied);
        expect(s.isPro, isFalse);
      });
    }

    test('Free plan → never entitled, regardless of status', () {
      const active = PlanStatus(plan: 'free', status: 'active');
      const none = PlanStatus(plan: 'free', status: 'none');
      expect(active.isPro, isFalse);
      expect(none.isPro, isFalse);
      expect(none.isFree, isTrue);
    });

    test('Unavailable (billing loading/errored) → fail closed', () {
      expect(PlanStatus.unavailable.isPro, isFalse);
      expect(PlanStatus.unavailable.isFree, isFalse);
      expect(PlanStatus.unavailable.isUnavailable, isTrue);
    });
  });

  group('PlanStatus.isStripeSubscribed — Customer Portal gate', () {
    test('stripe + active → portal visible', () {
      const s = PlanStatus(
          plan: 'writing_nook_pro', status: 'active', source: 'stripe');
      expect(s.isStripeSubscribed, isTrue);
    });

    test('stripe + trialing → portal visible (trial must be cancelable)',
        () {
      const s = PlanStatus(
          plan: 'writing_nook_pro', status: 'trialing', source: 'stripe');
      expect(s.isStripeSubscribed, isTrue);
    });

    test('stripe + canceled → portal hidden', () {
      const s = PlanStatus(
          plan: 'writing_nook_pro', status: 'canceled', source: 'stripe');
      expect(s.isStripeSubscribed, isFalse);
    });

    test('tester_allowlist + active → portal hidden (no Stripe record)', () {
      const s = PlanStatus(
        plan: 'writing_nook_pro',
        status: 'active',
        source: 'tester_allowlist',
      );
      expect(s.isPro, isTrue, reason: 'allowlist users are entitled');
      expect(s.isStripeSubscribed, isFalse,
          reason: 'portal would 502 without a Stripe customer');
      expect(s.isTesterAllowlist, isTrue);
    });
  });

  group('PlanStatus.fromMap — /billing/status parsing', () {
    test('trialing payload parses and is entitled', () {
      final s = PlanStatus.fromMap({
        'plan': 'writing_nook_pro',
        'status': 'trialing',
        'source': 'stripe',
        'current_period_end': '2026-08-03T00:00:00Z',
      });
      expect(s.isPro, isTrue);
      expect(s.isStripeSubscribed, isTrue);
      expect(s.currentPeriodEnd, isNotNull);
    });

    test('missing fields fall back to legitimate Free (not unavailable)',
        () {
      final s = PlanStatus.fromMap(const {});
      expect(s.plan, 'free');
      expect(s.status, 'none');
      expect(s.isFree, isTrue);
      expect(s.isPro, isFalse);
      expect(s.isUnavailable, isFalse);
    });
  });

  group('Plan limit constants (PAC-2B: runtime limits now come from the '
      'capability payload; these constants back prompt copy and the '
      'confirmed-Free clamp, mirroring backend plan_limits)', () {
    test('Pro ceilings are preserved', () {
      expect(kProMonthlyDocLimit, 50);
      expect(kProMaxSpeed, 4.0);
    });

    test('Free ceilings are preserved', () {
      expect(kFreeMonthlyDocLimit, 10);
      expect(kFreeMaxSpeed, 2.0);
    });
  });
}

// Capability-contract safety net for core/capabilities.dart (PAC-2B, Phase A).
//
// PAC-2B migrates every legacy entitlement gate (isPro, isProUserProvider,
// plan == 'writing_nook_pro') onto this layer, so its contract must be
// locked BEFORE any surface depends on it harder:
//   - the capability vocabulary matches the backend single source of truth
//     (core/backend/src/psitta/services/capabilities.py)
//   - GET /users/me/capabilities payload parsing (plan, capabilities, limits)
//   - fail-closed behavior: malformed/missing fields degrade to the Free
//     baseline, never upward
//   - Capabilities.free is the unavailable-state baseline (isUnavailable
//     true), while a parsed real Free payload is available (isUnavailable
//     false) — the distinction the library retry-vs-upgrade tooltips need
//   - numeric limits: doc_cap (-1 = unlimited) and max_playback_speed
//
// Pure unit tests of the Capabilities model — no providers, no network.

import 'package:flutter_test/flutter_test.dart';
import 'package:psitta/core/capabilities.dart';

void main() {
  group('Capability vocabulary — backend sync', () {
    test('capability strings match the backend vocabulary exactly', () {
      // Mirrors ALL_CAPABILITIES in services/capabilities.py. If this test
      // fails, the client and backend vocabularies have drifted — fix the
      // drift, do not just update the expectation.
      expect(Capability.readAloud, 'read_aloud');
      expect(Capability.editDocument, 'edit_document');
      expect(Capability.premiumVoices, 'premium_voices');
      expect(Capability.swh, 'swh');
      expect(Capability.languages, 'languages');
      expect(Capability.writingDesk, 'writing_desk');
      expect(Capability.blueprints, 'blueprints');
      expect(Capability.narrative, 'narrative');
      expect(Capability.structureAnalysis, 'structure_analysis');
      expect(Capability.aiSummary, 'ai_summary');
      expect(Capability.storyCoach, 'story_coach');
      expect(Capability.scribblesWhispers, 'scribbles_whispers');
    });
  });

  group('Capabilities.fromMap — payload parsing', () {
    test('full Writing Nook payload parses correctly', () {
      final caps = Capabilities.fromMap(const {
        'plan': 'writing_nook_pro',
        'capabilities': [
          'read_aloud',
          'edit_document',
          'premium_voices',
          'swh',
          'languages',
          'writing_desk',
          'blueprints',
          'narrative',
          'structure_analysis',
          'ai_summary',
          'story_coach',
          'scribbles_whispers',
        ],
        'limits': {'doc_cap': 50, 'max_playback_speed': 4.0},
      });
      expect(caps.plan, 'writing_nook_pro');
      expect(caps.capabilities, hasLength(12));
      expect(caps.has(Capability.writingDesk), isTrue);
      expect(caps.has(Capability.premiumVoices), isTrue);
      expect(caps.has(Capability.swh), isTrue);
      expect(caps.has(Capability.editDocument), isTrue);
      expect(caps.docCap, 50);
      expect(caps.maxPlaybackSpeed, 4.0);
      expect(caps.isUnavailable, isFalse);
      expect(caps.isUnlimitedDocs, isFalse);
    });

    test('real Free payload parses as AVAILABLE Free (not unavailable)', () {
      final caps = Capabilities.fromMap(const {
        'plan': 'free',
        'capabilities': ['read_aloud'],
        'limits': {'doc_cap': 10, 'max_playback_speed': 2.0},
      });
      expect(caps.plan, 'free');
      expect(caps.has(Capability.readAloud), isTrue);
      expect(caps.has(Capability.premiumVoices), isFalse);
      expect(caps.has(Capability.writingDesk), isFalse);
      expect(caps.docCap, 10);
      expect(caps.maxPlaybackSpeed, 2.0);
      // Parsed payloads are resolved server truth — distinct from the
      // fail-closed Capabilities.free baseline used while loading/errored.
      expect(caps.isUnavailable, isFalse);
    });

    test('doc_cap -1 means unlimited', () {
      final caps = Capabilities.fromMap(const {
        'plan': 'writing_nook_pro',
        'capabilities': ['read_aloud', 'writing_desk'],
        'limits': {'doc_cap': -1, 'max_playback_speed': 4.0},
      });
      expect(caps.docCap, -1);
      expect(caps.isUnlimitedDocs, isTrue);
    });

    test('integer max_playback_speed parses as double', () {
      final caps = Capabilities.fromMap(const {
        'plan': 'free',
        'capabilities': ['read_aloud'],
        'limits': {'doc_cap': 10, 'max_playback_speed': 2},
      });
      expect(caps.maxPlaybackSpeed, 2.0);
    });
  });

  group('Capabilities.fromMap — fail-closed degradation', () {
    test('empty payload degrades to Free-shaped defaults', () {
      final caps = Capabilities.fromMap(const {});
      expect(caps.plan, 'free');
      expect(caps.capabilities, isEmpty);
      expect(caps.docCap, 10);
      expect(caps.maxPlaybackSpeed, 2.0);
      expect(caps.has(Capability.readAloud), isFalse,
          reason: 'no capability is granted that the server did not send');
    });

    test('malformed capabilities field degrades to empty set', () {
      final notAList = Capabilities.fromMap(const {
        'plan': 'writing_nook_pro',
        'capabilities': 'writing_desk',
        'limits': {'doc_cap': 50, 'max_playback_speed': 4.0},
      });
      expect(notAList.capabilities, isEmpty);
      expect(notAList.has(Capability.writingDesk), isFalse);
    });

    test('non-string entries in capabilities list are filtered out', () {
      final caps = Capabilities.fromMap(const {
        'plan': 'free',
        'capabilities': ['read_aloud', 42, null, true],
        'limits': {'doc_cap': 10, 'max_playback_speed': 2.0},
      });
      expect(caps.capabilities, {'read_aloud'});
    });

    test('missing/malformed limits fall back to the Free ceilings', () {
      final missing = Capabilities.fromMap(const {
        'plan': 'writing_nook_pro',
        'capabilities': ['writing_desk'],
      });
      expect(missing.docCap, 10,
          reason: 'a missing limit must fail closed to the Free cap');
      expect(missing.maxPlaybackSpeed, 2.0);

      final malformed = Capabilities.fromMap(const {
        'plan': 'writing_nook_pro',
        'capabilities': ['writing_desk'],
        'limits': 'oops',
      });
      expect(malformed.docCap, 10);
      expect(malformed.maxPlaybackSpeed, 2.0);
    });

    test('unknown capability string is simply false, never a throw', () {
      final caps = Capabilities.fromMap(const {
        'plan': 'free',
        'capabilities': ['read_aloud'],
      });
      expect(caps.has('creative_studio'), isFalse);
      expect(caps.has(''), isFalse);
    });
  });

  group('Capabilities.free — the unavailable baseline', () {
    test('is Free-shaped, read-aloud only, and marked unavailable', () {
      const free = Capabilities.free;
      expect(free.plan, 'free');
      expect(free.capabilities, {Capability.readAloud});
      expect(free.docCap, 10);
      expect(free.maxPlaybackSpeed, 2.0);
      expect(free.isUnavailable, isTrue,
          reason: 'loading/errored state must be distinguishable from a '
              'legitimately Free payload (retry vs upgrade affordances)');
    });

    test('grants nothing premium while unavailable', () {
      const free = Capabilities.free;
      expect(free.has(Capability.premiumVoices), isFalse);
      expect(free.has(Capability.swh), isFalse);
      expect(free.has(Capability.writingDesk), isFalse);
      expect(free.has(Capability.editDocument), isFalse);
      expect(free.has(Capability.storyCoach), isFalse);
      expect(free.isUnlimitedDocs, isFalse);
    });
  });
}

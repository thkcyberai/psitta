// F3 — player-operation serialization (Perfection QA round 2).
//
// just_audio_windows does not tolerate concurrent native operations: a second
// stop()/setAudioSource() issued while a first load is still inside the
// native layer can crash the Windows app (observed in QA under rapid
// click-to-read during a cold synthesis). AsyncOpGate serializes every
// player-mutating chain; these tests pin its contract: strict FIFO, no
// overlap, error isolation, and correct result propagation.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:psitta/data/services/audio_service.dart' show AsyncOpGate;

void main() {
  group('AsyncOpGate', () {
    test('ops run strictly one at a time, in FIFO order', () async {
      final gate = AsyncOpGate();
      final events = <String>[];
      final release1 = Completer<void>();

      final f1 = gate.run(() async {
        events.add('1-start');
        await release1.future; // hold the gate (simulates a native load)
        events.add('1-end');
        return 1;
      });
      final f2 = gate.run(() async {
        events.add('2-start');
        return 2;
      });
      final f3 = gate.run(() async {
        events.add('3-start');
        return 3;
      });

      // Give the event loop room: 2 and 3 must NOT start while 1 holds.
      await Future<void>.delayed(Duration.zero);
      expect(events, ['1-start']);

      release1.complete();
      expect(await f1, 1);
      expect(await f2, 2);
      expect(await f3, 3);
      expect(events, ['1-start', '1-end', '2-start', '3-start']);
    });

    test('an op that throws does not block or poison later ops', () async {
      final gate = AsyncOpGate();
      final f1 = gate.run<int>(() async => throw StateError('native failure'));
      final f2 = gate.run(() async => 42);

      await expectLater(f1, throwsA(isA<StateError>()));
      expect(await f2, 42, reason: 'gate must fail open after an error');
    });

    test('a hung op released later still lets the queue proceed', () async {
      final gate = AsyncOpGate();
      final hang = Completer<void>();
      final f1 = gate.run(() => hang.future.then((_) => 'first'));
      var secondRan = false;
      final f2 = gate.run(() async {
        secondRan = true;
        return 'second';
      });

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(secondRan, isFalse,
          reason: 'no overlap: second op must wait out the first');

      hang.complete();
      expect(await f1, 'first');
      expect(await f2, 'second');
      expect(secondRan, isTrue);
    });

    test('return values map to their own ops (no cross-talk)', () async {
      final gate = AsyncOpGate();
      final results = await Future.wait([
        gate.run(() async => 'a'),
        gate.run(() async => 'b'),
        gate.run(() async => 'c'),
      ]);
      expect(results, ['a', 'b', 'c']);
    });

    test('rapid-click shape: N queued ops all settle, in order', () async {
      final gate = AsyncOpGate();
      final order = <int>[];
      final futures = [
        for (var i = 0; i < 25; i++)
          gate.run(() async {
            order.add(i);
            return i;
          }),
      ];
      final results = await Future.wait(futures);
      expect(results, List<int>.generate(25, (i) => i));
      expect(order, List<int>.generate(25, (i) => i));
    });
  });
}

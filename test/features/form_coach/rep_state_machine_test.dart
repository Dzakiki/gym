import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/form_coach/engine/hold_timer.dart';
import 'package:formcoach/features/form_coach/engine/rep_state_machine.dart';

/// (seconds, value) keyframes joined by straight lines.
typedef Keys = List<(double, double)>;

const _fps = 30;

/// Samples [keys] at 30 frames per second and feeds them to [machine].
/// Returns every event the machine reported.
List<RepEvent> run(RepStateMachine machine, Keys keys, {double startAt = 0}) {
  final events = <RepEvent>[];
  final end = keys.last.$1;
  for (var frame = 0; frame / _fps <= end + 1e-9; frame++) {
    final t = frame / _fps;
    final event = machine.update(
      _valueAt(keys, t),
      Duration(microseconds: ((startAt + t) * 1e6).round()),
    );
    if (event != null) events.add(event);
  }
  return events;
}

double _valueAt(Keys keys, double t) {
  for (var i = 1; i < keys.length; i++) {
    final (t0, v0) = keys[i - 1];
    final (t1, v1) = keys[i];
    if (t <= t1) return v0 + (v1 - v0) * ((t - t0) / (t1 - t0));
  }
  return keys.last.$2;
}

/// One squat-like repetition from [top] down to [bottom] and back.
Keys rep({
  double top = 170,
  double bottom = 90,
  double down = 1.5,
  double up = 1.5,
}) => [(0, top), (down, bottom), (down + up, top)];

void main() {
  const config = RepMachineConfig(downThreshold: 100, upThreshold: 160);
  late RepStateMachine machine;

  setUp(() => machine = RepStateMachine(config));

  test('counts repeated full repetitions', () {
    var offset = 0.0;
    final events = <RepEvent>[];
    machine.update(170, Duration.zero);
    for (var i = 0; i < 5; i++) {
      events.addAll(run(machine, rep(), startAt: offset + 0.05));
      offset += 3.1;
    }

    expect(machine.repCount, 5);
    expect(events.whereType<RepCompleted>(), hasLength(5));
    expect(machine.partialCount, 0);
    expect(machine.phase, RepPhase.top);
  });

  test('reports when the rep started, bottomed out and ended', () {
    machine.update(170, Duration.zero);

    final events = run(machine, rep(down: 2, up: 1), startAt: 0.033);

    final rep0 = events.single as RepCompleted;
    expect(rep0.minSignal, closeTo(90, 1));
    // The rep starts when the signal leaves the top zone (below 157) and ends
    // when it is back at the top (160), so the 2 s down and 1 s up are
    // measured slightly shorter than the full movement.
    expect(rep0.descentDuration.inMilliseconds, closeTo(1675, 60));
    expect(rep0.ascentDuration.inMilliseconds, closeTo(875, 60));
    expect(rep0.descentDuration, greaterThan(rep0.ascentDuration));
  });

  test('walks through the phases in order', () {
    final phases = <RepPhase>[];
    machine.update(170, Duration.zero);
    phases.add(machine.phase);
    machine.update(130, const Duration(milliseconds: 500));
    phases.add(machine.phase);
    machine.update(95, const Duration(seconds: 1));
    phases.add(machine.phase);
    machine.update(130, const Duration(milliseconds: 1500));
    phases.add(machine.phase);
    machine.update(165, const Duration(seconds: 2));
    phases.add(machine.phase);

    expect(phases, [
      RepPhase.top,
      RepPhase.descending,
      RepPhase.bottom,
      RepPhase.ascending,
      RepPhase.top,
    ]);
  });

  test('does not count anything until the top position was reached', () {
    // Starts half way down, so the first movement is not a full repetition.
    final events = run(machine, [(0, 120), (1, 90), (2, 170)]);
    expect(events, isEmpty);
    expect(machine.phase, RepPhase.top);

    final next = run(machine, rep(), startAt: 2.05);

    expect(next.whereType<RepCompleted>(), hasLength(1));
  });

  test('a big dip that does not reach the bottom is a partial rep', () {
    machine.update(170, Duration.zero);

    final events = run(machine, [(0, 170), (1, 130), (2, 170)], startAt: 0.05);

    expect(events.single, isA<PartialRep>());
    expect(machine.repCount, 0);
    expect(machine.partialCount, 1);
    expect(events.single.minSignal, closeTo(130, 1));
  });

  test('a tiny wobble at the top is ignored', () {
    machine.update(170, Duration.zero);

    final events = run(machine, [
      (0, 170),
      (0.5, 163),
      (1, 170),
    ], startAt: 0.05);

    expect(events, isEmpty);
    expect(machine.partialCount, 0);
  });

  test('a shallow dip below the partial limit is ignored', () {
    machine.update(170, Duration.zero);

    // Leaves the top zone but only drops 10 of the 60 degree range.
    final events = run(machine, [(0, 170), (1, 150), (2, 170)], startAt: 0.05);

    expect(events, isEmpty);
    expect(machine.partialCount, 0);
  });

  test('jitter around the bottom threshold does not double count', () {
    machine.update(170, Duration.zero);
    run(machine, [(0, 170), (1.5, 95)], startAt: 0.05);
    var t = 1.6;
    for (final wobble in [101.0, 99.0, 102.0, 98.0, 103.0, 97.0, 102.0]) {
      machine.update(wobble, Duration(milliseconds: (t * 1000).round()));
      t += 0.05;
    }

    final events = run(machine, [(0, 100), (1.5, 170)], startAt: t);

    expect(events.whereType<RepCompleted>(), hasLength(1));
    expect(machine.repCount, 1);
  });

  test('a movement that is too fast to be a rep is ignored', () {
    machine.update(170, Duration.zero);

    final events = run(machine, [
      (0, 170),
      (0.1, 90),
      (0.2, 170),
    ], startAt: 0.05);

    expect(events, isEmpty);
    expect(machine.repCount, 0);
    expect(machine.phase, RepPhase.top);
  });

  test('a rep that takes too long is abandoned', () {
    machine.update(170, Duration.zero);

    final events = run(machine, [(0, 170), (1, 90), (12, 90)], startAt: 0.05);

    expect(events, isEmpty);
    expect(machine.phase, RepPhase.waiting);

    // Coming back to the top re-arms the counter.
    machine.update(170, const Duration(seconds: 13));
    final next = run(machine, rep(), startAt: 13.05);
    expect(next.whereType<RepCompleted>(), hasLength(1));
    expect(machine.repCount, 1);
  });

  test('sinking back to the bottom while coming up still counts once', () {
    machine.update(170, Duration.zero);

    final events = run(machine, [
      (0, 170),
      (1, 90),
      (1.5, 120),
      (2, 90),
      (3.5, 170),
    ], startAt: 0.05);

    expect(events.whereType<RepCompleted>(), hasLength(1));
  });

  test('reset clears counts and waits for the top again', () {
    machine.update(170, Duration.zero);
    run(machine, rep(), startAt: 0.05);

    machine.reset();

    expect(machine.repCount, 0);
    expect(machine.partialCount, 0);
    expect(machine.phase, RepPhase.waiting);
  });

  test('a config needs the bottom below the top', () {
    expect(
      () => RepMachineConfig(downThreshold: 100, upThreshold: 100),
      throwsA(isA<AssertionError>()),
    );
  });

  group('HoldTimer', () {
    Duration ms(int value) => Duration(milliseconds: value);

    test('counts only time with valid form', () {
      final timer = HoldTimer()
        ..update(valid: true, time: ms(0))
        ..update(valid: true, time: ms(100))
        ..update(valid: false, time: ms(200))
        ..update(valid: true, time: ms(300));

      expect(timer.held, ms(200));
      expect(timer.brokenForm, ms(100));
    });

    test('the first update adds no time', () {
      final timer = HoldTimer()..update(valid: true, time: ms(1000));

      expect(timer.held, Duration.zero);
    });

    test('a long gap is not counted', () {
      final timer = HoldTimer()
        ..update(valid: true, time: ms(0))
        ..update(valid: true, time: ms(3000))
        ..update(valid: true, time: ms(3100));

      expect(timer.held, ms(100));
    });

    test('reset starts over', () {
      final timer = HoldTimer()
        ..update(valid: true, time: ms(0))
        ..update(valid: true, time: ms(100))
        ..reset();

      expect(timer.held, Duration.zero);
      expect(timer.brokenForm, Duration.zero);
    });
  });
}

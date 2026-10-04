import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/core/clock.dart';
import 'package:formcoach/features/workout/rest_alarm.dart';
import 'package:formcoach/features/workout/rest_timer.dart';

import '../../helpers/fake_rest_alarm.dart';

void main() {
  // The timer ends with a haptic pulse, which needs the platform binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late FakeRestAlarm alarm;

  RestTimer timer() => container.read(restTimerProvider.notifier);
  RestTimerState? state() => container.read(restTimerProvider);

  setUp(() {
    alarm = FakeRestAlarm();
    container = ProviderContainer(
      overrides: [restAlarmProvider.overrideWithValue(alarm)],
    );
  });
  tearDown(() => container.dispose());

  test('is idle at first', () {
    expect(state(), isNull);
  });

  test('counts down every second and stops at zero', () {
    fakeAsync((async) {
      timer().start(3);
      expect(state()?.remaining, 3);

      async.elapse(const Duration(seconds: 1));
      expect(state()?.remaining, 2);
      async.elapse(const Duration(seconds: 1));
      expect(state()?.remaining, 1);
      async.elapse(const Duration(seconds: 1));
      expect(state(), isNull);
    });
  });

  test('addTime extends the countdown and its total', () {
    fakeAsync((async) {
      timer().start(60);
      timer().addTime();

      expect(state()?.remaining, 75);
      expect(state()?.total, 75);
    });
  });

  test('addTime does nothing when idle', () {
    timer().addTime();

    expect(state(), isNull);
  });

  test('skip stops the countdown', () {
    fakeAsync((async) {
      timer().start(60);

      timer().skip();

      expect(state(), isNull);
      async.elapse(const Duration(seconds: 5));
      expect(state(), isNull);
    });
  });

  test('starting again restarts from the new value', () {
    fakeAsync((async) {
      timer().start(30);
      async.elapse(const Duration(seconds: 10));

      timer().start(90);

      expect(state()?.remaining, 90);
    });
  });

  test('a zero rest does not start a countdown', () {
    timer().start(0);

    expect(state(), isNull);
  });

  test('fractionLeft goes from 1 towards 0', () {
    fakeAsync((async) {
      timer().start(4);
      expect(state()?.fractionLeft, 1);
      async.elapse(const Duration(seconds: 2));
      expect(state()?.fractionLeft, 0.5);
    });
  });

  group('background alarm', () {
    late DateTime now;

    // A clock moved by hand, to stand for time that passes while the phone
    // has paused the app's timers.
    setUp(() {
      container.dispose();
      now = DateTime.utc(2026, 10, 4, 18);
      container = ProviderContainer(
        overrides: [
          restAlarmProvider.overrideWithValue(alarm),
          clockProvider.overrideWithValue(() => now),
        ],
      );
    });

    test('gets the alarm ready when a rest starts', () {
      timer().start(60);

      expect(alarm.prepared, 1);
    });

    test('alerts at the end of the rest when the app is hidden', () {
      timer()
        ..start(60)
        ..appHidden();

      expect(alarm.scheduled, [now.add(const Duration(seconds: 60))]);
    });

    test('alerts at the extended end when time was added', () {
      timer()
        ..start(60)
        ..addTime()
        ..appHidden();

      expect(alarm.scheduled, [now.add(const Duration(seconds: 75))]);
    });

    test('schedules nothing while the app stays on screen', () {
      fakeAsync((async) {
        timer().start(2);
        now = now.add(const Duration(seconds: 2));
        async.elapse(const Duration(seconds: 2));

        expect(state(), isNull);
        expect(alarm.scheduled, isEmpty);
      });
    });

    test('schedules nothing when the app is hidden between rests', () {
      timer().appHidden();

      expect(alarm.scheduled, isEmpty);
    });

    test('cancels the alert and catches up when the app comes back', () {
      timer()
        ..start(60)
        ..appHidden();
      now = now.add(const Duration(seconds: 50));

      timer().appShown();

      expect(alarm.cancelled, 1);
      expect(state()?.remaining, 10);
      expect(state()?.total, 60);
    });

    test('a rest that ended while away is over on return', () {
      timer()
        ..start(60)
        ..appHidden();
      now = now.add(const Duration(minutes: 5));

      timer().appShown();

      expect(state(), isNull);
    });

    test('the alert stays scheduled when the rest ends in the background', () {
      fakeAsync((async) {
        timer()
          ..start(2)
          ..appHidden();
        now = now.add(const Duration(seconds: 2));
        async.elapse(const Duration(seconds: 2));

        expect(state(), isNull);
        expect(alarm.cancelled, 0);
      });
    });

    test('skip cancels the alert', () {
      timer()
        ..start(60)
        ..skip();

      expect(alarm.cancelled, 1);
    });
  });

  test('follows the app going to the background and coming back', () {
    // The engine reports every state in between, as a phone does.
    void moveThrough(List<AppLifecycleState> states) {
      for (final state in states) {
        TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
          state,
        );
      }
    }

    moveThrough([AppLifecycleState.resumed]);
    timer().start(60);

    moveThrough([
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    expect(alarm.scheduled, hasLength(1));

    moveThrough([
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    expect(alarm.cancelled, 1);
  });

  test('the notification alarm never throws without a platform', () async {
    final real = LocalNotificationRestAlarm();

    await real.prepare();
    await real.schedule(DateTime.utc(2026, 10, 4));
    await real.cancel();
  });
}

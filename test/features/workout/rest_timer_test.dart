import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/workout/rest_timer.dart';

void main() {
  // The timer ends with a haptic pulse, which needs the platform binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  RestTimer timer() => container.read(restTimerProvider.notifier);
  RestTimerState? state() => container.read(restTimerProvider);

  setUp(() => container = ProviderContainer());
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
}

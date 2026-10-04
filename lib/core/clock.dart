import 'package:clock/clock.dart' as system;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Returns the current time in UTC. Injected so tests can control time.
typedef Clock = DateTime Function();

/// The real time, read through `package:clock` so `fakeAsync` and widget
/// tests move it along with their fake timers.
final clockProvider = Provider<Clock>(
  (ref) =>
      () => system.clock.now().toUtc(),
);

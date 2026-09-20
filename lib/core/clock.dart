import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Returns the current time in UTC. Injected so tests can control time.
typedef Clock = DateTime Function();

final clockProvider = Provider<Clock>(
  (ref) =>
      () => DateTime.now().toUtc(),
);

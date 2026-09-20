import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The state of a running rest countdown.
class RestTimerState {
  const RestTimerState({required this.remaining, required this.total});

  /// Seconds left.
  final int remaining;

  /// Seconds the countdown started with (including any added time).
  final int total;

  /// Fraction of the rest that is left, from 1 down to 0.
  double get fractionLeft => total == 0 ? 0 : remaining / total;
}

/// Counts down the rest between sets. The state is null when no rest is
/// running. Rings a haptic pulse when the countdown ends.
class RestTimer extends Notifier<RestTimerState?> {
  static const addedSeconds = 15;

  Timer? _ticker;

  @override
  RestTimerState? build() {
    ref.onDispose(() => _ticker?.cancel());
    return null;
  }

  /// Starts (or restarts) a countdown of [seconds]. Does nothing for 0.
  void start(int seconds) {
    if (seconds <= 0) return;
    _ticker?.cancel();
    state = RestTimerState(remaining: seconds, total: seconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Adds [addedSeconds] to a running countdown.
  void addTime() {
    final current = state;
    if (current == null) return;
    state = RestTimerState(
      remaining: current.remaining + addedSeconds,
      total: current.total + addedSeconds,
    );
  }

  /// Stops the countdown without any signal.
  void skip() {
    _ticker?.cancel();
    state = null;
  }

  void _tick() {
    final current = state;
    if (current == null || current.remaining <= 1) {
      _ticker?.cancel();
      final finished = current != null;
      state = null;
      if (finished) unawaited(HapticFeedback.heavyImpact());
      return;
    }
    state = RestTimerState(
      remaining: current.remaining - 1,
      total: current.total,
    );
  }
}

final restTimerProvider = NotifierProvider<RestTimer, RestTimerState?>(
  RestTimer.new,
);

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/form_coach/engine/one_euro_filter.dart';

/// Deterministic pseudo-noise in [-amplitude, amplitude].
double _noise(int i, double amplitude) => math.sin(i * 12.9898) * amplitude;

double _variance(List<double> values) {
  final mean = values.reduce((a, b) => a + b) / values.length;
  return values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
      values.length;
}

void main() {
  const dt = 1 / 30;

  test('the first value passes through unchanged', () {
    expect(OneEuroFilter().filter(0.42, 0), 0.42);
  });

  test('a constant signal stays constant', () {
    final filter = OneEuroFilter();
    var output = 0.0;
    for (var i = 0; i < 30; i++) {
      output = filter.filter(0.5, i * dt);
    }

    expect(output, closeTo(0.5, 1e-9));
  });

  test('jitter around a still value is reduced', () {
    final filter = OneEuroFilter();
    final raw = <double>[];
    final smooth = <double>[];
    for (var i = 0; i < 120; i++) {
      final value = 0.5 + _noise(i, 0.01);
      raw.add(value);
      smooth.add(filter.filter(value, i * dt));
    }

    expect(
      _variance(smooth.skip(10).toList()),
      lessThan(_variance(raw.skip(10).toList()) / 2),
    );
  });

  test('a step is followed within a fraction of a second', () {
    final filter = OneEuroFilter();
    for (var i = 0; i < 30; i++) {
      filter.filter(0.2, i * dt);
    }

    var output = 0.0;
    for (var i = 30; i < 45; i++) {
      output = filter.filter(0.8, i * dt);
    }

    expect(output, greaterThan(0.75));
  });

  test('a higher beta lags less during fast movement', () {
    double lagWith(double beta) {
      final filter = OneEuroFilter(beta: beta);
      var output = 0.0;
      var value = 0.0;
      for (var i = 0; i < 30; i++) {
        value = i * 0.03; // steady fast movement
        output = filter.filter(value, i * dt);
      }
      return value - output;
    }

    expect(lagWith(20), lessThan(lagWith(0)));
  });

  test('reset makes the next value pass through', () {
    final filter = OneEuroFilter();
    for (var i = 0; i < 10; i++) {
      filter.filter(0.2, i * dt);
    }

    filter.reset();

    expect(filter.filter(0.9, 10 * dt), 0.9);
  });

  test('a repeated timestamp does not divide by zero', () {
    final filter = OneEuroFilter()..filter(0.2, 1);

    expect(filter.filter(0.9, 1), 0.9);
  });
}

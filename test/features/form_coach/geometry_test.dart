import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/form_coach/engine/geometry.dart';

void main() {
  group('Vec2', () {
    test('supports arithmetic', () {
      const a = Vec2(3, 4);

      expect(a + const Vec2(1, 1), const Vec2(4, 5));
      expect(a - const Vec2(1, 1), const Vec2(2, 3));
      expect(a * 2, const Vec2(6, 8));
      expect(a.length, 5);
      expect(a.dot(const Vec2(1, 2)), 11);
    });

    test('distance and midpoint', () {
      const a = Vec2(0, 0);
      const b = Vec2(6, 8);

      expect(a.distanceTo(b), 10);
      expect(a.midpointTo(b), const Vec2(3, 4));
    });

    test('compares by value', () {
      expect(const Vec2(1, 2), const Vec2(1, 2));
      expect(const Vec2(1, 2).hashCode, const Vec2(1, 2).hashCode);
      expect(const Vec2(1, 2), isNot(const Vec2(2, 1)));
    });
  });

  group('angleAt', () {
    test('a right angle is 90 degrees', () {
      expect(
        angleAt(const Vec2(1, 0), Vec2.zero, const Vec2(0, 1)),
        closeTo(90, 1e-9),
      );
    });

    test('a straight line is 180 degrees', () {
      expect(
        angleAt(const Vec2(-1, 0), Vec2.zero, const Vec2(1, 0)),
        closeTo(180, 1e-9),
      );
    });

    test('a folded joint is 0 degrees', () {
      expect(
        angleAt(const Vec2(1, 0), Vec2.zero, const Vec2(2, 0)),
        closeTo(0, 1e-6),
      );
    });

    test('a 45 degree angle', () {
      expect(
        angleAt(const Vec2(1, 0), Vec2.zero, const Vec2(1, 1)),
        closeTo(45, 1e-9),
      );
    });

    test('does not depend on the order of the two ends', () {
      const a = Vec2(0.2, 0.7);
      const v = Vec2(0.5, 0.5);
      const c = Vec2(0.9, 0.6);

      expect(angleAt(a, v, c), closeTo(angleAt(c, v, a), 1e-9));
    });

    test('a zero-length segment counts as straight', () {
      expect(angleAt(Vec2.zero, Vec2.zero, const Vec2(1, 0)), 180);
    });
  });

  group('leanFromVertical', () {
    test('a segment pointing up is upright', () {
      expect(leanFromVertical(const Vec2(0.5, 0.5), const Vec2(0.5, 0.2)), 0);
    });

    test('a horizontal segment leans 90 degrees', () {
      expect(
        leanFromVertical(const Vec2(0.5, 0.5), const Vec2(0.8, 0.5)),
        closeTo(90, 1e-9),
      );
    });

    test('leaning forward or backward by the same amount is the same', () {
      final forward = leanFromVertical(Vec2.zero, const Vec2(1, -1));
      final backward = leanFromVertical(Vec2.zero, const Vec2(-1, -1));

      expect(forward, closeTo(45, 1e-9));
      expect(backward, closeTo(forward, 1e-9));
    });

    test('a segment pointing down is 180 degrees', () {
      expect(leanFromVertical(Vec2.zero, const Vec2(0, 1)), closeTo(180, 1e-9));
    });

    test('a zero-length segment is upright', () {
      expect(leanFromVertical(Vec2.zero, Vec2.zero), 0);
    });
  });
}

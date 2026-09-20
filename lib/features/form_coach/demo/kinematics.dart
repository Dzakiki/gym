import 'dart:math' as math;

import 'package:formcoach/features/form_coach/engine/geometry.dart';

/// The two points that are [rA] from [a] and [rB] from [b] (where the circles
/// around a and b meet). Empty results are avoided by clamping, so an
/// impossible pose collapses to the closest possible one.
List<Vec2> circleIntersections(Vec2 a, double rA, Vec2 b, double rB) {
  final between = b - a;
  final distance = between.length;
  final alongA = (rA * rA - rB * rB + distance * distance) / (2 * distance);
  final height = math.sqrt(math.max(0, rA * rA - alongA * alongA));
  final direction = between * (1 / distance);
  final middle = a + direction * alongA;
  final side = Vec2(-direction.y, direction.x) * height;
  return [middle + side, middle - side];
}

/// The intersection with the smaller y (higher up the image).
Vec2 upperIntersection(Vec2 a, double rA, Vec2 b, double rB) =>
    circleIntersections(a, rA, b, rB).reduce((p, q) => p.y < q.y ? p : q);

/// The intersection with the smaller x (further left in the image).
Vec2 leftIntersection(Vec2 a, double rA, Vec2 b, double rB) =>
    circleIntersections(a, rA, b, rB).reduce((p, q) => p.x < q.x ? p : q);

/// The distance between the two ends of two segments of lengths [first] and
/// [second] joined at a joint of [angleDegrees] (law of cosines).
double spanAcrossJoint(double first, double second, double angleDegrees) {
  final radians = angleDegrees * math.pi / 180;
  return math.sqrt(
    first * first + second * second - 2 * first * second * math.cos(radians),
  );
}

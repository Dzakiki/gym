import 'dart:math' as math;

/// A 2D point or vector. Coordinates are in image-height units (1.0 is the
/// full image height, y grows downwards) so distances and angles are not
/// distorted by the image aspect ratio.
class Vec2 {
  const Vec2(this.x, this.y);

  static const zero = Vec2(0, 0);

  final double x;
  final double y;

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);

  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);

  Vec2 operator *(double factor) => Vec2(x * factor, y * factor);

  double get length => math.sqrt(x * x + y * y);

  double dot(Vec2 other) => x * other.x + y * other.y;

  double distanceTo(Vec2 other) => (this - other).length;

  Vec2 midpointTo(Vec2 other) => Vec2((x + other.x) / 2, (y + other.y) / 2);

  @override
  bool operator ==(Object other) =>
      other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Vec2($x, $y)';
}

/// The angle in degrees (0 to 180) at [vertex] between the segments towards
/// [a] and [c]. A straight leg gives 180 at the knee.
///
/// Returns 180 when either segment has no length.
double angleAt(Vec2 a, Vec2 vertex, Vec2 c) {
  final first = a - vertex;
  final second = c - vertex;
  final lengths = first.length * second.length;
  if (lengths == 0) return 180;
  final cosine = (first.dot(second) / lengths).clamp(-1.0, 1.0);
  return math.acos(cosine) * 180 / math.pi;
}

/// How far the segment from [from] to [to] leans away from pointing straight
/// up, in degrees (0 to 180). 0 is upright, 90 is horizontal.
///
/// Returns 0 when the segment has no length.
double leanFromVertical(Vec2 from, Vec2 to) {
  final segment = to - from;
  if (segment.length == 0) return 0;
  const up = Vec2(0, -1);
  final cosine = (segment.dot(up) / segment.length).clamp(-1.0, 1.0);
  return math.acos(cosine) * 180 / math.pi;
}

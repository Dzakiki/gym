import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/form_coach/engine/geometry.dart';
import 'package:formcoach/features/form_coach/engine/landmark_smoother.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

PoseFrame _frame(int ms, Map<Landmark, LandmarkPoint> points) => PoseFrame(
  timestamp: Duration(milliseconds: ms),
  points: points,
);

LandmarkPoint _point(double x, double y, [double likelihood = 1]) =>
    LandmarkPoint(Vec2(x, y), likelihood: likelihood);

void main() {
  late LandmarkSmoother smoother;

  setUp(() => smoother = LandmarkSmoother());

  test('the first frame passes through', () {
    final result = smoother.smooth(
      _frame(0, {Landmark.nose: _point(0.4, 0.2)}),
    );

    expect(result.position(Landmark.nose), const Vec2(0.4, 0.2));
  });

  test('drops landmarks the detector is unsure about', () {
    final result = smoother.smooth(
      _frame(0, {
        Landmark.nose: _point(0.4, 0.2, 0.3),
        Landmark.leftHip: _point(0.5, 0.5, 0.9),
      }),
    );

    expect(result.position(Landmark.nose), isNull);
    expect(result.isVisible(Landmark.nose), isFalse);
    expect(result.isVisible(Landmark.leftHip), isTrue);
  });

  test('keeps the timestamp and the likelihood', () {
    final result = smoother.smooth(
      _frame(250, {Landmark.nose: _point(0.4, 0.2, 0.8)}),
    );

    expect(result.timestamp, const Duration(milliseconds: 250));
    expect(result.points[Landmark.nose]!.likelihood, 0.8);
  });

  test('a jump is smoothed rather than followed in one frame', () {
    smoother.smooth(_frame(0, {Landmark.nose: _point(0.5, 0.5)}));

    final result = smoother.smooth(
      _frame(33, {Landmark.nose: _point(0.5, 0.6)}),
    );

    final y = result.position(Landmark.nose)!.y;
    expect(y, greaterThan(0.5));
    expect(y, lessThan(0.6));
  });

  test('landmarks are smoothed independently', () {
    smoother.smooth(
      _frame(0, {
        Landmark.nose: _point(0.5, 0.5),
        Landmark.leftHip: _point(0.2, 0.2),
      }),
    );

    final result = smoother.smooth(
      _frame(33, {
        Landmark.nose: _point(0.5, 0.5),
        Landmark.leftHip: _point(0.2, 0.2),
      }),
    );

    expect(result.position(Landmark.nose), const Vec2(0.5, 0.5));
    expect(result.position(Landmark.leftHip), const Vec2(0.2, 0.2));
  });

  test('a landmark that was missing for a while starts fresh', () {
    smoother.smooth(_frame(0, {Landmark.nose: _point(0.5, 0.5)}));

    final result = smoother.smooth(
      _frame(2000, {Landmark.nose: _point(0.9, 0.9)}),
    );

    expect(result.position(Landmark.nose), const Vec2(0.9, 0.9));
  });

  test('reset forgets earlier frames', () {
    smoother.smooth(_frame(0, {Landmark.nose: _point(0.5, 0.5)}));

    smoother.reset();
    final result = smoother.smooth(
      _frame(33, {Landmark.nose: _point(0.9, 0.9)}),
    );

    expect(result.position(Landmark.nose), const Vec2(0.9, 0.9));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/form_coach/camera/frame_stats.dart';

void main() {
  test('RateMeter counts the events of the last second', () {
    final meter = RateMeter();
    for (var ms = 0; ms < 2000; ms += 50) {
      meter.add(Duration(milliseconds: ms));
    }
    expect(meter.rate(const Duration(milliseconds: 1999)), 20);
  });

  test('RateMeter falls to zero when events stop', () {
    final meter = RateMeter()..add(Duration.zero);
    expect(meter.rate(const Duration(milliseconds: 500)), 1);
    expect(meter.rate(const Duration(seconds: 2)), 0);
  });
}

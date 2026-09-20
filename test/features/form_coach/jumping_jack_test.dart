import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/form_coach/demo/jumping_jack_synth.dart';
import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/coach_session.dart';
import 'package:formcoach/features/form_coach/engine/rep_summary.dart';
import 'package:formcoach/features/form_coach/exercises/jumping_jack.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';

({CoachSession session, List<CoachUpdate> updates}) _run(
  List<PoseFrame> frames,
) {
  final session = CoachSession(definition: jumpingJack);
  final updates = [for (final frame in frames) session.update(frame)];
  return (session: session, updates: updates);
}

Set<String> _faultsOf(CoachSession session) => {
  for (final rep in session.reps) ...rep.faultCodes,
};

Iterable<String?> _cueTexts(List<CoachUpdate> updates) =>
    updates.map((u) => u.cue?.text);

RepSummary _rep({double arms = 1.0, double feet = 2.3, double asymmetry = 0}) {
  MetricStats peak(double value) =>
      MetricStats(min: value, max: value, atBottom: value);
  return RepSummary(
    stats: {
      JumpingJackMetric.armElevation: peak(arms),
      JumpingJackMetric.footSpread: peak(feet),
      JumpingJackMetric.armAsymmetry: peak(asymmetry),
      JumpingJackMetric.closedness: peak(0.1),
    },
    descent: const Duration(milliseconds: 450),
    ascent: const Duration(milliseconds: 450),
    startedAt: Duration.zero,
    endedAt: const Duration(milliseconds: 900),
  );
}

double _severity(String code, RepSummary rep) =>
    jumpingJack.rules.singleWhere((r) => r.code == code).check(rep);

void main() {
  test('it is a front-view exercise', () {
    expect(jumpingJack.view, CameraView.front);
  });

  group('measureJumpingJack', () {
    Map<String, double> measure(double openness, {double asymmetry = 0}) {
      final frame = PoseFrame(
        timestamp: Duration.zero,
        points: jumpingJackPose(openness: openness, asymmetry: asymmetry),
      );
      return measureJumpingJack(frame, BodySide.left)!;
    }

    test('closed: arms down, feet together', () {
      final metrics = measure(0);

      expect(metrics[JumpingJackMetric.closedness], closeTo(1, 1e-9));
      expect(metrics[JumpingJackMetric.armElevation], closeTo(-1, 0.02));
      expect(metrics[JumpingJackMetric.footSpread], closeTo(0.9, 1e-9));
    });

    test('open: arms overhead, feet wide', () {
      final metrics = measure(1);

      expect(metrics[JumpingJackMetric.closedness], closeTo(0, 0.02));
      expect(metrics[JumpingJackMetric.armElevation], closeTo(1, 0.05));
      expect(metrics[JumpingJackMetric.footSpread], closeTo(2.3, 1e-9));
    });

    test('closedness falls smoothly as the body opens', () {
      final values = [
        for (final openness in [0.0, 0.25, 0.5, 0.75, 1.0])
          measure(openness)[JumpingJackMetric.closedness]!,
      ];

      for (var i = 1; i < values.length; i++) {
        expect(values[i], lessThan(values[i - 1]));
      }
    });

    test('arms at different heights give an asymmetry', () {
      expect(measure(1)[JumpingJackMetric.armAsymmetry], closeTo(0, 1e-9));
      expect(
        measure(1, asymmetry: 60)[JumpingJackMetric.armAsymmetry],
        greaterThan(0.5),
      );
    });

    test('returns null when a needed landmark is missing', () {
      final points = jumpingJackPose(openness: 0.5)
        ..remove(Landmark.rightAnkle);

      expect(
        measureJumpingJack(
          PoseFrame(timestamp: Duration.zero, points: points),
          BodySide.left,
        ),
        isNull,
      );
    });
  });

  group('jumping jack rules', () {
    test('a good jumping jack has no faults', () {
      for (final rule in jumpingJack.rules) {
        expect(rule.check(_rep()), 0, reason: rule.code);
      }
    });

    test('arms: the wrists should get well above the shoulders', () {
      expect(_severity('jj_arms', _rep(arms: 0.4)), 0);
      expect(_severity('jj_arms', _rep(arms: 0.15)), closeTo(0.5, 1e-9));
      expect(_severity('jj_arms', _rep(arms: -0.2)), 1);
    });

    test('feet: the ankles should get well apart', () {
      expect(_severity('jj_feet', _rep(feet: 1.6)), 0);
      expect(_severity('jj_feet', _rep(feet: 1.3)), closeTo(0.5, 1e-9));
    });

    test('symmetry: both arms should move together', () {
      expect(_severity('jj_symmetry', _rep(asymmetry: 0.25)), 0);
      expect(
        _severity('jj_symmetry', _rep(asymmetry: 0.45)),
        closeTo(0.5, 1e-9),
      );
    });
  });

  group('coaching jumping jacks', () {
    test('good jumping jacks are all counted and judged excellent', () {
      final run = _run(jumpingJackFrames(const JumpingJackMotion()));

      expect(run.session.repCount, 6);
      expect(run.session.partialCount, 0);
      expect(_faultsOf(run.session), isEmpty);
      expect(run.session.setScore, greaterThanOrEqualTo(95));
    });

    test('keeps counting through detection jitter', () {
      final run = _run(
        jumpingJackFrames(const JumpingJackMotion(reps: 8, noise: 0.003)),
      );

      expect(run.session.repCount, 8);
      expect(run.session.partialCount, 0);
    });

    test('arms that only reach shoulder height are picked up', () {
      // 90 degrees is arms straight out to the sides.
      final run = _run(
        jumpingJackFrames(const JumpingJackMotion(armsOverhead: 90)),
      );

      expect(run.session.repCount, 6);
      expect(_faultsOf(run.session), contains('jj_arms'));
      expect(_cueTexts(run.updates), contains('Arms all the way up'));
    });

    test('feet that do not go wide enough are picked up', () {
      final run = _run(
        jumpingJackFrames(const JumpingJackMotion(feetSpread: 1.45)),
      );

      expect(run.session.repCount, 6);
      expect(_faultsOf(run.session), contains('jj_feet'));
      expect(_cueTexts(run.updates), contains('Jump wider'));
    });

    test('one arm lower than the other is picked up', () {
      final run = _run(
        jumpingJackFrames(const JumpingJackMotion(asymmetry: 60)),
      );

      expect(_faultsOf(run.session), contains('jj_symmetry'));
      expect(_cueTexts(run.updates), contains('Even on both sides'));
    });

    test('half-hearted jumping jacks are partial reps', () {
      // Arms only to shoulder height and feet only a little apart: the body
      // opens partway, but not enough to count.
      final run = _run(
        jumpingJackFrames(
          const JumpingJackMotion(armsOverhead: 90, feetSpread: 1.4),
        ),
      );

      expect(run.session.repCount, 0);
      expect(run.session.partialCount, 6);
      expect(_cueTexts(run.updates), contains('Open up more'));
    });

    test('tiny movements are ignored altogether', () {
      final run = _run(
        jumpingJackFrames(
          const JumpingJackMotion(armsOverhead: 60, feetSpread: 1.1),
        ),
      );

      expect(run.session.repCount, 0);
      expect(run.session.partialCount, 0);
    });
  });
}

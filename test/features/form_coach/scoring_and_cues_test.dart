import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/form_coach/engine/cue_manager.dart';
import 'package:formcoach/features/form_coach/engine/form_rule.dart';
import 'package:formcoach/features/form_coach/engine/rep_scorer.dart';
import 'package:formcoach/features/form_coach/engine/rep_summary.dart';

RepSummary _summary({double minValue = 100}) => RepSummary(
  stats: {'x': MetricStats(min: minValue, max: 170, atBottom: minValue)},
  descent: const Duration(seconds: 1),
  ascent: const Duration(seconds: 1),
  startedAt: Duration.zero,
  endedAt: const Duration(seconds: 2),
);

FormRule _rule(
  String code, {
  required double severity,
  double weight = 20,
  bool safety = false,
}) => FormRule(
  code: code,
  cue: 'Fix $code',
  weight: weight,
  safety: safety,
  check: (_) => severity,
);

Fault _fault(
  String code, {
  double weight = 20,
  double severity = 1,
  bool safety = false,
}) => Fault(
  code: code,
  cue: 'Fix $code',
  severity: severity,
  weight: weight,
  safety: safety,
);

/// A repetition [index] finished at index * 4 seconds.
RepAnalysis _rep(int index, [List<Fault> faults = const []]) {
  final deducted = faults.fold<double>(0, (sum, f) => sum + f.deduction);
  return RepAnalysis(
    index: index,
    score: 100 - deducted,
    faults: faults,
    summary: _summary(),
  );
}

Duration _at(int rep) => Duration(seconds: rep * 4);

void main() {
  group('RepScorer', () {
    test('a repetition with no problems scores 100', () {
      final result = RepScorer([_rule('a', severity: 0)]).score(1, _summary());

      expect(result.score, 100);
      expect(result.quality, RepQuality.excellent);
      expect(result.faults, isEmpty);
      expect(result.index, 1);
    });

    test('a fault takes off its weight scaled by severity', () {
      final scorer = RepScorer([_rule('a', severity: 0.5, weight: 30)]);

      final result = scorer.score(1, _summary());

      expect(result.score, 85);
      expect(result.quality, RepQuality.good);
      expect(result.faultCodes, {'a'});
    });

    test('several faults add up', () {
      final scorer = RepScorer([
        _rule('a', severity: 1, weight: 30),
        _rule('b', severity: 0.5, weight: 20),
      ]);

      expect(scorer.score(1, _summary()).score, 60);
    });

    test('the score never goes below zero', () {
      final scorer = RepScorer([
        _rule('a', severity: 1, weight: 80),
        _rule('b', severity: 1, weight: 80),
      ]);

      expect(scorer.score(1, _summary()).score, 0);
    });

    test('a severity above 1 counts as 1', () {
      final scorer = RepScorer([_rule('a', severity: 5, weight: 30)]);

      expect(scorer.score(1, _summary()).score, 70);
    });

    test('rules can look at the measurements of the repetition', () {
      final depth = FormRule(
        code: 'depth',
        cue: 'Go deeper',
        weight: 30,
        check: (rep) => rep.stat('x').min > 100 ? 1 : 0,
      );
      final scorer = RepScorer([depth]);

      expect(scorer.score(1, _summary(minValue: 90)).faults, isEmpty);
      expect(scorer.score(2, _summary(minValue: 120)).faultCodes, {'depth'});
    });

    test('asking for a metric that was not measured is an error', () {
      expect(() => _summary().stat('missing'), throwsStateError);
    });

    test('quality grades follow the score', () {
      expect(RepQuality.fromScore(100), RepQuality.excellent);
      expect(RepQuality.fromScore(90), RepQuality.excellent);
      expect(RepQuality.fromScore(89.9), RepQuality.good);
      expect(RepQuality.fromScore(75), RepQuality.good);
      expect(RepQuality.fromScore(74.9), RepQuality.needsWork);
      expect(RepQuality.fromScore(50), RepQuality.needsWork);
      expect(RepQuality.fromScore(49.9), RepQuality.poor);
      expect(RepQuality.excellent.label, 'Excellent');
    });
  });

  group('CueManager', () {
    late CueManager cues;

    setUp(() => cues = CueManager());

    test('a fault seen once is not mentioned yet', () {
      expect(cues.onRep(_rep(1, [_fault('a')]), _at(1)), isNull);
    });

    test('a fault in two of the last three reps is mentioned', () {
      cues.onRep(_rep(1, [_fault('a')]), _at(1));
      cues.onRep(_rep(2), _at(2));

      final cue = cues.onRep(_rep(3, [_fault('a')]), _at(3));

      expect(cue?.code, 'a');
      expect(cue?.text, 'Fix a');
      expect(cue?.kind, CueKind.correction);
    });

    test('a fault that stopped long ago is forgotten', () {
      cues.onRep(_rep(1, [_fault('a')]), _at(1));
      cues.onRep(_rep(2), _at(2));
      cues.onRep(_rep(3), _at(3));

      // The first rep with the fault is now outside the window of three.
      expect(cues.onRep(_rep(4, [_fault('a')]), _at(4)), isNull);
    });

    test('a safety fault is mentioned straight away', () {
      final cue = cues.onRep(_rep(1, [_fault('s', safety: true)]), _at(1));

      expect(cue?.code, 's');
      expect(cue?.kind, CueKind.safety);
    });

    test('the same cue is not repeated too soon', () {
      final results = [
        for (var i = 1; i <= 5; i++)
          cues.onRep(_rep(i, [_fault('a')]), _at(i))?.code,
      ];

      expect(results, [null, 'a', null, null, 'a']);
    });

    test('only one cue is given, the costliest fault first', () {
      cues.onRep(
        _rep(1, [_fault('big', weight: 30), _fault('small', weight: 10)]),
        _at(1),
      );

      final cue = cues.onRep(
        _rep(2, [_fault('small', weight: 10), _fault('big', weight: 30)]),
        _at(2),
      );

      expect(cue?.code, 'big');
    });

    test('a cue held back is given on a later repetition', () {
      final faults = [_fault('big', weight: 30), _fault('small', weight: 10)];
      cues.onRep(_rep(1, faults), _at(1));
      final second = cues.onRep(_rep(2, faults), _at(2));
      final third = cues.onRep(_rep(3, faults), _at(3));

      expect(second?.code, 'big');
      expect(third?.code, 'small');
    });

    test('safety comes before a costlier ordinary fault', () {
      final faults = [
        _fault('big', weight: 40),
        _fault('s', weight: 5, safety: true),
      ];
      cues.onRep(_rep(1, [_fault('big', weight: 40)]), _at(1));

      final cue = cues.onRep(_rep(2, faults), _at(2));

      expect(cue?.code, 's');
    });

    test('praises three excellent repetitions in a row', () {
      final results = [
        for (var i = 1; i <= 6; i++) cues.onRep(_rep(i), _at(i))?.code,
      ];

      expect(results, [null, null, 'praise', null, null, 'praise']);
      expect(cues.onRep(_rep(7, [_fault('a')]), _at(7)), isNull);
    });

    test('a faulty repetition restarts the praise count', () {
      cues.onRep(_rep(1), _at(1));
      cues.onRep(_rep(2), _at(2));
      cues.onRep(_rep(3, [_fault('a')]), _at(3));

      expect(cues.onRep(_rep(4), _at(4)), isNull);
      expect(cues.onRep(_rep(5), _at(5)), isNull);
      expect(cues.onRep(_rep(6), _at(6))?.kind, CueKind.encouragement);
    });

    test('partial reps get a cue that is limited by time', () {
      final first = cues.onPartialRep('Go deeper', const Duration(seconds: 10));
      final soon = cues.onPartialRep('Go deeper', const Duration(seconds: 13));
      final later = cues.onPartialRep('Go deeper', const Duration(seconds: 20));

      expect(first?.text, 'Go deeper');
      expect(soon, isNull);
      expect(later, isNotNull);
    });

    test('losing the person gives a cue again after a while', () {
      final first = cues.onPoseLost(const Duration(seconds: 10));
      final soon = cues.onPoseLost(const Duration(seconds: 12));
      final later = cues.onPoseLost(const Duration(seconds: 20));

      expect(first?.kind, CueKind.info);
      expect(first?.text, 'Step back into view');
      expect(soon, isNull);
      expect(later, isNotNull);
    });

    test('cues are spaced apart, except safety cues', () {
      cues.onPoseLost(const Duration(seconds: 10));

      final partial = cues.onPartialRep(
        'Go deeper',
        const Duration(milliseconds: 10500),
      );
      final safety = cues.onRep(
        _rep(1, [_fault('s', safety: true)]),
        const Duration(milliseconds: 10500),
      );

      expect(partial, isNull);
      expect(safety?.code, 's');
    });

    test('reset forgets earlier repetitions and cooldowns', () {
      cues.onRep(_rep(1, [_fault('a')]), _at(1));
      cues.onRep(_rep(2, [_fault('a')]), _at(2));

      cues.reset();

      expect(cues.onRep(_rep(1, [_fault('a')]), _at(1)), isNull);
      expect(cues.onRep(_rep(2, [_fault('a')]), _at(2))?.code, 'a');
    });
  });
}

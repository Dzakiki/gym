import 'package:formcoach/data/repositories/coach_result.dart';
import 'package:formcoach/features/form_coach/coach_controller.dart';

/// Turns the state of a finished coached set into a result that can be saved.
/// [isHold] is true for time-based exercises such as the plank.
CoachResult coachResultFromState(CoachState state, {required bool isHold}) {
  return CoachResult(
    repsCounted: state.repCount,
    partialReps: state.partialCount,
    holdSeconds: isHold ? state.holdTime.inMilliseconds / 1000 : null,
    setScore: state.setScore,
    reps: [
      for (final rep in state.reps)
        RepResult(
          score: rep.score,
          faults: rep.faultCodes.toList(),
          descentMs: rep.summary.descent.inMilliseconds,
          ascentMs: rep.summary.ascent.inMilliseconds,
        ),
    ],
  );
}

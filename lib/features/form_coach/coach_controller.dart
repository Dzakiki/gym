import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/features/form_coach/cue_player.dart';
import 'package:formcoach/features/form_coach/demo/pose_synth.dart';
import 'package:formcoach/features/form_coach/engine/coach_session.dart';
import 'package:formcoach/features/form_coach/engine/cue_manager.dart';
import 'package:formcoach/features/form_coach/engine/rep_scorer.dart';
import 'package:formcoach/features/form_coach/exercises/registry.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';
import 'package:formcoach/features/form_coach/pose/pose_source.dart';
import 'package:formcoach/features/form_coach/tts_cue_player.dart';
import 'package:formcoach/features/settings/settings_providers.dart';

enum CoachStatus {
  /// Waiting for the athlete to start.
  ready,

  /// A set is being coached.
  running,

  /// The set is over.
  finished,
}

/// What the coach screen shows.
class CoachState {
  const CoachState({
    this.status = CoachStatus.ready,
    this.latest,
    this.reps = const [],
    this.partialCount = 0,
    this.cue,
    this.holdScore,
  });

  final CoachStatus status;

  /// The most recent frame's result, for drawing the skeleton.
  final CoachUpdate? latest;

  /// The judged repetitions of this set.
  final List<RepAnalysis> reps;
  final int partialCount;

  /// The cue being shown right now, if any.
  final Cue? cue;

  /// For hold exercises: the share of the time with good form (0 to 100).
  final double? holdScore;

  /// For hold exercises: how long good form has been held.
  Duration get holdTime => latest?.holdTime ?? Duration.zero;

  int get repCount => reps.length;

  RepAnalysis? get lastRep => reps.isEmpty ? null : reps.last;

  double? get setScore =>
      holdScore ??
      (reps.isEmpty
          ? null
          : reps.fold<double>(0, (sum, r) => sum + r.score) / reps.length);

  CoachState copyWith({
    CoachStatus? status,
    CoachUpdate? latest,
    List<RepAnalysis>? reps,
    int? partialCount,
    Cue? cue,
    double? holdScore,
    bool clearCue = false,
  }) => CoachState(
    status: status ?? this.status,
    latest: latest ?? this.latest,
    reps: reps ?? this.reps,
    partialCount: partialCount ?? this.partialCount,
    cue: clearCue ? null : cue ?? this.cue,
    holdScore: holdScore ?? this.holdScore,
  );
}

/// Where poses come from. Replaced by the camera on a real device; until then
/// the app plays a simulated set of squats.
final poseSourceProvider = Provider<PoseSource>((ref) {
  return ReplayPoseSource(squatFrames(const SquatMotion(reps: 5)));
});

/// Speaks the coach's cues, or says nothing when spoken cues are switched off
/// in the settings.
final cuePlayerProvider = Provider<CuePlayer>((ref) {
  if (!ref.watch(voiceCuesProvider)) return const SilentCuePlayer();
  return TtsCuePlayer(FlutterTtsEngine());
});

/// Runs a coached set of the exercise with the given `coach_key`.
class CoachController extends Notifier<CoachState> {
  CoachController(this.coachKey);

  /// How long a cue stays on screen.
  static const cueDisplayTime = Duration(milliseconds: 2500);

  final String coachKey;

  CoachSession? _session;
  StreamSubscription<PoseFrame>? _subscription;
  Timer? _cueTimer;

  @override
  CoachState build() {
    ref.onDispose(_release);
    return const CoachState();
  }

  /// Starts a new set. Throws [StateError] if the exercise has no coach.
  void start() {
    if (state.status == CoachStatus.running) return;
    final definition = coachDefinitionFor(coachKey);
    if (definition == null) {
      throw StateError('No coach for exercise "$coachKey".');
    }
    _release();
    _session = CoachSession(definition: definition);
    state = const CoachState(status: CoachStatus.running);
    _subscription = ref
        .read(poseSourceProvider)
        .frames()
        .listen(_onFrame, onDone: stop);
  }

  /// Ends the set. The results stay in [state].
  void stop() {
    if (state.status != CoachStatus.running) return;
    _release();
    unawaited(ref.read(cuePlayerProvider).stop());
    state = state.copyWith(status: CoachStatus.finished, clearCue: true);
  }

  void _onFrame(PoseFrame frame) {
    final session = _session;
    if (session == null) return;

    final update = session.update(frame);
    state = state.copyWith(
      latest: update,
      reps: session.reps,
      partialCount: session.partialCount,
      holdScore: session.holdScore,
    );

    final cue = update.cue;
    if (cue != null) _showCue(cue);
  }

  void _showCue(Cue cue) {
    state = state.copyWith(cue: cue);
    unawaited(ref.read(cuePlayerProvider).speak(cue.text));
    _cueTimer?.cancel();
    _cueTimer = Timer(cueDisplayTime, () {
      if (state.cue == cue) state = state.copyWith(clearCue: true);
    });
  }

  void _release() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _cueTimer?.cancel();
    _cueTimer = null;
    _session = null;
  }
}

final coachControllerProvider = NotifierProvider.autoDispose
    .family<CoachController, CoachState, String>(CoachController.new);

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/core/widgets/empty_state.dart';
import 'package:formcoach/data/providers.dart';
import 'package:formcoach/features/form_coach/camera/camera_pose_source.dart';
import 'package:formcoach/features/form_coach/coach_controller.dart';
import 'package:formcoach/features/form_coach/coach_input.dart';
import 'package:formcoach/features/form_coach/coach_result_builder.dart';
import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/cue_manager.dart';
import 'package:formcoach/features/form_coach/engine/exercise_definition.dart';
import 'package:formcoach/features/form_coach/engine/rep_scorer.dart';
import 'package:formcoach/features/form_coach/engine/setup_check.dart';
import 'package:formcoach/features/form_coach/exercises/registry.dart';
import 'package:formcoach/features/form_coach/ui/set_summary.dart';
import 'package:formcoach/features/form_coach/ui/skeleton_painter.dart';
import 'package:formcoach/features/settings/settings_providers.dart';
import 'package:formcoach/features/workout/workout_formatting.dart';
import 'package:go_router/go_router.dart';

/// Coaches one set: shows the body, counts reps, gives cues and, at the end,
/// the results.
class CoachSessionScreen extends ConsumerWidget {
  const CoachSessionScreen({required this.coachKey, this.setLogId, super.key});

  final String coachKey;

  /// The set of the workout in progress to save the results into, if any.
  final String? setLogId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definition = coachDefinitionFor(coachKey);
    if (definition == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Coach')),
        body: const EmptyState(
          icon: Icons.videocam_off_outlined,
          title: 'No coach for this exercise yet',
        ),
      );
    }
    return _CoachView(definition: definition, setLogId: setLogId);
  }
}

class _CoachView extends ConsumerStatefulWidget {
  const _CoachView({required this.definition, required this.setLogId});

  final ExerciseDefinition definition;
  final String? setLogId;

  @override
  ConsumerState<_CoachView> createState() => _CoachViewState();
}

/// Owns the camera: opens it (after explaining why, the first time), lets
/// it go while the app is in the background, and hands it to the controller
/// for each set.
class _CoachViewState extends ConsumerState<_CoachView>
    with WidgetsBindingObserver {
  late CoachInput _input;
  CameraLensDirection _lens = CameraLensDirection.back;
  CameraPoseSource? _camera;
  Object? _cameraError;
  bool _explaining = false;
  bool _opening = false;

  /// The camera was let go because the app went to the background.
  bool _suspended = false;

  String get _key => widget.definition.key;

  CoachController get _controller =>
      ref.read(coachControllerProvider(_key).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _input = ref.read(defaultCoachInputProvider);
    if (_input == CoachInput.camera) _prepareCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_closeCamera());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (_input != CoachInput.camera) return;
    switch (lifecycle) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        if (_camera == null && !_opening) return;
        _suspended = true;
        _controller.stop();
        unawaited(_closeCamera());
        setState(() {});
      case AppLifecycleState.resumed:
        if (!_suspended) return;
        _suspended = false;
        unawaited(_openCamera());
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        // Inactive also happens while the permission dialog is up.
        break;
    }
  }

  /// Explains the camera the first time, otherwise opens it.
  void _prepareCamera() {
    if (ref.read(settingsStoreProvider).cameraExplained) {
      unawaited(_openCamera());
    } else {
      _explaining = true;
    }
  }

  Future<void> _acceptExplanation() async {
    setState(() => _explaining = false);
    await ref.read(settingsStoreProvider).setCameraExplained();
    await _openCamera();
  }

  Future<void> _openCamera() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _cameraError = null;
    });
    try {
      final camera = await ref.read(openCameraProvider)(_lens);
      if (!mounted || _suspended || _input != CoachInput.camera) {
        await camera.dispose();
        return;
      }
      setState(() => _camera = camera);
    } on Object catch (error) {
      if (mounted) setState(() => _cameraError = error);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _closeCamera() async {
    final camera = _camera;
    _camera = null;
    await camera?.dispose();
  }

  Future<void> _switchLens() async {
    await _closeCamera();
    setState(() {
      _lens = _lens == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;
    });
    await _openCamera();
  }

  Future<void> _switchInput() async {
    _controller.stop();
    final toCamera = _input == CoachInput.demo;
    setState(() {
      _input = toCamera ? CoachInput.camera : CoachInput.demo;
      _cameraError = null;
      _explaining = false;
    });
    if (toCamera) {
      _prepareCamera();
      setState(() {});
    } else {
      await _closeCamera();
      if (mounted) setState(() {});
    }
  }

  void _start() {
    if (_input == CoachInput.camera) {
      final camera = _camera;
      if (camera == null) return;
      _controller.start(source: camera, setUp: true);
    } else {
      _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final definition = widget.definition;
    final state = ref.watch(coachControllerProvider(_key));
    final idle =
        state.status == CoachStatus.ready ||
        state.status == CoachStatus.finished;
    final usingCamera = _input == CoachInput.camera;
    final setLogId = widget.setLogId;
    final camera = _camera;
    final canStart = !usingCamera || camera != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(definition.name),
        actions: [
          if (usingCamera && camera != null)
            IconButton(
              tooltip: 'Switch camera',
              icon: const Icon(Icons.cameraswitch_outlined),
              onPressed: idle ? _switchLens : null,
            ),
          IconButton(
            tooltip: usingCamera ? 'Use the demo' : 'Use the camera',
            icon: Icon(
              usingCamera ? Icons.smart_toy_outlined : Icons.videocam_outlined,
            ),
            onPressed: idle ? _switchInput : null,
          ),
        ],
      ),
      body: ListView(
        children: [
          _picture(context, state, definition),
          if (state.status == CoachStatus.finished)
            if (definition.isHold)
              HoldSummary(holdTime: state.holdTime, score: state.holdScore)
            else
              SetSummary(reps: state.reps, partialCount: state.partialCount),
          if (state.status == CoachStatus.ready)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                usingCamera
                    ? '${setupInstruction(definition.view)} '
                          'The video stays on your phone.'
                    : 'Demo mode: a simulated person is shown instead of '
                          'the camera.',
              ),
            ),
        ],
      ),
      // Pinned below the list so the buttons (and Save) are always in reach,
      // however long the summary is, and clear of the system gesture bar.
      bottomNavigationBar: _explaining || (usingCamera && _cameraError != null)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _Controls(
                  state: state,
                  onStart: canStart ? _start : null,
                  onStop: _controller.stop,
                  onSave: setLogId == null
                      ? null
                      : () => _saveResults(
                          context,
                          ref,
                          coachKey: _key,
                          setLogId: setLogId,
                          isHold: definition.isHold,
                          state: state,
                        ),
                ),
              ),
            ),
    );
  }

  Widget _picture(
    BuildContext context,
    CoachState state,
    ExerciseDefinition definition,
  ) {
    final overlay = _Overlay(state: state, isHold: definition.isHold);
    if (_input == CoachInput.demo) {
      return AspectRatio(
        aspectRatio: 1,
        child: ColoredBox(color: Colors.black, child: overlay),
      );
    }
    if (_explaining) {
      return _CameraExplainer(
        view: definition.view,
        onContinue: _acceptExplanation,
        onUseDemo: _switchInput,
      );
    }
    if (_cameraError case final error?) {
      return _CameraProblem(
        error: error,
        onRetry: _openCamera,
        onUseDemo: _switchInput,
      );
    }
    final camera = _camera;
    if (camera == null) {
      return const AspectRatio(
        aspectRatio: 1,
        child: ColoredBox(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return CameraPreview(camera.controller, child: ClipRect(child: overlay));
  }
}

Future<void> _saveResults(
  BuildContext context,
  WidgetRef ref, {
  required String coachKey,
  required String setLogId,
  required bool isHold,
  required CoachState state,
}) async {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  await ref
      .read(coachRepositoryProvider)
      .saveCoachedSet(
        setLogId: setLogId,
        exerciseKey: coachKey,
        result: coachResultFromState(state, isHold: isHold),
      );
  messenger.showSnackBar(
    const SnackBar(content: Text('Saved to your workout')),
  );
  router.pop();
}

/// Why the coach needs the camera, shown before Android asks for it.
class _CameraExplainer extends StatelessWidget {
  const _CameraExplainer({
    required this.view,
    required this.onContinue,
    required this.onUseDemo,
  });

  final CameraView view;
  final VoidCallback onContinue;
  final VoidCallback onUseDemo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.videocam_outlined,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'The coach watches you through the camera',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'It counts your reps and checks your form while you move. '
            'The video is analysed on your phone and never uploaded or '
            'saved.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(setupInstruction(view), style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          FilledButton(onPressed: onContinue, child: const Text('Continue')),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onUseDemo,
            child: const Text('Try the demo instead'),
          ),
        ],
      ),
    );
  }
}

/// Shown when the camera can't be used.
class _CameraProblem extends StatelessWidget {
  const _CameraProblem({
    required this.error,
    required this.onRetry,
    required this.onUseDemo,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onUseDemo;

  /// True when the camera permission was refused.
  static bool isDenied(Object error) =>
      error is CameraException && error.code.startsWith('CameraAccess');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final denied = isDenied(error);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.videocam_off_outlined,
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            denied ? 'Camera access is off' : 'The camera could not be opened',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            denied
                ? 'Allow the camera for FormCoach in your phone\'s settings '
                      '(Apps > FormCoach > Permissions), then try again.'
                : '$error',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onUseDemo,
            child: const Text('Try the demo instead'),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.state,
    required this.onStart,
    required this.onStop,
    required this.onSave,
  });

  final CoachState state;

  /// Null while a set can't be started (the camera is still opening).
  final VoidCallback? onStart;
  final VoidCallback onStop;

  /// Saves the results into the workout. Null when there is nothing to save
  /// them into.
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case CoachStatus.ready:
        return FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start'),
          onPressed: onStart,
        );
      case CoachStatus.settingUp:
        return OutlinedButton.icon(
          icon: const Icon(Icons.close),
          label: const Text('Cancel'),
          onPressed: onStop,
        );
      case CoachStatus.running:
        return FilledButton.icon(
          icon: const Icon(Icons.stop),
          label: const Text('Stop'),
          onPressed: onStop,
        );
      case CoachStatus.finished:
        final canSave =
            onSave != null &&
            (state.repCount > 0 || state.holdTime > Duration.zero);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (canSave) ...[
              FilledButton.icon(
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save to workout'),
                onPressed: onSave,
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Done'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onStart,
                    child: const Text('Again'),
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }
}

/// Drawn over the picture (camera or demo): skeleton, rep count, last score,
/// current cue and, before the set, what to fix.
class _Overlay extends StatelessWidget {
  const _Overlay({required this.state, required this.isHold});

  final CoachState state;
  final bool isHold;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => _layers(context, constraints.maxWidth),
    );
  }

  Widget _layers(BuildContext context, double width) {
    final theme = Theme.of(context);
    final settingUp = state.status == CoachStatus.settingUp;
    final latest = state.latest;
    final tracking = latest?.tracking ?? true;
    final setup = state.setup;
    final placed = setup != null && setup.problem == null && setup.progress > 0;
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: SkeletonPainter(
            frame: settingUp
                ? state.setupFrame
                : tracking
                ? latest?.frame
                : null,
            boneColor: settingUp
                ? (placed ? theme.colorScheme.primary : Colors.white)
                : (latest?.formValid ?? true)
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
            jointColor: Colors.white,
          ),
        ),
        if (!settingUp)
          Positioned(
            left: 16,
            top: 8,
            child: Semantics(
              label: isHold
                  ? '${state.holdTime.inSeconds} seconds'
                  : '${state.repCount} reps',
              child: ExcludeSemantics(
                child: Text(
                  isHold
                      ? formatClock(state.holdTime.inSeconds)
                      : '${state.repCount}',
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        if (state.lastRep case final rep?)
          Positioned(
            right: 16,
            top: 16,
            child: ConstrainedBox(
              // Never reaches the middle, where the person is, whatever
              // the text size.
              constraints: BoxConstraints(maxWidth: width * 0.3),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topRight,
                child: _RepChip(rep: rep),
              ),
            ),
          ),
        if (state.status == CoachStatus.running && !tracking)
          const Center(
            child: Text(
              'Step back into view',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        if (settingUp)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _SetupBanner(setup: setup),
          )
        else if (state.cue case final cue?)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _CueBanner(cue: cue),
          ),
      ],
    );
  }
}

/// What to fix before the set starts, and how long to hold still.
class _SetupBanner extends StatelessWidget {
  const _SetupBanner({required this.setup});

  final SetupStatus? setup;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final problem = setup?.problem;
    final progress = setup?.progress ?? 0;
    final text =
        problem?.hint ?? (progress > 0 ? 'Hold still' : 'Get into position');
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: scheme.onSecondaryContainer),
            ),
            if (problem == null && progress > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
            ],
          ],
        ),
      ),
    );
  }
}

/// The score of the last rep. Kept short so it stays in the corner, clear of
/// the person in the middle of the picture; the colour shows the quality.
class _RepChip extends StatelessWidget {
  const _RepChip({required this.rep});

  final RepAnalysis rep;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final score = rep.score.round();
    return Semantics(
      label: 'Rep ${rep.index}, score $score, ${rep.quality.label}',
      child: ExcludeSemantics(
        child: Chip(
          backgroundColor: qualityColor(rep.quality, scheme),
          label: Text(
            'Rep ${rep.index} · $score',
            style: TextStyle(color: scheme.surface),
          ),
        ),
      ),
    );
  }
}

class _CueBanner extends StatelessWidget {
  const _CueBanner({required this.cue});

  final Cue cue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (cue.kind) {
      CueKind.safety => (scheme.errorContainer, scheme.onErrorContainer),
      CueKind.encouragement => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      CueKind.correction ||
      CueKind.info => (scheme.secondaryContainer, scheme.onSecondaryContainer),
    };
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          cue.text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: foreground),
        ),
      ),
    );
  }
}

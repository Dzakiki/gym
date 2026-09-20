import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/core/widgets/empty_state.dart';
import 'package:formcoach/features/form_coach/coach_controller.dart';
import 'package:formcoach/features/form_coach/engine/cue_manager.dart';
import 'package:formcoach/features/form_coach/engine/rep_scorer.dart';
import 'package:formcoach/features/form_coach/exercises/registry.dart';
import 'package:formcoach/features/form_coach/ui/set_summary.dart';
import 'package:formcoach/features/form_coach/ui/skeleton_painter.dart';
import 'package:formcoach/features/workout/workout_formatting.dart';
import 'package:go_router/go_router.dart';

/// Coaches one set: shows the body, counts reps, gives cues and, at the end,
/// the results.
class CoachSessionScreen extends ConsumerWidget {
  const CoachSessionScreen({required this.coachKey, super.key});

  final String coachKey;

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

    final state = ref.watch(coachControllerProvider(coachKey));
    final controller = ref.read(coachControllerProvider(coachKey).notifier);
    return Scaffold(
      appBar: AppBar(title: Text(definition.name)),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: _Preview(state: state, isHold: definition.isHold),
          ),
          if (state.status == CoachStatus.finished)
            if (definition.isHold)
              HoldSummary(holdTime: state.holdTime, score: state.holdScore)
            else
              SetSummary(reps: state.reps, partialCount: state.partialCount),
          if (state.status == CoachStatus.ready)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                'Demo mode: a simulated person is shown until the camera is '
                'connected.',
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _Controls(state: state, controller: controller),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state, required this.controller});

  final CoachState state;
  final CoachController controller;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case CoachStatus.ready:
        return FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start'),
          onPressed: controller.start,
        );
      case CoachStatus.running:
        return FilledButton.icon(
          icon: const Icon(Icons.stop),
          label: const Text('Stop'),
          onPressed: controller.stop,
        );
      case CoachStatus.finished:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.pop(),
                child: const Text('Done'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: controller.start,
                child: const Text('Again'),
              ),
            ),
          ],
        );
    }
  }
}

/// The dark picture area: skeleton, rep count, last score and current cue.
class _Preview extends StatelessWidget {
  const _Preview({required this.state, required this.isHold});

  final CoachState state;
  final bool isHold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = state.latest;
    final tracking = latest?.tracking ?? true;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: SkeletonPainter(
              frame: tracking ? latest?.frame : null,
              boneColor: (latest?.formValid ?? true)
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
              jointColor: Colors.white,
            ),
          ),
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
            Positioned(right: 16, top: 16, child: _RepChip(rep: rep)),
          if (state.status == CoachStatus.running && !tracking)
            const Center(
              child: Text(
                'Step back into view',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
          if (state.cue case final cue?)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _CueBanner(cue: cue),
            ),
        ],
      ),
    );
  }
}

class _RepChip extends StatelessWidget {
  const _RepChip({required this.rep});

  final RepAnalysis rep;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      backgroundColor: qualityColor(rep.quality, scheme),
      label: Text(
        'Rep ${rep.index}: ${rep.score.round()} ${rep.quality.label}',
        style: TextStyle(color: scheme.surface),
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

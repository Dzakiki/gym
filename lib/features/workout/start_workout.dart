import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/app/routes.dart';
import 'package:formcoach/data/providers.dart';
import 'package:go_router/go_router.dart';

/// Starts a workout (from [routineId], or empty) and opens it.
///
/// Only one workout can run at a time: if one is already in progress it is
/// opened instead, with a message.
Future<void> startWorkout(
  BuildContext context,
  WidgetRef ref, {
  String? routineId,
}) async {
  final repository = ref.read(workoutRepositoryProvider);
  final active = await repository.getActiveSession();
  if (!context.mounted) return;

  if (active != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Finish your current workout first.')),
    );
    context.go(AppRoutes.workout(active.id));
    return;
  }
  final id = await repository.startWorkout(routineId: routineId);
  if (context.mounted) context.go(AppRoutes.workout(id));
}

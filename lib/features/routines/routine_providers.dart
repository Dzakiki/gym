import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/data/local/app_database.dart';
import 'package:formcoach/data/providers.dart';
import 'package:formcoach/data/repositories/routine_repository.dart';

/// The user's routines (`false`) or the built-in templates (`true`).
final routinesProvider = StreamProvider.autoDispose.family<List<Routine>, bool>(
  (ref, templates) {
    return ref
        .watch(routineRepositoryProvider)
        .watchRoutines(templates: templates);
  },
);

final routineDetailProvider = StreamProvider.autoDispose
    .family<RoutineDetail?, String>((ref, id) {
      return ref.watch(routineRepositoryProvider).watchDetail(id);
    });

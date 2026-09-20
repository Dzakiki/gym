import 'dart:async';

import 'package:drift/drift.dart';
import 'package:formcoach/data/local/app_database.dart';

/// Emits the result of [load] now and again whenever one of [tables] changes.
///
/// Use this for values that are assembled from several queries, where a plain
/// Drift `watch()` cannot be used. Cancelling the subscription stops all
/// further loading.
Stream<T> watchLoad<T>({
  required AppDatabase database,
  required List<ResultSetImplementation<dynamic, dynamic>> tables,
  required Future<T> Function() load,
}) {
  late final StreamController<T> controller;
  StreamSubscription<void>? updates;

  Future<void> emit() async {
    try {
      final value = await load();
      if (!controller.isClosed) controller.add(value);
    } on Object catch (error, stackTrace) {
      if (!controller.isClosed) controller.addError(error, stackTrace);
    }
  }

  controller = StreamController<T>(
    onListen: () {
      unawaited(emit());
      updates = database
          .tableUpdates(TableUpdateQuery.onAllTables(tables))
          .listen((_) => unawaited(emit()));
    },
    onCancel: () async {
      await updates?.cancel();
      await controller.close();
    },
  );
  return controller.stream;
}

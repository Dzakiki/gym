import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/data/local/app_database.dart';

/// The single on-device database. Tests override this with an in-memory one.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.persistent();
  ref.onDispose(database.close);
  return database;
});

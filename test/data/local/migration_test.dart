import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/data/local/app_database.dart';

void main() {
  test('upgrading from version 1 adds the coach analyses table', () async {
    // A database whose stored version is 1 is upgraded, not created.
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA user_version = 1'),
      ),
    );

    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'coach_analyses'",
        )
        .get();

    expect(tables, hasLength(1));
    expect(await db.select(db.coachAnalyses).get(), isEmpty);
    await db.close();
  });

  test('a new database has the current schema version', () async {
    final db = AppDatabase(NativeDatabase.memory());

    expect(db.schemaVersion, 2);
    expect(await db.select(db.coachAnalyses).get(), isEmpty);
    await db.close();
  });
}

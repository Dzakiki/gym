import 'package:drift/drift.dart';

/// Columns shared by every synced table.
///
/// Rows are never hard-deleted: [deletedAt] marks a soft delete so the change
/// can be pushed to the server. All timestamps are UTC.
mixin SyncColumns on Table {
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

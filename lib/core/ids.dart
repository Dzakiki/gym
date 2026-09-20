import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Creates unique ids for new rows. Ids are generated on the device so data
/// can be created offline and synced later without conflicts.
typedef IdGenerator = String Function();

final idGeneratorProvider = Provider<IdGenerator>((ref) {
  const uuid = Uuid();
  return () => uuid.v4();
});

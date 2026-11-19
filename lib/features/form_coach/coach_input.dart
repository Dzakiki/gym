import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the coach screen takes poses from.
enum CoachInput {
  /// The phone's camera, with a setup check before each set.
  camera,

  /// A simulated person, to try the coach without filming.
  demo,
}

/// What the coach screen starts with. Tests, which have no camera, use the
/// demo.
final defaultCoachInputProvider = Provider<CoachInput>(
  (ref) => CoachInput.camera,
);

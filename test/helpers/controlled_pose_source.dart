import 'dart:async';

import 'package:formcoach/features/form_coach/pose/pose.dart';
import 'package:formcoach/features/form_coach/pose/pose_source.dart';

/// A pose source that tests push frames into.
class ControlledPoseSource implements PoseSource {
  // Broadcast, so closing works even if nobody ever listened.
  final controller = StreamController<PoseFrame>.broadcast();

  @override
  Stream<PoseFrame> frames() => controller.stream;

  void addAll(List<PoseFrame> frames) => frames.forEach(controller.add);

  Future<void> close() => controller.close();
}

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/features/form_coach/camera/frame_stats.dart';
import 'package:formcoach/features/form_coach/camera/mlkit_pose_mapping.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';
import 'package:formcoach/features/form_coach/pose/pose_source.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Opens the camera for pose detection. Replaced in tests, which have no
/// camera.
final openCameraProvider =
    Provider<Future<CameraPoseSource> Function(CameraLensDirection lens)>(
      (ref) =>
          (lens) => CameraPoseSource.open(lens: lens),
    );

/// Poses from the phone's camera, found by ML Kit on the phone itself.
///
/// Frames that arrive while the previous one is still being analysed are
/// dropped, so the coach always works on the newest picture. A frame in
/// which nobody is found gives a [PoseFrame] without points.
class CameraPoseSource implements PoseSource {
  CameraPoseSource._(this.controller, this._detector);

  /// Opens the camera facing [lens] (or the first camera if there is none).
  ///
  /// Throws [CameraException] if the camera can't be opened, for example
  /// with code `CameraAccessDenied` when the permission is refused.
  static Future<CameraPoseSource> open({
    CameraLensDirection lens = CameraLensDirection.back,
  }) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException('NoCamera', 'This device has no camera.');
    }
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == lens,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    try {
      await controller.initialize();
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
    final detector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
    return CameraPoseSource._(controller, detector);
  }

  /// For the camera preview.
  final CameraController controller;
  final PoseDetector _detector;

  /// How the pipeline is keeping up, updated with every analysed frame.
  final ValueNotifier<FrameStats> stats = ValueNotifier(const FrameStats());

  final Stopwatch _clock = Stopwatch();
  final RateMeter _analyzed = RateMeter();
  final RateMeter _dropped = RateMeter();
  StreamController<PoseFrame>? _output;
  bool _busy = false;
  bool _disposed = false;

  bool get isFrontCamera =>
      controller.description.lensDirection == CameraLensDirection.front;

  @override
  Stream<PoseFrame> frames() {
    late final StreamController<PoseFrame> output;
    output = StreamController<PoseFrame>(
      onListen: () {
        _output = output;
        _clock
          ..reset()
          ..start();
        unawaited(controller.startImageStream(_onImage));
      },
      onCancel: () async {
        _output = null;
        unawaited(output.close());
        if (!_disposed && controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      },
    );
    return output.stream;
  }

  /// Starts recording a video while poses keep being detected.
  Future<void> startRecording() async {
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller.startVideoRecording(onAvailable: _onImage);
  }

  /// Stops the recording and goes back to detecting poses only.
  Future<XFile> stopRecording() async {
    final file = await controller.stopVideoRecording();
    if (_output != null) await controller.startImageStream(_onImage);
    return file;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _output?.close();
    await controller.dispose();
    await _detector.close();
    stats.dispose();
  }

  Future<void> _onImage(CameraImage image) async {
    final now = _clock.elapsed;
    if (_busy) {
      _dropped.add(now);
      return;
    }
    _busy = true;
    try {
      final rotation = _rotation();
      final input = _inputImage(image, rotation);
      if (input == null) return;

      final started = _clock.elapsed;
      final poses = await _detector.processImage(input);
      final detectionTime = _clock.elapsed - started;
      if (_disposed) return;

      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final frame = poses.isEmpty
          ? PoseFrame(timestamp: now, points: const {})
          : poseFrameFromMlKit(
              poses.first,
              uprightSize: uprightSize(imageSize, rotation),
              mirror: isFrontCamera,
              timestamp: now,
            );
      _output?.add(frame);

      _analyzed.add(now);
      stats.value = FrameStats(
        analyzedFps: _analyzed.rate(now),
        droppedFps: _dropped.rate(now),
        detectionTime: detectionTime,
        imageWidth: image.width,
        imageHeight: image.height,
        rotation: rotation,
      );
    } finally {
      _busy = false;
    }
  }

  int _rotation() => frameRotation(
    sensorOrientation: controller.description.sensorOrientation,
    frontCamera: isFrontCamera,
    deviceRotation: switch (controller.value.deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    },
  );

  /// The camera picture in the form ML Kit takes: NV21 with one plane on
  /// Android, BGRA on iOS.
  InputImage? _inputImage(CameraImage image, int rotation) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (format == null || image.planes.length != 1) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotationValue.fromRawValue(rotation)!,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }
}

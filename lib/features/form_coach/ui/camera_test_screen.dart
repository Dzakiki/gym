import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/features/form_coach/camera/camera_pose_source.dart';
import 'package:formcoach/features/form_coach/camera/frame_stats.dart';
import 'package:formcoach/features/form_coach/engine/body_side.dart';
import 'package:formcoach/features/form_coach/engine/geometry.dart';
import 'package:formcoach/features/form_coach/pose/pose.dart';
import 'package:formcoach/features/form_coach/ui/skeleton_painter.dart';

/// A developer screen that shows the live camera with the detected body on
/// top and how fast detection runs. Used to check the camera pipeline on a
/// real phone before the coach relies on it.
class CameraTestScreen extends ConsumerStatefulWidget {
  const CameraTestScreen({super.key});

  @override
  ConsumerState<CameraTestScreen> createState() => _CameraTestScreenState();
}

class _CameraTestScreenState extends ConsumerState<CameraTestScreen> {
  CameraPoseSource? _source;
  StreamSubscription<PoseFrame>? _subscription;
  PoseFrame? _frame;
  Object? _error;
  CameraLensDirection _lens = CameraLensDirection.back;
  bool _recording = false;
  String? _recordingResult;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  @override
  void dispose() {
    unawaited(_close());
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final source = await ref.read(openCameraProvider)(_lens);
      if (!mounted) {
        await source.dispose();
        return;
      }
      setState(() {
        _source = source;
        _error = null;
      });
      _subscription = source.frames().listen(
        (frame) => setState(() => _frame = frame),
      );
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _close() async {
    final source = _source;
    _source = null;
    await _subscription?.cancel();
    _subscription = null;
    await source?.dispose();
  }

  Future<void> _flip() async {
    await _close();
    setState(() {
      _frame = null;
      _lens = _lens == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;
    });
    await _open();
  }

  /// Records a short clip while detection keeps running, to see whether the
  /// phone can do both. The clip is deleted straight away.
  Future<void> _toggleRecording() async {
    final source = _source;
    if (source == null) return;
    try {
      if (!_recording) {
        await source.startRecording();
        setState(() {
          _recording = true;
          _recordingResult = null;
        });
        return;
      }
      final clip = await source.stopRecording();
      final file = File(clip.path);
      final megabytes = await file.length() / (1024 * 1024);
      await file.delete();
      setState(() {
        _recording = false;
        _recordingResult =
            'Recorded ${megabytes.toStringAsFixed(1)} MB (deleted).';
      });
    } on Object catch (error) {
      setState(() {
        _recording = false;
        _recordingResult = 'Recording failed: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera test'),
        actions: [
          IconButton(
            tooltip: 'Switch camera',
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: source == null || _recording ? null : _flip,
          ),
        ],
      ),
      body: switch ((source, _error)) {
        (_, final error?) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('The camera could not be opened.\n\n$error'),
          ),
        ),
        (null, _) => const Center(child: CircularProgressIndicator()),
        (final source?, _) => ListView(
          children: [
            CameraPreview(
              source.controller,
              child: ClipRect(
                child: CustomPaint(
                  painter: SkeletonPainter(
                    frame: _frame,
                    boneColor: Colors.white,
                    jointColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: source.stats,
              builder: (context, stats, _) => _StatsPanel(
                stats: stats,
                frame: _frame,
                previewSize: source.controller.value.previewSize,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                icon: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
                label: Text(_recording ? 'Stop recording' : 'Record a clip'),
                onPressed: _toggleRecording,
              ),
            ),
            if (_recordingResult case final result?)
              Padding(padding: const EdgeInsets.all(16), child: Text(result)),
          ],
        ),
      },
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({
    required this.stats,
    required this.frame,
    required this.previewSize,
  });

  final FrameStats stats;
  final PoseFrame? frame;
  final Size? previewSize;

  @override
  Widget build(BuildContext context) {
    final frame = this.frame;
    final seen = frame == null
        ? 0
        : Landmark.values.where((l) => frame.isVisible(l)).length;
    String knee(BodySide side) {
      final hip = frame?.position(side.hip);
      final knee = frame?.position(side.knee);
      final ankle = frame?.position(side.ankle);
      if (hip == null || knee == null || ankle == null) return '-';
      return '${angleAt(hip, knee, ankle).round()}°';
    }

    final preview = previewSize;
    final lines = [
      'Analysed ${stats.analyzedFps.toStringAsFixed(1)} fps, '
          'dropped ${stats.droppedFps.toStringAsFixed(1)} fps',
      'Detection ${stats.detectionTime.inMilliseconds} ms',
      'Image ${stats.imageWidth}x${stats.imageHeight}, '
          'turned ${stats.rotation}°',
      if (preview != null)
        'Preview ${preview.width.round()}x${preview.height.round()}',
      'Landmarks seen: $seen of ${Landmark.values.length}',
      'Knee angle: left ${knee(BodySide.left)}, '
          'right ${knee(BodySide.right)}',
    ];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        lines.join('\n'),
        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      ),
    );
  }
}

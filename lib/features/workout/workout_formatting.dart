/// Formats seconds as a clock, e.g. `1:05`.
String formatClock(int totalSeconds) {
  final seconds = totalSeconds < 0 ? 0 : totalSeconds;
  final minutes = seconds ~/ 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$rest';
}

/// Formats a duration for summaries, e.g. `45 min` or `1 h 5 min`.
String formatDuration(Duration duration) {
  final totalMinutes = duration.inMinutes;
  if (totalMinutes < 1) return '${duration.inSeconds} s';
  if (totalMinutes < 60) return '$totalMinutes min';
  final minutes = totalMinutes % 60;
  return minutes == 0
      ? '${totalMinutes ~/ 60} h'
      : '${totalMinutes ~/ 60} h $minutes min';
}

/// Formats a training volume in kilograms, e.g. `1,440 kg`.
String formatVolume(double kg) {
  final rounded = kg.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < rounded.length; i++) {
    if (i > 0 && (rounded.length - i) % 3 == 0) buffer.write(',');
    buffer.write(rounded[i]);
  }
  return '$buffer kg';
}

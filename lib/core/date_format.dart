const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Formats a date in the user's local time, e.g. `Sat 20 Sep 2026`.
String formatDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  final weekday = _weekdays[local.weekday - 1];
  final month = _months[local.month - 1];
  return '$weekday ${local.day} $month ${local.year}';
}

/// Formats a time in the user's local time as `HH:mm`, e.g. `07:05`.
String formatTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

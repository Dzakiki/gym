import 'package:flutter/services.dart';

/// Rejects edits that would make a number larger than [max].
///
/// Combine with a digits-only filter. A comma is read as a decimal point.
class MaxValueFormatter extends TextInputFormatter {
  const MaxValueFormatter(this.max);

  final num max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final value = num.tryParse(newValue.text.replaceAll(',', '.'));
    return value != null && value > max ? oldValue : newValue;
  }
}

/// Parses whole-number input. Empty or invalid text gives null.
int? parseWholeNumber(String text) => int.tryParse(text.trim());

/// Parses a weight typed with a dot or a comma. Empty or invalid gives null.
double? parseWeight(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

/// Formats a weight for a text field: `60` for 60.0 and `62.5` for 62.5.
String formatWeight(double? kg) {
  if (kg == null) return '';
  return kg == kg.roundToDouble() ? kg.round().toString() : kg.toString();
}

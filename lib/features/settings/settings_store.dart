import 'package:formcoach/domain/weight_unit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads and writes the user's settings on the device.
class SettingsStore {
  SettingsStore(this._preferences);

  static const _weightUnitKey = 'weight_unit';
  static const _voiceCuesKey = 'voice_cues';
  static const _askedAboutOnTimeAlertsKey = 'asked_about_on_time_alerts';

  final SharedPreferences _preferences;

  /// The unit weights are shown in. Defaults to kilograms.
  WeightUnit get weightUnit {
    final name = _preferences.getString(_weightUnitKey);
    return WeightUnit.values.firstWhere(
      (unit) => unit.name == name,
      orElse: () => WeightUnit.kg,
    );
  }

  Future<void> setWeightUnit(WeightUnit unit) =>
      _preferences.setString(_weightUnitKey, unit.name);

  /// Whether the coach speaks its cues out loud. On by default.
  bool get voiceCues => _preferences.getBool(_voiceCuesKey) ?? true;

  Future<void> setVoiceCues({required bool enabled}) =>
      _preferences.setBool(_voiceCuesKey, enabled);

  /// Whether the user was already asked to let rest alerts come on time.
  bool get askedAboutOnTimeAlerts =>
      _preferences.getBool(_askedAboutOnTimeAlertsKey) ?? false;

  Future<void> setAskedAboutOnTimeAlerts() =>
      _preferences.setBool(_askedAboutOnTimeAlertsKey, true);
}

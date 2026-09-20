import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formcoach/domain/weight_unit.dart';
import 'package:formcoach/features/settings/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The device's preferences. Set to the real instance in `main`; tests
/// override it.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider is not set.'),
);

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SettingsStore(ref.watch(sharedPreferencesProvider)),
);

/// The unit weights are shown in.
class WeightUnitNotifier extends Notifier<WeightUnit> {
  @override
  WeightUnit build() => ref.watch(settingsStoreProvider).weightUnit;

  Future<void> select(WeightUnit unit) async {
    state = unit;
    await ref.read(settingsStoreProvider).setWeightUnit(unit);
  }
}

final weightUnitProvider = NotifierProvider<WeightUnitNotifier, WeightUnit>(
  WeightUnitNotifier.new,
);

/// Whether the coach speaks its cues.
class VoiceCuesNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(settingsStoreProvider).voiceCues;

  Future<void> set({required bool enabled}) async {
    state = enabled;
    await ref.read(settingsStoreProvider).setVoiceCues(enabled: enabled);
  }
}

final voiceCuesProvider = NotifierProvider<VoiceCuesNotifier, bool>(
  VoiceCuesNotifier.new,
);

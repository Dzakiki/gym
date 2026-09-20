import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/features/form_coach/coach_controller.dart';
import 'package:formcoach/features/form_coach/cue_player.dart';
import 'package:formcoach/features/form_coach/tts_cue_player.dart';
import 'package:formcoach/features/settings/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeEngine implements SpeechEngine {
  final calls = <String>[];
  Object? failWith;

  @override
  Future<void> configure() async {
    calls.add('configure');
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> speak(String text) async {
    calls.add('speak:$text');
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> stop() async => calls.add('stop');
}

void main() {
  group('TtsCuePlayer', () {
    late _FakeEngine engine;
    late TtsCuePlayer player;

    setUp(() {
      engine = _FakeEngine();
      player = TtsCuePlayer(engine);
    });

    test(
      'sets the voice up once, then cuts off the last cue and speaks',
      () async {
        await player.speak('Chest up');
        await player.speak('Go deeper');

        expect(engine.calls, [
          'configure',
          'stop',
          'speak:Chest up',
          'stop',
          'speak:Go deeper',
        ]);
      },
    );

    test('stop stops the engine', () async {
      await player.stop();

      expect(engine.calls, ['stop']);
    });

    test('a broken speech engine never throws', () async {
      engine.failWith = StateError('no voice installed');

      await expectLater(player.speak('Chest up'), completes);
      await expectLater(player.stop(), completes);
    });

    test('tries to configure again after a failed setup', () async {
      engine.failWith = StateError('not ready');
      await player.speak('a');
      engine.failWith = null;

      await player.speak('b');

      expect(engine.calls.where((c) => c == 'configure'), hasLength(2));
      expect(engine.calls, contains('speak:b'));
    });
  });

  group('cuePlayerProvider', () {
    Future<ProviderContainer> container({required bool voice}) async {
      SharedPreferences.setMockInitialValues({'voice_cues': voice});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('speaks when spoken cues are on', () async {
      final c = await container(voice: true);

      expect(c.read(cuePlayerProvider), isA<TtsCuePlayer>());
    });

    test('is silent when spoken cues are off', () async {
      final c = await container(voice: false);

      expect(c.read(cuePlayerProvider), isA<SilentCuePlayer>());
    });

    test('follows the setting when it changes', () async {
      final c = await container(voice: true);
      expect(c.read(cuePlayerProvider), isA<TtsCuePlayer>());

      await c.read(voiceCuesProvider.notifier).set(enabled: false);

      expect(c.read(cuePlayerProvider), isA<SilentCuePlayer>());
    });
  });
}

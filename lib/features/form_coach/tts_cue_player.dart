import 'package:flutter_tts/flutter_tts.dart';
import 'package:formcoach/features/form_coach/cue_player.dart';

/// The text-to-speech engine behind [TtsCuePlayer]. A thin wrapper so the
/// player can be tested without a device.
abstract interface class SpeechEngine {
  /// Sets up the voice (rate, volume, language). Called once before speaking.
  Future<void> configure();

  Future<void> speak(String text);

  Future<void> stop();
}

/// The phone's built-in text-to-speech, through the `flutter_tts` plugin.
///
/// The plugin is created on first use, so building the engine never touches
/// the platform.
class FlutterTtsEngine implements SpeechEngine {
  FlutterTtsEngine([this._injected]);

  final FlutterTts? _injected;
  FlutterTts? _created;

  FlutterTts get _tts => _injected ?? (_created ??= FlutterTts());

  @override
  Future<void> configure() async {
    await _tts.setLanguage('en-US');
    // A little slower than normal so cues are easy to catch mid-exercise.
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1);
  }

  @override
  Future<void> speak(String text) => _tts.speak(text);

  @override
  Future<void> stop() => _tts.stop();
}

/// Says coaching cues out loud.
///
/// A new cue cuts off the previous one, so the athlete always hears the
/// latest advice. Problems with the speech engine (no voice installed, muted
/// device) are swallowed: a coach that cannot speak must still coach.
class TtsCuePlayer implements CuePlayer {
  TtsCuePlayer(this._engine);

  final SpeechEngine _engine;
  bool _configured = false;

  @override
  Future<void> speak(String text) async {
    try {
      if (!_configured) {
        await _engine.configure();
        _configured = true;
      }
      await _engine.stop();
      await _engine.speak(text);
    } on Object {
      // Speech is a nicety; the on-screen cue is still shown.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _engine.stop();
    } on Object {
      // Nothing to stop.
    }
  }
}

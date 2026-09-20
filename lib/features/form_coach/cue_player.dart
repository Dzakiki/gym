/// Says coaching cues out loud.
abstract interface class CuePlayer {
  Future<void> speak(String text);

  Future<void> stop();
}

/// Says nothing. Used until text-to-speech is connected, and in tests.
class SilentCuePlayer implements CuePlayer {
  const SilentCuePlayer();

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}

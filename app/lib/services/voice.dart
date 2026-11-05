import 'package:flame_audio/flame_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../l10n/strings.dart';

/// Audio carries the key information; the screen confirms it. Every obstacle
/// has its own sound, and the voice coach speaks English, Hindi or Gujarati.
class Voice {
  Voice();
  final FlutterTts _tts = FlutterTts();
  AppLanguage _lang = AppLanguage.en;

  /// Cue sounds and TTS fail independently: a phone without a TTS engine
  /// still plays cues, and a missing sound never silences the coach.
  bool _audioReady = false;
  bool _ttsReady = false;
  Future<void>? _cueLoad;
  DateTime _lastSpoke = DateTime.fromMillisecondsSinceEpoch(0);

  /// The only sounds the game ships (all small). Loaded into the audio cache
  /// once per app run, however often [init] is called (language changes).
  static const cues = [
    'cue_beam.wav',
    'cue_laneBlock.wav',
    'cue_orb.wav',
    'cue_gate.wav',
    'clear.wav',
    'hit.wav',
    'checkpoint.wav',
    'tracking.wav',
  ];

  Future<void> init(AppLanguage lang) async {
    _lang = lang;
    _cueLoad ??= _loadCues();
    await _cueLoad;
    try {
      await _tts.setLanguage(lang.ttsLocale);
      await _tts.setSpeechRate(0.5);
      await _tts.awaitSpeakCompletion(false);
      _ttsReady = true;
    } catch (_) {
      _ttsReady = false;
    }
  }

  Future<void> _loadCues() async {
    try {
      await FlameAudio.audioCache.loadAll(cues);
      _audioReady = true;
    } catch (_) {
      _audioReady = false;
    }
  }

  /// One reusable low-latency player per cue (at most [cues].length), so
  /// cues never create a new platform player per play the way
  /// `FlameAudio.play` does.
  final Map<String, AudioPlayer> _players = {};

  Future<void> cue(String name) async {
    if (!_audioReady) return;
    try {
      final p = _players[name] ??= AudioPlayer()
        ..audioCache = FlameAudio.audioCache;
      await p.stop();
      await p.play(
        AssetSource('$name.wav'),
        volume: 0.9,
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {}
  }

  /// Releases the cue players and the cached sounds.
  Future<void> dispose() async {
    final players = _players.values.toList();
    _players.clear();
    for (final p in players) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    try {
      await FlameAudio.audioCache.clearAll();
    } catch (_) {}
    _audioReady = false;
    _cueLoad = null;
    await stop();
  }

  /// Speaks a line, skipping it if another started under 1.2 s ago.
  Future<void> say(String text, {bool force = false}) async {
    if (!_ttsReady) return;
    final now = DateTime.now();
    if (!force &&
        now.difference(_lastSpoke) < const Duration(milliseconds: 1200)) {
      return;
    }
    _lastSpoke = now;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> sayKey(String key, {bool force = false}) =>
      say(S(_lang).t(key), force: force);

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

final voiceProvider = Provider<Voice>((ref) {
  final voice = Voice();
  ref.onDispose(voice.dispose);
  return voice;
});

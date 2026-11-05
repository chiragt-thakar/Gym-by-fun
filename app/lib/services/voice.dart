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

  Future<void> cue(String name) async {
    if (!_audioReady) return;
    try {
      await FlameAudio.play('$name.wav', volume: 0.9);
    } catch (_) {}
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

final voiceProvider = Provider<Voice>((_) => Voice());

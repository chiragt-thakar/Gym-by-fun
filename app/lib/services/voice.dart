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
  bool _ready = false;
  DateTime _lastSpoke = DateTime.fromMillisecondsSinceEpoch(0);

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
    try {
      await FlameAudio.audioCache.loadAll(cues);
      await _tts.setLanguage(lang.ttsLocale);
      await _tts.setSpeechRate(0.5);
      await _tts.awaitSpeakCompletion(false);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> cue(String name) async {
    if (!_ready) return;
    try {
      await FlameAudio.play('$name.wav', volume: 0.9);
    } catch (_) {}
  }

  /// Speaks a line, skipping it if another started under 1.2 s ago.
  Future<void> say(String text, {bool force = false}) async {
    if (!_ready) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastSpoke) < const Duration(milliseconds: 1200)) return;
    _lastSpoke = now;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> sayKey(String key, {bool force = false}) => say(S(_lang).t(key), force: force);

  Future<void> stop() => _tts.stop();
}

final voiceProvider = Provider<Voice>((_) => Voice());

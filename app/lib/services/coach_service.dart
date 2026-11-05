import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_director/game_director.dart';
import 'package:motion_core/motion_core.dart';

import 'settings.dart';

/// Coach Kavi's memory: the last [maxHistory] run summaries, on the device.
/// Only counts are kept — never video, frames or landmarks (rule 2).
class CoachHistoryNotifier extends Notifier<List<SessionSummary>> {
  static const key = 'coach.history.v1';
  static const maxHistory = 20;

  @override
  List<SessionSummary> build() {
    final raw = ref.watch(sharedPrefsProvider).getString(key);
    if (raw == null) return const [];
    try {
      return [
        for (final j in jsonDecode(raw) as List<dynamic>)
          SessionSummary.fromJson(Map<String, dynamic>.from(j as Map)),
      ];
    } catch (_) {
      return const [];
    }
  }

  void record(SessionSummary s) {
    final next = [...state, s];
    state = List.unmodifiable(
      next.length > maxHistory ? next.sublist(next.length - maxHistory) : next,
    );
    ref
        .read(sharedPrefsProvider)
        .setString(key, jsonEncode([for (final h in state) h.toJson()]));
  }

  void clear() {
    state = const [];
    ref.read(sharedPrefsProvider).remove(key);
  }
}

final coachHistoryProvider =
    NotifierProvider<CoachHistoryNotifier, List<SessionSummary>>(
      CoachHistoryNotifier.new,
    );

/// Kavi's current advice for the stored history.
final coachAdviceProvider = Provider<CoachAdvice>(
  (ref) => const Coach().advise(ref.watch(coachHistoryProvider)),
);

/// Converts the pose service's per-move counts into the coach's form.
Map<Move, MoveStats> moveStatsFrom(Map<String, Map<String, int>>? raw) {
  if (raw == null) return const {};
  final moves = Move.values.asNameMap();
  return {
    for (final e in raw.entries)
      if (moves[e.key] != null) moves[e.key]!: MoveStats.fromJson(e.value),
  };
}

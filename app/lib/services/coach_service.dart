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
  static const activityDaysKey = 'activity.days.v1';

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

  /// Adds [s], or replaces the entry with the same clientId (so saving a
  /// run again, e.g. with its effort rating, never duplicates it).
  void record(SessionSummary s) {
    final prefs = ref.read(sharedPrefsProvider);
    final days = <String>{};
    try {
      days.addAll(
        (jsonDecode(prefs.getString(activityDaysKey) ?? '[]') as List)
            .cast<String>(),
      );
    } catch (_) {}
    // Keep a bounded calendar independently of the 20-run coach history.
    // Re-saving a result or its effort rating does not add another active day.
    for (final run in [...state, s]) {
      days.add(localActivityDay(run.date));
    }
    final ordered = days.toList()..sort();
    prefs.setString(
      activityDaysKey,
      jsonEncode(
        ordered.length > 14 ? ordered.sublist(ordered.length - 14) : ordered,
      ),
    );
    final i = s.clientId == null
        ? -1
        : state.indexWhere((h) => h.clientId == s.clientId);
    final next = [...state];
    if (i >= 0) {
      next[i] = s;
    } else {
      next.add(s);
    }
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
    ref.read(sharedPrefsProvider).remove(activityDaysKey);
  }
}

final coachHistoryProvider =
    NotifierProvider<CoachHistoryNotifier, List<SessionSummary>>(
      CoachHistoryNotifier.new,
    );

String localActivityDay(DateTime date) {
  final d = date.toLocal();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final activityDaysProvider = Provider<Set<String>>((ref) {
  final history = ref.watch(coachHistoryProvider);
  final days = {for (final run in history) localActivityDay(run.date)};
  try {
    days.addAll(
      (jsonDecode(
        ref
                .watch(sharedPrefsProvider)
                .getString(CoachHistoryNotifier.activityDaysKey) ??
            '[]',
      ) as List).cast<String>(),
    );
  } catch (_) {}
  return days;
});

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

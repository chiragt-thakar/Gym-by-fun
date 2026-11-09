import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_director/game_director.dart';

import '../game/stages.dart' show devUnlockAll;
import '../services/coach_service.dart';
import '../services/settings.dart';

/// Best result for one stage of one arcade game.
class StageRecord {
  const StageRecord({
    this.bestScore = 0,
    this.stars = 0,
    this.plays = 0,
    this.completed = false,
  });
  final int bestScore;
  final int stars;
  final int plays;
  final bool completed;

  Map<String, Object> toJson() => {
    'b': bestScore,
    's': stars,
    'p': plays,
    'c': completed,
  };

  factory StageRecord.fromJson(Map<String, dynamic> j) => StageRecord(
    bestScore: (j['b'] as num?)?.toInt() ?? 0,
    stars: (j['s'] as num?)?.toInt() ?? 0,
    plays: (j['p'] as num?)?.toInt() ?? 0,
    completed: j['c'] as bool? ?? false,
  );
}

/// A finished arcade session, counts only (rule 2: no video, no landmarks).
class ArcadeSession {
  const ArcadeSession({
    required this.gameId,
    required this.stageId,
    required this.date,
    required this.activeMs,
    required this.moves,
  });
  final String gameId;
  final String stageId;
  final DateTime date;
  final int activeMs;
  final int moves;

  Map<String, Object> toJson() => {
    'g': gameId,
    'st': stageId,
    'd': date.toUtc().toIso8601String(),
    'a': activeMs,
    'm': moves,
  };

  factory ArcadeSession.fromJson(Map<String, dynamic> j) => ArcadeSession(
    gameId: j['g'] as String,
    stageId: j['st'] as String,
    date: DateTime.parse(j['d'] as String),
    activeMs: (j['a'] as num).toInt(),
    moves: (j['m'] as num).toInt(),
  );
}

class ArcadeProgress {
  const ArcadeProgress({
    this.records = const {},
    this.sessions = const [],
    this.habitat = const {},
  });

  /// gameId → stageId → record.
  final Map<String, Map<String, StageRecord>> records;
  final List<ArcadeSession> sessions;

  /// Restored LUMEN modules, as 'stageId/boardId'.
  final Set<String> habitat;

  StageRecord record(String game, String stage) =>
      records[game]?[stage] ?? const StageRecord();

  int starsFor(String game) =>
      records[game]?.values.fold<int>(0, (a, r) => a + r.stars) ?? 0;

  int playsFor(String game) =>
      records[game]?.values.fold<int>(0, (a, r) => a + r.plays) ?? 0;

  bool completed(String game, String stage) => record(game, stage).completed;

  /// The first stage is open; each later stage opens when the one before it
  /// is completed. Party stages are always open.
  bool unlocked(
    String game,
    List<String> order,
    String stage, {
    bool alwaysOpen = false,
  }) {
    if (devUnlockAll || alwaysOpen) return true;
    final i = order.indexOf(stage);
    if (i <= 0) return true;
    return completed(game, order[i - 1]);
  }

  Map<String, Object> toJson() => {
    'r': {
      for (final g in records.entries)
        g.key: {for (final s in g.value.entries) s.key: s.value.toJson()},
    },
    's': [for (final s in sessions) s.toJson()],
    'h': [...habitat],
  };

  factory ArcadeProgress.fromJson(Map<String, dynamic> j) => ArcadeProgress(
    records: {
      for (final g in (j['r'] as Map? ?? const {}).entries)
        g.key as String: {
          for (final s in (g.value as Map).entries)
            s.key as String: StageRecord.fromJson(
              Map<String, dynamic>.from(s.value as Map),
            ),
        },
    },
    sessions: [
      for (final s in j['s'] as List<dynamic>? ?? const [])
        ArcadeSession.fromJson(Map<String, dynamic>.from(s as Map)),
    ],
    habitat: {
      for (final h in j['h'] as List<dynamic>? ?? const [])
        if (h is String) h,
    },
  );
}

class ArcadeProgressNotifier extends Notifier<ArcadeProgress> {
  static const key = 'arcade.progress.v1';
  static const maxSessions = 60;

  @override
  ArcadeProgress build() {
    final raw = ref.watch(sharedPrefsProvider).getString(key);
    if (raw == null) return const ArcadeProgress();
    try {
      return ArcadeProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ArcadeProgress();
    }
  }

  /// Saves a finished session; keeps the best score and stars per stage.
  void record(ArcadeSummary s, {Set<String> habitat = const {}}) {
    final old = state.record(s.gameId, s.stageId);
    final next = StageRecord(
      bestScore: s.score > old.bestScore ? s.score : old.bestScore,
      stars: s.stars > old.stars ? s.stars : old.stars,
      plays: old.plays + 1,
      completed: old.completed || (s.completed && s.stars > 0),
    );
    final records = {
      for (final g in state.records.entries) g.key: {...g.value},
    };
    (records[s.gameId] ??= {})[s.stageId] = next;
    final now = DateTime.now();
    final sessions = [
      ...state.sessions,
      if (s.activeMs > 0)
        ArcadeSession(
          gameId: s.gameId,
          stageId: s.stageId,
          date: now,
          activeMs: s.activeMs,
          moves: s.totalMoves,
        ),
    ];
    state = ArcadeProgress(
      records: records,
      sessions: sessions.length > maxSessions
          ? sessions.sublist(sessions.length - maxSessions)
          : sessions,
      habitat: {...state.habitat, ...habitat},
    );
    final prefs = ref.read(sharedPrefsProvider);
    prefs.setString(key, jsonEncode(state.toJson()));
    if (s.activeMs > 0) _markActiveDay(now);
  }

  void _markActiveDay(DateTime now) {
    final prefs = ref.read(sharedPrefsProvider);
    final days = <String>{};
    try {
      days.addAll(
        (jsonDecode(
          prefs.getString(CoachHistoryNotifier.activityDaysKey) ?? '[]',
        ) as List).cast<String>(),
      );
    } catch (_) {}
    days.add(localActivityDay(now));
    final ordered = days.toList()..sort();
    prefs.setString(
      CoachHistoryNotifier.activityDaysKey,
      jsonEncode(
        ordered.length > 14 ? ordered.sublist(ordered.length - 14) : ordered,
      ),
    );
    ref.invalidate(activityDaysProvider);
  }

  void clear() {
    state = const ArcadeProgress();
    ref.read(sharedPrefsProvider).remove(key);
  }
}

final arcadeProgressProvider =
    NotifierProvider<ArcadeProgressNotifier, ArcadeProgress>(
      ArcadeProgressNotifier.new,
    );

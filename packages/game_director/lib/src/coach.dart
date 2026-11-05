import 'package:motion_core/motion_core.dart';

import 'level.dart';
import 'run_engine.dart';

// Coach Kavi: MotionQuest's on-device coach.
//
// Fully rule-based, deterministic and offline (rule 8): the same history
// always gives the same advice. Every output is a message key plus
// parameters; the app layer owns the English, Hindi and Gujarati text.
// Kavi only makes game suggestions. It never claims to measure fatigue,
// heart rate or health.

/// Counts for one move in one session. Only counts: never video or landmarks.
class MoveStats {
  const MoveStats({
    this.attempts = 0,
    this.recognised = 0,
    this.tooShallow = 0,
    this.notVisible = 0,
    this.tooEarly = 0,
  });

  final int attempts;
  final int recognised;
  final int tooShallow;
  final int notVisible;
  final int tooEarly;

  int rejected(RejectReason r) => switch (r) {
        RejectReason.tooShallow => tooShallow,
        RejectReason.notVisible => notVisible,
        RejectReason.tooEarly => tooEarly,
      };

  Map<String, int> toJson() => {
        'attempts': attempts,
        'recognised': recognised,
        'tooShallow': tooShallow,
        'notVisible': notVisible,
        'tooEarly': tooEarly,
      };

  factory MoveStats.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return MoveStats(
      attempts: n('attempts'),
      recognised: n('recognised'),
      tooShallow: n('tooShallow'),
      notVisible: n('notVisible'),
      tooEarly: n('tooEarly'),
    );
  }
}

/// What the coach remembers about one finished run.
class SessionSummary {
  const SessionSummary({
    required this.date,
    required this.levelId,
    required this.completed,
    required this.score,
    required this.hearts,
    required this.maxHearts,
    required this.cleared,
    required this.hit,
    required this.reps,
    required this.difficulty,
    required this.lowImpact,
    this.activeMs = 0,
    this.effort,
    this.moveStats = const {},
  });

  factory SessionSummary.fromResult(
    RunResult r, {
    required DateTime date,
    int maxHearts = 3,
    int? effort,
    Map<Move, MoveStats> moveStats = const {},
  }) =>
      SessionSummary(
        date: date,
        levelId: r.levelId,
        completed: r.completed,
        score: r.score,
        hearts: r.hearts,
        maxHearts: maxHearts,
        cleared: r.cleared,
        hit: r.hit,
        reps: Map.of(r.reps),
        difficulty: r.difficulty,
        lowImpact: r.lowImpact,
        activeMs: r.activeMs,
        effort: effort,
        moveStats: moveStats,
      );

  final DateTime date;
  final String levelId;
  final bool completed;
  final int score;
  final int hearts;
  final int maxHearts;
  final int cleared;
  final int hit;
  final Map<Move, int> reps;
  final Difficulty difficulty;
  final bool lowImpact;
  final int activeMs;

  /// The player's own 1–5 "how hard did that feel" answer, if given.
  final int? effort;
  final Map<Move, MoveStats> moveStats;

  int get heartsLost => (maxHearts - hearts).clamp(0, maxHearts);
  int get totalReps => reps.values.fold(0, (a, b) => a + b);

  /// Felt hard by the player's own rating. Not a fatigue measurement.
  bool get feltHard => (effort ?? 0) >= 4;

  Map<String, Object?> toJson() => {
        'date': date.toIso8601String(),
        'levelId': levelId,
        'completed': completed,
        'score': score,
        'hearts': hearts,
        'maxHearts': maxHearts,
        'cleared': cleared,
        'hit': hit,
        'reps': {for (final e in reps.entries) e.key.name: e.value},
        'difficulty': difficulty.name,
        'lowImpact': lowImpact,
        'activeMs': activeMs,
        'effort': effort,
        'moveStats': {
          for (final e in moveStats.entries) e.key.name: e.value.toJson(),
        },
      };

  factory SessionSummary.fromJson(Map<String, dynamic> j) {
    final moves = Move.values.asNameMap();
    final reps = <Move, int>{};
    (j['reps'] as Map?)?.forEach((k, v) {
      final m = moves[k];
      if (m != null) reps[m] = (v as num).toInt();
    });
    final stats = <Move, MoveStats>{};
    (j['moveStats'] as Map?)?.forEach((k, v) {
      final m = moves[k];
      if (m != null) {
        stats[m] = MoveStats.fromJson(Map<String, dynamic>.from(v as Map));
      }
    });
    return SessionSummary(
      date: DateTime.parse(j['date'] as String),
      levelId: j['levelId'] as String,
      completed: j['completed'] as bool,
      score: (j['score'] as num).toInt(),
      hearts: (j['hearts'] as num).toInt(),
      maxHearts: (j['maxHearts'] as num?)?.toInt() ?? 3,
      cleared: (j['cleared'] as num?)?.toInt() ?? 0,
      hit: (j['hit'] as num?)?.toInt() ?? 0,
      reps: reps,
      difficulty:
          Difficulty.values.asNameMap()[j['difficulty']] ?? Difficulty.beginner,
      lowImpact: j['lowImpact'] as bool? ?? true,
      activeMs: (j['activeMs'] as num?)?.toInt() ?? 0,
      effort: (j['effort'] as num?)?.toInt(),
      moveStats: stats,
    );
  }
}

/// A message for the app to translate: a key and its parameters.
class CoachMessage {
  const CoachMessage(this.key, [this.params = const {}]);
  final String key;
  final Map<String, Object> params;

  @override
  bool operator ==(Object other) =>
      other is CoachMessage &&
      other.key == key &&
      other.params.length == params.length &&
      params.entries.every((e) => other.params[e.key] == e.value);

  @override
  int get hashCode => Object.hash(key,
      Object.hashAllUnordered(params.entries.map((e) => (e.key, e.value))));

  @override
  String toString() => params.isEmpty ? key : '$key$params';
}

/// Why Kavi recommends what it does. Shown to the player as an explanation.
enum CoachReason {
  /// No runs yet.
  noHistory,

  /// Keep going at this level.
  steady,

  /// Two clean, comfortable finishes in a row at this level.
  readyToMoveUp,

  /// Already on the top level and doing well.
  atTop,

  /// The last run was not finished.
  runNotFinished,

  /// Two or more hearts were lost.
  heartsLost,

  /// The player rated the run 4 or 5.
  feltHard,
}

class DifficultyAdvice {
  const DifficultyAdvice({
    required this.current,
    required this.recommended,
    required this.suggestAssist,
    required this.suggestLowImpact,
    required this.reason,
  });

  final Difficulty current;

  /// At most one level away from [current].
  final Difficulty recommended;

  /// Suggest turning assist mode on (more warning, wider windows).
  final bool suggestAssist;

  /// Suggest turning low-impact on. Kavi never suggests turning it off.
  final bool suggestLowImpact;
  final CoachReason reason;

  bool get changes => recommended != current;
  bool get movesUp => recommended.index > current.index;
}

class CoachAdvice {
  const CoachAdvice({
    required this.difficulty,
    required this.tips,
    required this.recap,
    required this.nextGoal,
    required this.balance,
  });

  final DifficultyAdvice difficulty;

  /// At most two form tips, most frequent rejection first.
  final List<CoachMessage> tips;
  final CoachMessage? recap;
  final CoachMessage? nextGoal;

  /// A note about the week's mix of moves and sessions, if any.
  final CoachMessage? balance;

  @override
  String toString() =>
      'CoachAdvice(${difficulty.reason} ${difficulty.recommended} '
      'assist=${difficulty.suggestAssist} li=${difficulty.suggestLowImpact} '
      'tips=$tips recap=$recap goal=$nextGoal balance=$balance)';
}

/// The coach's rules. Thresholds are documented in docs/game-design.md.
class Coach {
  const Coach();

  /// A form tip needs at least this many rejections of one kind in the run.
  static const tipMinRejections = 3;

  /// One move above this share of the week's reps suggests more variety.
  static const dominantShare = 0.6;

  /// Variety is only judged once the week has this many reps.
  static const minWeeklyReps = 20;

  /// This many runs in a row rated 4+ suggests a lighter day.
  static const hardStreak = 3;

  /// [history] is oldest first; the last entry is the run just finished.
  CoachAdvice advise(List<SessionSummary> history) {
    if (history.isEmpty) {
      return const CoachAdvice(
        difficulty: DifficultyAdvice(
          current: Difficulty.beginner,
          recommended: Difficulty.beginner,
          suggestAssist: false,
          suggestLowImpact: false,
          reason: CoachReason.noHistory,
        ),
        tips: [],
        recap: null,
        nextGoal: null,
        balance: null,
      );
    }
    return CoachAdvice(
      difficulty: difficultyAdvice(history),
      tips: formTips(history.last),
      recap: recap(history),
      nextGoal: nextGoal(history),
      balance: balance(history),
    );
  }

  DifficultyAdvice difficultyAdvice(List<SessionSummary> history) {
    final last = history.last;
    final cur = last.difficulty;
    final easier = Difficulty.values[(cur.index - 1).clamp(0, 2)];
    final harder = Difficulty.values[(cur.index + 1).clamp(0, 2)];

    CoachReason? down;
    if (!last.completed) {
      down = CoachReason.runNotFinished;
    } else if (last.heartsLost >= 2) {
      down = CoachReason.heartsLost;
    } else if (last.feltHard) {
      down = CoachReason.feltHard;
    }
    if (down != null) {
      return DifficultyAdvice(
        current: cur,
        recommended: easier,
        suggestAssist: true,
        suggestLowImpact: !last.lowImpact,
        reason: down,
      );
    }

    final recent = history.length >= 2
        ? history.sublist(history.length - 2)
        : const <SessionSummary>[];
    final ready = recent.length == 2 &&
        recent.every((s) =>
            s.difficulty == cur &&
            s.completed &&
            s.hit <= 1 &&
            (s.effort ?? 3) <= 3);
    if (ready) {
      return DifficultyAdvice(
        current: cur,
        recommended: harder,
        suggestAssist: false,
        suggestLowImpact: false,
        reason: cur == harder ? CoachReason.atTop : CoachReason.readyToMoveUp,
      );
    }
    return DifficultyAdvice(
      current: cur,
      recommended: cur,
      suggestAssist: false,
      suggestLowImpact: false,
      reason: CoachReason.steady,
    );
  }

  /// Up to two tips from why attempts did not count in [s].
  List<CoachMessage> formTips(SessionSummary s) {
    final counts = <String, int>{};
    void add(String key, int n) => counts[key] = (counts[key] ?? 0) + n;
    for (final m in Move.values) {
      final st = s.moveStats[m];
      if (st == null) continue;
      add('coach_tip_camera', st.notVisible);
      switch (m) {
        case Move.squat:
          add('coach_tip_squat_deeper', st.tooShallow);
          add('coach_tip_squat_rise', st.tooEarly);
        case Move.leanLeft || Move.leanRight:
          add('coach_tip_lean_further', st.tooShallow);
          add('coach_tip_lean_centre', st.tooEarly);
        case Move.raiseArms:
          add('coach_tip_raise_higher', st.tooShallow);
          add('coach_tip_raise_lower', st.tooEarly);
      }
    }
    final keys =
        counts.keys.where((k) => counts[k]! >= tipMinRejections).toList()
          ..sort((a, b) {
            final c = counts[b]!.compareTo(counts[a]!);
            return c != 0 ? c : a.compareTo(b);
          });
    return [for (final k in keys.take(2)) CoachMessage(k)];
  }

  CoachMessage recap(List<SessionSummary> history) {
    final last = history.last;
    final top = _mostUsed(last.reps);
    final params = <String, Object>{
      'score': last.score,
      'cleared': last.cleared,
      if (top != null) 'move': top.name,
    };
    final earlier = history.sublist(0, history.length - 1);
    final prevBest = earlier.isEmpty
        ? null
        : earlier.map((s) => s.score).reduce((a, b) => a > b ? a : b);
    if (prevBest != null && last.score > prevBest) {
      return CoachMessage('coach_recap_best', params);
    }
    if (last.completed && last.hit == 0) {
      return CoachMessage('coach_recap_flawless', params);
    }
    if (last.completed) return CoachMessage('coach_recap_finished', params);
    return CoachMessage('coach_recap_effort', params);
  }

  CoachMessage nextGoal(List<SessionSummary> history) {
    final last = history.last;
    if (!last.completed) return const CoachMessage('coach_goal_finish');
    if (last.heartsLost > 0) {
      return CoachMessage('coach_goal_all_hearts', {'hearts': last.maxHearts});
    }
    final best = history.map((s) => s.score).reduce((a, b) => a > b ? a : b);
    // Next round 100 above the best score.
    return CoachMessage('coach_goal_score', {'score': (best ~/ 100 + 1) * 100});
  }

  /// A note across the last 7 days (counted back from the latest run).
  CoachMessage? balance(List<SessionSummary> history) {
    final last = history.last;
    if (history.length >= hardStreak &&
        history.sublist(history.length - hardStreak).every((s) => s.feltHard)) {
      return const CoachMessage('coach_balance_lighter');
    }
    final since = last.date.subtract(const Duration(days: 7));
    final week = history.where((s) => s.date.isAfter(since));
    final reps = <Move, int>{};
    for (final s in week) {
      s.reps.forEach((m, n) => reps[m] = (reps[m] ?? 0) + n);
    }
    final total = reps.values.fold(0, (a, b) => a + b);
    final top = _mostUsed(reps);
    if (top == null || total < minWeeklyReps) return null;
    final share = reps[top]! / total;
    if (share > dominantShare) {
      return CoachMessage('coach_balance_variety', {
        'move': top.name,
        'percent': (share * 100).round(),
      });
    }
    return null;
  }

  /// Most reps, ties broken by enum order so the answer is stable.
  static Move? _mostUsed(Map<Move, int> reps) {
    Move? best;
    for (final m in Move.values) {
      final n = reps[m] ?? 0;
      if (n > 0 && (best == null || n > reps[best]!)) best = m;
    }
    return best;
  }
}

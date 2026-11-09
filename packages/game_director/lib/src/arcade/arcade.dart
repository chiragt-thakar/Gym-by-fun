import 'package:motion_core/motion_core.dart';

/// Shared rules for the camera arcade games (Mirror Mela, Pataka Pose,
/// Craftguard Duels, Taal Toofan, Tapeball Tamasha, LUMEN).
///
/// Every engine is deterministic: the same config, seed and inputs give the
/// same result. Engines never see camera pixels — only [BodyPose] (built
/// from landmarks) and motion-core events. A tracking problem freezes the
/// game clock and is always forgiven (rule 5); a recognised move does
/// nothing unless something on screen asks for it (rule 6).

enum Grade { perfect, good, ok, miss }

extension GradeLabel on Grade {
  String get label => switch (this) {
        Grade.perfect => 'Perfect',
        Grade.good => 'Good',
        Grade.ok => 'OK',
        Grade.miss => 'Miss',
      };
}

/// Something the app should show or play: a pop, a hit, a beat.
class ArcadeEvent {
  const ArcadeEvent(this.kind,
      {this.id = 0,
      this.grade,
      this.points = 0,
      this.text,
      this.side,
      this.value = 0,
      this.x = 0,
      this.y = 0});

  /// Short machine name: 'pop', 'miss', 'beat', 'hit', 'call', ...
  final String kind;
  final int id;
  final Grade? grade;
  final int points;

  /// An English line for captions/voice (translated by the app).
  final String? text;
  final BodySide? side;

  /// Free number (beat index, note index, runs...).
  final int value;

  /// Body-space position for effects, when the event has one.
  final double x;
  final double y;

  @override
  String toString() => 'ArcadeEvent($kind#$id ${grade?.name ?? ''} $text)';
}

/// What a finished (or abandoned) round reports. Counts only, no video.
class ArcadeSummary {
  const ArcadeSummary({
    required this.gameId,
    required this.stageId,
    required this.score,
    required this.stars,
    required this.maxStars,
    required this.accuracy,
    required this.bestCombo,
    required this.activeMs,
    required this.completed,
    required this.headline,
    this.moves = const {},
    this.forgiven = 0,
    this.details = const {},
  });

  final String gameId;
  final String stageId;
  final int score;
  final int stars;
  final int maxStars;

  /// 0..1 share of the best possible result.
  final double accuracy;
  final int bestCombo;

  /// Game-clock time actually played (tracking holds excluded).
  final int activeMs;
  final bool completed;

  /// One short English line ("Calmed the Baoli Warden").
  final String headline;

  /// Deliberate movements by name, e.g. {'reach': 22, 'duck': 4}.
  final Map<String, int> moves;

  /// Targets removed because tracking was lost (never counted as misses).
  final int forgiven;

  /// Game-specific numbers for the results card (runs, wickets, rank...).
  final Map<String, String> details;

  int get totalMoves => moves.values.fold(0, (a, b) => a + b);
}

/// The contract every arcade game implements. The app calls [advance] from
/// its frame ticker with real elapsed time, [pose] for every quality-gated
/// frame and [motion] for every motion-core event.
abstract class ArcadeEngine {
  /// Game clock in ms. Frozen while tracking is lost.
  int get clockMs;

  /// Planned length, for the progress bar (0 when open-ended).
  int get durationMs;

  bool get finished;

  /// True while the clock is held for a tracking problem.
  bool get holding;

  void advance(int dtMs, {required bool tracked});
  void pose(BodyPose body);
  void motion(MotionEvent event);

  /// Events since the last call, oldest first.
  List<ArcadeEvent> drainEvents();

  ArcadeSummary get summary;
}

/// Clock + tracking-hold + forgiveness shared by the engines.
mixin ArcadeClock {
  int clock = 0;
  bool _held = false;
  int _graceUntil = -1;
  int forgivenCount = 0;
  final List<ArcadeEvent> pending = [];

  /// Time after tracking returns during which closing windows are forgiven.
  int get resumeGraceMs => 800;

  bool get isHeld => _held;

  /// Advances the clock unless tracking is lost. Returns the ms advanced.
  int tick(int dtMs, bool tracked) {
    final dt = dtMs.clamp(0, 100);
    if (!tracked) {
      if (!_held) {
        _held = true;
        pending.add(const ArcadeEvent('hold'));
      }
      return 0;
    }
    if (_held) {
      _held = false;
      _graceUntil = clock + resumeGraceMs;
      pending.add(const ArcadeEvent('resume'));
    }
    clock += dt;
    return dt;
  }

  /// True while a window closing now would be forgiven.
  bool get inGrace => clock < _graceUntil;

  List<ArcadeEvent> drain() {
    if (pending.isEmpty) return const [];
    final out = List.of(pending);
    pending.clear();
    return out;
  }
}

/// Late-biased timing windows: the pipeline reports a move ~100–180 ms after
/// it happened, so the late side of every window is wider.
class TimingWindows {
  const TimingWindows({
    this.perfect = 140,
    this.good = 260,
    this.ok = 400,
    this.lateBias = 80,
  });

  factory TimingWindows.fromJson(Map<String, dynamic>? j) => j == null
      ? const TimingWindows()
      : TimingWindows(
          perfect: (j['perfect'] as num?)?.toInt() ?? 140,
          good: (j['good'] as num?)?.toInt() ?? 260,
          ok: (j['ok'] as num?)?.toInt() ?? 400,
          lateBias: (j['lateBias'] as num?)?.toInt() ?? 80,
        );

  final int perfect;
  final int good;
  final int ok;
  final int lateBias;

  int get open => -ok;
  int get close => ok + lateBias;

  TimingWindows scaled(double f) => TimingWindows(
        perfect: (perfect * f).round(),
        good: (good * f).round(),
        ok: (ok * f).round(),
        lateBias: lateBias,
      );

  /// Grade for an action at [offset] ms from the target (negative = early).
  Grade grade(int offset) {
    final d = offset > 0 ? offset - lateBias : offset;
    final a = d.abs();
    if (offset > 0 && offset <= lateBias) return Grade.perfect;
    if (a <= perfect) return Grade.perfect;
    if (a <= good) return Grade.good;
    if (a <= ok) return Grade.ok;
    return Grade.miss;
  }
}

/// Small, portable seeded generator (mulberry32) so a seed gives the same
/// round on every device (Daily Remix, crew challenges).
class SeededRandom {
  SeededRandom(int seed) : _s = seed & 0xFFFFFFFF;
  int _s;

  double next() {
    _s = (_s + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _s;
    t = _imul(t ^ (t >> 15), t | 1);
    t ^= (t + _imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF;
    return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0;
  }

  int nextInt(int max) => (next() * max).floor().clamp(0, max - 1);

  T pick<T>(List<T> items) => items[nextInt(items.length)];

  static int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;
}

/// Day seed in IST, so everyone in India gets the same daily round.
int dailySeed(DateTime utc, {int salt = 0}) {
  final ist = utc.toUtc().add(const Duration(hours: 5, minutes: 30));
  return ist.year * 10000 + ist.month * 100 + ist.day + salt * 7919;
}

/// Tracks which core moves are currently active from motion-core events.
class MoveState {
  bool squat = false;
  bool leanLeft = false;
  bool leanRight = false;
  bool armsUp = false;
  int squatAt = 0, leanLeftAt = 0, leanRightAt = 0, armsUpAt = 0;
  final Map<Move, int> started = {for (final m in Move.values) m: 0};

  void apply(MotionEvent e) {
    switch (e) {
      case MoveStarted(:final move, :final timestampMs):
        started[move] = started[move]! + 1;
        _set(move, true, timestampMs);
      case MoveEnded(:final move, :final timestampMs):
        _set(move, false, timestampMs);
      case TrackingPaused():
        squat = leanLeft = leanRight = armsUp = false;
      default:
        break;
    }
  }

  void _set(Move m, bool v, int ts) {
    switch (m) {
      case Move.squat:
        squat = v;
        if (v) squatAt = ts;
      case Move.leanLeft:
        leanLeft = v;
        if (v) leanLeftAt = ts;
      case Move.leanRight:
        leanRight = v;
        if (v) leanRightAt = ts;
      case Move.raiseArms:
        armsUp = v;
        if (v) armsUpAt = ts;
    }
  }
}

/// Stars from an accuracy share and three thresholds.
int starsFor(double share, List<double> thresholds) {
  var s = 0;
  for (final t in thresholds) {
    if (share >= t) s++;
  }
  return s;
}

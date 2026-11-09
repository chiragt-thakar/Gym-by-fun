import 'body_pose.dart';

/// A target body shape: joint angles in the player's own left/right.
class PoseTarget {
  const PoseTarget({
    required this.id,
    required this.angles,
    this.must = const {},
    this.mirrorOk = false,
  });

  final String id;
  final Map<PoseAngle, double> angles;

  /// Features that must be roughly right: a score below 0.4 on any of them
  /// caps the whole match at 60 %.
  final Set<PoseAngle> must;

  /// Either side is fine (scored both ways, best taken).
  final bool mirrorOk;

  factory PoseTarget.fromJson(Map<String, dynamic> j) {
    final names = PoseAngle.values.asNameMap();
    return PoseTarget(
      id: j['id'] as String,
      angles: {
        for (final e in (j['angles'] as Map).entries)
          names[e.key]!: (e.value as num).toDouble(),
      },
      must: {
        for (final n in (j['must'] as List<dynamic>? ?? const []))
          names[n as String]!,
      },
      mirrorOk: j['mirrorOk'] as bool? ?? false,
    );
  }

  PoseTarget mirrored() => PoseTarget(
        id: id,
        angles: {for (final e in angles.entries) _swap(e.key): _flip(e)},
        must: {for (final a in must) _swap(a)},
      );

  static double _flip(MapEntry<PoseAngle, double> e) =>
      e.key == PoseAngle.lean ? -e.value : e.value;

  static PoseAngle _swap(PoseAngle a) => switch (a) {
        PoseAngle.shoulderL => PoseAngle.shoulderR,
        PoseAngle.shoulderR => PoseAngle.shoulderL,
        PoseAngle.elbowL => PoseAngle.elbowR,
        PoseAngle.elbowR => PoseAngle.elbowL,
        PoseAngle.hipL => PoseAngle.hipR,
        PoseAngle.hipR => PoseAngle.hipL,
        PoseAngle.kneeL => PoseAngle.kneeR,
        PoseAngle.kneeR => PoseAngle.kneeL,
        PoseAngle.lean => PoseAngle.lean,
      };
}

class PoseMatch {
  const PoseMatch(this.similarity, this.seenWeight, this.worst);

  /// 0..100 over the features that were seen.
  final double similarity;

  /// Share (0..1) of the target's weight that was visible.
  final double seenWeight;

  /// The visible feature furthest from its target, when any is off.
  final PoseAngle? worst;
}

/// Scores how close a body is to a [PoseTarget]. Each angle earns full
/// marks inside its tolerance and falls to zero over a further falloff.
class PoseMatcher {
  const PoseMatcher();

  static double weight(PoseAngle a) => switch (a) {
        PoseAngle.shoulderL || PoseAngle.shoulderR || PoseAngle.lean => 1.0,
        _ => 0.8,
      };

  static (double, double) tolerance(PoseAngle a) => switch (a) {
        PoseAngle.shoulderL ||
        PoseAngle.shoulderR ||
        PoseAngle.hipL ||
        PoseAngle.hipR =>
          (20, 30),
        PoseAngle.lean => (10, 15),
        _ => (25, 35),
      };

  /// [tolOffset] widens (positive) or tightens (negative) every tolerance,
  /// in degrees. [extra] adds per-feature tolerance (adaptive help).
  PoseMatch match(BodyPose p, PoseTarget t,
      {double tolOffset = 0, Map<PoseAngle, double> extra = const {}}) {
    final direct = _score(p, t, tolOffset, extra);
    if (!t.mirrorOk) return direct;
    final other = _score(p, t.mirrored(), tolOffset, extra);
    return other.similarity > direct.similarity ? other : direct;
  }

  PoseMatch _score(BodyPose p, PoseTarget t, double tolOffset,
      Map<PoseAngle, double> extra) {
    var total = 0.0, seen = 0.0, sum = 0.0;
    var capped = false;
    PoseAngle? worst;
    var worstScore = 1.0;
    for (final e in t.angles.entries) {
      final w = weight(e.key);
      total += w;
      final v = p.angle(e.key);
      if (v == null) continue;
      seen += w;
      final (tol, falloff) = tolerance(e.key);
      final diff = (v - e.value).abs();
      final over = diff - (tol + tolOffset + (extra[e.key] ?? 0));
      final s = over <= 0 ? 1.0 : (1 - over / falloff).clamp(0.0, 1.0);
      sum += w * s;
      if (s < 0.4 && t.must.contains(e.key)) capped = true;
      if (s < worstScore) {
        worstScore = s;
        worst = e.key;
      }
    }
    if (seen == 0) return const PoseMatch(0, 0, null);
    var sim = 100 * sum / seen;
    if (capped && sim > 60) sim = 60;
    return PoseMatch(sim, total == 0 ? 0 : seen / total, worst);
  }
}

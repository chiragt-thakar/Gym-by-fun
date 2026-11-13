import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_director/game_director.dart';

import 'looks.dart';
import 'paint_kit.dart';

const _ice = Color(0xFF7FD8FF);
const _warm = Color(0xFFFFC46B);
const _leaf = Color(0xFF7BD389);
const _panel = Color(0xFF13233F);

/// Orbit: stars, the Earth's limb and the habitat's glass ring.
void _lumenScene(Canvas c, Size s, double t) {
  sky(c, s, const [Color(0xFF02040C), Color(0xFF07122A), Color(0xFF0E1B33)]);
  starfield(c, s, n: 70, maxY: 1, t: t * 0.5);
  // Earth limb.
  final earth = Offset(s.width * 0.5, s.height * 1.55);
  final r = s.height * 0.75;
  glow(c, earth, r * 1.12, const Color(0xFF4FA3FF), alpha: 0.35);
  c.drawCircle(
    earth,
    r,
    Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF1C5FA8), Color(0xFF0B2A55)],
      ).createShader(Rect.fromCircle(center: earth, radius: r)),
  );
  // Cloud bands.
  for (var i = 0; i < 5; i++) {
    c.drawArc(
      Rect.fromCircle(center: earth, radius: r - 8 - i * 9),
      -math.pi * 0.85 + t * 0.01 * (i + 1),
      0.6,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }
  // Habitat ring arcs.
  final ring = Offset(s.width / 2, s.height * 0.42);
  for (var k = 0; k < 2; k++) {
    c.drawArc(
      Rect.fromCenter(
        center: ring,
        width: s.width * (1.4 + k * 0.2),
        height: s.height * (0.9 + k * 0.1),
      ),
      math.pi * 1.05,
      math.pi * 0.9,
      false,
      Paint()
        ..color = _ice.withValues(alpha: 0.12 - k * 0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 - k * 4,
    );
  }
}

IconData moduleIcon(String module) => switch (module) {
  'light' => Icons.light_rounded,
  'water' => Icons.water_drop_rounded,
  'air' => Icons.air_rounded,
  'canopy' => Icons.local_florist_rounded,
  'lens' => Icons.center_focus_strong_rounded,
  'coolant' => Icons.ac_unit_rounded,
  _ => Icons.auto_awesome_rounded,
};

void _iconAt(Canvas c, IconData icon, Offset at, double size, Color color) {
  final tp = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
}

Offset _port(Rect cell, Dir d) => switch (d) {
  Dir.n => cell.topCenter,
  Dir.e => cell.centerRight,
  Dir.s => cell.bottomCenter,
  Dir.w => cell.centerLeft,
};

/// Draws the board in [area]. [lit] cells glow; [flow] animates energy.
void paintBoard(
  Canvas c,
  Rect area,
  LumenBoard b,
  double t, {
  int? selected,
  bool connected = false,
  double restore = 0,
  Color accent = _ice,
}) {
  final (lit, ok) = b.trace();
  final litSet = lit.toSet();
  final cell = math.min(area.width / b.cols, area.height / b.rows);
  final origin = Offset(
    area.center.dx - cell * b.cols / 2,
    area.center.dy - cell * b.rows / 2,
  );
  Rect rect(int r, int col) =>
      Rect.fromLTWH(origin.dx + col * cell, origin.dy + r * cell, cell, cell);
  final frame = Rect.fromLTWH(
    origin.dx,
    origin.dy,
    cell * b.cols,
    cell * b.rows,
  ).inflate(8);
  c.drawRRect(
    RRect.fromRectAndRadius(frame, const Radius.circular(18)),
    Paint()..color = _panel.withValues(alpha: 0.92),
  );
  c.drawRRect(
    RRect.fromRectAndRadius(frame, const Radius.circular(18)),
    Paint()
      ..color = accent.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
  for (var r = 0; r < b.rows; r++) {
    for (var col = 0; col < b.cols; col++) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          rect(r, col).deflate(3),
          const Radius.circular(10),
        ),
        Paint()..color = const Color(0xFF0B1730),
      );
    }
  }
  // Source and receiver.
  final src = rect(b.source.$1, b.source.$2);
  glow(c, src.center, cell * 0.7, _warm, alpha: 0.7);
  c.drawCircle(src.center, cell * 0.22, Paint()..color = _warm);
  c.drawLine(
    src.center,
    _port(src, b.source.$3),
    Paint()
      ..color = _warm
      ..strokeWidth = cell * 0.14
      ..strokeCap = StrokeCap.round,
  );
  final rcv = rect(b.receiver.$1, b.receiver.$2);
  final on = ok || restore > 0;
  if (on) glow(c, rcv.center, cell * (0.8 + restore), _leaf, alpha: 0.7);
  c.drawCircle(
    rcv.center,
    cell * 0.3,
    Paint()..color = on ? _leaf : const Color(0xFF22324F),
  );
  c.drawLine(
    rcv.center,
    _port(rcv, b.receiver.$3),
    Paint()
      ..color = on ? _leaf : const Color(0xFF3A4F75)
      ..strokeWidth = cell * 0.14
      ..strokeCap = StrokeCap.round,
  );
  _iconAt(
    c,
    moduleIcon(b.module),
    rcv.center,
    cell * 0.36,
    on ? const Color(0xFF07122A) : const Color(0xFF7F93B8),
  );
  // Conduits.
  for (final p in b.pieces) {
    final r = rect(p.r, p.c);
    final isLit = litSet.contains((p.r, p.c));
    final isSel = p.card != null && p.card == selected;
    if (p.card != null) {
      c.drawRRect(
        RRect.fromRectAndRadius(r.deflate(4), const Radius.circular(10)),
        Paint()
          ..color = isSel
              ? accent.withValues(alpha: 0.28 + 0.12 * math.sin(t * 6))
              : const Color(0xFF14284A),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(r.deflate(4), const Radius.circular(10)),
        Paint()
          ..color = isSel ? accent : const Color(0xFF2E4A78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSel ? 3 : 1.5,
      );
    }
    final ports = p.ports.toList();
    final path = Path();
    if (p.type == PieceType.straight) {
      final a = _port(r, ports[0]), z = _port(r, ports[1]);
      path
        ..moveTo(a.dx, a.dy)
        ..lineTo(z.dx, z.dy);
    } else {
      final a = _port(r, ports[0]), z = _port(r, ports[1]);
      path
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(r.center.dx, r.center.dy, z.dx, z.dy);
    }
    final col = isLit ? (on ? _leaf : _warm) : const Color(0xFF5B7099);
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF050B08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.2
        ..strokeCap = StrokeCap.round,
    );
    c.drawPath(
      path,
      Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.13
        ..strokeCap = StrokeCap.round,
    );
    if (isLit) {
      // Moving energy pulses along the lit conduit.
      for (final metric in path.computeMetrics()) {
        for (var k = 0; k < 2; k++) {
          final f = ((t * 0.9 + k * 0.5) % 1.0);
          final pos = metric.getTangentForOffset(metric.length * f)?.position;
          if (pos != null) {
            glow(c, pos, cell * 0.2, col, alpha: 0.9);
          }
        }
      }
    }
    if (p.fixed) {
      c.drawCircle(
        r.center,
        cell * 0.06,
        Paint()..color = const Color(0xFF8DA0C4),
      );
    }
    if (p.card != null) {
      final badge = r.topLeft + Offset(cell * 0.2, cell * 0.2);
      c.drawCircle(
        badge,
        cell * 0.14,
        Paint()..color = isSel ? accent : const Color(0xFF2E4A78),
      );
      strokedText(
        c,
        '${p.card}',
        badge,
        size: cell * 0.18,
        color: Colors.white,
      );
    }
  }
}

/// Tool cards at the player's reach zones, with dwell rings.
void paintToolCards(Canvas c, BodyMap m, LumenEngine e, double t) {
  final pieces = e.board.editable;
  for (final entry in lumenCards.entries) {
    final k = entry.key;
    final continueCard = e.state == 'rest';
    if (!continueCard && k > pieces.length) continue;
    if (continueCard && k != 2) continue;
    final (x, y) = entry.value;
    final at = m(x, y);
    final size = m.unit * 0.8;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: at, width: size, height: size * 1.1),
      Radius.circular(size * 0.2),
    );
    final sel = e.selected == k && e.state != 'rest';
    final hover = e.hover == k;
    c.drawRRect(rect.inflate(3), Paint()..color = const Color(0xCC050B08));
    c.drawRRect(rect, Paint()..color = sel ? _ice : _panel);
    c.drawRRect(
      rect,
      Paint()
        ..color = hover ? _warm : _ice.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = hover ? 3 : 1.5,
    );
    strokedText(
      c,
      continueCard ? '▶' : '$k',
      at,
      size: size * 0.42,
      color: sel ? const Color(0xFF07122A) : Colors.white,
    );
    if (hover && e.dwell > 0) {
      progressArc(c, at, size * 0.78, e.dwellProgress, _warm, width: 5);
    }
    if (!e.armed && hover) {
      strokedText(
        c,
        'arms down first',
        at + Offset(0, size * 0.85),
        size: 11,
        color: const Color(0xFFFFC857),
      );
    }
  }
}

void lumenPlay(
  Canvas c,
  Size s,
  BodyMap m,
  LumenEngine e,
  Rect boardArea,
  double t,
) {
  final restore = e.state == 'restoring'
      ? (e.stateMs / 3500).clamp(0.0, 1.0)
      : (e.state == 'rest' || e.state == 'done' ? 1.0 : 0.0);
  paintBoard(
    c,
    boardArea,
    e.board,
    t,
    selected: e.state == 'edit' || e.state == 'ready' ? e.selected : null,
    connected: e.board.connected,
    restore: restore,
  );
  if (e.state != 'restoring' && e.state != 'intro' && e.state != 'done') {
    paintToolCards(c, m, e, t);
  }
  if (e.state == 'ready') {
    final at = m(0, -1.35);
    final weld = e.weldArmed;
    glow(
      c,
      at,
      m.unit * 0.9,
      weld ? _leaf : _warm,
      alpha: 0.5 + 0.2 * math.sin(t * 5),
    );
    strokedText(
      c,
      weld ? (e.noSquat ? 'HANDS TOGETHER' : 'BEND TO WELD') : 'ARMS DOWN',
      at,
      size: 18,
      color: weld ? _leaf : _warm,
    );
    if (e.noSquat && e.weldHold > 0) {
      progressArc(c, at, m.unit * 0.6, e.weldProgress, _leaf, width: 5);
    }
  }
  if (e.state == 'restoring') {
    final at = boardArea.center;
    glow(
      c,
      at,
      boardArea.width * 0.6 * restore,
      _leaf,
      alpha: 0.5 * (1 - restore * 0.5),
    );
    _sprouts(
      c,
      Rect.fromLTRB(0, boardArea.bottom, s.width, boardArea.bottom + 60),
      restore,
      t,
    );
  }
}

void _sprouts(Canvas c, Rect band, double grow, double t) {
  for (var i = 0; i < 9; i++) {
    final x = band.left + band.width * (0.06 + i * 0.11);
    final h = band.height * grow * (0.5 + 0.5 * hash(i));
    final stem = Paint()
      ..color = _leaf
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final base = Offset(x, band.bottom);
    final top = base - Offset(math.sin(t + i) * 4, h);
    c.drawLine(base, top, stem);
    if (grow > 0.5) {
      c.drawOval(
        Rect.fromCenter(
          center: top + const Offset(6, 2),
          width: 12 * grow,
          height: 6 * grow,
        ),
        Paint()..color = _leaf,
      );
      c.drawOval(
        Rect.fromCenter(
          center: top + const Offset(-6, 4),
          width: 10 * grow,
          height: 5 * grow,
        ),
        Paint()..color = const Color(0xFF5DB872),
      );
    }
  }
}

/// The player's conservatory, restored module by module. [restored] holds
/// module names ('light', 'water', 'air', 'canopy', ...).
void paintHabitat(Canvas c, Size s, Set<String> restored, double t) {
  lumenBackdrop(c, s, t);
  final dome = Rect.fromCenter(
    center: Offset(s.width / 2, s.height * 0.78),
    width: s.width * 0.86,
    height: s.height * 0.9,
  );
  final canopy = restored.contains('canopy');
  // Glass dome.
  c.drawArc(
    dome,
    math.pi,
    math.pi,
    true,
    Paint()
      ..color = (canopy ? const Color(0xFF1A3A4A) : const Color(0xFF101B2E))
          .withValues(alpha: 0.85),
  );
  for (var i = 1; i < 6; i++) {
    c.drawArc(
      Rect.fromCenter(
        center: dome.center,
        width: dome.width * i / 6,
        height: dome.height,
      ),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = _ice.withValues(alpha: canopy ? 0.35 : 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }
  c.drawArc(
    dome,
    math.pi,
    math.pi,
    false,
    Paint()
      ..color = _ice.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3,
  );
  final floorY = dome.center.dy;
  c.drawRect(
    Rect.fromLTRB(dome.left, floorY, dome.right, floorY + 12),
    Paint()..color = const Color(0xFF22324F),
  );
  // Light: grow lamps.
  final light = restored.contains('light');
  for (var i = 0; i < 4; i++) {
    final x = dome.left + dome.width * (0.2 + i * 0.2);
    final y = floorY - dome.height * 0.3;
    if (light) glow(c, Offset(x, y), 34, _warm, alpha: 0.5);
    c.drawCircle(
      Offset(x, y),
      6,
      Paint()..color = light ? _warm : const Color(0xFF3A4F75),
    );
  }
  // Water: a channel along the floor.
  final water = restored.contains('water');
  c.drawRect(
    Rect.fromLTRB(dome.left + 12, floorY - 8, dome.right - 12, floorY),
    Paint()..color = water ? const Color(0xFF3FA9E0) : const Color(0xFF1C2A40),
  );
  if (water) {
    for (var i = 0; i < 6; i++) {
      final x = dome.left + ((t * 30 + i * 50) % dome.width);
      c.drawCircle(Offset(x, floorY - 4), 2, Paint()..color = Colors.white70);
    }
  }
  // Air: fans.
  final air = restored.contains('air');
  for (final x in [
    dome.left + dome.width * 0.12,
    dome.right - dome.width * 0.12,
  ]) {
    final at = Offset(x, floorY - dome.height * 0.12);
    c.drawCircle(at, 14, Paint()..color = const Color(0xFF22324F));
    for (var k = 0; k < 3; k++) {
      final a = (air ? t * 4 : 0) + k * math.pi * 2 / 3;
      c.drawLine(
        at,
        at + Offset(math.cos(a) * 12, math.sin(a) * 12),
        Paint()
          ..color = air ? _ice : const Color(0xFF3A4F75)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }
  }
  // Plants: more and greener with each restored module.
  final n = restored.length;
  for (var i = 0; i < 10; i++) {
    final x = dome.left + dome.width * (0.08 + i * 0.093);
    final h = 10 + (n == 0 ? 6 : 14 * n) * (0.6 + 0.4 * hash(i + 3));
    final col = n == 0
        ? const Color(0xFF5A5040)
        : Color.lerp(const Color(0xFF5DB872), _leaf, hash(i))!;
    c.drawLine(
      Offset(x, floorY - 8),
      Offset(x + math.sin(t + i) * 3, floorY - 8 - h),
      Paint()
        ..color = col
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    if (n > 0) {
      c.drawOval(
        Rect.fromCenter(
          center: Offset(x + 5, floorY - 8 - h),
          width: 12,
          height: 6,
        ),
        Paint()..color = col,
      );
    }
    if (canopy && i.isEven) {
      c.drawCircle(
        Offset(x, floorY - 12 - h),
        4,
        Paint()..color = const Color(0xFFFF8FB1),
      );
    }
  }
}

void lumenPreview(Canvas c, Size s, int variant, {LumenBoard? board}) {
  if (variant == 3) {
    paintHabitat(c, s, const {'light', 'water', 'air'}, 2);
    return;
  }
  lumenBackdrop(c, s, 1 + variant.toDouble());
  final b = board ?? _demoBoard();
  if (variant >= 1) {
    b.editable[0].turn(true);
  }
  if (variant == 2) {
    b.editable[1]
      ..turn(true)
      ..turn(true);
    b.editable[2]
      ..turn(true)
      ..turn(true);
  }
  // Wide framing: the board on the left, the player and tool cards right.
  final area = Rect.fromLTWH(
    s.width * 0.04,
    s.height * 0.1,
    s.width * 0.5,
    s.height * 0.8,
  );
  paintBoard(
    c,
    area,
    b,
    1.3,
    selected: variant == 2 ? null : (variant == 1 ? 2 : 1),
    connected: variant == 2,
  );
  final m = BodyMap(Offset(s.width * 0.76, s.height * 0.34), s.height * 0.12);
  final j = switch (variant) {
    1 => AvatarJoints.demo(m, lean: 13),
    2 => AvatarJoints.demo(m, dip: 0.55),
    _ => AvatarJoints.demo(m, shoulderL: 52),
  };
  paintAvatar(c, j, look: lumenLook);
  for (final e in lumenCards.entries) {
    final (x, y) = e.value;
    final at = m(x, y);
    final size = m.unit * 0.8;
    final sel = (variant == 0 && e.key == 1) || (variant == 1 && e.key == 2);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: at, width: size, height: size * 1.1),
        Radius.circular(size * 0.2),
      ),
      Paint()..color = sel ? _ice : _panel,
    );
    strokedText(
      c,
      '${e.key}',
      at,
      size: size * 0.42,
      color: sel ? const Color(0xFF07122A) : Colors.white,
    );
    if (sel && variant == 0) {
      progressArc(c, at, size * 0.78, 0.7, _warm, width: 4);
    }
  }
  if (variant == 2) {
    strokedText(c, 'WELD!', m(0, 1.0), size: 26, color: _leaf);
  }
}

LumenBoard _demoBoard() => LumenBoard(
  id: 'demo',
  title: 'Water pump',
  module: 'water',
  rows: 3,
  cols: 3,
  source: (1, 0, Dir.e),
  receiver: (2, 2, Dir.n),
  pieces: [
    LumenPiece(1, 1, PieceType.corner, 2, card: 1),
    LumenPiece(0, 1, PieceType.corner, 3, card: 2),
    LumenPiece(0, 2, PieceType.corner, 0, card: 3),
    LumenPiece(1, 2, PieceType.straight, 0, fixed: true),
  ],
);

/// Orbit, seen from inside the habitat: stars, the Earth's limb with the
/// sun just breaking over it, and the window's frame in the foreground.
void lumenBackdrop(Canvas c, Size s, double t) {
  _lumenScene(c, s, t);
  // Sunrise on the limb: a thin bright atmosphere and a flare.
  final earth = Offset(s.width * 0.5, s.height * 1.55);
  final r = s.height * 0.75;
  c.drawArc(
    Rect.fromCircle(center: earth, radius: r + 2),
    -math.pi * 0.72,
    math.pi * 0.44,
    false,
    Paint()
      ..color = const Color(0xFFBFE6FF).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5,
  );
  final sun = earth + Offset(math.cos(-math.pi * 0.36) * r, math.sin(-math.pi * 0.36) * r);
  final breathe = 0.85 + 0.15 * math.sin(t * 0.6);
  glow(c, sun, s.width * 0.45 * breathe, const Color(0xFFFFE9C2), alpha: 0.35);
  glow(c, sun, s.width * 0.1, Colors.white, alpha: 0.9);
  // A streak of flare across the window.
  c.drawLine(
    sun - Offset(s.width * 0.5, 0),
    sun + Offset(s.width * 0.5, 0),
    Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.35 * breathe),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCenter(center: sun, width: s.width, height: 4))
      ..strokeWidth = 2,
  );
  // Sunlight falling into the cabin.
  lightShaft(c, sun, s.height * 0.8, s.width * 0.3, const Color(0xFFFFE9C2), alpha: 0.1, lean: -s.width * 0.3);
  // The window frame: two struts and a sill, close to the eye.
  final strut = Paint()..color = const Color(0xFF060B16);
  final edge = Paint()
    ..color = _ice.withValues(alpha: 0.25)
    ..strokeWidth = 1.5;
  for (final x in [s.width * 0.035, s.width * 0.965]) {
    final rect = Rect.fromCenter(center: Offset(x, s.height / 2), width: s.width * 0.05, height: s.height);
    c.drawRect(rect, strut);
    c.drawLine(Offset(x < s.width / 2 ? rect.right : rect.left, 0), Offset(x < s.width / 2 ? rect.right : rect.left, s.height), edge);
  }
  vignette(c, s, strength: 0.5);
}

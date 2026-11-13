import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../l10n/tr.dart';

/// ------------------------------------------------------------------------
/// THE LOGO LIVES HERE.
///
/// Every screen shows the brand through [JoyneticMark] (the tile),
/// [JoyneticWordmark] (the name) or [JoyneticLogo] (both). To use your own
/// artwork, replace the file at [JoyneticBrand.markAsset] with a square PNG
/// (512 px or larger): nothing else changes, and no layout moves. The
/// launcher icon is made from the same drawing by `tools/make_brand.py`.
/// ------------------------------------------------------------------------
abstract final class JoyneticBrand {
  static const name = 'Joynetic';
  static const tagline = 'Your body is the controller.';

  /// The mark, as a bundled image.
  static const markAsset = 'assets/brand/logo_mark.png';

  /// Joy + kinetic: the two halves of the name, coloured apart.
  static const nameLead = 'joy';
  static const nameTail = 'netic';
}

/// The Joynetic mark: a rounded tile in the brand gradient with a "J" whose
/// dot has leapt up and away, and speed lines behind it. Joy, in motion.
///
/// Drawn from the bundled image; if that is missing it is painted from the
/// same geometry, so the mark never disappears.
class JoyneticMark extends StatelessWidget {
  const JoyneticMark({super.key, this.size = 88, this.glow = false});
  final double size;

  /// A soft halo in the brand colour behind the tile (hero placements).
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final fallback = CustomPaint(
      size: Size.square(size),
      painter: const _MarkPainter(),
    );
    final mark = Image.asset(
      JoyneticBrand.markAsset,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => fallback,
    );
    return Semantics(
      label: JoyneticBrand.name,
      image: true,
      child: glow
          ? DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.24),
                boxShadow: [
                  BoxShadow(
                    color: Jn.volt.withValues(alpha: 0.35),
                    blurRadius: size * 0.5,
                    spreadRadius: -size * 0.08,
                  ),
                ],
              ),
              child: mark,
            )
          : mark,
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(s * 0.24)),
      Paint()..shader = Jn.brand.createShader(rect),
    );
    final ink = Paint()
      ..color = Jn.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // The J: a stem and a hook.
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.60, s * 0.32)
        ..lineTo(s * 0.60, s * 0.62)
        ..cubicTo(s * 0.60, s * 0.84, s * 0.33, s * 0.86, s * 0.32, s * 0.68),
      ink,
    );
    // Its dot, mid-leap.
    canvas.drawCircle(
      Offset(s * 0.745, s * 0.175),
      s * 0.082,
      Paint()..color = Jn.ink,
    );
    // Speed lines.
    ink.strokeWidth = s * 0.05;
    for (final (y, x0) in const [(0.30, 0.23), (0.41, 0.14), (0.52, 0.27)]) {
      canvas.drawLine(Offset(s * x0, s * y), Offset(s * 0.44, s * y), ink);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => false;
}

/// The name, set tight and heavy, with "joy" in volt and "netic" in white.
class JoyneticWordmark extends StatelessWidget {
  const JoyneticWordmark({super.key, this.size = 28, this.color = Jn.text});

  /// Font size.
  final double size;

  /// Colour of the second half of the name.
  final Color color;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        const TextSpan(
          text: JoyneticBrand.nameLead,
          style: TextStyle(color: Jn.volt),
        ),
        TextSpan(
          text: JoyneticBrand.nameTail,
          style: TextStyle(color: color),
        ),
      ],
    ),
    semanticsLabel: JoyneticBrand.name,
    maxLines: 1,
    style: TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w900,
      letterSpacing: -size * 0.045,
      height: 1,
    ),
  );
}

/// Mark and name together. [stacked] puts the name under the mark (the
/// welcome screen); otherwise they sit side by side (headers).
class JoyneticLogo extends StatelessWidget {
  const JoyneticLogo({
    super.key,
    this.size = 32,
    this.stacked = false,
    this.glow = false,
  });

  /// Height of the mark; the name scales with it.
  final double size;
  final bool stacked;
  final bool glow;

  @override
  Widget build(BuildContext context) => stacked
      ? Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            JoyneticMark(size: size, glow: glow),
            SizedBox(height: size * 0.28),
            JoyneticWordmark(size: size * 0.62),
          ],
        )
      : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            JoyneticMark(size: size, glow: glow),
            SizedBox(width: size * 0.3),
            JoyneticWordmark(size: size * 0.72),
          ],
        );
}

/// The loading state: the mark, breathing, over a thin progress line.
/// Used wherever the app is getting something ready (the camera, a level).
class BrandLoader extends StatefulWidget {
  const BrandLoader({super.key, this.label});

  /// What is being prepared, in a few words.
  final String? label;

  @override
  State<BrandLoader> createState() => _BrandLoaderState();
}

class _BrandLoaderState extends State<BrandLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: hold still.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, child) => Transform.scale(
            scale: 0.94 + 0.06 * Curves.easeInOut.transform(_c.value),
            child: child,
          ),
          child: const JoyneticMark(size: 72, glow: true),
        ),
        const SizedBox(height: Space.xl),
        const SizedBox(
          width: 120,
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(3)),
            child: LinearProgressIndicator(minHeight: 4),
          ),
        ),
        if (widget.label != null) ...[
          const SizedBox(height: Space.m),
          Text(
            widget.label!,
            style: const TextStyle(color: Jn.textDim, fontSize: 15),
          ),
        ],
      ],
    ),
  );
}

/// One promise, stated plainly, with an icon. Used wherever the app asks
/// for trust: first launch, before the camera permission, in Settings.
class TrustPoint extends StatelessWidget {
  const TrustPoint(this.icon, this.title, {super.key, this.detail});
  final IconData icon;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.s),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Jn.aqua.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: Jn.aqua),
        ),
        const SizedBox(width: Space.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(title),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(
                  tr(detail!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// The privacy promises about the camera, in one panel. The wording is
/// factual and checkable: the camera image is drawn by Android and never
/// enters the app's own code, only 33 body points do.
class CameraTrustPanel extends StatelessWidget {
  const CameraTrustPanel({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.l, Space.m),
    decoration: BoxDecoration(
      color: Jn.panel,
      borderRadius: BorderRadius.circular(Jn.radiusCard),
      border: Border.all(color: Jn.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('YOUR CAMERA, YOUR PHONE'), style: Txt.overline),
        const SizedBox(height: Space.xs),
        const TrustPoint(
          Icons.smartphone_rounded,
          'Processed on this phone',
          detail: 'The camera is read here, live. Nothing is sent anywhere.',
        ),
        const TrustPoint(
          Icons.videocam_off_rounded,
          'Never recorded',
          detail: 'No photos, no video, no screenshots of you. Ever.',
        ),
        const TrustPoint(
          Icons.accessibility_new_rounded,
          'Only 33 body points',
          detail:
              'The game sees a stick figure, not you. You can watch exactly what it sees.',
        ),
      ],
    ),
  );
}

/// A full-page state: something went wrong, or there is nothing here yet.
/// One icon, one headline, one line of help, and what to do next.
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actions = const [],
    this.tone = Jn.warning,
  });
  final IconData icon;
  final String title;
  final String? message;
  final List<Widget> actions;
  final Color tone;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 42, color: tone),
          ),
        ),
        const SizedBox(height: Space.xl),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (message != null) ...[
          const SizedBox(height: Space.s),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Jn.textDim),
          ),
        ],
        const SizedBox(height: Space.xl),
        ...actions,
      ],
    ),
  );
}

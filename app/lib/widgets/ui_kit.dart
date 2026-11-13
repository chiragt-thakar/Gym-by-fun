import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../l10n/tr.dart';

/// Section heading used on every shell page: an optional overline, a title
/// and an optional trailing action ("See all").
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.overline,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.only(top: Space.xl, bottom: Space.m),
  });
  final String title;
  final String? overline;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (overline != null) ...[
                Text(tr(overline!).toUpperCase(), style: Txt.overline),
                const SizedBox(height: 4),
              ],
              Text(tr(title), style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(48, 36),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr(action!)),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
      ],
    ),
  );
}

/// The standard tappable panel: one hairline border, one radius, optional
/// accent wash. Used for every card in the shell so they all match.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Space.l),
    this.color = Lantern.canopy,
    this.borderColor = Lantern.line,
    this.radius = Lantern.radius,
    this.clip = false,
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double radius;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    // The standard panel is a raised surface: lit from above, with a
    // shadow under it. A card given its own colour stays flat in it.
    final raised = color == Lantern.canopy;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: raised ? Jn.surface : null,
        color: raised ? null : color,
        border: Border.all(color: borderColor),
        boxShadow: raised ? Jn.cardShadow : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: r,
        clipBehavior: clip || onTap != null ? Clip.antiAlias : Clip.none,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Small rounded label with an icon: duration, moves, intensity, genre.
class MetaPill extends StatelessWidget {
  const MetaPill(
    this.icon,
    this.label, {
    super.key,
    this.color = Lantern.fog,
    this.background = Lantern.surface2,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Lantern.line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Lantern.parchment,
            ),
          ),
        ),
      ],
    ),
  );
}

/// A number with a label, for stats strips.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.accent = Lantern.glow,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: accent),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: Txt.numeral),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Txt.caption,
        ),
      ],
    ),
  );
}

/// Earned stars, shape + colour (filled vs outlined), never colour alone.
class StarRow extends StatelessWidget {
  const StarRow(this.stars, {super.key, this.max = 3, this.size = 18});
  final int stars;
  final int max;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$stars of $max stars',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < max; i++)
          Icon(
            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i < stars ? Lantern.warning : Lantern.ridge,
          ),
      ],
    ),
  );
}

/// Tiny uppercase badge ("NEW", "PREMIUM", "PARTY").
class TagBadge extends StatelessWidget {
  const TagBadge(this.text, {super.key, this.color = Lantern.glow});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.9,
        color: color,
      ),
    ),
  );
}

/// A settings-style row: leading icon tile, title, subtitle, chevron.
class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.accent = Lantern.scarf,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color accent;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 21, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          trailing ??
              (onTap == null
                  ? const SizedBox.shrink()
                  : const Icon(
                      Icons.chevron_right_rounded,
                      color: Lantern.mist,
                    )),
        ],
      ),
    ),
  );
}

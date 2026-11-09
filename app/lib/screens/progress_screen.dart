import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../arcade/catalog.dart';
import '../arcade/content.dart';
import '../arcade/progress.dart';
import '../game/stages.dart';
import '../l10n/tr.dart';
import '../services/coach_service.dart';
import '../services/session_queue.dart';
import '../services/settings.dart';
import '../widgets/common.dart';
import '../widgets/world_card.dart';
import 'home_screen.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final week = weekStats(ref);
    final arcade = ref.watch(arcadeProgressProvider);
    final history = ref.watch(coachHistoryProvider);
    final content = ref.watch(arcadeContentProvider).value;
    final catalogue = ref.watch(levelCatalogueProvider).value;
    final status = ref.watch(syncStatusProvider).value;
    final active = {
      for (final day in ref.watch(activityDaysProvider))
        if (DateTime.tryParse(day) != null) DateTime.parse(day),
    };
    final today = DateUtils.dateOnly(DateTime.now());
    final fortnight = [
      for (var i = 13; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];
    final keepsakes = [
      for (final st in stages)
        if (s.completedLevels.contains(st.levelId))
          catalogue?[st.levelId]?.journey?.keepsake ?? st.title,
    ];
    final calmed = content == null
        ? const <String>[]
        : [
            for (final g in content.guardians)
              if (arcade.completed('craftguard', g.id)) g.name,
          ];
    final allTimeMoves =
        history.fold<int>(0, (n, r) => n + r.totalReps) +
        arcade.sessions.fold<int>(0, (n, x) => n + x.moves);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.l,
            Space.gutter,
            Space.xxl,
          ),
          children: [
            Text(tr('THIS WEEK'), style: Txt.overline),
            const SizedBox(height: 4),
            Text(
              tr('Progress'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              tr('Counts only, kept on this phone. Rest days belong here too.'),
              style: const TextStyle(color: Lantern.fog, fontSize: 14),
            ),
            const SizedBox(height: Space.l),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.calendar_today_rounded,
                    value: '${week.activeDays}/7',
                    label: tr('Active days'),
                    accent: Lantern.scarf,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    icon: Icons.bolt_rounded,
                    value: '${week.moves}',
                    label: tr('Moves done'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    icon: Icons.timelapse_rounded,
                    value: week.minutes.toStringAsFixed(
                      week.minutes < 10 ? 1 : 0,
                    ),
                    label: tr('Active min'),
                    accent: Lantern.warning,
                  ),
                ),
              ],
            ),
            const SectionHeader('Last 14 days'),
            AppCard(
              child: Column(
                children: [
                  for (final row in [
                    fortnight.sublist(0, 7),
                    fortnight.sublist(7),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          for (final d in row)
                            Expanded(
                              child: Column(
                                children: [
                                  Container(
                                    height: 28,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: active.contains(d)
                                          ? Lantern.scarf
                                          : Lantern.surface2,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: d == today
                                            ? Lantern.parchment
                                            : Lantern.line,
                                      ),
                                    ),
                                    child: active.contains(d)
                                        ? const Icon(
                                            Icons.check_rounded,
                                            size: 16,
                                            color: Lantern.night,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${d.day}',
                                    style: Txt.caption.copyWith(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.all_inclusive_rounded,
                        size: 16,
                        color: Lantern.mist,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${tr('All-time moves')}: $allTimeMoves',
                          style: Txt.caption,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SectionHeader('By game'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  for (final (i, g) in games.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    NavRow(
                      key: ValueKey('progress-${g.id}'),
                      icon: g.icon,
                      accent: g.accent,
                      title: tr(g.title),
                      subtitle: g.id == adventureId
                          ? '${s.completedLevels.length}/${stages.length} ${tr('chapters complete')} · ${history.length} ${tr('recent runs')}'
                          : arcade.playsFor(g.id) == 0
                          ? tr('Not played yet')
                          : '${arcade.playsFor(g.id)} ${tr('plays')} · ${arcade.starsFor(g.id)} ${tr('stars')}',
                      onTap: () => context.push('/game/${g.id}'),
                    ),
                  ],
                ],
              ),
            ),
            const SectionHeader('Collection'),
            _CollectionRow(
              icon: Icons.diamond_outlined,
              title: tr('Trail keepsakes'),
              count: '${keepsakes.length}/${stages.length}',
              items: keepsakes,
              empty: tr('Finish a chapter to find your first keepsake.'),
            ),
            const SizedBox(height: 10),
            _CollectionRow(
              icon: Icons.shield_moon_outlined,
              title: tr('Calmed guardians'),
              count: '${calmed.length}/${content?.guardians.length ?? 6}',
              items: calmed,
              empty: tr(
                'Calm a guardian in Craftguard Duels to start your shelf.',
              ),
            ),
            const SizedBox(height: 10),
            _CollectionRow(
              icon: Icons.eco_outlined,
              title: tr('Habitat repairs'),
              count: '${arcade.habitat.length}',
              items: [for (final h in arcade.habitat) h.split('/').last],
              empty: tr('Restore a module in LUMEN and it stays restored.'),
            ),
            const SizedBox(height: Space.xl),
            SyncLine(
              status: status,
              signedIn: s.signedIn,
              onRetry: () async {
                try {
                  await ref.read(sessionQueueProvider).flush();
                } catch (_) {}
                ref.invalidate(syncStatusProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({
    required this.icon,
    required this.title,
    required this.count,
    required this.items,
    required this.empty,
  });
  final IconData icon;
  final String title;
  final String count;
  final List<String> items;
  final String empty;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Lantern.glow, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            Text(
              count,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Lantern.scarf,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Text(empty, style: Txt.caption)
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final i in items)
                MetaPill(
                  Icons.auto_awesome_rounded,
                  tr(i[0].toUpperCase() + i.substring(1)),
                  color: Lantern.warning,
                ),
            ],
          ),
      ],
    ),
  );
}

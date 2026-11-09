import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_director/game_director.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../arcade/art/game_art.dart';
import '../arcade/catalog.dart';
import '../arcade/progress.dart';
import '../game/forest_game.dart' show HeroLook;
import '../game/stages.dart';
import '../l10n/tr.dart';
import '../services/api_client.dart';
import '../services/coach_service.dart';
import '../services/premium.dart';
import '../services/session_queue.dart';
import '../services/settings.dart';
import '../widgets/common.dart';
import 'quest_screen.dart' show warmup, cooldown;
import 'stage_info_sheet.dart';

/// Gym branding and progress, if signed in. Null when offline or signed out.
final homeDataProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((
  ref,
) async {
  final api = ref.watch(apiProvider);
  if (!api.tokens.hasSession) return null;
  try {
    await ref.read(sessionQueueProvider).flush();
    final results = await Future.wait([api.progress(), api.myGym()]);
    return {
      'progress': results[0],
      'gym': results[1]['gym'],
      'quests': results[1]['quests'],
    };
  } catch (_) {
    return null;
  }
});

final _hexColour = RegExp(r'^#[0-9a-fA-F]{6}$');

/// The gym's primary colour, or null if it is missing or not `#RRGGBB`.
Color? parseGymColour(Map<String, dynamic>? gym) {
  final colours = gym?['colours'];
  if (colours is! Map) return null;
  final hex = colours['primary'];
  if (hex is! String || !_hexColour.hasMatch(hex)) return null;
  return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}

/// The bundled catalogue is the single source for story and time estimates.
final levelCatalogueProvider = FutureProvider<Map<String, LevelConfig>>((
  ref,
) async {
  final levels = await Future.wait([
    for (final stage in stages)
      rootBundle.loadString(stage.asset).then(LevelConfig.decode),
  ]);
  return {for (final level in levels) level.id: level};
});

final syncStatusProvider =
    FutureProvider.autoDispose<({int pending, int rejected})?>((ref) async {
      try {
        final q = ref.watch(sessionQueueProvider);
        return (
          pending: (await q.pendingForCurrentAccount()).length,
          rejected: await q.rejectedCount(),
        );
      } catch (_) {
        return null;
      }
    });

String questTimeLabel(LevelConfig level) {
  final seconds =
      level.durationMs ~/ 1000 +
      [...warmup, ...cooldown].fold<int>(0, (n, e) => n + e.seconds);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// Today's featured game: the same for everyone on an IST day.
GameInfo gameOfTheDay(DateTime now) {
  final pool = games.where((g) => g.id != adventureId).toList();
  return pool[dailySeed(now.toUtc()) % pool.length];
}

/// The last 7 local days, oldest first.
List<DateTime> lastSevenDays([DateTime? now]) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  return [
    for (var i = 6; i >= 0; i--)
      DateTime(today.year, today.month, today.day - i),
  ];
}

/// Weekly numbers across the runner and the arcade games.
({int activeDays, int moves, double minutes}) weekStats(WidgetRef ref) {
  final days = lastSevenDays();
  final active = {
    for (final day in ref.watch(activityDaysProvider))
      if (DateTime.tryParse(day) != null) DateTime.parse(day),
  };
  final since = days.first;
  final runs = ref
      .watch(coachHistoryProvider)
      .where((r) => !r.date.toLocal().isBefore(since));
  final arcade = ref
      .watch(arcadeProgressProvider)
      .sessions
      .where((s) => !s.date.toLocal().isBefore(since));
  final moves =
      runs.fold<int>(0, (n, r) => n + r.totalReps) +
      arcade.fold<int>(0, (n, s) => n + s.moves);
  final ms =
      runs.fold<int>(0, (n, r) => n + r.activeMs) +
      arcade.fold<int>(0, (n, s) => n + s.activeMs);
  return (
    activeDays: days.where(active.contains).length,
    moves: moves,
    minutes: ms / 60000,
  );
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final data = ref.watch(homeDataProvider).value;
    final gym = data?['gym'] as Map<String, dynamic>?;
    final premium = ref.watch(premiumProvider).value ?? const PremiumState();
    final premiumLocked = PaywallPolicy.paymentsEnabled && !premium.premium;
    final next = nextStage(s.completedLevels, premiumLocked: premiumLocked);
    final level = ref.watch(levelCatalogueProvider).value?[next.levelId];
    final gymColour = parseGymColour(gym);
    final pick = gameOfTheDay(DateTime.now());
    final week = weekStats(ref);
    final arcade = ref.watch(arcadeProgressProvider);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeDataProvider);
            await ref.read(homeDataProvider.future);
            ref.invalidate(syncStatusProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.l,
              Space.gutter,
              Space.xxl,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _Greeting(
                greeting: tr(greeting),
                gymName: gym?['name'] as String?,
                look: s.heroLook,
                onProfile: () => context.go('/profile'),
              ),
              if (s.calibration == null) ...[
                const SizedBox(height: Space.l),
                _SetupReminder(onTap: () => context.push('/get-ready')),
              ],
              SectionHeader(
                'Continue your adventure',
                overline: 'MotionQuest Trails',
                action: 'Chapters',
                onAction: () => context.push('/game/$adventureId'),
              ),
              _AdventureCard(
                stage: next,
                level: level,
                lowImpact: s.lowImpact,
                difficulty: s.difficulty,
                accent: gymColour,
                onPlay: () => context.push('/quest?level=${next.levelId}'),
                onGentle: () =>
                    context.push('/quest?level=${next.levelId}&pace=gentle'),
                onGuide: () => showStageInfoSheet(
                  context,
                  next,
                  onPlay: () => context.push('/quest?level=${next.levelId}'),
                ),
              ),
              SectionHeader("Today's pick", overline: 'New game'),
              _PickCard(
                game: pick,
                stars: arcade.starsFor(pick.id),
                onTap: () => context.push('/game/${pick.id}'),
              ),
              SectionHeader(
                'Your week',
                action: 'Progress',
                onAction: () => context.go('/progress'),
              ),
              _WeekCard(
                activeDays: week.activeDays,
                moves: week.moves,
                minutes: week.minutes,
                onTap: () => context.go('/progress'),
              ),
              SectionHeader(
                'Explore games',
                action: 'See all',
                onAction: () => context.go('/games'),
              ),
              SizedBox(
                height: 214,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: games.length,
                  separatorBuilder: (_, _) => const SizedBox(width: Space.m),
                  itemBuilder: (context, i) => _MiniGameCard(
                    game: games[i],
                    onTap: () => context.push('/game/${games[i].id}'),
                  ),
                ),
              ),
              const SizedBox(height: Space.xl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: Lantern.mist,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${s.s.t('video_never_leaves')} ${s.s.t('not_medical')}',
                      style: Txt.caption,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.greeting,
    required this.gymName,
    required this.look,
    required this.onProfile,
  });
  final String greeting;
  final String? gymName;
  final HeroLook look;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (gymName ?? 'MotionQuest').toUpperCase(),
              style: Txt.overline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(greeting, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 2),
            Text(
              tr('A little movement. A new adventure.'),
              style: const TextStyle(color: Lantern.fog, fontSize: 14),
            ),
          ],
        ),
      ),
      Semantics(
        button: true,
        label: tr('Profile'),
        child: InkWell(
          onTap: onProfile,
          customBorder: const CircleBorder(),
          child: Container(
            width: 52,
            height: 52,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Lantern.moss,
              border: Border.all(color: Lantern.ridge, width: 1.5),
            ),
            child: FittedBox(
              fit: BoxFit.cover,
              child: ExplorerPortrait(look: look),
            ),
          ),
        ),
      ),
    ],
  );
}

class _SetupReminder extends StatelessWidget {
  const _SetupReminder({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AppCard(
    key: const ValueKey('setup-reminder'),
    onTap: onTap,
    color: const Color(0xFF0D2622),
    borderColor: const Color(0xFF1E4A43),
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Lantern.scarf.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.accessibility_new_rounded,
            color: Lantern.scarf,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('One minute before your first run'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                tr(
                  'Explore freely. When you tap play, we will quickly learn your comfortable range.',
                ),
                style: Txt.caption,
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: Lantern.mist),
      ],
    ),
  );
}

class _AdventureCard extends StatelessWidget {
  const _AdventureCard({
    required this.stage,
    required this.level,
    required this.lowImpact,
    required this.difficulty,
    required this.onPlay,
    required this.onGentle,
    required this.onGuide,
    this.accent,
  });
  final Stage stage;
  final LevelConfig? level;
  final bool lowImpact;
  final Difficulty difficulty;
  final VoidCallback onPlay;
  final VoidCallback onGentle;
  final VoidCallback onGuide;
  final Color? accent;

  @override
  Widget build(BuildContext context) => AppCard(
    key: const ValueKey('adventure-card'),
    padding: EdgeInsets.zero,
    clip: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 8,
          child: Stack(
            fit: StackFit.expand,
            children: [
              WorldVista(theme: stage.theme),
              Positioned(
                left: 14,
                top: 14,
                child: _Chip(
                  '${tr('World')} ${stage.world} · ${tr('Chapter')} ${stage.stageNumber}',
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(stage.title),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                tr(level?.journey?.mission ?? stage.description),
                style: const TextStyle(
                  fontSize: 14,
                  color: Lantern.fog,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (level != null)
                    MetaPill(
                      Icons.schedule_rounded,
                      '${questTimeLabel(level!)} ${tr('total')}',
                    ),
                  MetaPill(
                    lowImpact ? Icons.spa_outlined : Icons.directions_run,
                    tr(lowImpact ? 'Low-impact' : 'Standard moves'),
                  ),
                  MetaPill(
                    Icons.tune_rounded,
                    tr(switch (difficulty) {
                      Difficulty.beginner => 'Beginner',
                      Difficulty.intermediate => 'Medium',
                      Difficulty.advanced => 'Advanced',
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: FilledButton.icon(
                      key: const ValueKey('start-adventure'),
                      style: FilledButton.styleFrom(backgroundColor: accent),
                      onPressed: onPlay,
                      icon: const Icon(Icons.play_arrow_rounded, size: 26),
                      label: Text(tr('Play')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      key: const ValueKey('gentle-today'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 54),
                      ),
                      onPressed: onGentle,
                      icon: const Icon(Icons.spa_outlined, size: 18),
                      label: Text(tr('Gentle'), maxLines: 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: onGuide,
                icon: const Icon(Icons.info_outline_rounded, size: 18),
                label: Text(tr('Mission & movement guide')),
              ),
              Text(
                tr(
                  'Includes warm-up and cool-down. Gentle is one run with beginner pace, low-impact and assist.',
                ),
                style: Txt.caption,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Lantern.night.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Lantern.parchment,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _PickCard extends StatelessWidget {
  const _PickCard({
    required this.game,
    required this.stars,
    required this.onTap,
  });
  final GameInfo game;
  final int stars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    padding: EdgeInsets.zero,
    color: game.deep,
    borderColor: game.accent.withValues(alpha: 0.35),
    child: SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 124, child: GameArt(gameId: game.id, variant: 0)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(game.icon, size: 16, color: game.accent),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          tr(game.genre.label).toUpperCase(),
                          style: Txt.overline.copyWith(
                            color: game.accent,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(game.title),
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(game.tagline),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Txt.caption.copyWith(color: Lantern.fog),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        tr('Play now'),
                        style: TextStyle(
                          color: game.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: game.accent,
                      ),
                      const Spacer(),
                      if (stars > 0) StarRow(stars.clamp(0, 3), size: 14),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.activeDays,
    required this.moves,
    required this.minutes,
    required this.onTap,
  });
  final int activeDays;
  final int moves;
  final double minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, _) {
      final active = {
        for (final day in ref.watch(activityDaysProvider))
          if (DateTime.tryParse(day) != null) DateTime.parse(day),
      };
      final days = lastSevenDays();
      final today = days.last;
      const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      return AppCard(
        onTap: onTap,
        child: Column(
          children: [
            Row(
              children: [
                for (final day in days)
                  Expanded(
                    child: Semantics(
                      label:
                          '${day.day}/${day.month}: ${tr(active.contains(day) ? 'Active day' : 'Rest day')}',
                      child: Column(
                        children: [
                          Text(
                            names[day.weekday - 1],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: day == today
                                  ? Lantern.parchment
                                  : Lantern.mist,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active.contains(day)
                                  ? Lantern.scarf
                                  : Lantern.surface2,
                              border: Border.all(
                                color: day == today
                                    ? Lantern.parchment
                                    : Lantern.line,
                              ),
                            ),
                            child: Icon(
                              active.contains(day)
                                  ? Icons.check_rounded
                                  : Icons.remove_rounded,
                              size: 16,
                              color: active.contains(day)
                                  ? Lantern.night
                                  : Lantern.ridge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                _MiniStat('$activeDays/7', tr('Active days')),
                _MiniStat('$moves', tr('Moves done')),
                _MiniStat(
                  minutes.toStringAsFixed(minutes < 10 ? 1 : 0),
                  tr('Active min'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: Txt.numeral.copyWith(fontSize: 20)),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Txt.caption.copyWith(fontSize: 12),
        ),
      ],
    ),
  );
}

class _MiniGameCard extends StatelessWidget {
  const _MiniGameCard({required this.game, required this.onTap});
  final GameInfo game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 168,
    child: AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 122,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GameArt(gameId: game.id, variant: 0),
                if (game.isNew)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: TagBadge(tr('New'), color: game.accent),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(game.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(game.icon, size: 13, color: game.accent),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        tr(game.genre.label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Txt.caption.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

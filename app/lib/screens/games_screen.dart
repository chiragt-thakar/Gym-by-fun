import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../arcade/art/game_art.dart';
import '../arcade/catalog.dart';
import '../arcade/progress.dart';
import '../game/stages.dart';
import '../l10n/tr.dart';
import '../services/settings.dart';
import '../widgets/common.dart';

/// The game library: every way to move, with a preview of each world.
class GamesScreen extends ConsumerStatefulWidget {
  const GamesScreen({super.key});
  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen> {
  GameGenre? _genre;

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(arcadeProgressProvider);
    final completed = ref.watch(
      settingsProvider.select((s) => s.completedLevels),
    );
    final shown = [
      for (final g in games)
        if (_genre == null || g.inGenre(_genre!)) g,
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.l,
                Space.gutter,
                0,
              ),
              sliver: SliverList.list(
                children: [
                  Text(tr('LIBRARY'), style: Txt.overline),
                  const SizedBox(height: 4),
                  Text(
                    tr('Games'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(
                      'Seven ways to move. Your body is the controller in every one.',
                    ),
                    style: const TextStyle(color: Lantern.fog, fontSize: 14),
                  ),
                  const SizedBox(height: Space.l),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  children: [
                    _filter(null, 'All'),
                    for (final g in GameGenre.values) _filter(g, g.label),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.l,
                Space.gutter,
                Space.xxl,
              ),
              sliver: SliverList.separated(
                itemCount: shown.length,
                separatorBuilder: (_, _) => const SizedBox(height: Space.l),
                itemBuilder: (context, i) {
                  final g = shown[i];
                  final stars = g.id == adventureId
                      ? stages
                            .where((s) => completed.contains(s.levelId))
                            .length
                      : progress.starsFor(g.id);
                  return GameCard(
                    key: ValueKey('game-${g.id}'),
                    game: g,
                    progressLabel: g.id == adventureId
                        ? '${stages.where((s) => completed.contains(s.levelId)).length}/${stages.length} ${tr('chapters')}'
                        : stars > 0
                        ? '$stars ${tr('stars earned')}'
                        : null,
                    onTap: () => context.push('/game/${g.id}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filter(GameGenre? g, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(tr(label)),
      selected: _genre == g,
      onSelected: (_) => setState(() => _genre = g),
    ),
  );
}

/// A large library card: preview art, title, tagline and quick facts.
class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.game,
    required this.onTap,
    this.progressLabel,
  });
  final GameInfo game;
  final VoidCallback onTap;
  final String? progressLabel;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'art-${game.id}',
                child: GameArt(gameId: game.id),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x99000000)],
                    stops: [0.55, 1],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: Wrap(
                  spacing: 6,
                  children: [
                    if (game.isNew) TagBadge(tr('New'), color: game.accent),
                    if (game.selfView)
                      TagBadge(tr('See yourself'), color: Lantern.parchment),
                  ],
                ),
              ),
              Positioned(
                left: 14,
                bottom: 12,
                right: 14,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: game.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        game.icon,
                        size: 18,
                        color: const Color(0xFF0B1611),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      tr(game.genre.label).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(game.title),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Lantern.mist),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                tr(game.tagline),
                style: const TextStyle(
                  color: Lantern.fog,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  MetaPill(Icons.schedule_rounded, tr(game.minutes)),
                  MetaPill(Icons.favorite_border_rounded, tr(game.intensity)),
                  if (progressLabel != null)
                    MetaPill(
                      Icons.star_rounded,
                      progressLabel!,
                      color: Lantern.warning,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

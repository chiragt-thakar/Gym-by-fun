import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../l10n/tr.dart';
import '../widgets/common.dart';
import 'arcade_screen.dart';
import 'art/game_art.dart';
import 'catalog.dart';
import 'progress.dart';

class ArcadeResultsScreen extends ConsumerWidget {
  const ArcadeResultsScreen({super.key, required this.result});
  final ArcadeResult? result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = result;
    if (r == null) {
      return ScreenScaffold(
        title: tr('Results'),
        children: [Text(tr('Nothing to show yet.'))],
      );
    }
    final game = gameById(r.args.gameId) ?? games.first;
    final s = r.summary;
    final progress = ref.watch(arcadeProgressProvider);
    final best = s.score > r.previousBest && r.previousBest > 0;
    final next = r.nextStage;
    final nextOpen =
        next != null &&
        progress.unlocked(
          game.id,
          [r.args.stageId, next.id],
          next.id,
          alwaysOpen: next.party,
        );
    final minutes = s.activeMs / 60000;
    void back() =>
        context.canPop() ? context.pop() : context.go('/game/${game.id}');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) {
        if (!did) back();
      },
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 230,
              leading: IconButton(
                tooltip: tr('Back'),
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: back,
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    GameArt(gameId: game.id, variant: 2),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0xEE0A0C10)],
                          stops: [0.45, 1],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                0,
                Space.gutter,
                Space.xxl,
              ),
              sliver: SliverList.list(
                children: [
                  Text(
                    '${tr(game.title)} · ${tr(r.stageName)}'.toUpperCase(),
                    style: Txt.overline.copyWith(color: game.accent),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(s.headline),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StarRow(s.stars, max: s.maxStars, size: 30),
                      if (best) TagBadge(tr('New best'), color: Lantern.scarf),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          icon: Icons.emoji_events_rounded,
                          value: '${s.score}',
                          label: tr(game.id == 'tapeball' ? 'Runs' : 'Score'),
                          accent: game.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatTile(
                          icon: Icons.bolt_rounded,
                          value: '${s.totalMoves}',
                          label: tr('Moves'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatTile(
                          icon: Icons.timelapse_rounded,
                          value: minutes.toStringAsFixed(1),
                          label: tr('Active min'),
                          accent: Lantern.scarf,
                        ),
                      ),
                    ],
                  ),
                  if (s.details.isNotEmpty) ...[
                    const SectionHeader('Round details'),
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Column(
                        children: [
                          for (final (i, e) in s.details.entries.indexed) ...[
                            if (i > 0) const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      tr(e.key),
                                      style: const TextStyle(
                                        color: Lantern.fog,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    e.value,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (s.bestCombo > 1) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      tr('Best streak'),
                                      style: const TextStyle(
                                        color: Lantern.fog,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${s.bestCombo}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (s.moves.isNotEmpty) ...[
                    const SectionHeader('Movement involved'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in s.moves.entries)
                          if (m.value > 0)
                            MetaPill(
                              Icons.check_rounded,
                              '${tr(_cap(m.key))} × ${m.value}',
                              color: Lantern.scarf,
                            ),
                      ],
                    ),
                  ],
                  if (s.forgiven > 0) ...[
                    const SizedBox(height: 14),
                    Text(
                      '${tr('Forgiven while tracking was paused')}: ${s.forgiven}',
                      style: Txt.caption,
                    ),
                  ],
                  const SizedBox(height: 24),
                  BigButton(
                    tr('Play again'),
                    icon: Icons.replay_rounded,
                    onPressed: () =>
                        context.pushReplacement(r.args.toUri().toString()),
                  ),
                  if (next != null && nextOpen)
                    BigButton(
                      '${tr('Next')}: ${tr(next.name)}',
                      icon: Icons.skip_next_rounded,
                      secondary: true,
                      onPressed: () => context.pushReplacement(
                        ArcadeArgs(
                          gameId: r.args.gameId,
                          stageId: next.id,
                          difficulty: r.args.difficulty,
                          assist: r.args.assist,
                          noSquat: r.args.noSquat,
                          level: r.args.level,
                        ).toUri().toString(),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: back,
                      child: Text(tr('Back to the game')),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      'General fitness play, not a medical product. Counts are kept on this phone.',
                    ),
                    textAlign: TextAlign.center,
                    style: Txt.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

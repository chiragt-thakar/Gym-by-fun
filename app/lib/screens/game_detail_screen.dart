import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../arcade/arcade_screen.dart' show ArcadeArgs;
import '../arcade/art/duel_art.dart' show paintGuardian;
import '../arcade/art/game_art.dart';
import '../arcade/catalog.dart';
import '../arcade/content.dart';
import '../arcade/progress.dart';
import '../game/stages.dart';
import '../l10n/tr.dart';
import '../services/premium.dart';
import '../services/settings.dart';
import '../widgets/common.dart';
import '../widgets/world_card.dart';

class GameDetailScreen extends ConsumerStatefulWidget {
  const GameDetailScreen({super.key, required this.gameId});
  final String gameId;
  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailState();
}

class _GameDetailState extends ConsumerState<GameDetailScreen> {
  String? _stage;
  String? _difficulty;
  String _level = 'light';
  bool _assist = false;
  bool _noSquat = false;
  bool _adults = false;
  final List<String> _players = [];
  final _name = TextEditingController();
  final _scroll = ScrollController();
  bool _collapsed = false;
  int _page = 0;

  GameInfo get game => gameById(widget.gameId) ?? games.first;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _difficulty = s.difficulty.name;
    _assist = s.assist;
    _scroll.addListener(() {
      final c = _scroll.hasClients && _scroll.offset > 170;
      if (c != _collapsed) setState(() => _collapsed = c);
    });
    _level = switch (s.difficulty.name) {
      'advanced' => 'toofan',
      'intermediate' => 'groove',
      _ => 'light',
    };
  }

  @override
  void dispose() {
    _name.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _back() => context.canPop() ? context.pop() : context.go('/games');

  @override
  Widget build(BuildContext context) {
    final g = game;
    final content = ref.watch(arcadeContentProvider).value;
    final progress = ref.watch(arcadeProgressProvider);
    final stageList = content?.stagesFor(g.id) ?? const <ArcadeStage>[];
    final order = [for (final s in stageList) s.id];
    bool open(ArcadeStage s) =>
        progress.unlocked(g.id, order, s.id, alwaysOpen: s.party);
    final selected = stageList.isEmpty
        ? null
        : stageList.firstWhere(
            (s) => s.id == _stage,
            orElse: () => stageList.firstWhere(
              (s) => open(s) && !progress.completed(g.id, s.id),
              orElse: () => stageList.first,
            ),
          );
    final isAdventure = g.id == adventureId;
    final party = selected?.party ?? false;
    final canPlay =
        isAdventure ||
        (selected != null &&
            open(selected) &&
            (!party || (_players.length >= 2 && _adults)));

    return PopScope(
      canPop: true,
      child: Scaffold(
        body: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: 250,
              backgroundColor: Lantern.night,
              leading: Padding(
                padding: const EdgeInsets.all(6),
                child: IconButton.filledTonal(
                  tooltip: tr('Back'),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0x990A0C10),
                  ),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Lantern.parchment,
                  ),
                  onPressed: _back,
                ),
              ),
              title: AnimatedOpacity(
                opacity: _collapsed ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Text(tr(g.title)),
              ),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsets.zero,
                title: const SizedBox.shrink(),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'art-${g.id}',
                      child: GameArt(gameId: g.id),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x66000000),
                            Color(0x00000000),
                            Color(0xFF0A0C10),
                          ],
                          stops: [0, 0.4, 1],
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
                120,
              ),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      Icon(g.icon, size: 16, color: g.accent),
                      const SizedBox(width: 6),
                      Text(
                        [
                          g.genre,
                          ?g.extraGenre,
                        ].map((x) => tr(x.label)).join(' · ').toUpperCase(),
                        style: Txt.overline.copyWith(color: g.accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(g.title),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(g.tagline),
                    style: const TextStyle(color: Lantern.fog, fontSize: 15),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      MetaPill(Icons.schedule_rounded, tr(g.minutes)),
                      MetaPill(Icons.favorite_border_rounded, tr(g.intensity)),
                      if (g.selfView)
                        MetaPill(
                          Icons.camera_front_rounded,
                          tr('Best with the mirror on'),
                        ),
                    ],
                  ),
                  const SectionHeader('Preview'),
                  _Gallery(
                    game: g,
                    guardianArt:
                        g.id == 'craftguard' &&
                            content != null &&
                            selected != null
                        ? content.guardians
                              .firstWhere(
                                (x) => x.id == selected.id,
                                orElse: () => content.guardians.first,
                              )
                              .art
                        : null,
                    page: _page,
                    onPage: (p) => setState(() => _page = p),
                  ),
                  const SizedBox(height: Space.l),
                  Text(
                    tr(g.description),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.55,
                      color: Lantern.parchment,
                    ),
                  ),
                  const SectionHeader('How to play'),
                  for (final (i, step) in g.howTo.indexed)
                    _HowToRow(index: i + 1, step: step, accent: g.accent),
                  const SectionHeader('Movement involved'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in g.moves)
                        MetaPill(m.icon, tr(m.label), color: g.accent),
                    ],
                  ),
                  if (g.comfort != null) ...[
                    const SizedBox(height: Space.m),
                    LanternCard(
                      tone: LanternTone.scarf,
                      icon: Icons.health_and_safety_outlined,
                      child: Text(
                        tr(g.comfort!),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                  if (isAdventure)
                    ..._adventureSections(context)
                  else ...[
                    if (g.id == 'craftguard' && content != null) ...[
                      const SectionHeader('Trophy shelf'),
                      _TrophyShelf(
                        guardians: [
                          for (final x in content.guardians)
                            (x.art, x.name, progress.completed(g.id, x.id)),
                        ],
                      ),
                    ],
                    if (g.id == 'lumen' &&
                        content != null &&
                        selected != null) ...[
                      const SectionHeader('Your habitat'),
                      _HabitatCard(
                        habitat: content.lumen
                            .firstWhere(
                              (x) => x.id == selected.id,
                              orElse: () => content.lumen.first,
                            )
                            .habitat,
                        restored: progress.habitat,
                        total: content.lumen
                            .firstWhere(
                              (x) => x.id == selected.id,
                              orElse: () => content.lumen.first,
                            )
                            .boards
                            .length,
                      ),
                    ],
                    SectionHeader('Choose a ${g.stageNoun.toLowerCase()}'),
                    if (content == null)
                      const Center(child: CircularProgressIndicator()),
                    for (final (i, st) in stageList.indexed)
                      _StageTile(
                        key: ValueKey('stage-${st.id}'),
                        index: i + 1,
                        stage: st,
                        accent: g.accent,
                        selected: selected?.id == st.id,
                        unlocked: open(st),
                        record: progress.record(g.id, st.id),
                        onTap: () {
                          if (!open(st)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  tr(
                                    'Finish the one before it to unlock this.',
                                  ),
                                ),
                              ),
                            );
                            return;
                          }
                          setState(() => _stage = st.id);
                        },
                      ),
                    const SectionHeader('Options'),
                    ..._options(context, party),
                  ],
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              10,
              Space.gutter,
              10,
            ),
            decoration: const BoxDecoration(
              color: Lantern.canopy,
              border: Border(top: BorderSide(color: Lantern.line)),
            ),
            child: FilledButton.icon(
              key: const ValueKey('play-game'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: canPlay ? () => _play(selected) : null,
              icon: const Icon(Icons.play_arrow_rounded, size: 28),
              label: Text(
                isAdventure
                    ? tr('Play next chapter')
                    : selected == null
                    ? tr('Loading…')
                    : party && _players.length < 2
                    ? tr('Add at least two players')
                    : party && !_adults
                    ? tr('Confirm everyone is 18+')
                    : '${tr('Play')} · ${tr(selected.name)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _play(ArcadeStage? st) {
    if (game.id == adventureId) {
      final s = ref.read(settingsProvider);
      final premium = ref.read(premiumProvider).value ?? const PremiumState();
      final next = nextStage(
        s.completedLevels,
        premiumLocked: PaywallPolicy.paymentsEnabled && !premium.premium,
      );
      context.push('/quest?level=${next.levelId}');
      return;
    }
    if (st == null) return;
    final args = ArcadeArgs(
      gameId: game.id,
      stageId: st.id,
      difficulty: _difficulty,
      assist: _assist,
      level: game.id == 'taal-toofan' ? _level : null,
      noSquat: _noSquat,
      players: st.party ? List.of(_players) : const [],
      daily: st.daily,
    );
    context.push(args.toUri().toString());
  }

  List<Widget> _adventureSections(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final premium = ref.watch(premiumProvider).value ?? const PremiumState();
    final locked = PaywallPolicy.paymentsEnabled && !premium.premium;
    final done = stages
        .where((x) => s.completedLevels.contains(x.levelId))
        .length;
    return [
      SectionHeader(
        'World map',
        overline: '$done / ${stages.length} ${tr('chapters complete')}',
      ),
      for (final w in worlds)
        RepaintBoundary(
          child: WorldCard(
            world: w,
            completed: s.completedLevels,
            missionLevels: s.missionLevels,
            premiumLocked: locked,
            expanded:
                w.number ==
                nextStage(s.completedLevels, premiumLocked: locked).world,
          ),
        ),
    ];
  }

  List<Widget> _options(BuildContext context, bool party) {
    final g = game;
    final out = <Widget>[];
    if (g.id == 'taal-toofan') {
      out.add(
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'light', label: Text(tr('Light'))),
            ButtonSegment(value: 'groove', label: Text(tr('Groove'))),
            ButtonSegment(value: 'toofan', label: Text(tr('Toofan'))),
          ],
          selected: {_level},
          onSelectionChanged: (v) => setState(() => _level = v.first),
        ),
      );
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            tr(
              'Everyone dances the same routine; higher levels score more of its beats.',
            ),
            style: Txt.caption,
          ),
        ),
      );
    } else if (g.id == 'craftguard' || g.id == 'tapeball') {
      out.add(
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'beginner', label: Text(tr('Beginner'))),
            ButtonSegment(value: 'intermediate', label: Text(tr('Medium'))),
            ButtonSegment(value: 'advanced', label: Text(tr('Advanced'))),
          ],
          selected: {_difficulty ?? 'beginner'},
          onSelectionChanged: (v) => setState(() => _difficulty = v.first),
        ),
      );
    }
    if (g.id != 'lumen' && g.id != 'taal-toofan') {
      out.add(
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr('Assist')),
          subtitle: Text(tr('More time, bigger targets, gentler shapes.')),
          value: _assist,
          onChanged: (v) => setState(() => _assist = v),
        ),
      );
    }
    if (g.id == 'lumen') {
      out.add(
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr('No-squat welding')),
          subtitle: Text(
            tr(
              'Weld with a hands-together hold instead of a bend. Same rewards.',
            ),
          ),
          value: _noSquat,
          onChanged: (v) => setState(() => _noSquat = v),
        ),
      );
    }
    if (party) {
      out.add(const SectionHeader('Players', overline: 'Pass the Pataka'));
      out.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in _players)
              InputChip(
                label: Text(p),
                onDeleted: () => setState(() => _players.remove(p)),
              ),
          ],
        ),
      );
      if (_players.length < 6) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('player-name'),
                    controller: _name,
                    maxLength: 14,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: tr('Nickname'),
                      counterText: '',
                    ),
                    onSubmitted: (_) => _addPlayer(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  tooltip: tr('Add player'),
                  onPressed: _addPlayer,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                ),
              ],
            ),
          ),
        );
      }
      out.add(
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _adults,
          onChanged: (v) => setState(() => _adults = v ?? false),
          title: Text(tr('Everyone playing is 18 or older')),
          subtitle: Text(tr('Nicknames are kept for this game only.')),
        ),
      );
    }
    return out;
  }

  void _addPlayer() {
    final n = _name.text.trim();
    if (n.isEmpty || _players.contains(n)) return;
    setState(() {
      _players.add(n);
      _name.clear();
    });
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.game,
    required this.page,
    required this.onPage,
    this.guardianArt,
  });
  final GameInfo game;
  final int page;
  final ValueChanged<int> onPage;
  final String? guardianArt;

  @override
  Widget build(BuildContext context) {
    final captions = previewCaptions(game.id);
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: PageController(
              viewportFraction: 0.88,
              initialPage: page,
            ),
            padEnds: false,
            onPageChanged: onPage,
            itemCount: 4,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GameArt(
                      gameId: game.id,
                      variant: i,
                      guardianArt: guardianArt,
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 24, 14, 12),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0xCC000000)],
                          ),
                        ),
                        child: Text(
                          tr(captions[i]),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 4; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == page ? game.accent : Lantern.ridge,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          tr('Illustrations of the game. No camera image is ever shown here.'),
          style: Txt.caption.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

class _HowToRow extends StatelessWidget {
  const _HowToRow({
    required this.index,
    required this.step,
    required this.accent,
  });
  final int index;
  final HowToStep step;
  final Color accent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(step.icon, color: accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$index. ${tr(step.title)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  tr(step.text),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _StageTile extends StatelessWidget {
  const _StageTile({
    super.key,
    required this.index,
    required this.stage,
    required this.accent,
    required this.selected,
    required this.unlocked,
    required this.record,
    required this.onTap,
  });
  final int index;
  final ArcadeStage stage;
  final Color accent;
  final bool selected;
  final bool unlocked;
  final StageRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      color: selected ? accent.withValues(alpha: 0.10) : Lantern.canopy,
      borderColor: selected ? accent : Lantern.line,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? accent : Lantern.surface2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: unlocked
                ? Text(
                    '$index',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: selected
                          ? const Color(0xFF0A0C10)
                          : Lantern.parchment,
                    ),
                  )
                : const Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: Lantern.mist,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tr(stage.name),
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (stage.daily) ...[
                      const SizedBox(width: 6),
                      TagBadge(tr('Daily'), color: Lantern.scarf),
                    ],
                    if (stage.party) ...[
                      const SizedBox(width: 6),
                      TagBadge(tr('Party'), color: accent),
                    ],
                    if (stage.premium) ...[
                      const SizedBox(width: 6),
                      TagBadge(tr('Premium'), color: Lantern.warning),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  tr(
                    unlocked
                        ? stage.blurb
                        : 'Finish the one before it to unlock this.',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (stage.subtitle != null || record.plays > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (stage.subtitle != null)
                        Flexible(
                          child: Text(
                            tr(stage.subtitle!),
                            overflow: TextOverflow.ellipsis,
                            style: Txt.caption.copyWith(
                              fontSize: 12,
                              color: accent,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (record.plays > 0)
                        StarRow(
                          record.stars.clamp(0, 5),
                          max: record.stars > 3 ? 5 : 3,
                          size: 15,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? accent : Lantern.ridge,
          ),
        ],
      ),
    ),
  );
}

class _TrophyShelf extends StatelessWidget {
  const _TrophyShelf({required this.guardians});
  final List<(String, String, bool)> guardians;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 118,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: guardians.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, i) {
        final (art, name, calmed) = guardians[i];
        return SizedBox(
          width: 96,
          child: AppCard(
            padding: const EdgeInsets.all(8),
            color: calmed ? const Color(0xFF1F2A5C) : Lantern.canopy,
            child: Column(
              children: [
                Expanded(
                  child: Opacity(
                    opacity: calmed ? 1 : 0.28,
                    child: CustomPaint(
                      painter: _GuardianPainter(art),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  calmed ? tr(name) : tr('Not yet calmed'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _GuardianPainter extends CustomPainter {
  _GuardianPainter(this.art);
  final String art;
  @override
  void paint(Canvas c, Size s) {
    final size = s.shortestSide * 1.15;
    paintGuardian(c, Offset(s.width / 2, s.height * 0.6), size, art, 1.0);
  }

  @override
  bool shouldRepaint(_GuardianPainter old) => old.art != art;
}

class _HabitatCard extends StatelessWidget {
  const _HabitatCard({
    required this.habitat,
    required this.restored,
    required this.total,
  });
  final String habitat;
  final Set<String> restored;
  final int total;

  @override
  Widget build(BuildContext context) {
    final modules = {
      for (final r in restored)
        if (r.startsWith('$habitat/')) r.substring(habitat.length + 1),
    };
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 170,
            child: GameArt(gameId: 'lumen', habitat: modules),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.eco_rounded, color: Color(0xFF7BD389)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    modules.isEmpty
                        ? tr(
                            'Nothing restored yet. Your first repair brings the lights back.',
                          )
                        : '${modules.length} / $total ${tr('repairs restored. They stay restored, even if you take a break.')}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

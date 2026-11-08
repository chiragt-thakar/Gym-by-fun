import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_director/game_director.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../game/stage_info.dart';
import '../game/stages.dart';
import '../l10n/tr.dart';

import '../services/api_client.dart';
import '../services/coach_service.dart';
import '../widgets/forest_backdrop.dart';
import 'quest_screen.dart' show warmup, cooldown;
import '../services/premium.dart';
import '../services/session_queue.dart';
import '../services/settings.dart';
import '../widgets/lantern_card.dart';
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
    final catalogue = ref.watch(levelCatalogueProvider);
    final level = catalogue.value?[next.levelId];
    final history = ref.watch(coachHistoryProvider);
    final status = ref.watch(syncStatusProvider).value;
    final worldList = worlds.where((w) => !w.comingSoon).toList();
    final gymColour = parseGymColour(gym);
    final today = DateUtils.dateOnly(DateTime.now());
    final days = [
      for (var i = 6; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];
    final active = {
      for (final day in ref.watch(activityDaysProvider))
        if (DateTime.tryParse(day) != null) DateTime.parse(day),
    };
    final activeDays = days.where(active.contains).length;
    final totalMoves = history.fold<int>(0, (sum, run) => sum + run.totalReps);
    final activeMinutes =
        history.fold<int>(0, (sum, run) => sum + run.activeMs) / 60000;

    Widget header() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Text(
            tr('A little movement. A new adventure.'),
            style: const TextStyle(color: Lantern.fog, fontSize: 16),
          ),
        ),
        Container(
          key: const ValueKey('adventure-card'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Lantern.ridge),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 178,
                    width: double.infinity,
                    child: WorldVista(theme: next.theme),
                  ),
                  Positioned(
                    left: 16,
                    top: 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Lantern.night.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          '${tr('World')} ${next.world}  /  ${next.stageNumber}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Lantern.parchment,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              ColoredBox(
                color: Lantern.canopy,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        tr('YOUR NEXT ADVENTURE'),
                        style: const TextStyle(
                          color: Lantern.scarf,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(next.title),
                        style: const TextStyle(
                          fontSize: 28,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(level?.journey?.mission ?? next.description),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Lantern.fog,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          if (level != null)
                            _Tag(
                              Icons.schedule,
                              '${questTimeLabel(level)} ${tr('total')}',
                            ),
                          _Tag(
                            s.lowImpact
                                ? Icons.spa_outlined
                                : Icons.directions_run,
                            tr(s.lowImpact ? 'Low-impact' : 'Standard moves'),
                          ),
                          _Tag(
                            Icons.tune,
                            tr(
                              s.difficulty == Difficulty.beginner
                                  ? 'Beginner'
                                  : s.difficulty == Difficulty.intermediate
                                  ? 'Medium'
                                  : 'Advanced',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        key: const ValueKey('start-adventure'),
                        style: FilledButton.styleFrom(
                          backgroundColor: gymColour,
                          minimumSize: const Size(0, 60),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () =>
                            context.push('/quest?level=${next.levelId}'),
                        icon: const Icon(Icons.play_arrow_rounded, size: 30),
                        label: Text(s.s.t('daily_quest')),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const ValueKey('gentle-today'),
                        onPressed: () => context.push(
                          '/quest?level=${next.levelId}&pace=gentle',
                        ),
                        icon: const Icon(Icons.spa_outlined, size: 20),
                        label: Text(tr('Gentle today')),
                      ),
                      Text(
                        tr(
                          'One run with beginner pace, low-impact and assist.',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Lantern.fog,
                        ),
                      ),
                      TextButton(
                        onPressed: () => showStageInfoSheet(
                          context,
                          next,
                          onPlay: () =>
                              context.push('/quest?level=${next.levelId}'),
                        ),
                        child: Text(tr('Mission & movement guide')),
                      ),
                      Text(
                        tr(
                          'Includes warm-up and cool-down. Tracking breaks may add time.',
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Lantern.fog,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SyncLine(
          status: status,
          signedIn: s.signedIn,
          onRetry: () async {
            try {
              await ref.read(sessionQueueProvider).flush();
            } catch (_) {}
            ref.invalidate(syncStatusProvider);
            ref.invalidate(homeDataProvider);
          },
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text(
                tr('Your last 7 days'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              '$activeDays / 7',
              style: const TextStyle(
                color: Lantern.scarf,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final day in days)
              Expanded(
                child: Semantics(
                  label:
                      '${day.day}/${day.month}: ${tr(active.contains(day) ? 'Active day' : 'Rest day')}',
                  child: Column(
                    children: [
                      Container(
                        width: 30,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active.contains(day)
                              ? Lantern.scarf
                              : Lantern.moss,
                          borderRadius: BorderRadius.circular(11),
                          border: day == today
                              ? Border.all(color: Lantern.parchment)
                              : null,
                        ),
                        child: Icon(
                          active.contains(day)
                              ? Icons.check_rounded
                              : Icons.remove_rounded,
                          size: 18,
                          color: active.contains(day)
                              ? Lantern.night
                              : Lantern.fog,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${day.day}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Lantern.fog,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          tr('Rest days belong here too. Your keepsakes stay with you.'),
          style: const TextStyle(color: Lantern.fog, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Tile(Icons.bolt_rounded, tr('Moves done'), '$totalMoves'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Tile(
                Icons.timelapse_rounded,
                tr('Active min'),
                activeMinutes.toStringAsFixed(1),
              ),
            ),
          ],
        ),
        Text(
          '${tr('Recent runs')}: ${history.length}',
          style: const TextStyle(fontSize: 12, color: Lantern.fog),
        ),
        const SizedBox(height: 24),
        if (s.completedLevels.isNotEmpty && catalogue.value != null) ...[
          ExpansionTile(
            key: const ValueKey('keepsake-collection'),
            tilePadding: EdgeInsets.zero,
            leading: const Icon(Icons.auto_awesome, color: Lantern.glow),
            title: Text(
              tr('Your keepsakes'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${stages.where((st) => s.completedLevels.contains(st.levelId)).length} / ${stages.length} ${tr('discovered')}',
            ),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final st in stages.where(
                    (st) => s.completedLevels.contains(st.levelId),
                  ))
                    Chip(
                      avatar: const Icon(Icons.diamond_outlined, size: 16),
                      label: Text(
                        tr(
                          catalogue.value![st.levelId]?.journey?.keepsake ??
                              st.title,
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        Text(tr('World map'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          tr('One trail at a time. Every chapter has something to discover.'),
          style: const TextStyle(fontSize: 14, color: Lantern.fog),
        ),
        const SizedBox(height: 12),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(gym?['name'] as String? ?? 'MotionQuest'),
        actions: [
          IconButton(
            tooltip: tr('Settings'),
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeDataProvider);
            await ref.read(homeDataProvider.future);
            ref.invalidate(syncStatusProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: worldList.length + 2,
            itemBuilder: (context, i) {
              if (i == 0) return header();
              if (i == worldList.length + 1) {
                return Column(
                  children: [
                    const SizedBox(height: 18),
                    ListTile(
                      leading: const Icon(Icons.groups_outlined),
                      title: Text(
                        gym == null
                            ? tr('Gym Crew')
                            : '${gym['name']} ${tr('crew')}',
                      ),
                      subtitle: Text(
                        tr(
                          gym == null
                              ? 'Move together with your gym.'
                              : "See this week's crew board",
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.push(s.signedIn ? '/crew' : '/sign-in'),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      s.s.t('video_never_leaves'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Lantern.fog, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.s.t('not_medical'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Lantern.fog, fontSize: 12),
                    ),
                  ],
                );
              }
              final world = worldList[i - 1];
              return RepaintBoundary(
                child: _WorldCard(
                  world: world,
                  expanded: world.number == next.world,
                  completed: s.completedLevels,
                  missionLevels: s.missionLevels,
                  premiumLocked: premiumLocked,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: Lantern.scarf),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: Lantern.parchment),
        ),
      ),
    ],
  );
}

class _SyncLine extends StatelessWidget {
  const _SyncLine({
    required this.status,
    required this.signedIn,
    required this.onRetry,
  });
  final ({int pending, int rejected})? status;
  final bool signedIn;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Icon(
        status == null
            ? Icons.info_outline
            : (status!.rejected > 0
                  ? Icons.info_outline
                  : status!.pending > 0
                  ? Icons.cloud_queue_outlined
                  : Icons.offline_pin_outlined),
        color: Lantern.scarf,
        size: 18,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          status == null
              ? tr('Local save status unavailable')
              : status!.rejected > 0
              ? '${tr('Sync needs attention. Runs kept on this phone')}: ${status!.rejected}'
              : status!.pending > 0
              ? '${tr('Waiting to sync')}: ${status!.pending}'
              : tr(
                  signedIn ? 'No runs waiting to sync' : 'Saved on this phone',
                ),
          style: const TextStyle(fontSize: 13, color: Lantern.fog),
        ),
      ),
      if (signedIn && (status?.pending ?? 0) > 0)
        TextButton(
          onPressed: onRetry,
          child: Text(tr('Retry sync'), style: const TextStyle(fontSize: 12)),
        ),
    ],
  );
}

class _WorldCard extends StatelessWidget {
  const _WorldCard({
    required this.world,
    required this.completed,
    this.premiumLocked = false,
    this.expanded = false,
    this.missionLevels = const {},
  });
  final World world;
  final Set<String> completed;

  /// Payments on and the player not Premium: Premium stages show a badge.
  final bool premiumLocked;
  final bool expanded;
  final Set<String> missionLevels;

  @override
  Widget build(BuildContext context) {
    if (world.comingSoon) {
      return Card(
        child: ListTile(
          leading: CircleAvatar(child: Text('${world.number}')),
          title: Text(tr(world.name), style: const TextStyle(fontSize: 19)),
          subtitle: Text(tr('Coming soon')),
          trailing: const Icon(Icons.lock_outline),
        ),
      );
    }
    final done = world.stages
        .where((st) => completed.contains(st.levelId))
        .length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey('world-${world.number}'),
        initiallyExpanded: expanded,
        leading: CircleAvatar(
          backgroundColor: Lantern.moss,
          child: Text('${world.number}'),
        ),
        title: Text(
          tr(world.name),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '$done / ${world.stages.length} ${tr('chapters complete')}',
          style: const TextStyle(fontSize: 13, color: Lantern.fog),
        ),
        children: [
          LinearProgressIndicator(
            value: done / world.stages.length,
            minHeight: 3,
          ),
          for (final st in world.stages) _stageTile(context, st),
        ],
      ),
    );
  }

  Widget _stageTile(BuildContext context, Stage st) {
    final open = isUnlocked(st, completed, premiumLocked: premiumLocked);
    final done = completed.contains(st.levelId);
    final paywalled = premiumLocked && infoFor(st).premium;
    return ListTile(
      key: ValueKey('stage-${st.levelId}'),
      contentPadding: const EdgeInsets.only(left: 32, right: 16),
      leading: Icon(
        missionLevels.contains(st.levelId)
            ? Icons.auto_awesome
            : done
            ? Icons.check_circle
            : paywalled
            ? Icons.workspace_premium
            : open
            ? Icons.play_circle_fill
            : Icons.lock_outline,
        size: 32,
      ),
      trailing: open ? const Icon(Icons.chevron_right) : null,
      title: Text(
        '${world.number}-${st.stageNumber} · ${tr(st.title)}',
        style: const TextStyle(fontSize: 18),
      ),
      subtitle: Text(
        paywalled
            ? tr('Premium stage')
            : !open
            ? tr('Finish the previous stage to unlock')
            : tr(st.description),
      ),
      enabled: open,
      onTap: open
          ? () => showStageInfoSheet(
              context,
              st,
              onPlay: () => context.push('/quest?level=${st.levelId}'),
            )
          : null,
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => LanternCard(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    child: Column(
      children: [
        Icon(icon, size: 32, color: Lantern.glow),
        Text(
          value,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Lantern.fog),
        ),
      ],
    ),
  );
}

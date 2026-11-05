import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../game/stage_info.dart';
import '../game/stages.dart';
import '../l10n/tr.dart';

import '../services/api_client.dart';
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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final data = ref.watch(homeDataProvider).value;
    final gym = data?['gym'] as Map<String, dynamic>?;
    final progress = data?['progress'] as Map<String, dynamic>?;
    final quests = (data?['quests'] as List<dynamic>?) ?? const [];
    final premium = ref.watch(premiumProvider).value ?? const PremiumState();
    final premiumLocked = PaywallPolicy.paymentsEnabled && !premium.premium;
    final next = nextStage(s.completedLevels, premiumLocked: premiumLocked);
    final gymColour = parseGymColour(gym);
    final worldList = worlds;
    Widget header(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 140),
          child: FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              backgroundColor: gymColour,
            ),
            onPressed: () => context.push('/quest?level=${next.levelId}'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow_rounded, size: 56),
                Text(
                  s.s.t('daily_quest'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${tr('Warm-up')} · ${tr(next.title)} · '
                  '${tr('Cool-down')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Tile(
                Icons.local_fire_department,
                tr('Streak'),
                '${progress?['streak'] ?? '–'}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Tile(
                Icons.shield,
                tr('Shields'),
                '${progress?['shields'] ?? '–'}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Tile(
                Icons.star,
                tr('Hero level'),
                '${progress?['heroLevel'] ?? '–'}',
              ),
            ),
          ],
        ),
        if (premium.premium)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Chip(
              avatar: const Icon(Icons.workspace_premium),
              label: Text(
                premium.source == 'gym'
                    ? tr('Premium via your gym')
                    : tr('Premium'),
                style: const TextStyle(fontSize: 17),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.groups, size: 36),
            title: Text(
              gym == null ? tr('Gym Crew') : '${gym['name']} ${tr('crew')}',
              style: const TextStyle(fontSize: 20),
            ),
            subtitle: Text(
              gym == null
                  ? (s.signedIn
                        ? tr('Have a gym code? Join your crew.')
                        : tr('Sign in to join your gym crew.'))
                  : quests.isEmpty
                  ? tr("See this week's crew board")
                  : '${tr('Trainer quest')}: ${(quests.first as Map)['title']}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(s.signedIn ? '/crew' : '/sign-in'),
          ),
        ),
        const SizedBox(height: 16),
        Text(tr('World map'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
      ],
    );
    final footer = Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        s.s.t('not_medical'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: Lantern.fog),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(gym?['name'] as String? ?? 'MotionQuest'),
        backgroundColor: gymColour,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, size: 30),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(homeDataProvider),
          // Built lazily: only the header, the world cards on screen and the
          // footer exist at any time. Each world card has its own repaint
          // layer so scrolling never repaints its stage tiles.
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: worldList.length + 2,
            itemBuilder: (context, i) {
              if (i == 0) return header(context);
              if (i == worldList.length + 1) return footer;
              return RepaintBoundary(
                child: _WorldCard(
                  world: worldList[i - 1],
                  completed: s.completedLevels,
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

class _WorldCard extends StatelessWidget {
  const _WorldCard({
    required this.world,
    required this.completed,
    this.premiumLocked = false,
  });
  final World world;
  final Set<String> completed;

  /// Payments on and the player not Premium: Premium stages show a badge.
  final bool premiumLocked;

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
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: CircleAvatar(child: Text('${world.number}')),
            title: Text(
              tr(world.name),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(tr('Squat · Lean · Raise arms')),
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
        done
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
        !open
            ? tr('Finish the previous stage to unlock')
            : paywalled
            ? '${tr('Premium')} · ${tr(st.description)}'
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

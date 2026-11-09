import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../game/stage_info.dart';
import '../game/stages.dart';
import '../l10n/tr.dart';
import '../screens/stage_info_sheet.dart';

/// Local save / sync status in one line.
class SyncLine extends StatelessWidget {
  const SyncLine({
    super.key,
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

/// One world on the adventure map, with its chapters.
class WorldCard extends StatelessWidget {
  const WorldCard({
    super.key,
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

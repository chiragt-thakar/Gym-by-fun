import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/stage_info.dart';
import '../game/stages.dart';
import '../l10n/tr.dart';
import '../services/premium.dart';
import '../services/settings.dart';
import '../widgets/body_map.dart';
import '../widgets/forest_backdrop.dart';
import 'home_screen.dart' show levelCatalogueProvider, questTimeLabel;

const stageInfoDisclaimer =
    'General fitness information, not medical advice. Stop if anything hurts.';

/// Opens the stage info sheet. [onPlay] runs after the sheet closes.
Future<void> showStageInfoSheet(
  BuildContext context,
  Stage stage, {
  required VoidCallback onPlay,
}) async {
  final play = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (c) =>
        StageInfoSheet(stage: stage, onPlay: () => Navigator.pop(c, true)),
  );
  if (play == true) onPlay();
}

class StageInfoSheet extends ConsumerWidget {
  const StageInfoSheet({
    super.key,
    required this.stage,
    required this.onPlay,
    this.paymentsEnabled = PaywallPolicy.paymentsEnabled,
  });

  final Stage stage;
  final VoidCallback onPlay;

  /// Only when payments are on and the player isn't Premium is Play locked.
  final bool paymentsEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = infoFor(stage);
    final level = ref.watch(levelCatalogueProvider).value?[stage.levelId];
    final style = ref.watch(settingsProvider.select((s) => s.bodyStyle));
    final premium = ref.watch(premiumProvider).value ?? const PremiumState();
    final locked = paymentsEnabled && info.premium && !premium.premium;
    final theme = Theme.of(context);
    final trains = [
      for (final r in info.primary) '${tr(r.label)} · ${tr('Main focus')}',
      for (final r in info.secondary) '${tr(r.label)} · ${tr('Also works')}',
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 130,
                child: WorldVista(theme: stage.theme),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr(stage.title),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (level != null) ...[
              Text(
                tr(level.journey?.mission ?? stage.description),
                style: const TextStyle(fontSize: 17),
              ),
              const SizedBox(height: 8),
              Text(
                '${questTimeLabel(level)} ${tr('total')}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                tr(
                  'Includes warm-up and cool-down. Tracking breaks may add time.',
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${tr('World')} ${stage.world} · ${tr(stage.worldName)}',
                  style: const TextStyle(fontSize: 16),
                ),
                Chip(
                  key: const ValueKey('tier-badge'),
                  avatar: Icon(
                    info.premium ? Icons.workspace_premium : Icons.lock_open,
                    size: 18,
                  ),
                  label: Text(info.premium ? tr('Premium') : tr('Free')),
                ),
                Chip(
                  label: Text(
                    '${tr('Intensity')}: ${tr(info.intensity.label)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (level?.gameplay != null)
              ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: Text(tr(missionName(level!.gameplay!.mission))),
                subtitle: Text(
                  tr(
                    'An optional mission star. Tracking issues never cost your stage progress.',
                  ),
                ),
              ),
            Center(
              child: BodyMap(
                style: style,
                primary: info.primary,
                secondary: info.secondary,
              ),
            ),
            _heading(context, tr('Trains')),
            for (final t in trains) _bullet(t),
            const SizedBox(height: 4),
            _bullet(
              '${tr('Moves')}: '
              '${info.movements.map((m) => tr(m.label)).join(' · ')}',
            ),
            _heading(context, tr('Benefits')),
            for (final b in info.benefits) _bullet(tr(b)),
            _heading(context, tr('Why it helps')),
            Text(
              tr(
                'Regular muscle-strengthening and aerobic activity is part of '
                'general fitness guidance from:',
              ),
            ),
            const SizedBox(height: 4),
            for (final r in info.references)
              _bullet('${r.source} (${r.year})', icon: Icons.menu_book),
            const SizedBox(height: 16),
            Text(
              tr(stageInfoDisclaimer),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 64,
              child: locked
                  ? FilledButton.tonalIcon(
                      key: const ValueKey('stage-locked'),
                      onPressed: null,
                      icon: const Icon(Icons.lock),
                      label: Text(
                        tr('Premium'),
                        style: const TextStyle(fontSize: 20),
                      ),
                    )
                  : FilledButton.icon(
                      key: const ValueKey('stage-play'),
                      onPressed: onPlay,
                      icon: const Icon(Icons.play_arrow_rounded, size: 32),
                      label: Text(
                        tr('Play'),
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _bullet(String text, {IconData icon = Icons.circle}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 8),
          child: Icon(icon, size: icon == Icons.circle ? 8 : 16),
        ),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
      ],
    ),
  );
}

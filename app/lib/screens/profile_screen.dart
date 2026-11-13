import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../game/forest_game.dart' show HeroLook;
import '../game/stages.dart' show devUnlockAll;
import '../l10n/strings.dart';
import '../l10n/tr.dart';
import '../services/settings.dart';
import '../widgets/common.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final explorer = switch (s.heroLook) {
      HeroLook.fox => 'Kavi the fox',
      HeroLook.otter => 'Neela the otter',
      HeroLook.robot => 'Tara the starbot',
    };
    final band = switch (s.ageBand) {
      AgeBand.gentle => 'Gentle',
      AgeBand.balanced => 'Balanced',
      AgeBand.active => 'Active',
    };
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
            Text(tr('YOU'), style: Txt.overline),
            const SizedBox(height: 4),
            Text(
              tr('Profile'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: Space.l),
            AppCard(
              onTap: () => context.push('/settings'),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Lantern.moss,
                      border: Border.all(color: Lantern.glow, width: 2),
                    ),
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: ExplorerPortrait(look: s.heroLook),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(explorer),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr(
                            s.signedIn
                                ? 'Signed in · progress syncs'
                                : 'Playing on this phone',
                          ),
                          style: Txt.caption,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            MetaPill(Icons.tune_rounded, tr(band)),
                            MetaPill(
                              s.lowImpact
                                  ? Icons.spa_outlined
                                  : Icons.directions_run,
                              tr(s.lowImpact ? 'Low-impact' : 'Standard moves'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SectionHeader('Quick settings'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(tr('Low-impact mode')),
                    subtitle: Text(
                      tr('Half squats count, one arm is enough, no jumps.'),
                    ),
                    value: s.lowImpact,
                    onChanged: (v) => n.update((x) => x.copyWith(lowImpact: v)),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text(tr('Camera mirror')),
                    subtitle: Text(
                      tr(
                        'See yourself behind the game. Drawn on the phone, never saved.',
                      ),
                    ),
                    value: s.cameraMirror,
                    onChanged: (v) =>
                        n.update((x) => x.copyWith(cameraMirror: v)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: Text(tr('Language')),
                    subtitle: Text(switch (s.language) {
                      AppLanguage.en => 'English',
                      AppLanguage.hi => 'हिन्दी',
                      AppLanguage.gu => 'ગુજરાતી',
                    }),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Lantern.mist,
                    ),
                    onTap: () => context.push('/settings'),
                  ),
                ],
              ),
            ),
            const SectionHeader('Your body and space'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  NavRow(
                    icon: Icons.accessibility_new_rounded,
                    title: tr(
                      s.calibration == null
                          ? 'Set up movement range'
                          : 'Recalibrate',
                    ),
                    subtitle: tr(
                      s.calibration == null
                          ? 'About a minute. Needed before your first game.'
                          : 'Do this if you moved the phone or changed rooms.',
                    ),
                    onTap: () =>
                        context.push(s.setupDone ? '/calibrate' : '/setup'),
                  ),
                  const Divider(height: 1),
                  NavRow(
                    icon: Icons.phone_android_rounded,
                    title: tr('Phone placement guide'),
                    subtitle: tr('Prop it up, step back about two metres.'),
                    onTap: () => context.push('/setup'),
                  ),
                ],
              ),
            ),
            const SectionHeader('More'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  NavRow(
                    icon: Icons.settings_rounded,
                    title: tr('All settings'),
                    subtitle: tr(
                      'Difficulty, play style, explorer, voice, privacy',
                    ),
                    onTap: () => context.push('/settings'),
                  ),
                  const Divider(height: 1),
                  NavRow(
                    icon: Icons.groups_rounded,
                    accent: Lantern.glow,
                    title: tr('Gym Crew'),
                    subtitle: tr('Move together with your gym.'),
                    onTap: () =>
                        context.push(s.signedIn ? '/crew' : '/sign-in'),
                  ),
                  if (devUnlockAll || kDebugMode) ...[
                    const Divider(height: 1),
                    NavRow(
                      icon: Icons.developer_mode_rounded,
                      accent: Lantern.warning,
                      title: tr('Developer tools'),
                      subtitle: tr(
                        'Live tracking monitor and landmark recorder',
                      ),
                      onTap: () => context.push('/debug'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Space.xl),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: Lantern.scarf,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${s.s.t('video_never_leaves')} ${s.s.t('not_medical')}',
                    style: Txt.caption,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Center(child: JoyneticLogo(size: 24)),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Joynetic 0.2.0${devUnlockAll ? ' · ${tr('developer build: everything unlocked')}' : ''}',
                style: Txt.caption.copyWith(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

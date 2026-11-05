import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_director/game_director.dart';
import 'package:go_router/go_router.dart';

import '../l10n/strings.dart';
import '../l10n/tr.dart';
import '../services/api_client.dart';
import '../services/coach_service.dart';
import '../services/local_data.dart';
import '../services/settings.dart';
import '../app/theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final api = ref.read(apiProvider);

    Future<void> consent(String purpose, bool granted) async {
      try {
        await api.setConsents({purpose: granted});
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(granted ? 'Turned on' : 'Turned off')),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Needs a connection and sign-in')),
          );
        }
      }
    }

    return ScreenScaffold(
      title: 'Settings',
      children: [
        const _H('Play'),
        const Text('Difficulty', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 6),
        SegmentedButton<Difficulty>(
          segments: const [
            ButtonSegment(value: Difficulty.beginner, label: Text('Beginner')),
            ButtonSegment(
              value: Difficulty.intermediate,
              label: Text('Medium'),
            ),
            ButtonSegment(value: Difficulty.advanced, label: Text('Advanced')),
          ],
          selected: {s.difficulty},
          onSelectionChanged: (v) =>
              n.update((x) => x.copyWith(difficulty: v.first)),
        ),
        ListTile(
          title: Text(tr('Play style'), style: const TextStyle(fontSize: 18)),
          subtitle: Text(tr('You choose; we never ask your age.')),
        ),
        SegmentedButton<AgeBand>(
          key: const ValueKey('age-band'),
          segments: [
            ButtonSegment(value: AgeBand.gentle, label: Text(tr('Gentle'))),
            ButtonSegment(value: AgeBand.balanced, label: Text(tr('Balanced'))),
            ButtonSegment(value: AgeBand.active, label: Text(tr('Active'))),
          ],
          selected: {s.ageBand},
          onSelectionChanged: (v) => n.update((x) => x.withAgeBand(v.first)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(tr(_bandBlurb[s.ageBand]!)),
        ),
        SwitchListTile(
          title: const Text('Low-impact mode', style: TextStyle(fontSize: 18)),
          subtitle: const Text(
            'Half squats count, one arm is enough, no jumps.',
          ),
          value: s.lowImpact,
          onChanged: (v) => n.update((x) => x.copyWith(lowImpact: v)),
        ),
        SwitchListTile(
          title: const Text('Assist mode', style: TextStyle(fontSize: 18)),
          subtitle: const Text('More warning time and wider timing windows.'),
          value: s.assist,
          onChanged: (v) => n.update((x) => x.copyWith(assist: v)),
        ),
        ListTile(
          title: const Text('Language', style: TextStyle(fontSize: 18)),
          trailing: DropdownButton<AppLanguage>(
            value: s.language,
            items: [
              for (final l in AppLanguage.values)
                DropdownMenuItem(value: l, child: Text(l.label)),
            ],
            onChanged: (l) => n.update((x) => x.copyWith(language: l)),
          ),
        ),
        ListTile(
          title: Text(
            tr('Body diagram style'),
            style: const TextStyle(fontSize: 18),
          ),
          subtitle: Text(tr('Used on stage info. You choose; we never guess.')),
        ),
        SegmentedButton<BodyStyle>(
          key: const ValueKey('body-style'),
          segments: [
            ButtonSegment(value: BodyStyle.neutral, label: Text(tr('Neutral'))),
            ButtonSegment(value: BodyStyle.female, label: Text(tr('Female'))),
            ButtonSegment(value: BodyStyle.male, label: Text(tr('Male'))),
          ],
          selected: {s.bodyStyle},
          onSelectionChanged: (v) =>
              n.update((x) => x.copyWith(bodyStyle: v.first)),
        ),
        const SizedBox(height: 8),
        BigButton(
          'Recalibrate',
          icon: Icons.accessibility_new,
          secondary: true,
          onPressed: () {
            n.update((x) => x.copyWith(clearCalibration: true));
            context.go('/calibrate');
          },
        ),
        BigButton(
          'Redo space setup',
          icon: Icons.crop_free,
          secondary: true,
          onPressed: () {
            n.update((x) => x.copyWith(setupDone: false));
            context.go('/setup');
          },
        ),
        const _H('Privacy'),
        Text(s.s.t('video_never_leaves')),
        if (s.signedIn) ...[
          SwitchListTile(
            title: const Text('Back up calibration'),
            subtitle: const Text(
              'Store your movement range on our server for a new phone. Off by default.',
            ),
            value: false,
            onChanged: (v) => consent('calibration_backup', v),
          ),
          SwitchListTile(
            title: const Text('Anonymous analytics'),
            subtitle: const Text('Crash and usage counts to improve the game.'),
            value: false,
            onChanged: (v) => consent('analytics', v),
          ),
          BigButton(
            'Download my data',
            icon: Icons.download,
            secondary: true,
            onPressed: () async {
              try {
                final data = await api.exportData();
                await Clipboard.setData(
                  ClipboardData(
                    text: const JsonEncoder.withIndent('  ').convert(data),
                  ),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Your data was copied to the clipboard.'),
                    ),
                  );
                }
              } catch (_) {}
            },
          ),
          BigButton(
            'Delete my account',
            icon: Icons.delete_forever,
            secondary: true,
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Delete your account?'),
                  content: const Text(
                    'Your progress, gym membership and any backups are removed. This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              try {
                await api.deleteAccount();
                await wipeLocalData(ref.read(sharedPrefsProvider));
                ref.invalidate(coachHistoryProvider);
                n.reset();
                if (context.mounted) context.go('/welcome');
              } catch (_) {}
            },
          ),
          BigButton(
            tr('Sign out'),
            key: const ValueKey('sign-out'),
            icon: Icons.logout,
            secondary: true,
            onPressed: () async {
              await ref.read(tokenStoreProvider).clear();
              n.update((x) => x.copyWith(signedIn: false));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      tr('Signed out. Your progress stays on this phone.'),
                    ),
                  ),
                );
              }
            },
          ),
        ] else
          BigButton(
            'Sign in',
            icon: Icons.login,
            onPressed: () => context.push('/sign-in'),
          ),
        const _H('About'),
        Text(s.s.t('not_medical')),
        const SizedBox(height: 8),
        const Text(
          'Grievances and data requests: grievance@motionquest.app — we respond within 30 days.',
        ),
        const _H('Developer'),
        BigButton(
          'Tracking debug screen',
          icon: Icons.bug_report,
          secondary: true,
          onPressed: () => context.push('/debug'),
        ),
        BigButton(
          'Landmark recorder',
          icon: Icons.fiber_manual_record,
          secondary: true,
          onPressed: () => context.push('/recorder'),
        ),
      ],
    );
  }
}

const _bandBlurb = {
  AgeBand.gentle: 'Gentle: more warning time, low-impact and assist on.',
  AgeBand.balanced: 'Balanced: standard pacing for most players.',
  AgeBand.active: 'Active: brisker pacing; assist can be off.',
};

class _H extends StatelessWidget {
  const _H(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: Lantern.scarf,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(text, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(width: 12),
        const Expanded(child: Divider()),
      ],
    ),
  );
}

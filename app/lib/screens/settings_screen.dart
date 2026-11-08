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

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Server consent state; null until loaded (switches stay disabled).
  Map<String, bool>? _consents;
  final _pendingConsent = <String>{};
  bool _exporting = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _loadConsents();
  }

  Future<void> _loadConsents() async {
    if (!ref.read(settingsProvider).signedIn) return;
    try {
      final c = await ref.read(apiProvider).consents();
      if (mounted) setState(() => _consents = c);
    } catch (_) {
      // Leave null: switches stay disabled until a connection is back.
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _consent(String purpose, bool granted) async {
    if (_pendingConsent.contains(purpose)) return;
    final before = _consents?[purpose] ?? false;
    setState(() {
      _pendingConsent.add(purpose);
      _consents = {...?_consents, purpose: granted};
    });
    try {
      await ref.read(apiProvider).setConsents({purpose: granted});
      _snack(granted ? tr('Turned on') : tr('Turned off'));
    } catch (_) {
      if (mounted) {
        setState(() => _consents = {...?_consents, purpose: before});
      }
      _snack(tr('Needs a connection and sign-in'));
    } finally {
      if (mounted) setState(() => _pendingConsent.remove(purpose));
    }
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final data = await ref.read(apiProvider).exportData();
      await Clipboard.setData(
        ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)),
      );
      _snack(tr('Your data was copied to the clipboard.'));
    } catch (_) {
      _snack(tr('Needs a connection and sign-in'));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _delete() async {
    if (_deleting) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Delete your account?')),
        content: Text(
          tr(
            'Your progress, gym membership and any backups are removed. This cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    final n = ref.read(settingsProvider.notifier);
    final prefs = ref.read(sharedPrefsProvider);
    try {
      await ref.read(apiProvider).deleteAccount();
      await wipeLocalData(prefs);
      if (!mounted) return;
      ref.invalidate(coachHistoryProvider);
      n.reset();
      context.go('/welcome');
    } catch (_) {
      _snack(tr('Needs a connection and sign-in'));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final signedIn = s.signedIn && ref.read(tokenStoreProvider).hasSession;

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
        SwitchListTile(
          title: Text(
            tr('Show camera mirror'),
            style: const TextStyle(fontSize: 18),
          ),
          subtitle: Text(
            tr(
              'See yourself while lining up. Shown only on this phone, never saved. Off: body outline only.',
            ),
          ),
          value: s.cameraMirror,
          onChanged: (v) => n.update((x) => x.copyWith(cameraMirror: v)),
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
        if (signedIn) ...[
          SwitchListTile(
            key: const ValueKey('consent-calibration_backup'),
            title: Text(tr('Back up calibration')),
            subtitle: Text(
              tr(
                'Store your movement range on our server for a new phone. Off by default.',
              ),
            ),
            value: _consents?['calibration_backup'] ?? false,
            onChanged:
                _consents == null ||
                    _pendingConsent.contains('calibration_backup')
                ? null
                : (v) => _consent('calibration_backup', v),
          ),
          SwitchListTile(
            key: const ValueKey('consent-analytics'),
            title: Text(tr('Anonymous analytics')),
            subtitle: Text(tr('Crash and usage counts to improve the game.')),
            value: _consents?['analytics'] ?? false,
            onChanged:
                _consents == null || _pendingConsent.contains('analytics')
                ? null
                : (v) => _consent('analytics', v),
          ),
          BigButton(
            tr('Download my data'),
            icon: Icons.download,
            secondary: true,
            onPressed: _exporting ? null : _export,
          ),
          BigButton(
            tr('Delete my account'),
            icon: Icons.delete_forever,
            secondary: true,
            onPressed: _deleting ? null : _delete,
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
            tr('Sign in'),
            icon: Icons.login,
            onPressed: () async {
              await context.push('/sign-in');
              if (!mounted) return;
              _consents = null;
              await _loadConsents();
            },
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

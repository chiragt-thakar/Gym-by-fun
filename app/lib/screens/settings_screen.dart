import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_director/game_director.dart';
import 'package:go_router/go_router.dart';

import '../l10n/strings.dart';
import '../l10n/tr.dart';
import '../services/api_client.dart';
import '../arcade/progress.dart';
import '../services/coach_service.dart';
import '../services/local_data.dart';
import '../services/session_queue.dart';
import '../services/premium.dart';
import '../services/settings.dart';
import '../game/forest_game.dart' show HeroLook;
import '../app/theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

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
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      final queue = ref.read(sessionQueueProvider);
      if ((await queue.pending()).isNotEmpty && mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(tr('Unsynced runs on this phone')),
            content: Text(
              tr(
                'Sign out removes unsynced runs. Stay signed in to sync them later.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(tr('Cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(tr('Sign out')),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
      await queue.clear();
      if (!mounted) return;
      ref.read(coachHistoryProvider.notifier).clear();
      ref.read(arcadeProgressProvider.notifier).clear();
      await ref.read(sharedPrefsProvider).remove('pendingGymCode');
      await ref.read(tokenStoreProvider).clear();
      if (!mounted) return;
      ref
          .read(settingsProvider.notifier)
          .update((x) => x.copyWith(signedIn: false));
      ref.invalidate(homeDataProvider);
      ref.invalidate(premiumProvider);
      _snack(tr('Signed out. Your progress stays on this phone.'));
    } catch (_) {
      _snack(tr('Could not clear local activity. Please try again.'));
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

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
      ref.invalidate(arcadeProgressProvider);
      n.reset();
      context.go('/welcome');
    } catch (_) {
      _snack(tr('Needs a connection and sign-in'));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _addPlayer() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Add player')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 16,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: tr('Name')),
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: Text(tr('Add')),
          ),
        ],
      ),
    );
    final clean = name?.trim() ?? '';
    if (clean.isEmpty || !mounted) return;
    ref.read(settingsProvider.notifier).update((x) => x.switchPlayer(clean));
    _snack(tr('Their body profile is measured before their first game.'));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final signedIn = s.signedIn && ref.read(tokenStoreProvider).hasSession;

    return ScreenScaffold(
      title: tr('Settings'),
      children: [
        const _H('Play'),
        Text(tr('Difficulty'), style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 6),
        SegmentedButton<Difficulty>(
          segments: [
            ButtonSegment(
              value: Difficulty.beginner,
              label: Text(tr('Beginner')),
            ),
            ButtonSegment(
              value: Difficulty.intermediate,
              label: Text(tr('Medium')),
            ),
            ButtonSegment(
              value: Difficulty.advanced,
              label: Text(tr('Advanced')),
            ),
          ],
          selected: {s.difficulty},
          onSelectionChanged: (v) =>
              n.update((x) => x.copyWith(difficulty: v.first)),
        ),
        const _H('Your explorer'),
        Center(child: ExplorerPortrait(look: s.heroLook)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final look in HeroLook.values)
              ChoiceChip(
                key: ValueKey('explorer-${look.name}'),
                selected: s.heroLook == look,
                label: Text(
                  tr(switch (look) {
                    HeroLook.fox => 'Kavi the fox',
                    HeroLook.otter => 'Neela the otter',
                    HeroLook.robot => 'Tara the starbot',
                  }),
                ),
                onSelected: (_) => n.update((x) => x.copyWith(heroLook: look)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          tr('Same moves, same rules. Pick the explorer you love.'),
          textAlign: TextAlign.center,
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
          title: Text(
            tr('Low-impact mode'),
            style: const TextStyle(fontSize: 18),
          ),
          subtitle: Text(tr('Half squats count, one arm is enough, no jumps.')),
          value: s.lowImpact,
          onChanged: (v) => n.update((x) => x.copyWith(lowImpact: v)),
        ),
        SwitchListTile(
          title: Text(tr('Assist mode'), style: const TextStyle(fontSize: 18)),
          subtitle: Text(tr('More warning time and wider timing windows.')),
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
              'Mirror on: see yourself with an outline. Mirror off: a live body avatar. Video is never saved.',
            ),
          ),
          value: s.cameraMirror,
          onChanged: (v) => n.update((x) => x.copyWith(cameraMirror: v)),
        ),
        ListTile(
          title: Text(tr('Language'), style: const TextStyle(fontSize: 18)),
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
        const _H('Tracking'),
        Text(
          s.calibration == null
              ? tr('No body profile yet. It is measured before your first game.')
              : '${tr('Body profile')}: ${s.player} · ${tr(_qualityLabel(s.calibration!.quality))}',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        // Everyone who plays on this phone keeps their own body profile.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in s.players)
              InputChip(
                key: ValueKey('player-$name'),
                selected: name == s.player,
                selectedColor: Lantern.glow.withValues(alpha: 0.22),
                label: Text(name),
                onPressed: () => n.update((x) => x.switchPlayer(name)),
                onDeleted: name == s.player
                    ? null
                    : () => n.update((x) => x.removePlayer(name)),
              ),
            ActionChip(
              key: const ValueKey('add-player'),
              avatar: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Text(tr('Add player')),
              onPressed: _addPlayer,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (s.calibration != null)
          BigButton(
            tr('Quick re-check (5 seconds)'),
            key: const ValueKey('quick-recalibrate'),
            icon: Icons.my_location_rounded,
            secondary: true,
            onPressed: () => context.push('/calibrate?quick=1'),
          ),
        BigButton(
          tr('Recalibrate'),
          icon: Icons.accessibility_new,
          secondary: true,
          // The current profile stays until the new one is finished.
          onPressed: () => context.push('/calibrate'),
        ),
        BigButton(
          tr('Redo space setup'),
          icon: Icons.crop_free,
          secondary: true,
          onPressed: () {
            n.update((x) => x.copyWith(setupDone: false));
            context.push('/setup');
          },
        ),
        SwitchListTile(
          key: const ValueKey('multi-person'),
          title: Text(
            tr('Other people in the room'),
            style: const TextStyle(fontSize: 18),
          ),
          subtitle: Text(
            tr(
              'Keeps tracking locked onto you when someone else is in view. Uses more battery.',
            ),
          ),
          value: s.multiPerson,
          onChanged: (v) => n.update((x) => x.copyWith(multiPerson: v)),
        ),
        SwitchListTile(
          key: const ValueKey('haptics'),
          title: Text(tr('Vibration cues'), style: const TextStyle(fontSize: 18)),
          subtitle: Text(
            tr('A short buzz when a step is done or tracking changes.'),
          ),
          value: s.haptics,
          onChanged: (v) => n.update((x) => x.copyWith(haptics: v)),
        ),
        SwitchListTile(
          key: const ValueKey('diagnostics'),
          title: Text(
            tr('Diagnostics overlay'),
            style: const TextStyle(fontSize: 18),
          ),
          subtitle: Text(
            tr(
              'Shows what tracking sees on camera screens: body points, confidence, state and frame rate.',
            ),
          ),
          value: s.diagnostics,
          onChanged: (v) => n.update((x) => x.copyWith(diagnostics: v)),
        ),
        const _H('Privacy'),
        const CameraTrustPanel(),
        const SizedBox(height: 8),
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
            onPressed: _signingOut ? null : _signOut,
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
        Text(
          tr(
            'Grievances and data requests: grievance@motionquest.app — we respond within 30 days.',
          ),
        ),
        const _H('Developer'),
        BigButton(
          tr('Tracking debug screen'),
          icon: Icons.bug_report,
          secondary: true,
          onPressed: () => context.push('/debug'),
        ),
        BigButton(
          tr('Landmark recorder'),
          icon: Icons.fiber_manual_record,
          secondary: true,
          onPressed: () => context.push('/recorder'),
        ),
      ],
    );
  }
}

/// Plain words for a calibration quality score (0 = not scored).
String _qualityLabel(double q) => q <= 0
    ? 'quick estimate'
    : q >= 0.75
    ? 'good quality'
    : q >= 0.5
    ? 'fair quality'
    : 'low quality — recalibrate in better conditions';

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
        Flexible(
          child: Text(tr(text), style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider()),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/tr.dart';

import '../app/theme.dart';
import '../l10n/strings.dart';
import '../services/settings.dart';
import '../widgets/common.dart';

/// First launch. One idea (your body is the controller), three honest
/// promises, the language, one button.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final str = s.s;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: ForestBackdrop()),
          SafeArea(
            // Scrolls on short screens; Spacers still centre on tall ones.
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight - 48),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const StepProgress(current: 0, total: 3),
                        const Spacer(),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: JoyneticLogo(
                            size: 76,
                            stacked: true,
                            glow: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          str.t('tagline'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: Lantern.glow),
                        ),
                        const SizedBox(height: 20),
                        const _Promise(
                          Icons.timer_outlined,
                          'Three to fifteen minutes a session',
                        ),
                        const _Promise(
                          Icons.lock_outline_rounded,
                          'Your camera stays on this phone',
                        ),
                        const _Promise(
                          Icons.favorite_outline_rounded,
                          'A game, not medical advice',
                        ),
                        const Spacer(),
                        Text(
                          str.t('choose_language'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Lantern.fog),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final l in AppLanguage.values)
                              ChoiceChip(
                                key: ValueKey('language-${l.name}'),
                                selected: s.language == l,
                                label: Text(
                                  l.label,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                onSelected: (_) => ref
                                    .read(settingsProvider.notifier)
                                    .update((x) => x.copyWith(language: l)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        BigButton(
                          str.t('continue'),
                          icon: Icons.arrow_forward,
                          onPressed: () => context.go('/age'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AgeGateScreen extends ConsumerStatefulWidget {
  const AgeGateScreen({super.key});
  @override
  ConsumerState<AgeGateScreen> createState() => _AgeGateState();
}

class _AgeGateState extends ConsumerState<AgeGateScreen> {
  bool _under18 = false;

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: tr('Before you play'),
      children: [
        const StepProgress(current: 1, total: 3),
        Text(
          tr('Joynetic is for adults aged 18 and over.'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        Text(
          ref.watch(settingsProvider).s.t('not_medical'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        if (_under18)
          LanternCard(
            tone: LanternTone.warning,
            icon: Icons.do_not_disturb_on,
            child: Text(
              tr(
                'Sorry — Joynetic is only for adults right now. Thanks for your interest!',
              ),
              style: const TextStyle(fontSize: 19),
            ),
          )
        else ...[
          BigButton(
            tr('I am 18 or older'),
            icon: Icons.check_circle,
            onPressed: () {
              ref
                  .read(settingsProvider.notifier)
                  .update((s) => s.copyWith(ageConfirmed: true));
              context.go('/readiness');
            },
          ),
          BigButton(
            tr('I am under 18'),
            secondary: true,
            onPressed: () => setState(() => _under18 = true),
          ),
        ],
      ],
    );
  }
}

/// Short readiness check. Advises seeing a doctor if any answer is yes.
/// The answers are NOT stored anywhere — only that the check was shown.
class ReadinessScreen extends ConsumerStatefulWidget {
  const ReadinessScreen({super.key});
  @override
  ConsumerState<ReadinessScreen> createState() => _ReadinessState();
}

class _ReadinessState extends ConsumerState<ReadinessScreen> {
  static const questions = [
    'Has a doctor ever said you have a heart condition or high blood pressure?',
    'Do you feel pain in your chest at rest or when you are active?',
    'Do you lose balance because of dizziness, or have you fainted recently?',
    'Do you have a bone, joint or back problem that movement could make worse?',
    'Are you pregnant, or recovering from surgery or an injury?',
  ];
  final _answers = List<bool?>.filled(questions.length, null);

  @override
  Widget build(BuildContext context) {
    final allAnswered = _answers.every((a) => a != null);
    final anyYes = _answers.any((a) => a == true);
    return ScreenScaffold(
      title: tr('Readiness check'),
      children: [
        const StepProgress(current: 2, total: 3),
        Text(
          tr(
            'A quick check before you move. Your answers stay on this screen and are not saved.',
          ),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < questions.length; i++)
          LanternCard(
            tone: _answers[i] == null ? LanternTone.plain : LanternTone.scarf,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr(questions[i]),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(tr('No'))),
                    ButtonSegment(value: true, label: Text(tr('Yes'))),
                  ],
                  selected: {if (_answers[i] != null) _answers[i]!},
                  emptySelectionAllowed: true,
                  onSelectionChanged: (v) =>
                      setState(() => _answers[i] = v.isEmpty ? null : v.first),
                ),
              ],
            ),
          ),
        if (anyYes)
          LanternCard(
            tone: LanternTone.warning,
            icon: Icons.health_and_safety,
            child: Text(
              tr(
                'Please talk to a doctor before playing. If you choose to play, keep low-impact mode on, move gently, and stop if anything hurts.',
              ),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        const SizedBox(height: 12),
        BigButton(
          anyYes ? tr('I understand — continue gently') : tr('Continue'),
          onPressed: allAnswered
              ? () {
                  ref
                      .read(settingsProvider.notifier)
                      .update(
                        (s) => s.copyWith(
                          readinessDone: true,
                          lowImpact: anyYes ? true : null,
                        ),
                      );
                  context.go('/sign-in');
                }
              : null,
        ),
      ],
    );
  }
}

/// One short promise on the welcome screen: an icon and a line.
class _Promise extends StatelessWidget {
  const _Promise(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icon, size: 20, color: Lantern.scarf),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            tr(text),
            style: const TextStyle(fontSize: 16, color: Lantern.parchment),
          ),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_director/game_director.dart';
import 'package:go_router/go_router.dart';

import '../l10n/coach_strings.dart';
import '../l10n/tr.dart';

import '../services/api_client.dart';
import '../services/coach_service.dart';
import '../services/session_queue.dart';
import '../services/settings.dart';
import '../services/voice.dart';
import '../widgets/common.dart';

class ResultsData {
  const ResultsData({
    required this.result,
    required this.clientId,
    required this.startedAt,
    required this.durationS,
    this.moveStats,
    this.tutorial = false,
  });
  final RunResult result;
  final String clientId;
  final DateTime startedAt;
  final int durationS;
  final Map<String, Map<String, int>>? moveStats;
  final bool tutorial;
}

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key, required this.data});
  final ResultsData? data;
  @override
  ConsumerState<ResultsScreen> createState() => _ResultsState();
}

class _ResultsState extends ConsumerState<ResultsScreen> {
  int? _effort;
  bool _saved = false;
  bool _coachApplied = false;

  SessionSummary? _summary() {
    final d = widget.data;
    if (d == null || d.tutorial) return null;
    return SessionSummary.fromResult(
      d.result,
      date: d.startedAt,
      effort: _effort,
      moveStats: moveStatsFrom(d.moveStats),
    );
  }

  /// Kavi's advice including this run (not yet stored until Done).
  CoachAdvice? _advice() {
    final s = _summary();
    if (s == null) return null;
    return const Coach().advise([...ref.read(coachHistoryProvider), s]);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final recap = _advice()?.recap;
      if (recap == null) return;
      final lang = ref.read(settingsProvider).language;
      ref.read(voiceProvider).say(coachText(lang, recap), force: true);
    });
  }

  void _record() {
    final s = _summary();
    if (s != null) ref.read(coachHistoryProvider.notifier).record(s);
  }

  Future<void> _save() async {
    final d = widget.data;
    if (d == null || _saved || d.tutorial) return;
    _saved = true;
    _record();
    final q = ref.read(sessionQueueProvider);
    await q.add(
      SessionQueue.fromResult(
        d.result,
        clientId: d.clientId,
        startedAt: d.startedAt,
        durationS: d.durationS,
        effortRating: _effort,
        moveStats: d.moveStats,
      ),
    );
    try {
      await q.flush();
    } catch (_) {
      // Offline: it stays queued and syncs next time.
    }
  }

  Future<void> _painReport() async {
    const areas = [
      'knees',
      'back',
      'hips',
      'shoulders',
      'neck',
      'ankles',
      'other',
    ];
    final area = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              tr('Where did it hurt?'),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            for (final a in areas)
              ListTile(
                title: Text(
                  a[0].toUpperCase() + a.substring(1),
                  style: const TextStyle(fontSize: 20),
                ),
                onTap: () => Navigator.pop(c, a),
              ),
          ],
        ),
      ),
    );
    if (area == null || !mounted) return;
    var sent = false;
    try {
      await ref
          .read(apiProvider)
          .painReport(area, sessionClientId: widget.data?.clientId);
      sent = true;
    } catch (_) {}
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Thank you for telling us')),
        content: Text(
          '${sent ? 'We review every report within a week. ' : ''}Stop if it hurts, rest, and if pain continues please see a doctor. Low-impact mode keeps moves gentler.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _applyCoach(DifficultyAdvice a) {
    ref
        .read(settingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            difficulty: a.recommended,
            assist: a.suggestAssist ? true : null,
            lowImpact: a.suggestLowImpact ? true : null,
          ),
        );
    setState(() => _coachApplied = true);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    if (d == null) {
      return ScreenScaffold(
        title: tr('Results'),
        children: [BigButton(tr('Home'), onPressed: () => context.go('/home'))],
      );
    }
    final r = d.result;
    final s = ref.watch(settingsProvider).s;
    return ScreenScaffold(
      title: s.t('well_done'),
      showBack: false,
      children: [
        Text(
          r.completed
              ? tr('You escaped the forest!')
              : tr('Good effort — the forest will be there tomorrow.'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Stat(tr('Score'), '${r.score}'),
            _Stat(tr('Moves done'), '${r.movesDone}'),
            _Stat(tr('Active min'), (r.activeMs / 60000).toStringAsFixed(1)),
            _Stat(tr('Energy'), '${r.energy}'),
            _Stat(tr('Cleared'), '${r.cleared}'),
            _Stat(tr('Hearts left'), '${r.hearts}'),
          ],
        ),
        if (r.forgiven > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${r.forgiven} obstacle(s) were skipped because tracking dropped — no hearts lost.',
            ),
          ),
        if (!d.tutorial) ...[
          const SizedBox(height: 24),
          Text(
            tr('How hard did that feel?'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: [
              for (var i = 1; i <= 5; i++)
                ButtonSegment(
                  value: i,
                  label: Text('$i', style: const TextStyle(fontSize: 20)),
                ),
            ],
            selected: {?_effort},
            emptySelectionAllowed: true,
            onSelectionChanged: (v) =>
                setState(() => _effort = v.isEmpty ? null : v.first),
          ),
          Text(tr('1 = very easy · 5 = very hard')),
        ],
        if (!d.tutorial) ...[
          const SizedBox(height: 24),
          _CoachCard(
            advice: _advice()!,
            applied: _coachApplied,
            onApply: _applyCoach,
          ),
        ],
        const SizedBox(height: 24),
        BigButton(
          d.tutorial ? tr('Go to home') : tr('Done'),
          icon: Icons.home,
          onPressed: () async {
            await _save();
            if (context.mounted) context.go('/home');
          },
        ),
        BigButton(
          tr('Something hurt'),
          icon: Icons.healing,
          secondary: true,
          onPressed: _painReport,
        ),
        const SizedBox(height: 8),
        Text(s.t('stop_if_hurts'), textAlign: TextAlign.center),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
            Text(label, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    ),
  );
}

/// Coach Kavi's card: recap, up to two tips, next goal and a suggestion.
class _CoachCard extends ConsumerWidget {
  const _CoachCard({
    required this.advice,
    required this.applied,
    required this.onApply,
  });
  final CoachAdvice advice;
  final bool applied;
  final void Function(DifficultyAdvice) onApply;

  static const kaviOrange = Color(0xFFF07A1A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).language;
    final a = advice;
    final diff = a.difficulty;
    final offer = diff.changes || diff.suggestAssist;
    return Card(
      key: const Key('coach-card'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kaviOrange, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: kaviOrange,
                  child: Icon(Icons.directions_run, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(
                  coachKey(lang, 'coach_name'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (a.recap != null) ...[
              const SizedBox(height: 12),
              Text(
                coachText(lang, a.recap!),
                style: const TextStyle(fontSize: 18),
              ),
            ],
            for (final t in a.tips)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.tips_and_updates, color: kaviOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        coachText(lang, t),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            if (a.nextGoal != null) ...[
              const SizedBox(height: 12),
              Text(
                '${coachKey(lang, 'coach_next_goal')}: '
                '${coachText(lang, a.nextGoal!)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (a.balance != null) ...[
              const SizedBox(height: 8),
              Text(
                coachText(lang, a.balance!),
                style: const TextStyle(fontSize: 16),
              ),
            ],
            if (offer) ...[
              const SizedBox(height: 12),
              Text(
                reasonText(lang, diff.reason),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (applied)
                Text(coachKey(lang, 'coach_applied'))
              else
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kaviOrange),
                  onPressed: () => onApply(diff),
                  child: Text(
                    diff.changes
                        ? coachText(
                            lang,
                            CoachMessage('coach_try_level', {
                              'level': difficultyName(lang, diff.recommended),
                            }),
                          )
                        : coachKey(lang, 'coach_try_assist'),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

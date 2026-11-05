import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_director/game_director.dart';
import 'package:go_router/go_router.dart';

import '../l10n/tr.dart';

import '../services/api_client.dart';
import '../services/session_queue.dart';
import '../services/settings.dart';
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

  Future<void> _save() async {
    final d = widget.data;
    if (d == null || _saved || d.tutorial) return;
    _saved = true;
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

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    if (d == null)
      return ScreenScaffold(
        title: tr('Results'),
        children: [BigButton(tr('Home'), onPressed: () => context.go('/home'))],
      );
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

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
import '../app/theme.dart';
import '../game/forest_game.dart' show SceneTheme;
import '../game/stages.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

class ResultsData {
  const ResultsData({
    required this.result,
    required this.clientId,
    required this.startedAt,
    required this.durationS,
    this.moveStats,
    this.tutorial = false,
    this.levelId,
    this.maxHearts = 3,
    this.assist,
  });
  final RunResult result;
  final String clientId;
  final DateTime startedAt;
  final int durationS;
  final Map<String, Map<String, int>>? moveStats;
  final bool tutorial;

  /// The stage played; picks the headline. Null means Forest Escape.
  final String? levelId;
  final int maxHearts;
  final bool? assist;
}

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key, required this.data});
  final ResultsData? data;
  @override
  ConsumerState<ResultsScreen> createState() => _ResultsState();
}

class _ResultsState extends ConsumerState<ResultsScreen> {
  int? _effort;
  bool _done = false;
  bool _coachApplied = false;
  bool _saved = false;
  bool _saveFailed = false;

  /// Assist as it was for the run, before any coach change on this screen.
  late final bool _assist =
      widget.data?.assist ?? ref.read(settingsProvider).assist;

  /// The coach history before this run, captured on first show so the card
  /// keeps showing advice "including this run" after it has been saved.
  late final List<SessionSummary> _before = ref
      .read(coachHistoryProvider)
      .where((h) => h.clientId != widget.data?.clientId)
      .toList();

  SessionSummary? _summary() {
    final d = widget.data;
    if (d == null || d.tutorial) return null;
    return SessionSummary.fromResult(
      d.result,
      date: d.startedAt,
      assist: _assist,
      maxHearts: d.maxHearts,
      clientId: d.clientId,
      effort: _effort,
      moveStats: moveStatsFrom(d.moveStats),
    );
  }

  /// Kavi's advice including this run.
  CoachAdvice? _advice() {
    final s = _summary();
    if (s == null) return null;
    return const Coach().advise([..._before, s]);
  }

  @override
  void initState() {
    super.initState();
    _assist;
    _before;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Save as soon as the results appear, so leaving by system back or
      // the app being killed never loses the run.
      _persist(flush: false);
      final recap = _advice()?.recap;
      if (recap == null) return;
      final lang = ref.read(settingsProvider).language;
      ref.read(voiceProvider).say(coachText(lang, recap), force: true);
    });
  }

  /// Records the run in Kavi's history (replaced by clientId, so repeat
  /// calls are harmless) and queues it for upload (idempotent by clientId
  /// on the server).
  Future<void> _persist({required bool flush}) async {
    final d = widget.data;
    final s = _summary();
    if (d == null || s == null) return;
    ref.read(coachHistoryProvider.notifier).record(s);
    final q = ref.read(sessionQueueProvider);
    try {
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
      if (mounted) {
        setState(() {
          _saved = true;
          _saveFailed = false;
        });
        ref.invalidate(syncStatusProvider);
      }
      if (flush) await q.flush();
      if (mounted) ref.invalidate(syncStatusProvider);
    } catch (_) {
      // A disk-write failure is different from being offline. Never promise
      // the run is queued when the local write did not succeed.
      if (mounted) setState(() => _saveFailed = !_saved);
    }
  }

  Future<bool> _save() async {
    if (_done) return false;
    _done = true;
    await _persist(flush: true);
    if (_saveFailed) {
      _done = false;
      return false;
    }
    return true;
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
                  tr(a[0].toUpperCase() + a.substring(1)),
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
          '${sent ? '${tr('We review every report within a week.')} ' : ''}'
          '${tr('Stop if it hurts, rest, and if pain continues please see a doctor. Low-impact mode keeps moves gentler.')}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('OK'))),
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
    final st = stageById(d.levelId ?? r.levelId) ?? stages.first;
    final story = ref.watch(levelCatalogueProvider).value?[st.levelId]?.journey;
    return ScreenScaffold(
      title: s.t('well_done'),
      showBack: false,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            alignment: Alignment.bottomLeft,
            children: [
              SizedBox(
                height: 168,
                width: double.infinity,
                child: WorldVista(theme: st.theme, restored: r.completed),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Lantern.night.withValues(alpha: 0.95),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      r.completed ? Icons.auto_awesome : Icons.spa_outlined,
                      color: Lantern.glow,
                      size: 30,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      r.completed && story != null
                          ? tr(story.completion)
                          : tr('Every move is a step forward.'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (r.completed && story != null && !d.tutorial)
                      Text(
                        '${tr('Keepsake earned')}: ${tr(story.keepsake)}',
                        style: const TextStyle(color: Lantern.scarf),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!d.tutorial && r.completed && r.missionWon)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Chip(
              avatar: const Icon(Icons.auto_awesome, color: Lantern.glow),
              label: Text(
                '${tr('Mission star earned')} · ${r.missionCount.clamp(0, r.missionGoal)}/${r.missionGoal}',
              ),
            ),
          ),
        Text(
          _headline(r.completed, d.levelId),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        if (!d.tutorial)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(
                  _saveFailed
                      ? Icons.error_outline
                      : _saved
                      ? Icons.offline_pin_outlined
                      : Icons.hourglass_top,
                  color: _saveFailed ? Lantern.danger : Lantern.scarf,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr(
                      _saveFailed
                          ? 'Could not save. Tap Retry before leaving.'
                          : _saved
                          ? 'Saved on this phone. Syncs when signed in and online.'
                          : 'Saving on this phone...',
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (_saveFailed)
                  TextButton(
                    onPressed: () => _persist(flush: false),
                    child: Text(tr('Retry')),
                  ),
              ],
            ),
          ),
        // Equal-width grid: 3 columns when there is room, else 2, so the six
        // stats always fill whole rows instead of leaving a ragged gap.
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 480 ? 3 : 2;
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 0,
              children: [
                for (final (label, value) in [
                  (tr('Score'), '${r.score}'),
                  (tr('Moves done'), '${r.movesDone}'),
                  (tr('Active min'), (r.activeMs / 60000).toStringAsFixed(1)),
                  (tr('Energy'), '${r.energy}'),
                  (tr('Cleared'), '${r.cleared}'),
                  (tr('Hearts left'), '${r.hearts}'),
                ])
                  SizedBox(width: w, child: _Stat(label, value)),
              ],
            );
          },
        ),
        if (r.forgiven > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '${r.forgiven} '
              '${tr('obstacle(s) were skipped because tracking dropped — no hearts lost.')}',
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
            style: const ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(48, 56)),
            ),
            selected: {?_effort},
            emptySelectionAllowed: true,
            onSelectionChanged: (v) {
              setState(() => _effort = v.isEmpty ? null : v.first);
              _persist(flush: false);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              tr('1 = very easy · 5 = very hard'),
              style: const TextStyle(color: Lantern.fog),
            ),
          ),
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
            final saved = await _save();
            if (saved && context.mounted) context.go('/home');
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
  Widget build(BuildContext context) => LanternCard(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, color: Lantern.fog),
        ),
      ],
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

/// Results headline: the forest lines for forest stages (and when the stage
/// is unknown), neutral lines for every other world.
String _headline(bool completed, String? levelId) {
  final st = levelId == null ? null : stageById(levelId);
  final forest = st == null || st.theme == SceneTheme.forest;
  if (forest) {
    return completed
        ? tr('You escaped the forest!')
        : tr('Good effort — the forest will be there tomorrow.');
  }
  return completed
      ? tr('Stage complete!')
      : tr('Good effort — this stage will be there tomorrow.');
}

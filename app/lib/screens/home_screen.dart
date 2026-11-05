import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/api_client.dart';
import '../services/session_queue.dart';
import '../services/settings.dart';

/// Gym branding and progress, if signed in. Null when offline or signed out.
final homeDataProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final api = ref.watch(apiProvider);
  if (!api.tokens.hasSession) return null;
  try {
    await ref.read(sessionQueueProvider).flush();
    final results = await Future.wait([api.progress(), api.myGym()]);
    return {'progress': results[0], 'gym': results[1]['gym'], 'quests': results[1]['quests']};
  } catch (_) {
    return null;
  }
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const worlds = [
    ('Forest Awakening', true),
    ('Desert Trials', false),
    ('Stadium Nights', false),
    ('Neon City', false),
    ('Mountain Expedition', false),
    ('Ancient Temple', false),
    ('Shadow Arena', false),
    ('Cosmic Journey', false),
    ('Final Guardian', false),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final data = ref.watch(homeDataProvider).value;
    final gym = data?['gym'] as Map<String, dynamic>?;
    final progress = data?['progress'] as Map<String, dynamic>?;
    final quests = (data?['quests'] as List<dynamic>?) ?? const [];
    Color? gymColour;
    if (gym != null) {
      final hex = (gym['colours'] as Map)['primary'] as String;
      gymColour = Color(int.parse('FF${hex.substring(1)}', radix: 16));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(gym?['name'] as String? ?? 'MotionQuest'),
        backgroundColor: gymColour,
        actions: [IconButton(icon: const Icon(Icons.settings, size: 30), onPressed: () => context.push('/settings'))],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(homeDataProvider),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            SizedBox(
              height: 140,
              child: FilledButton(
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), backgroundColor: gymColour),
                onPressed: () => context.push('/quest'),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.play_arrow_rounded, size: 56),
                  Text(s.s.t('daily_quest'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                  const Text('Warm-up · Forest Escape · Cool-down', style: TextStyle(fontSize: 16)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _Tile(Icons.local_fire_department, 'Streak', '${progress?['streak'] ?? '–'}')),
              Expanded(child: _Tile(Icons.shield, 'Shields', '${progress?['shields'] ?? 2}')),
              Expanded(child: _Tile(Icons.star, 'Hero level', '${progress?['heroLevel'] ?? 1}')),
            ]),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.groups, size: 36),
                title: Text(gym == null ? 'Gym Crew' : '${gym['name']} crew', style: const TextStyle(fontSize: 20)),
                subtitle: Text(gym == null
                    ? (s.signedIn ? 'Have a gym code? Join your crew.' : 'Sign in to join your gym crew.')
                    : quests.isEmpty
                        ? 'See this week\'s crew board'
                        : 'Trainer quest: ${(quests.first as Map)['title']}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(s.signedIn ? '/crew' : '/sign-in'),
              ),
            ),
            const SizedBox(height: 16),
            Text('World map', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final (i, (name, open)) in worlds.indexed)
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(name, style: const TextStyle(fontSize: 19)),
                  subtitle: Text(open ? 'Squat · Lean · Raise arms' : 'Coming soon'),
                  trailing: Icon(open ? Icons.lock_open : Icons.lock_outline),
                  onTap: open ? () => context.push('/quest') : null,
                ),
              ),
            const SizedBox(height: 12),
            Text(s.s.t('not_medical'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.white60)),
          ]),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Icon(icon, size: 32),
            Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            Text(label),
          ]),
        ),
      );
}


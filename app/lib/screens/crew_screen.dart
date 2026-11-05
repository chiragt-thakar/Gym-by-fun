import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/router.dart';
import '../l10n/tr.dart';
import '../services/api_client.dart';
import '../services/settings.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

/// Gym Crew: join with a code (Premium free), then the weekly board by effort.
class CrewScreen extends ConsumerStatefulWidget {
  const CrewScreen({super.key});
  @override
  ConsumerState<CrewScreen> createState() => _CrewState();
}

class _CrewState extends ConsumerState<CrewScreen> {
  final _code = TextEditingController();
  bool _share = true;
  String? _error;
  Map<String, dynamic>? _gym;
  List<dynamic> _board = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPrefsProvider);
    final pending = prefs.getString(pendingGymCodeKey);
    if (pending != null) {
      _code.text = pending;
      prefs.remove(pendingGymCodeKey);
    }
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiProvider);
    try {
      final mine = await api.myGym();
      _gym = mine['gym'] as Map<String, dynamic>?;
      if (_gym != null) {
        _board =
            (await api.crewBoard(_gym!['id'] as String))['entries']
                as List<dynamic>;
      }
    } catch (_) {
      _error = tr('Needs a connection.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _join() async {
    setState(() => _error = null);
    try {
      await ref
          .read(apiProvider)
          .joinGym(_code.text.trim(), shareActivity: _share);
      ref.invalidate(homeDataProvider);
      await _load();
    } on ApiException catch (e) {
      setState(
        () => _error = switch (e.code) {
          'gym_code_unknown' =>
            'We don\'t know that code. Check the poster at your gym.',
          'gym_code_full' => tr(
            'This code has reached its member limit. Ask your gym for a new one.',
          ),
          'gym_code_expired' ||
          'gym_inactive' => tr('This code is no longer active.'),
          'already_in_a_gym' => tr('Leave your current gym first.'),
          _ => 'Could not join (${e.code}).',
        },
      );
    } catch (_) {
      setState(() => _error = tr('Needs a connection.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final gym = _gym;
    if (gym == null) {
      return ScreenScaffold(
        title: tr('Join your gym crew'),
        children: [
          Text(
            tr('Members of partner gyms get Premium free.'),
            style: TextStyle(fontSize: 19),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 24, letterSpacing: 2),
            decoration: InputDecoration(
              labelText: tr('Gym code'),
              hintText: 'IRON-AB12CD',
              border: OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            value: _share,
            onChanged: (v) => setState(() => _share = v),
            title: Text(tr('Share my activity with my gym')),
            subtitle: const Text(
              'Your first name, sessions and effort points appear on the crew board and the owner\'s weekly report. Never body measurements. You can turn this off any time.',
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 17),
            ),
          BigButton(tr('Join crew'), icon: Icons.groups, onPressed: _join),
        ],
      );
    }
    return ScreenScaffold(
      title: '${gym['name']} crew',
      children: [
        Text(
          'This week\'s board — effort, not raw reps, so everyone can compete.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        if (_board.isEmpty)
          Text(tr('No sessions yet this week. Be the first!')),
        for (final e in _board.cast<Map<String, dynamic>>())
          Card(
            color: e['isMe'] == true
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: ListTile(
              leading: CircleAvatar(child: Text('${e['rank']}')),
              title: Text(
                e['name'] as String,
                style: const TextStyle(fontSize: 20),
              ),
              trailing: Text(
                '${e['effortPoints']}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        BigButton(
          tr('Leave this gym'),
          secondary: true,
          onPressed: () async {
            await ref.read(apiProvider).leaveGym();
            ref.invalidate(homeDataProvider);
            setState(() {
              _gym = null;
              _board = const [];
            });
          },
        ),
      ],
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_director/game_director.dart';
import 'package:path_provider/path_provider.dart';

import 'api_client.dart';

/// Offline-first session storage: every finished run is written to a local
/// file first and uploaded when online. Uploads are idempotent (clientId).
class SessionQueue {
  SessionQueue(this._api, {Future<Directory> Function()? dir})
    : _dir = dir ?? getApplicationSupportDirectory;

  final ApiClient _api;
  final Future<Directory> Function() _dir;

  Future<File> get _file async =>
      File('${(await _dir()).path}/session_queue.json');

  static String newClientId() {
    final r = Random.secure();
    return List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static Map<String, Object?> fromResult(
    RunResult r, {
    required String clientId,
    required DateTime startedAt,
    required int durationS,
    int? effortRating,
    Map<String, Map<String, int>>? moveStats,
  }) {
    return {
      'clientId': clientId,
      'levelId': r.levelId,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'durationS': durationS,
      'activeS': (r.activeMs / 1000).round().clamp(0, durationS),
      'score': r.score,
      'difficulty': r.difficulty.name,
      'lowImpact': r.lowImpact,
      'completed': r.completed,
      'effortRating': effortRating,
      'moves': [
        for (final e in r.reps.entries)
          {
            'move': e.key.name,
            'attempts': moveStats?[e.key.name]?['attempts'] ?? e.value,
            'recognised': e.value,
            'falseTriggers': moveStats?[e.key.name]?['falseTriggers'] ?? 0,
            if (moveStats?[e.key.name]?['avgLatencyMs'] != null)
              'avgLatencyMs': moveStats![e.key.name]!['avgLatencyMs'],
          },
      ],
    };
  }

  Future<List<Map<String, Object?>>> pending() async {
    final f = await _file;
    if (!await f.exists()) return [];
    try {
      return [
        for (final e in jsonDecode(await f.readAsString()) as List<dynamic>)
          Map<String, Object?>.from(e as Map),
      ];
    } catch (_) {
      return [];
    }
  }

  /// Queues a session. A session with the same clientId replaces the queued
  /// one (e.g. the results screen saves first, then again with the effort
  /// rating), so the latest version is what gets uploaded.
  Future<void> add(Map<String, Object?> session) => _locked(() async {
    final all = await pending()
      ..removeWhere((s) => s['clientId'] == session['clientId'])
      ..add(session);
    await _write(all);
  });

  /// Uploads pending sessions in batches of 50. Returns how many were synced.
  ///
  /// Queue access is serialised, and after each upload the file is re-read
  /// and only the uploaded versions are removed, so a session added or
  /// updated meanwhile is never lost.
  Future<int> flush() => _locked(() async {
    if (!_api.tokens.hasSession) return 0;
    var synced = 0;
    while (true) {
      final batch = (await pending()).take(50).toList();
      if (batch.isEmpty) break;
      try {
        await _api.uploadSessions(batch);
      } on SocketException {
        break;
      } on ApiException catch (e) {
        // Retry later on server errors, auth, rate limits and timeouts.
        if (e.status >= 500 ||
            e.status == 401 ||
            e.status == 429 ||
            e.status == 408) {
          break;
        }
        // Other 4xx: permanently invalid; drop the batch so it can't block the queue.
      }
      final sent = {for (final s in batch) '${s['clientId']}': jsonEncode(s)};
      final rest = (await pending())
          .where((s) => sent['${s['clientId']}'] != jsonEncode(s))
          .toList();
      await _write(rest);
      synced += batch.length;
    }
    return synced;
  });

  static Future<void> _tail = Future.value();

  /// Runs [f] after any queue operation already in progress.
  static Future<T> _locked<T>(Future<T> Function() f) {
    final result = _tail.then((_) => f());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _write(List<Map<String, Object?>> all) async {
    final f = await _file;
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(all));
    await tmp.rename(f.path);
  }
}

final sessionQueueProvider = Provider<SessionQueue>(
  (ref) => SessionQueue(ref.watch(apiProvider)),
);

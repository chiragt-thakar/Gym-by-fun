import 'dart:async';
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
      // Preserve the original file rather than overwriting unreadable
      // activity on the next add. The UI can report a local save problem.
      throw const FormatException('Local activity could not be read');
    }
  }

  /// Queues a session. A session with the same clientId replaces the queued
  /// one (e.g. the results screen saves first, then again with the effort
  /// rating), so the latest version is what gets uploaded.
  Future<void> add(Map<String, Object?> session) => _locked(() async {
    final all = await pending()
      ..removeWhere((s) => s['clientId'] == session['clientId'])
      ..add({...session, '_accountId': _api.tokens.accountId});
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
    final account = _api.tokens.accountId;
    final retryToken = _api.tokens.refresh;
    // Snapshot work once. Entries owned by another account never leave
    // this device under the current player's credentials.
    final work = (await pending())
        .where((s) => s['_accountId'] == null || s['_accountId'] == account)
        .toList();
    Future<bool> send(List<Map<String, Object?>> batch) async {
      if (!_api.tokens.hasSession ||
          _api.tokens.accountId != account ||
          (account == null && _api.tokens.refresh != retryToken)) {
        return false;
      }
      var accepted = false;
      try {
        await _api.uploadSessions([
          for (final s in batch) {...s}..remove('_accountId'),
        ]);
        accepted = true;
      } on SocketException {
        return false;
      } on TimeoutException {
        return false;
      } on ApiException catch (e) {
        // Only validation errors isolate a bad record. Permissions, missing
        // routes, rate limits and service errors must never discard activity.
        if (e.status != 400 && e.status != 422) return false;
        if (batch.length > 1) {
          final mid = batch.length ~/ 2;
          if (!await send(batch.sublist(0, mid))) return false;
          return send(batch.sublist(mid));
        }
        final rejected = await _rejected();
        rejected.removeWhere((s) => s['clientId'] == batch.single['clientId']);
        rejected.add(batch.single);
        final f = await _file;
        await File('${f.path}.rejected').writeAsString(jsonEncode(rejected));
      }
      final sent = {for (final s in batch) '${s['clientId']}': jsonEncode(s)};
      final rest = (await pending())
          .where((s) => sent['${s['clientId']}'] != jsonEncode(s))
          .toList();
      await _write(rest);
      if (accepted) synced += batch.length;
      return true;
    }

    for (var i = 0; i < work.length; i += 50) {
      final batch = work.sublist(i, min(i + 50, work.length));
      if (batch.isEmpty) break;
      if (!await send(batch)) break;
    }
    return synced;
  });

  Future<List<Map<String, Object?>>> _rejected() async {
    final f = File('${(await _file).path}.rejected');
    if (!await f.exists()) return [];
    return [
      for (final s in jsonDecode(await f.readAsString()) as List)
        Map<String, Object?>.from(s as Map),
    ];
  }

  Future<int> rejectedCount() async => (await _rejected())
      .where(
        (s) =>
            s['_accountId'] == null || s['_accountId'] == _api.tokens.accountId,
      )
      .length;

  Future<List<Map<String, Object?>>> pendingForCurrentAccount() async =>
      (await pending())
          .where(
            (s) =>
                s['_accountId'] == null ||
                s['_accountId'] == _api.tokens.accountId,
          )
          .toList();

  /// Stamp pre-upgrade entries before replacing an existing account's tokens.
  Future<void> claimLegacy(String owner) => _locked(() async {
    final all = await pending();
    for (final s in all) {
      s.putIfAbsent('_accountId', () => owner);
    }
    await _write(all);
  });

  /// Uses the same lock as uploads: sign-out cannot race an in-flight flush.
  Future<void> clear() => _locked(() async {
    final f = await _file;
    for (final path in [f.path, '${f.path}.tmp', '${f.path}.rejected']) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
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

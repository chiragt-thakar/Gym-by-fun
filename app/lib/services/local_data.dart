import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coach_service.dart';

/// Keys removed by [wipeLocalData].
const localDataKeys = [
  'settings.v1',
  'auth.access',
  'auth.refresh',
  CoachHistoryNotifier.key,
  'pendingGymCode', // pendingGymCodeKey in app/router.dart
];

/// Removes everything MotionQuest keeps on this device: settings, auth tokens,
/// on-device Coach history, a pending gym code and the offline session queue.
/// A missing queue file or unavailable directory is fine.
Future<void> wipeLocalData(
  SharedPreferences prefs, {
  Future<Directory> Function()? dir,
}) async {
  for (final k in localDataKeys) {
    await prefs.remove(k);
  }
  try {
    final d = await (dir ?? getApplicationSupportDirectory)();
    final f = File('${d.path}/session_queue.json');
    if (await f.exists()) await f.delete();
  } catch (_) {}
}

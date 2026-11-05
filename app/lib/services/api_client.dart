import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'settings.dart';

/// Server base URL. Override at build time:
/// `flutter run --dart-define=API_BASE=https://api.example.in`
const apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:8080',
);

class ApiException implements Exception {
  ApiException(this.status, this.code);
  final int status;
  final String code;
  @override
  String toString() => 'ApiException($status, $code)';
}

/// Short-lived access token + rotating refresh token.
class TokenStore {
  TokenStore(this._prefs);
  final SharedPreferences _prefs;
  String? get access => _prefs.getString('auth.access');
  String? get refresh => _prefs.getString('auth.refresh');
  Future<void> save(String access, String refresh) async {
    await _prefs.setString('auth.access', access);
    await _prefs.setString('auth.refresh', refresh);
  }

  Future<void> clear() async {
    await _prefs.remove('auth.access');
    await _prefs.remove('auth.refresh');
  }

  bool get hasSession => refresh != null;
}

class ApiClient {
  ApiClient(this.tokens, {http.Client? client, String? base})
    : _http = client ?? http.Client(),
      _base = base ?? apiBase;

  final TokenStore tokens;
  final http.Client _http;
  final String _base;

  Uri _u(String path) => Uri.parse('$_base/v1$path');

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    bool auth = true,
    bool retried = false,
  }) async {
    final headers = {'content-type': 'application/json'};
    if (auth && tokens.access != null) {
      headers['authorization'] = 'Bearer ${tokens.access}';
    }
    final req = http.Request(method, _u(path))..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(
      await _http.send(req).timeout(const Duration(seconds: 15)),
    );
    if (res.statusCode == 401 && auth && !retried && tokens.refresh != null) {
      if (await _refresh()) {
        return _send(method, path, body: body, auth: auth, retried: true);
      }
    }
    final decoded = res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiException(
        res.statusCode,
        (decoded is Map ? decoded['error'] : null)?.toString() ?? 'error',
      );
    }
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  }

  Future<bool> _refresh() async {
    try {
      final r = await _send(
        'POST',
        '/auth/refresh',
        body: {'refreshToken': tokens.refresh},
        auth: false,
        retried: true,
      );
      await tokens.save(
        r['accessToken'] as String,
        r['refreshToken'] as String,
      );
      return true;
    } on ApiException {
      await tokens.clear();
      return false;
    }
  }

  Future<void> startOtp(String phone) =>
      _send('POST', '/auth/otp/start', body: {'phone': phone}, auth: false);

  Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String code, {
    required bool ageConfirmed,
    required String language,
  }) async {
    final r = await _send(
      'POST',
      '/auth/otp/verify',
      body: {
        'phone': phone,
        'code': code,
        'ageConfirmed': ageConfirmed,
        'language': language,
      },
      auth: false,
    );
    await tokens.save(r['accessToken'] as String, r['refreshToken'] as String);
    return r;
  }

  Future<Map<String, dynamic>> me() => _send('GET', '/me');
  Future<Map<String, dynamic>> updateMe(Map<String, Object?> patch) =>
      _send('PATCH', '/me', body: patch);
  Future<Map<String, dynamic>> progress() => _send('GET', '/progress');
  Future<Map<String, dynamic>> entitlements() => _send('GET', '/entitlements');
  Future<Map<String, dynamic>> uploadSessions(
    List<Map<String, Object?>> sessions,
  ) => _send('POST', '/sessions', body: {'sessions': sessions});
  Future<Map<String, dynamic>> joinGym(
    String code, {
    required bool shareActivity,
  }) => _send(
    'POST',
    '/gyms/join',
    body: {'code': code, 'shareActivity': shareActivity},
  );
  Future<void> leaveGym() => _send('DELETE', '/gyms/membership');
  Future<Map<String, dynamic>> myGym() => _send('GET', '/gyms/mine');
  Future<Map<String, dynamic>> crewBoard(String gymId) =>
      _send('GET', '/crews/$gymId/board');
  Future<Map<String, dynamic>> setConsents(Map<String, bool> c) => _send(
    'PUT',
    '/me/consents',
    body: {
      'consents': [
        for (final e in c.entries) {'purpose': e.key, 'granted': e.value},
      ],
    },
  );
  Future<Map<String, dynamic>> exportData() => _send('GET', '/me/export');
  Future<void> deleteAccount() async {
    await _send('DELETE', '/me');
    await tokens.clear();
  }

  Future<void> painReport(
    String area, {
    String? note,
    String? sessionClientId,
  }) => _send(
    'POST',
    '/me/pain-reports',
    body: {'area': area, 'note': note, 'sessionClientId': sessionClientId},
  );
}

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => TokenStore(ref.watch(sharedPrefsProvider)),
);
final apiProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(tokenStoreProvider)),
);

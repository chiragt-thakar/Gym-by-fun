import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/tr.dart';

import '../app/router.dart';
import '../services/api_client.dart';
import '../services/settings.dart';
import '../app/theme.dart';
import '../widgets/common.dart';

/// Phone OTP sign-in. Optional: the game works offline and syncs later.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInState();
}

class _SignInState extends ConsumerState<SignInScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _error;

  String get _e164 => '+91${_phone.text.replaceAll(RegExp(r'\D'), '')}';

  Future<void> _run(Future<void> Function() f) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await f();
    } on ApiException catch (e) {
      setState(
        () => _error = switch (e.code) {
          'otp_invalid' => tr('That code is not right. Try again.'),
          'otp_expired' => tr('The code expired. Ask for a new one.'),
          'otp_rate_limited' => tr(
            'Too many tries. Please wait a few minutes.',
          ),
          _ => 'Something went wrong (${e.code}).',
        },
      );
    } catch (_) {
      setState(
        () => _error = tr(
          'No connection. You can play offline and sign in later.',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _next() {
    final s = ref.read(settingsProvider);
    final pendingCode = ref
        .read(sharedPrefsProvider)
        .getString(pendingGymCodeKey);
    if (!s.setupDone) return context.go('/setup');
    context.go(pendingCode != null && s.signedIn ? '/crew' : '/home');
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.read(apiProvider);
    final s = ref.watch(settingsProvider);
    return ScreenScaffold(
      title: tr('Sign in'),
      children: [
        Text(
          tr('Save your progress and join your gym crew.'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phone,
          enabled: !_sent,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontSize: 22),
          decoration: InputDecoration(
            prefixText: '+91 ',
            labelText: tr('Mobile number'),
                      ),
        ),
        if (_sent) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(fontSize: 26, letterSpacing: 8),
            decoration: InputDecoration(
              labelText: tr('6-digit code'),
                          ),
          ),
        ],
        if (_error != null)
          LanternCard(
            tone: LanternTone.warning,
            icon: Icons.error_outline,
            child: Text(
              _error!,
              style: const TextStyle(color: Lantern.warning, fontSize: 17),
            ),
          ),
        const SizedBox(height: 12),
        if (!_sent)
          BigButton(
            tr('Send code'),
            onPressed: _busy
                ? null
                : () => _run(() async {
                    await api.startOtp(_e164);
                    setState(() => _sent = true);
                  }),
          )
        else
          BigButton(
            tr('Verify'),
            onPressed: _busy
                ? null
                : () => _run(() async {
                    await api.verifyOtp(
                      _e164,
                      _code.text.trim(),
                      ageConfirmed: s.ageConfirmed,
                      language: s.language.name,
                    );
                    ref
                        .read(settingsProvider.notifier)
                        .update((x) => x.copyWith(signedIn: true));
                    _next();
                  }),
          ),
        BigButton(
          tr('Play offline for now'),
          secondary: true,
          onPressed: _next,
        ),
      ],
    );
  }
}

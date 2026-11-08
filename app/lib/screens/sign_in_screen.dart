import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/tr.dart';

import '../app/router.dart';
import '../services/api_client.dart';
import '../services/settings.dart';
import '../services/coach_service.dart';
import '../services/premium.dart';
import '../services/session_queue.dart';
import 'home_screen.dart';
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
  bool _resendCooling = false;
  Timer? _cooldown;

  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '');
  String get _e164 => '+91$_digits';
  bool get _validNumber => RegExp(r'^[6-9]\d{9}$').hasMatch(_digits);

  @override
  void initState() {
    super.initState();
    _phone.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cooldown?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldown?.cancel();
    _resendCooling = true;
    _cooldown = Timer(const Duration(seconds: 30), () {
      if (mounted) setState(() => _resendCooling = false);
    });
  }

  Future<void> _sendCode() => _run(() async {
    await ref.read(apiProvider).startOtp(_e164);
    if (!mounted) return;
    setState(() {
      _sent = true;
      _code.clear();
      _startCooldown();
    });
  });

  void _changeNumber() {
    _cooldown?.cancel();
    setState(() {
      _sent = false;
      _resendCooling = false;
      _code.clear();
      _error = null;
    });
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await f();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = switch (e.code) {
          'otp_invalid' => tr('That code is not right. Try again.'),
          'otp_expired' => tr('The code expired. Ask for a new one.'),
          'otp_rate_limited' => tr(
            'Too many tries. Please wait a few minutes.',
          ),
          _ => tr('Something went wrong. Please try again.'),
        },
      );
    } catch (_) {
      if (!mounted) return;
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
            decoration: InputDecoration(labelText: tr('6-digit code')),
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
        if (!_sent) ...[
          if (_phone.text.isNotEmpty && !_validNumber)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(tr('Enter a 10-digit mobile number.')),
            ),
          BigButton(
            tr('Send code'),
            key: const ValueKey('send-code'),
            onPressed: _busy || !_validNumber ? null : _sendCode,
          ),
        ] else ...[
          BigButton(
            tr('Verify'),
            onPressed: _busy
                ? null
                : () => _run(() async {
                    final previousAccount = api.tokens.accountId;
                    if (previousAccount != null) {
                      await ref
                          .read(sessionQueueProvider)
                          .claimLegacy(previousAccount);
                    }
                    final result = await api.verifyOtp(
                      _e164,
                      _code.text.trim(),
                      ageConfirmed: s.ageConfirmed,
                      language: s.language.name,
                    );
                    if (!mounted) return;
                    final account = (result['user'] as Map?)?['id'];
                    if (previousAccount != null && account != previousAccount) {
                      ref.read(coachHistoryProvider.notifier).clear();
                      ref
                          .read(settingsProvider.notifier)
                          .update(
                            (x) => x.copyWith(
                              completedLevels: {},
                              missionLevels: {},
                              sessionsPlayed: 0,
                              seenTypes: {},
                              clearCalibration: true,
                              tutorialDone: false,
                            ),
                          );
                    }
                    ref
                        .read(settingsProvider.notifier)
                        .update((x) => x.copyWith(signedIn: true));
                    ref.invalidate(homeDataProvider);
                    ref.invalidate(premiumProvider);
                    _next();
                  }),
          ),
          BigButton(
            tr('Resend code'),
            key: const ValueKey('resend-code'),
            secondary: true,
            onPressed: _busy || _resendCooling ? null : _sendCode,
          ),
          BigButton(
            tr('Change number'),
            key: const ValueKey('change-number'),
            secondary: true,
            onPressed: _busy ? null : _changeNumber,
          ),
        ],
        BigButton(
          tr('Play offline for now'),
          secondary: true,
          onPressed: _next,
        ),
      ],
    );
  }
}

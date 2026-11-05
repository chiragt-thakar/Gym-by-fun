import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// Premium as decided by the server (Play purchase or gym code). The app
/// never grants itself access.
class PremiumState {
  const PremiumState({this.premium = false, this.source, this.activeUntil});
  final bool premium;

  /// `play`, `gym` or `promo`.
  final String? source;
  final DateTime? activeUntil;

  /// An [activeUntil] in the past (or before [now]) means not Premium, even
  /// if a stale server or cache still says `premium: true`.
  factory PremiumState.fromJson(Map<String, dynamic> j, {DateTime? now}) {
    final raw = j['activeUntil'];
    final until = raw is String ? DateTime.tryParse(raw) : null;
    final expired = until != null && until.isBefore(now ?? DateTime.now());
    return PremiumState(
      premium: j['premium'] == true && !expired,
      source: j['source'] as String?,
      activeUntil: until,
    );
  }
}

final premiumProvider = FutureProvider.autoDispose<PremiumState>((ref) async {
  final api = ref.watch(apiProvider);
  if (!api.tokens.hasSession) return const PremiumState();
  try {
    return PremiumState.fromJson(await api.entitlements());
  } catch (_) {
    return const PremiumState();
  }
});

/// Where the player is when we consider showing the paywall.
enum PaywallMoment { afterSession, lockedWorld, midRun }

/// Paywall rules from the plan: after the third session or when opening a
/// locked world — never mid-run, never for Premium or gym members, and never
/// while payments are switched off.
class PaywallPolicy {
  const PaywallPolicy({this.enabled = paymentsEnabled, this.freeSessions = 3});

  /// Payments ship in Phase 3. Turn on with `--dart-define=PAYMENTS=true`.
  /// Off when the developer unlock-all switch is on, so nothing is locked.
  static const paymentsEnabled =
      bool.fromEnvironment('PAYMENTS') &&
      !bool.fromEnvironment('DEV_UNLOCK_ALL');

  final bool enabled;
  final int freeSessions;

  bool shouldShow({
    required PaywallMoment moment,
    required PremiumState premium,
    required int sessionsPlayed,
    bool shownThisSession = false,
  }) {
    if (!enabled || premium.premium || shownThisSession) return false;
    return switch (moment) {
      PaywallMoment.midRun => false,
      PaywallMoment.lockedWorld => true,
      PaywallMoment.afterSession => sessionsPlayed == freeSessions,
    };
  }
}

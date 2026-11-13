import 'package:flutter_test/flutter_test.dart';
import 'package:joynetic/services/premium.dart';

void main() {
  const on = PaywallPolicy(enabled: true);
  const free = PremiumState();
  const paid = PremiumState(premium: true, source: 'gym');

  test('never mid-run', () {
    expect(
      on.shouldShow(
        moment: PaywallMoment.midRun,
        premium: free,
        sessionsPlayed: 3,
      ),
      isFalse,
    );
  });

  test('after the third session, once', () {
    expect(
      on.shouldShow(
        moment: PaywallMoment.afterSession,
        premium: free,
        sessionsPlayed: 2,
      ),
      isFalse,
    );
    expect(
      on.shouldShow(
        moment: PaywallMoment.afterSession,
        premium: free,
        sessionsPlayed: 3,
      ),
      isTrue,
    );
    expect(
      on.shouldShow(
        moment: PaywallMoment.afterSession,
        premium: free,
        sessionsPlayed: 4,
      ),
      isFalse,
    );
    expect(
      on.shouldShow(
        moment: PaywallMoment.afterSession,
        premium: free,
        sessionsPlayed: 3,
        shownThisSession: true,
      ),
      isFalse,
    );
  });

  test('locked worlds, but not for Premium or gym members', () {
    expect(
      on.shouldShow(
        moment: PaywallMoment.lockedWorld,
        premium: free,
        sessionsPlayed: 0,
      ),
      isTrue,
    );
    expect(
      on.shouldShow(
        moment: PaywallMoment.lockedWorld,
        premium: paid,
        sessionsPlayed: 0,
      ),
      isFalse,
    );
  });

  test('off until payments are switched on', () {
    const off = PaywallPolicy(enabled: false);
    expect(
      off.shouldShow(
        moment: PaywallMoment.lockedWorld,
        premium: free,
        sessionsPlayed: 3,
      ),
      isFalse,
    );
    expect(PaywallPolicy.paymentsEnabled, isFalse);
  });

  test('parses the server entitlement', () {
    final s = PremiumState.fromJson({
      'premium': true,
      'source': 'play',
      'activeUntil': '2027-01-01T00:00:00.000Z',
    });
    expect(s.premium, isTrue);
    expect(s.activeUntil!.year, 2027);
  });
}

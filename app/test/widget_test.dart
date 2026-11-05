import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motionquest/app/router.dart';
import 'package:motionquest/main.dart';
import 'package:motionquest/services/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpApp(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2.6;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const MotionQuestApp(),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'a new player lands on the welcome screen and can switch language',
    (t) async {
      await pumpApp(t);
      expect(find.text('MotionQuest'), findsOneWidget);
      expect(find.text('Your body is the controller.'), findsOneWidget);
      await t.tap(find.text('ગુજરાતી'));
      await t.pumpAndSettle();
      expect(find.text('તમારું શરીર જ કંટ્રોલર છે.'), findsOneWidget);
    },
  );

  testWidgets('under-18 players cannot continue', (t) async {
    await pumpApp(t);
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    await t.tap(find.text('I am under 18'));
    await t.pumpAndSettle();
    expect(find.textContaining('only for adults'), findsOneWidget);
    expect(find.text('I am 18 or older'), findsNothing);
  });

  testWidgets('a "yes" in the readiness check advises seeing a doctor', (
    t,
  ) async {
    await pumpApp(t);
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    await t.tap(find.text('I am 18 or older'));
    await t.pumpAndSettle();
    expect(find.text('Readiness check'), findsOneWidget);
    expect(find.textContaining('talk to a doctor'), findsNothing);
    await t.tap(find.text('Yes').first);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.textContaining('talk to a doctor'), 300);
    expect(find.textContaining('talk to a doctor'), findsOneWidget);
  });

  testWidgets('a gym QR deep link remembers the code through onboarding', (
    t,
  ) async {
    await pumpApp(t);
    final container = ProviderScope.containerOf(
      t.element(find.byType(MotionQuestApp)),
    );
    container.read(routerProvider).go('/join?code=iron-ab12cd');
    await t.pumpAndSettle();
    expect(
      container.read(sharedPrefsProvider).getString(pendingGymCodeKey),
      'IRON-AB12CD',
    );
    expect(
      find.text('Your body is the controller.'),
      findsOneWidget,
    ); // onboarding first
  });

  testWidgets('choosing Hindi translates the following screens', (t) async {
    await pumpApp(t);
    await t.tap(find.text('हिंदी'));
    await t.pumpAndSettle();
    await t.tap(find.text('आगे बढ़ें'));
    await t.pumpAndSettle();
    expect(find.text('मेरी उम्र 18 या उससे अधिक है'), findsOneWidget);
    await t.tap(find.text('मेरी उम्र 18 या उससे अधिक है'));
    await t.pumpAndSettle();
    expect(find.text('तैयारी जाँच'), findsOneWidget);
  });
}

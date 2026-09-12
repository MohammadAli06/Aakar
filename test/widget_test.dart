import 'package:craft_connect/app.dart';
import 'package:craft_connect/core/routing/app_router.dart';
import 'package:craft_connect/core/services/app_providers.dart';
import 'package:craft_connect/shared/models/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_session_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Restores saved language and handles older unsupported choices',
      () async {
    for (final code in ['en', 'hi', 'mr']) {
      SharedPreferences.setMockInitialValues({'selected_language': code});
      expect(await loadSelectedLanguage(), code == 'en' ? 'en' : 'hi');
    }
  });

  Future<ProviderContainer> start(
    WidgetTester tester,
    String language,
    String route, {
    AccountRole? asRole,
    bool completeProfile = true,
  }) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(overrides: [
      selectedLanguageProvider.overrideWith((ref) => language),
      sessionProvider.overrideWith((ref) => asRole == null
          ? signedOutSession()
          : signedInSession(asRole, complete: completeProfile)),
    ]);
    final router = container.read(appRouterProvider);
    router.go(route);
    addTearDown(container.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const AakarApp()));
    if (route == '/photo-capture') {
      await tester.pump(const Duration(seconds: 1));
    } else {
      await tester.pumpAndSettle();
    }
    return container;
  }

  testWidgets('English selection persists and continues in English',
      (tester) async {
    final container = await start(tester, 'hi', '/language');
    await tester.tap(find.text('English').first);
    await tester.pumpAndSettle();
    expect(container.read(selectedLanguageProvider), 'en');
    expect(find.text('Continue  →'), findsOneWidget);
    await tester.tap(find.text('Continue  →'));
    await tester.pumpAndSettle();
    expect(find.text('Snap. We enhance.'), findsOneWidget);
    expect(find.text('फोटो खींचें, हम संवारेंगे'), findsNothing);
    expect(await loadSelectedLanguage(), 'en');
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Aakar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hindi selection persists and continues in Hindi',
      (tester) async {
    await start(tester, 'en', '/language');
    await tester.tap(find.text('हिंदी'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('आगे बढ़ें  →'));
    await tester.pumpAndSettle();
    expect(find.text('फोटो खींचें, हम संवारेंगे'), findsOneWidget);
    expect(find.text('Snap. We enhance.'), findsNothing);
    expect(await loadSelectedLanguage(), 'hi');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Signed-out visitor is sent to common phone sign-in',
      (tester) async {
    await start(tester, 'en', '/dashboard');
    expect(find.text('Welcome to Aakar'), findsOneWidget);
    expect(find.text('Mobile number'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dashboard can switch language and return to the same route',
      (tester) async {
    await start(tester, 'en', '/dashboard', asRole: AccountRole.artisan);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.byIcon(Icons.language));
    await tester.pumpAndSettle();
    await tester.tap(find.text('हिंदी'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('आगे बढ़ें  →'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Your account'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unavailable language does not change selection', (tester) async {
    final container = await start(tester, 'en', '/language');
    await tester.tap(find.text('मराठी'));
    await tester.pumpAndSettle();
    expect(container.read(selectedLanguageProvider), 'en');
    expect(find.text('Coming soon'), findsNWidgets(4));
  });

  for (final route in {
    '/profile-setup': ['Tell us about yourself', 'अपने बारे में बताएँ'],
    '/photo-capture': ['Your profile', 'आपकी प्रोफ़ाइल'],
    '/cataloging': ['Your profile', 'आपकी प्रोफ़ाइल'],
    '/pricing': ['Your profile', 'आपकी प्रोफ़ाइल'],
    '/b2b': ['Your profile', 'आपकी प्रोफ़ाइल'],
  }.entries) {
    for (final language in ['en', 'hi']) {
      testWidgets('${route.key} follows $language', (tester) async {
        // An unfinished artisan profile keeps the guard on /profile-setup.
        await start(tester, language, route.key,
            asRole: AccountRole.artisan,
            completeProfile: route.key != '/profile-setup');
        expect(
            find.text(route.value[language == 'en' ? 0 : 1]), findsOneWidget);
        expect(find.text(route.value[language == 'en' ? 1 : 0]), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

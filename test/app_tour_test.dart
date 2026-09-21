import 'dart:convert';

import 'package:craft_connect/app.dart';
import 'package:craft_connect/core/routing/app_router.dart';
import 'package:craft_connect/core/services/app_providers.dart';
import 'package:craft_connect/features/commerce/data/bidding_repository.dart';
import 'package:craft_connect/features/commerce/domain/commerce_engine.dart';
import 'package:craft_connect/features/commerce/presentation/app_tour.dart';
import 'package:craft_connect/shared/models/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

import 'test_session_helper.dart';

/// Keeps the bidding hub off the network while the tour test renders Home.
class EmptyBidding extends BiddingRepository {
  @override
  Future<void> refresh() async {}
}

/// Renders a workspace page with a fresh provider scope.
Future<ProviderContainer> openWorkspace(WidgetTester tester, String page,
    {AccountRole role = AccountRole.artisan}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(overrides: [
    biddingProvider(testAccount(role).id).overrideWith((ref) => EmptyBidding()),
    selectedLanguageProvider.overrideWith((ref) => 'en'),
    sessionProvider.overrideWith((ref) => signedInSession(role)),
  ]);
  final router = container.read(appRouterProvider);
  router.go('/workspace/$page');
  addTearDown(router.dispose);
  addTearDown(container.dispose);
  await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const AakarApp()));
  await tester.pump();
  return container;
}

Future<void> openHome(WidgetTester tester,
        {AccountRole role = AccountRole.artisan}) =>
    openWorkspace(tester, 'home', role: role);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the seen flag is per role and starts unset', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await AppTour.seen(buyer: true), isFalse);
    expect(await AppTour.seen(buyer: false), isFalse);

    await AppTour.markSeen(buyer: true);

    expect(await AppTour.seen(buyer: true), isTrue);
    // Recording one role must not silence the other role's first run.
    expect(await AppTour.seen(buyer: false), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_seen_buyer'), isTrue);
    expect(prefs.getBool('onboarding_seen_artisan'), isNull);
  });

  test('each role gets five stops that follow its own bottom bar', () {
    final buyer = AppTour.targets(buyer: true);
    final artisan = AppTour.targets(buyer: false);

    expect(buyer, hasLength(5));
    expect(artisan, hasLength(5));
    expect(buyer, ['home', 'discover', 'inquiries', 'bidding', 'orders']);
    expect(artisan, ['home', 'add_product', 'products', 'bidding', 'orders']);
    // The buyer has no Products destination and the artisan has no Discover one.
    expect(buyer, isNot(contains('products')));
    expect(artisan, isNot(contains('discover')));
  });

  test('every stop has bilingual copy so no bubble renders empty', () {
    final targets = {
      ...AppTour.targets(buyer: true),
      ...AppTour.targets(buyer: false),
    };
    for (final target in targets) {
      final copy = AppTour.copy[target];
      expect(copy, isNotNull, reason: '$target has no caption');
      expect(copy!.titleEn, isNotEmpty);
      expect(copy.titleHi, isNotEmpty);
      expect(copy.bodyEn, isNotEmpty);
      expect(copy.bodyHi, isNotEmpty);
    }
  });

  testWidgets('the first Home visit runs the tour and records it once',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'commerce_state_v1': jsonEncode(CommerceEngine.seed()),
    });

    await openHome(tester);
    // The tour starts after a short delay so Home can lay out first.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 400));

    // Step 1 of 5 is on screen, with the counter in the bubble title.
    expect(find.textContaining('1/5'), findsWidgets);
    expect(find.textContaining('Skip'), findsWidgets);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_seen_artisan'), isTrue);
    expect(tester.takeException(), isNull);

    // Dismiss so the overlay does not outlive the test.
    ShowcaseView.get().dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets('App guide replays the tour even though it was already seen',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'commerce_state_v1': jsonEncode(CommerceEngine.seed()),
      // A returning user: the first-run tour has already been shown.
      'onboarding_seen_artisan': true,
    });

    // Profile opens without a tour, and switching back to Home keeps the same
    // screen State, so the replay request has to be noticed on the tab change.
    await openWorkspace(tester, 'profile');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('1/5'), findsNothing);

    final guide = find.text('App guide');
    await tester.scrollUntilVisible(guide, 300, maxScrolls: 40);
    await tester.tap(guide);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('1/5'), findsWidgets);
    expect(tester.takeException(), isNull);

    // A replay must not consume the "seen" flag.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_seen_artisan'), isTrue);

    ShowcaseView.get().dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets('a returning user is not shown the tour again', (tester) async {
    SharedPreferences.setMockInitialValues({
      'commerce_state_v1': jsonEncode(CommerceEngine.seed()),
      'onboarding_seen_artisan': true,
    });

    await openHome(tester);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('1/5'), findsNothing);
    expect(tester.takeException(), isNull);
    // The flag is untouched.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_seen_artisan'), isTrue);
  });
}

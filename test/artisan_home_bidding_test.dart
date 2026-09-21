import 'dart:convert';

import 'package:craft_connect/app.dart';
import 'package:craft_connect/core/routing/app_router.dart';
import 'package:craft_connect/core/services/app_providers.dart';
import 'package:craft_connect/features/commerce/domain/commerce_engine.dart';
import 'package:craft_connect/shared/models/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_session_helper.dart';
import 'package:craft_connect/features/commerce/data/bidding_repository.dart';
import 'package:craft_connect/features/commerce/presentation/craft_widgets.dart';

/// The artisan home, bottom bar and Bulk Bidding surface.
class EmptyBidding extends BiddingRepository {
  @override
  Future<void> refresh() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> open(WidgetTester tester, String page,
      {AccountRole role = AccountRole.artisan, String language = 'en'}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'commerce_state_v1': jsonEncode(CommerceEngine.seed()),
      'selected_language': language,
      // A returning user: the first-run tour has already been seen, so these
      // tests exercise the screens rather than the coach marks.
      'onboarding_seen_artisan': true,
      'onboarding_seen_buyer': true,
    });
    final container = ProviderContainer(overrides: [
      biddingProvider(testAccount(role).id)
          .overrideWith((ref) => EmptyBidding()),
      selectedLanguageProvider.overrideWith((ref) => language),
      sessionProvider.overrideWith((ref) => signedInSession(role)),
    ]);
    final router = container.read(appRouterProvider);
    router.go('/workspace/$page');
    addTearDown(router.dispose);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const AakarApp()));
    await tester.pumpAndSettle();
  }

  List<String> labelsIn(WidgetTester tester) => tester
      .widgetList<NavigationDestination>(find.byType(NavigationDestination))
      .map((d) => d.label)
      .toList();

  testWidgets('the artisan bar carries Bidding and no longer Profile',
      (tester) async {
    await open(tester, 'home');
    expect(labelsIn(tester),
        ['Home', 'Products', 'Bidding', 'Inquiries', 'Orders']);
    expect(find.text('Profile'), findsNothing);
  });

  testWidgets('the app bar avatar opens the profile screen', (tester) async {
    await open(tester, 'home');
    await tester.tap(find.byTooltip('Your profile'));
    await tester.pumpAndSettle();
    expect(find.text('Your artisan profile'), findsOneWidget);
    expect(find.text('Ramesh Kumar'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign out is not offered from the home app bar', (tester) async {
    await open(tester, 'home');
    expect(find.byTooltip('Sign out'), findsNothing);
    expect(find.byIcon(Icons.logout_rounded), findsNothing);
  });

  testWidgets('home shows the greeting, four tiles and the bidding hub',
      (tester) async {
    await open(tester, 'home');
    expect(find.text('Bulk Bidding Hub'), findsOneWidget);
    expect(find.text('Live Sessions'), findsOneWidget);
    expect(find.text('Add product'), findsOneWidget);
    expect(find.text('Host Bidding'), findsOneWidget);
    expect(find.textContaining('Ends in'), findsNothing);
    // Both home actions stay one line tall: a wrapped label puffed the add
    // button up next to the shorter bidding button.
    final add = tester.getSize(find.ancestor(
        of: find.text('Add product'), matching: find.byType(CraftButton)));
    final host = tester.getSize(find.ancestor(
        of: find.text('Host Bidding'), matching: find.byType(CraftButton)));
    expect(add.height, host.height);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bidding starts empty with a working create entry',
      (tester) async {
    await open(tester, 'bidding');
    expect(find.text('Create new bidding'), findsOneWidget);
    expect(find.text('No sessions here yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bidding tab renders the hub in Hindi', (tester) async {
    await open(tester, 'bidding', language: 'hi');
    expect(find.text('बोली'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the buyer bar carries Inquiries and no longer Profile',
      (tester) async {
    await open(tester, 'home', role: AccountRole.buyer);
    expect(labelsIn(tester),
        ['Home', 'Discover', 'Inquiries', 'Bidding', 'Orders']);
    expect(find.text('Profile'), findsNothing);
    // Alerts left the bar for the app bar bell.
    expect(
        find.descendant(
            of: find.byType(NavigationBar), matching: find.text('Alerts')),
        findsNothing);
    expect(find.byTooltip('Alerts'), findsOneWidget);
  });

  testWidgets('the app bar bell opens the buyer alerts', (tester) async {
    await open(tester, 'home', role: AccountRole.buyer);
    await tester.tap(find.byTooltip('Alerts'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a buyer sees their own side of the bidding round',
      (tester) async {
    await open(tester, 'bidding', role: AccountRole.buyer);
    expect(find.text('No sessions here yet.'), findsOneWidget);
    expect(find.text('Create new bidding'), findsNothing);
    expect(find.text('Modify offer'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the buyer bidding view renders in Hindi', (tester) async {
    await open(tester, 'bidding', role: AccountRole.buyer, language: 'hi');
    expect(find.text('बोली'), findsWidgets);
    expect(find.text('अभी कोई सत्र नहीं है।'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

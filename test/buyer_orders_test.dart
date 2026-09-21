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

/// A buyer-owned order with one unpaid milestone, so the order detail renders
/// its payment button.
Record buyerOrderState() {
  final state = CommerceEngine.seed();
  (state['orders'] as List).add({
    'id': 'order-1',
    'inquiry_id': 'rfq-1',
    'product_id': 'basket',
    'product_title': 'Handmade Bamboo Basket',
    'buyer_id': 'buyer-test',
    'buyer_name': 'The Earth Store',
    'artisan_id': 'ramesh',
    'quantity': 500,
    'unit_price': 300,
    'total': 152000,
    'lead_days': 30,
    'status': 'confirmed',
    'production': 'not_started',
    'shipment': 'not_dispatched',
    'inspection': 'pending',
    'checkpoint': 'not_submitted',
    'inspection_hours': 48,
    'milestones': [
      {
        'id': 'm0',
        'trigger': 'advance',
        'percent': 30,
        'amount': 45600,
        'status': 'pending',
      },
    ],
    'events': [],
    'packaging_checks': [],
    'time': '2026-09-18T00:00:00.000Z',
  });
  return state;
}

Future<void> openBuyerPage(WidgetTester tester, String page) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    'commerce_state_v1': jsonEncode(buyerOrderState()),
    'commerce_role': 'buyer',
    // The first-run tour has been seen, so it does not overlay the screen.
    'onboarding_seen_buyer': true,
  });
  final container = ProviderContainer(overrides: [
    selectedLanguageProvider.overrideWith((ref) => 'en'),
    sessionProvider.overrideWith((ref) => signedInSession(AccountRole.buyer)),
  ]);
  final router = container.read(appRouterProvider);
  router.go('/workspace/$page');
  addTearDown(router.dispose);
  addTearDown(container.dispose);
  await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const AakarApp()));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a buyer order is listed once, not twice', (tester) async {
    await openBuyerPage(tester, 'orders');

    // The list used to draw its own inline card and then the shared card, so
    // every order appeared twice.
    expect(find.text('Handmade Bamboo Basket'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the payment button shows the rupee symbol once', (tester) async {
    await openBuyerPage(tester, 'order/order-1');

    // The payment block sits far down the order detail, so scroll to it.
    final pay = find.textContaining('Pay ');
    await tester.scrollUntilVisible(pay, 400, maxScrolls: 60);
    await tester.pumpAndSettle();

    final labels =
        tester.widgetList<Text>(pay).map((text) => text.data ?? '').toList();
    expect(labels, isNotEmpty, reason: 'the pay button should render');
    for (final label in labels) {
      expect('₹'.allMatches(label).length, 1,
          reason: 'doubled currency in "$label"');
    }
    expect(tester.takeException(), isNull);
  });
}

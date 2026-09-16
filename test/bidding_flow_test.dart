import 'package:craft_connect/core/services/app_providers.dart';
import 'package:craft_connect/features/commerce/data/bidding_repository.dart';
import 'package:craft_connect/features/commerce/data/commerce_repository.dart';
import 'package:craft_connect/features/commerce/domain/commerce_engine.dart';
import 'package:craft_connect/features/commerce/presentation/bidding_panel.dart';
import 'package:craft_connect/shared/models/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_session_helper.dart';

class TestBids extends BiddingRepository {
  Record? submitted;
  bool noMatches = false;
  String? actionName;
  Record? actionFields;
  final buyerRows = <Record>[
    {
      'id': 'one',
      'name': 'Earth Store',
      'type': 'Retailer',
      'reason': 'Requirement matches basket'
    }
  ];
  @override
  Future<void> refresh() async {}
  @override
  Future<Record> matches(String product, {String? sessionId}) async => {
        'buyers': noMatches ? [] : buyerRows,
        'available_stock': 250,
        'cost_floor': 220
      };
  @override
  Future<Record> save(Record data, {String? id}) async {
    submitted = data;
    final row = {
      'id': 'session',
      'revision': 1,
      'status': 'scheduled',
      'product': CommerceEngine.seed()['products'][0],
      ...data,
      'offers': [],
      'my_offer': null,
      'buyers': buyerRows,
      'offer_count': 0,
      'buyer_count': 1,
      'allocations': <String, int>{},
      'inquiries': []
    };
    adopt(row);
    return row;
  }

  @override
  Future<Record> act(Record session, String action,
      [Record fields = const {}]) async {
    actionName = action;
    actionFields = fields;
    final row = {
      ...session,
      ...fields,
      'status': action == 'select' ? 'selected' : session['status']
    };
    adopt(row);
    return row;
  }
}

void main() {
  Future<void> open(WidgetTester tester, TestBids bids,
      {AccountRole role = AccountRole.artisan}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final commerce = CommerceRepository();
    await commerce.load();
    commerce.role = role.name;
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith((ref) => signedInSession(role)),
      commerceProvider.overrideWith((ref) => commerce),
      biddingProvider(testAccount(role).id).overrideWith((ref) => bids),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    padding: EdgeInsets.all(16), child: BiddingPanel())))));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'product to preview to details to buyers to confirmation saves real form values',
      (tester) async {
    final bids = TestBids();
    await open(tester, bids);
    await tap(tester, 'Select a product');
    await tap(tester, 'Handmade Bamboo Basket');
    expect(find.text('Product preview'), findsOneWidget);
    await tap(tester, 'Put up for bidding');
    await tester.enterText(
        find.widgetWithText(TextField, 'Available quantity (pieces)'), '25');
    await tester.enterText(
        find.widgetWithText(TextField, 'Minimum unit price (₹)'), '240');
    await tap(tester, 'Find relevant buyers');
    expect(find.text('Earth Store'), findsOneWidget);
    await tap(tester, 'Continue');
    expect(find.text('Confirm & schedule'), findsWidgets);
    await tap(tester, 'Confirm & schedule');
    expect(bids.submitted?['quantity'], 25);
    expect(bids.submitted?['min_price'], 240);
    expect(bids.submitted?['starts_at'], endsWith('Z'));
    expect(find.text('Edit session'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'no fabricated buyers and scheduling stays disabled without matches',
      (tester) async {
    final bids = TestBids()..noMatches = true;
    await open(tester, bids);
    await tap(tester, 'Select a product');
    await tap(tester, 'Handmade Bamboo Basket');
    await tap(tester, 'Put up for bidding');
    await tap(tester, 'Find relevant buyers');
    expect(find.textContaining('No matches yet'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.ancestor(
        of: find.text('Continue'), matching: find.byType(FilledButton)));
    expect(button.onPressed, isNull);
    expect(bids.submitted, isNull);
  });
  Record closed() => {
        'id': 's',
        'revision': 3,
        'status': 'closed',
        'product': CommerceEngine.seed()['products'][0],
        'quantity': 25,
        'min_price': 220,
        'starts_at': '2030-01-01T10:00:00Z',
        'ends_at': '2030-01-01T11:00:00Z',
        'offer_count': 2,
        'buyer_count': 2,
        'my_offer': null,
        'buyers': [
          {'id': 'one', 'name': 'Earth Store'},
          {'id': 'two', 'name': 'Craft Shop'}
        ],
        'allocations': <String, int>{},
        'inquiries': [],
        'offers': [
          {
            'buyer_id': 'one',
            'name': 'Earth Store',
            'quantity': 20,
            'price': 260,
            'reliability': 'No rating yet',
            'fit': 'Matches basket',
            'note': ''
          },
          {
            'buyer_id': 'two',
            'name': 'Craft Shop',
            'quantity': 15,
            'price': 250,
            'reliability': 'No rating yet',
            'fit': 'Matches basket',
            'note': ''
          }
        ]
      };
  testWidgets(
      'closed offers can be split and handed to quotation without accepting an order',
      (tester) async {
    final bids = TestBids()..sessions = [closed()];
    await open(tester, bids);
    await tap(tester, 'Completed (1)');
    await tap(tester, 'View session');
    expect(find.text('Compare offers'), findsOneWidget);
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tap(tester, 'Split between buyers');
    final checks = find.byType(CheckboxListTile);
    await tester.ensureVisible(checks.at(0));
    await tester.tap(checks.at(0));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Allocate quantity (max 20)'), '10');
    await tester.ensureVisible(checks.at(1));
    await tester.tap(checks.at(1));
    await tester.pumpAndSettle();
    await tap(tester, 'Confirm allocation');
    expect(bids.actionName, 'select');
    expect(bids.actionFields?['allocations'], {'one': 10, 'two': 15});
    expect(find.text('Proceed to quotation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('buyer sees own sealed offer and no artisan controls',
      (tester) async {
    final row = closed()
      ..['status'] = 'live'
      ..['offers'] = []
      ..['my_offer'] = {'quantity': 10, 'price': 245};
    final bids = TestBids()..sessions = [row];
    await open(tester, bids, role: AccountRole.buyer);
    await tap(tester, 'Live (1)');
    await tap(tester, 'View session');
    expect(find.text('Your sealed offer'), findsOneWidget);
    expect(find.text('Modify offer'), findsOneWidget);
    expect(find.text('Compare offers'), findsNothing);
    expect(find.text('Edit session'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

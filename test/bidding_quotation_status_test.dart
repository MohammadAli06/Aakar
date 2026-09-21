import 'package:craft_connect/features/commerce/data/commerce_repository.dart';
import 'package:craft_connect/features/commerce/presentation/inquiry_workspace.dart';
import 'package:craft_connect/shared/models/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_session_helper.dart';

Future<CommerceRepository> openRepository(WidgetTester tester) async {
  late CommerceRepository repository;
  await tester.runAsync(() async {
    repository = CommerceRepository();
    while (!repository.ready) {
      await Future<void>.delayed(Duration.zero);
    }
    await repository.applyAccount(testAccount(AccountRole.buyer));
  });
  return repository;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Buyer view shows Review quotation instead of Waiting for capacity when quote exists',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await openRepository(tester);
    addTearDown(repo.dispose);

    // Inquiry with a proposed quote, even if capacity_status was pending or confirmed
    final inq = <String, dynamic>{
      'id': 'bid-session-buyer',
      'bidding_session_id': 'session-123',
      'buyer_id': repo.actor,
      'artisan_id': 'artisan-123',
      'product_title': 'Channapatna Wooden Toys',
      'quantity': 20,
      'lead_days': 15,
      'location': 'Bangalore',
      'status': 'sent',
      'capacity_status': 'pending',
      'messages': <dynamic>[],
      'quotes': <dynamic>[
        {
          'id': 'quote-1',
          'unit_price': 150.0,
          'quantity': 20,
          'lead_days': 15,
          'author': 'artisan',
          'status': 'proposed'
        }
      ],
      'buyer_language': 'en',
      'artisan_language': 'en',
    };

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: InquiryWorkspace(
                inquiry: inq,
                repository: repo,
                initialTab: 0,
                request: const [Text('REQUEST TAB')],
                quotation: const [Text('QUOTATION TAB')]))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Must NOT say "Waiting for the artisan's capacity response"
    expect(
        find.text('Waiting for the artisan’s capacity response'), findsNothing);
    // Must say "Review the latest quotation and agree the terms"
    expect(find.text('Review the latest quotation and agree the terms'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('importBiddingInquiry initializes capacity_status to confirmed',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repo = CommerceRepository();
    while (!repo.ready) {
      await Future<void>.delayed(Duration.zero);
    }
    await repo.applyAccount(testAccount(AccountRole.buyer));

    final product = {
      'id': 'prod-1',
      'title': 'Clay Pot',
      'price': 200,
      'moq': 5,
      'stock': 50,
      'capacity': 100,
      'lead_days': 10,
      'artisan_id': 'art-1',
      'cost_floor': 100,
    };

    final rawInquiry = {
      'id': 'bid-test-1',
      'bidding_session_id': 'sess-1',
      'product_id': 'prod-1',
      'artisan_id': 'art-1',
      'buyer_id': repo.actor,
      'buyer_name': 'Test Buyer',
      'quantity': 25,
      'budget': 180,
      'lead_days': 12,
      'quotes': [],
      'capacity_status': 'pending',
    };

    await repo.importBiddingInquiry(rawInquiry, product);

    final saved = repo.lookup('inquiries', 'bid-test-1');
    expect(saved, isNotNull);
    expect(saved!['capacity_status'], 'confirmed');
    expect(saved['confirmed_quantity'], 25);
    expect(saved['offered_lead_days'], 12);

    repo.dispose();
  });
}

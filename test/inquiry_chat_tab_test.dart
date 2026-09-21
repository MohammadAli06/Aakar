import 'package:craft_connect/features/commerce/data/commerce_repository.dart';
import 'package:craft_connect/features/commerce/presentation/inquiry_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The thread a message notification links to.
Map<String, dynamic> inquiry() => <String, dynamic>{
      'id': 'rfq-1',
      'buyer_id': 'buyer-1',
      'artisan_id': 'ramesh',
      'product_title': 'Handmade Bamboo Basket',
      'quantity': 50,
      'lead_days': 20,
      'location': 'Mumbai',
      'status': 'sent',
      'capacity_status': 'pending',
      'messages': <dynamic>[],
      'quotes': <dynamic>[],
      'buyer_language': 'en',
      'artisan_language': 'en',
    };

/// The repository loads through real async work, so it is built outside the
/// widget test's fake clock.
Future<CommerceRepository> openRepository(WidgetTester tester) async {
  late CommerceRepository repository;
  await tester.runAsync(() async {
    repository = CommerceRepository();
    while (!repository.ready) {
      await Future<void>.delayed(Duration.zero);
    }
    await repository.switchRole('buyer');
  });
  return repository;
}

Future<void> openWorkspace(WidgetTester tester, CommerceRepository repo,
    {required int initialTab}) async {
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: InquiryWorkspace(
              inquiry: inquiry(),
              repository: repo,
              initialTab: initialTab,
              request: const [Text('REQUEST TAB')],
              quotation: const [Text('QUOTATION TAB')]))));
  // The workspace polls on a periodic timer, so the tree never settles; pump
  // explicit frames rather than waiting for quiescence.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a message link opens the conversation, not the request',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await openRepository(tester);
    addTearDown(repo.dispose);

    await openWorkspace(tester, repo, initialTab: 1);

    // The chat composer is on screen and the request tab is not built.
    expect(find.textContaining('Message'), findsWidgets);
    expect(find.text('REQUEST TAB'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a link the request tab is still the default',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await openRepository(tester);
    addTearDown(repo.dispose);

    await openWorkspace(tester, repo, initialTab: 0);

    expect(find.text('REQUEST TAB'), findsOneWidget);
    expect(find.textContaining('Message'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

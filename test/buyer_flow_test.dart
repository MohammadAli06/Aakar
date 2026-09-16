import 'package:craft_connect/features/commerce/domain/commerce_engine.dart';
import 'package:craft_connect/features/commerce/presentation/buyer_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Record order() => {
        'id': 'past-order',
        'product_id': 'basket',
        'product_title': 'Bamboo basket',
        'artisan_id': 'ramesh',
        'buyer_id': 'buyer',
        'status': 'completed',
        'quantity': 100,
        'unit_price': 200,
        'lead_days': 20,
        'location': 'Mumbai',
        'customization': 'Natural finish'
      };
  Future<void> open(WidgetTester tester, Widget child) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16), child: child)))));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'review requires stars and submits editable feedback with selected tags',
      (tester) async {
    Record? sent;
    await open(
        tester,
        BuyerReviewPanel(
            order: order(),
            submit: (r) async {
              sent = r;
              return true;
            }));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await tester.tap(find.byTooltip('4 stars'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField).first, 'Carefully made and packed');
    await tap(tester, 'Packaging');
    await tap(tester, 'Submit review');
    expect(sent?['rating'], 4);
    expect(sent?['text'], 'Carefully made and packed');
    expect(sent?['tags'], ['Packaging']);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'repeat purchase uses current price and creates fresh inquiry after confirmation',
      (tester) async {
    Record? sent;
    final product = records(CommerceEngine.seed()['products']).first
      ..['price'] = 350;
    final original = order();
    await open(
        tester,
        BuyerReorderPanel(
            order: original,
            products: [product],
            submit: (r) async {
              sent = r;
              return true;
            }));
    await tap(tester, 'Handmade Bamboo Basket');
    await tester.enterText(find.widgetWithText(TextField, 'Quantity'), '60');
    await tap(tester, 'Review new request');
    expect(sent, isNull);
    expect(find.text('₹350'), findsOneWidget);
    await tap(tester, 'Confirm & send inquiry');
    expect(sent?['quantity'], 60);
    expect(sent?['budget'], 350);
    expect(sent?['source_order_id'], 'past-order');
    expect(sent!.containsKey('quote_id'), false);
    expect(sent!.containsKey('milestones'), false);
    expect(original['quantity'], 100);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'repeat purchase enforces current MOQ and handles unavailable catalogue',
      (tester) async {
    final product = records(CommerceEngine.seed()['products']).first;
    await open(
        tester,
        BuyerReorderPanel(
            order: order(), products: [product], submit: (_) async => true));
    await tap(tester, 'Handmade Bamboo Basket');
    await tester.enterText(find.widgetWithText(TextField, 'Quantity'), '1');
    await tap(tester, 'Review new request');
    expect(find.textContaining('Enter valid quantity'), findsOneWidget);
    expect(find.text('Confirm & send inquiry'), findsNothing);
    await open(
        tester,
        BuyerReorderPanel(
            key: const ValueKey('empty'),
            order: order(),
            products: [],
            submit: (_) async => true));
    expect(find.text('No products available'), findsOneWidget);
  });
  test('review rules reject another buyer and edits replace one order review',
      () {
    var state = CommerceEngine.seed();
    state['orders'] = [order()];
    final input = {
      'id': 'past-order',
      'rating': 5,
      'text': 'Good',
      'tags': ['Product quality']
    };
    expect(
        () => CommerceEngine.apply(
            state, 'review_order', input, 'buyer', 'other'),
        throwsA(isA<WorkflowError>()));
    expect(
        () => CommerceEngine.apply(
            state, 'review_order', {...input, 'rating': 2.5}, 'buyer', 'buyer'),
        throwsA(isA<WorkflowError>()));
    state =
        CommerceEngine.apply(state, 'review_order', input, 'buyer', 'buyer');
    state = CommerceEngine.apply(
        state, 'review_order', {...input, 'rating': 4}, 'buyer', 'buyer');
    expect(state['orders'][0]['review']['rating'], 4);
    state['orders'][0]['status'] = 'in_production';
    expect(
        () => CommerceEngine.apply(
            state, 'review_order', input, 'buyer', 'buyer'),
        throwsA(isA<WorkflowError>()));
  });
}

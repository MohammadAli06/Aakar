import 'dart:async';

import 'package:craft_connect/core/services/app_providers.dart';
import 'package:craft_connect/core/services/studio_service.dart';
import 'package:craft_connect/features/commerce/data/commerce_repository.dart';
import 'package:craft_connect/features/commerce/domain/photo_enhancement.dart';
import 'package:craft_connect/features/commerce/presentation/craft_widgets.dart';
import 'package:craft_connect/features/commerce/presentation/product_studio_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeStudio extends StudioService {
  final calls = <PhotoPrep>[];
  String? analyzed;
  bool fail = false;
  Completer<PreparedStudioPhoto>? pending;

  @override
  Future<PreparedStudioPhoto> prepare(String source, PhotoPrep mode,
      {bool catalogPlainBackground = true}) async {
    calls.add(mode);
    if (fail) throw Exception('OpenAI unavailable');
    if (pending != null) return pending!.future;
    return PreparedStudioPhoto(
        '/enhanced.jpg',
        source,
        mode == PhotoPrep.naturalSetting ? 'deterministic' : 'openai',
        mode != PhotoPrep.naturalSetting);
  }

  @override
  Future<Map<String, dynamic>> analyze(
      String original, String notes, String language) async {
    analyzed = original;
    if (fail) throw Exception('OpenAI unavailable');
    return {
      'fields': {'title': 'AI title', 'material': 'Bamboo', 'colour': 'Brown'},
      'evidence': {
        'material': {'source': 'artisan', 'reason': 'made from bamboo'}
      },
      'questions': ['What are its dimensions?']
    };
  }
}

void main() {
  late CommerceRepository repository;
  late FakeStudio service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = CommerceRepository();
    while (!repository.ready) {
      await Future<void>.delayed(Duration.zero);
    }
    final product = (repository.state['products'] as List).first as Map;
    product['original_image'] = '/original.jpg';
    product['image'] = '/previous.jpg';
    product['title'] = 'Artisan title';
    product['material'] = '';
    product['transcript'] = 'made from bamboo';
    service = FakeStudio();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          commerceProvider.overrideWith((ref) => repository),
          studioServiceProvider.overrideWithValue(service),
          selectedLanguageProvider.overrideWith((ref) => 'en'),
        ],
        child:
            const MaterialApp(home: ProductStudioScreen(productId: 'basket'))));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.scrollUntilVisible(finder.hitTestable(), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('OpenAI result requires photo review and modes stay separate',
      (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Previous step'));
    await tester.pumpAndSettle();
    await tap(tester, 'Plain white background');
    final review = find.byKey(const ValueKey('photo-fidelity-review'));
    await tester.scrollUntilVisible(review, 250,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<CheckboxListTile>(review).value, false);
    final next = find.widgetWithText(CraftButton, 'Review catalog details');
    await tester.scrollUntilVisible(next, 250,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<CraftButton>(next).onPressed, isNull);
    await tester.scrollUntilVisible(review, -250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(review);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(next, 250,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<CraftButton>(next).onPressed, isNotNull);
    await tester.scrollUntilVisible(find.text('Keep my natural setting'), -300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Keep my natural setting'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('photo-fidelity-review')), findsNothing);
    expect(
        service.calls, [PhotoPrep.plainBackground, PhotoPrep.naturalSetting]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Original photo suggestions preserve existing artisan wording',
      (tester) async {
    await open(tester);
    await tap(tester, 'Suggest missing details from photo');
    expect(service.analyzed, '/original.jpg');
    final title = find.widgetWithText(TextFormField, 'Product title');
    expect(
        tester.widget<TextFormField>(title).controller!.text, 'Artisan title');
    final material = find.widgetWithText(TextFormField, 'Material');
    await tester.scrollUntilVisible(material, 350,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<TextFormField>(material).controller!.text, 'Bamboo');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pending OpenAI request blocks duplicate changes until resolved',
      (tester) async {
    service.pending = Completer<PreparedStudioPhoto>();
    await open(tester);
    await tester.tap(find.byTooltip('Previous step'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Plain white background'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Plain white background'));
    await tester.pump();
    expect(service.calls, [PhotoPrep.plainBackground]);
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Previous step'))
            .onPressed,
        isNull);
    expect(find.byWidgetPredicate((w) => w is AbsorbPointer && w.absorbing),
        findsWidgets);
    service.pending!.complete(const PreparedStudioPhoto(
        '/enhanced.jpg', '/original.jpg', 'openai', true));
    await tester.pumpAndSettle();
    expect(service.calls, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Catalog failure still opens manual entry', (tester) async {
    service.fail = true;
    await open(tester);
    await tap(tester, 'Suggest missing details from photo');
    expect(find.text('Review catalog & fill gaps'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed B2B request leaves original and exposes natural switch',
      (tester) async {
    service.fail = true;
    await open(tester);
    await tester.tap(find.byTooltip('Previous step'));
    await tester.pumpAndSettle();
    await tap(tester, 'B2B catalogue frame');
    final toggle = find.text('White background for B2B frame');
    await tester.scrollUntilVisible(toggle, 250,
        scrollable: find.byType(Scrollable).first);
    expect(toggle, findsOneWidget);
    final photos = tester
        .widgetList<CraftImage>(find.byType(CraftImage))
        .map((p) => p.source);
    expect(photos, isNot(contains('/enhanced.jpg')));
    expect(tester.takeException(), isNull);
  });
}

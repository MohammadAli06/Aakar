import 'dart:async';

import 'package:craft_connect/core/services/app_providers.dart';
import 'package:craft_connect/core/services/studio_service.dart';
import 'package:craft_connect/features/commerce/data/commerce_repository.dart';
import 'package:craft_connect/features/commerce/domain/photo_enhancement.dart';
import 'package:craft_connect/features/commerce/presentation/craft_widgets.dart';
import 'package:craft_connect/features/commerce/presentation/product_studio_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeStudio extends StudioService {
  String photoProvider = 'openai';
  final calls = <PhotoPrep>[];
  String? analyzed;
  bool fail = false;
  Completer<PreparedStudioPhoto>? pending;
  bool lowScore = false;
  int translationChecks = 0;

  @override
  Future<PreparedStudioPhoto> prepare(String source, PhotoPrep mode,
      {bool catalogPlainBackground = true}) async {
    calls.add(mode);
    if (fail) throw Exception('OpenAI unavailable');
    if (pending != null) return pending!.future;
    return PreparedStudioPhoto(
        '/enhanced.jpg',
        source,
        mode == PhotoPrep.naturalSetting ? 'deterministic' : photoProvider,
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

  @override
  Future<Map<String, dynamic>> checkTranslation(
      String description, String descriptionHi,
      {String sourceLang = 'hi'}) async {
    translationChecks++;
    if (fail) throw Exception('Translation unavailable');
    return {
      'roundtrip': description,
      'roundtrip_score': lowScore ? 0.4 : 0.9,
      'confidence_label': lowScore ? 'review' : 'checked',
      'source_lang': sourceLang,
      'pivot_lang': 'en',
      'method': 'openai',
      'is_fallback': false,
    };
  }
}

void main() {
  late CommerceRepository repository;
  late FakeStudio service;
  late Map product;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = CommerceRepository();
    while (!repository.ready) {
      await Future<void>.delayed(Duration.zero);
    }
    product = (repository.state['products'] as List).first as Map;
    product['original_image'] = '/original.jpg';
    product['image'] = '/previous.jpg';
    product['title'] = 'Artisan title';
    product['material'] = '';
    product['usage'] = '';
    product['transcript'] = 'made from bamboo';
    service = FakeStudio();
  });

  Future<void> open(WidgetTester tester, {String locale = 'en'}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          commerceProvider.overrideWith((ref) => repository),
          studioServiceProvider.overrideWithValue(service),
          selectedLanguageProvider.overrideWith((ref) => locale),
        ],
        child: MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('hi')],
            home: const ProductStudioScreen(productId: 'basket'))));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.scrollUntilVisible(finder.hitTestable(), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> nextFromPhoto(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Previous step'));
    await tester.pumpAndSettle();
    await tap(tester, 'Next');
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
    final next = find.widgetWithText(CraftButton, 'Next');
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

  testWidgets('Cloudinary result also requires explicit photo review',
      (tester) async {
    service.photoProvider = 'cloudinary';
    await open(tester);
    await tester.tap(find.byTooltip('Previous step'));
    await tester.pumpAndSettle();
    await tap(tester, 'Plain white background');
    final review = find.byKey(const ValueKey('photo-fidelity-review'));
    await tester.scrollUntilVisible(review, 250,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<CheckboxListTile>(review).value, false);
    final next = find.widgetWithText(CraftButton, 'Next');
    await tester.scrollUntilVisible(next, 250,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<CraftButton>(next).onPressed, isNull);
  });

  testWidgets('Original photo suggestions preserve existing artisan wording',
      (tester) async {
    await open(tester);
    expect(find.text('Suggest missing details from photo'), findsNothing);
    await nextFromPhoto(tester);
    expect(service.analyzed, '/original.jpg');
    expect(find.text('Fill missing details'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Product title'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Material'), findsNothing);
    await tap(tester, 'Review catalog');
    expect(find.text('Review catalog details'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Product title'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Material'), findsOneWidget);
    expect(find.text('Listen to my catalog'), findsNothing);
    await tap(tester, 'Continue to Listen & Verify');
    expect(find.text('Artisan title'), findsOneWidget);
    expect(find.text('Bamboo'), findsOneWidget);
    await tap(tester, 'Correct details / voice edit');
    final title = find.widgetWithText(TextFormField, 'Product title');
    expect(
        tester.widget<TextFormField>(title).controller!.text, 'Artisan title');
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

  testWidgets(
      'Missing-only form preserves zero and false and review corrections',
      (tester) async {
    product['stock'] = 0;
    product['customizable'] = false;
    await open(tester);
    await nextFromPhoto(tester);
    expect(find.widgetWithText(TextFormField, 'Current available stock'),
        findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Usage'), 'Storage');
    await tap(tester, 'Review catalog');
    final title = find.widgetWithText(TextFormField, 'Product title');
    await tester.enterText(title, 'Corrected basket');
    await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, 'Current available stock'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'Current available stock'))
            .controller!
            .text,
        '0');
    await tap(tester, 'Continue to Listen & Verify');
    expect(find.text('Corrected basket'), findsOneWidget);
    expect(find.text('Storage'), findsOneWidget);
    final pricing = find.widgetWithText(CraftButton, 'Continue to pricing');
    await tester.scrollUntilVisible(pricing, 250,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<CraftButton>(pricing).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Leaving full review retains answers without opening verification',
      (tester) async {
    await open(tester);
    await nextFromPhoto(tester);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Usage'), 'Storage');
    await tap(tester, 'Review catalog');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Listen to my catalog'), findsNothing);
    await tap(tester, 'Next');
    if (find.text('Fill missing details').evaluate().isNotEmpty) {
      expect(find.widgetWithText(TextFormField, 'Usage'), findsNothing);
      await tap(tester, 'Review catalog');
    }
    expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Usage'))
            .controller!
            .text,
        'Storage');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Catalog failure still opens manual entry', (tester) async {
    service.fail = true;
    await open(tester);
    await nextFromPhoto(tester);
    expect(find.text('Fill missing details'), findsOneWidget);
    expect(find.textContaining('Go back to retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed B2B request leaves original and exposes natural switch',
      (tester) async {
    service.fail = true;
    await open(tester);
    await tester.tap(find.byTooltip('Previous step'));
    await tester.pumpAndSettle();
    await tap(tester, 'B2B catalogue frame');
    expect(
        find.byKey(const ValueKey('photo-preparation-error')), findsOneWidget);
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

  testWidgets('Listen & Verify shows a checked translation chip',
      (tester) async {
    product['description_hi'] = 'हाथ से बुनी बांस की टोकरी।';
    await open(tester);
    expect(service.translationChecks, greaterThan(0));
    expect(find.text('Translation checked ✓'), findsOneWidget);
    expect(find.text('Please listen carefully'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Low round-trip score asks the artisan to listen carefully',
      (tester) async {
    product['description_hi'] = 'हाथ से बुनी बांस की टोकरी।';
    service.lowScore = true;
    await open(tester);
    expect(find.text('Please listen carefully'), findsOneWidget);
    expect(find.text('Translation checked ✓'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unavailable check shows no chip and leaves no stored score',
      (tester) async {
    product['description_hi'] = 'हाथ से बुनी बांस की टोकरी।';
    service.fail = true;
    await open(tester);
    expect(find.text('Translation checked ✓'), findsNothing);
    expect(find.text('Please listen carefully'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English reader never sees the Hindi title or description',
      (tester) async {
    product['title_hi'] = 'हाथ से बुनी बांस की टोकरी';
    product['description_hi'] = 'यह टोकरी हाथ से बुनी गई है।';
    await open(tester);
    expect(find.text('Artisan title'), findsOneWidget);
    expect(find.text('Hindi product title'), findsNothing);
    expect(find.text('Hindi description'), findsNothing);
    expect(find.textContaining('हाथ से बुनी'), findsNothing);
    expect(find.textContaining('यह टोकरी'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hindi reader is shown the Hindi title and description',
      (tester) async {
    product['title_hi'] = 'हाथ से बुनी बांस की टोकरी';
    product['description_hi'] = 'यह टोकरी हाथ से बुनी गई है।';
    await open(tester, locale: 'hi');
    expect(find.text('हाथ से बुनी बांस की टोकरी'), findsOneWidget);
    expect(find.text('यह टोकरी हाथ से बुनी गई है।'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English reader is not asked to fill in Hindi wording',
      (tester) async {
    await open(tester);
    await nextFromPhoto(tester);
    expect(find.text('Fill missing details'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Hindi product title'),
        findsNothing);
    expect(
        find.widgetWithText(TextFormField, 'Hindi description'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

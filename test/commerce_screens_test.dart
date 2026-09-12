import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:craft_connect/app.dart';
import 'package:craft_connect/core/routing/app_router.dart';
import 'package:craft_connect/core/services/app_providers.dart';
import 'package:craft_connect/features/commerce/domain/commerce_engine.dart';
import 'package:craft_connect/shared/models/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_session_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Poppins');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/Poppins-$weight.ttf'));
    }
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  Record fixture() {
    var s = CommerceEngine.seed();
    s = CommerceEngine.apply(
        s,
        'requirement',
        {
          'product': 'Bamboo basket',
          'quantity': 500,
          'lead_days': 30,
          'location': 'Mumbai',
          'confirmed': true
        },
        'buyer',
        'buyer');
    s = CommerceEngine.apply(
        s,
        'inquiry',
        {
          'product_id': 'basket',
          'quantity': 500,
          'lead_days': 30,
          'location': 'Mumbai',
          'sample_required': true
        },
        'buyer',
        'buyer');
    final r = (s['inquiries'] as List).first as Map;
    r['id'] = 'test-rfq';
    r['sample_required'] = false;
    s = CommerceEngine.apply(
        s,
        'capacity',
        {
          'id': 'test-rfq',
          'status': 'confirmed',
          'quantity': 500,
          'lead_days': 30
        },
        'artisan',
        'ramesh');
    s = CommerceEngine.apply(
        s,
        'quote',
        {
          'id': 'test-rfq',
          'quantity': 500,
          'unit_price': 300,
          'lead_days': 30,
          'inspection_hours': 48,
          'location': 'Mumbai',
          'delivery_terms': 'Artisan packs and books delivery',
          'milestones': [
            {'trigger': 'advance', 'percent': 30},
            {'trigger': 'dispatch', 'percent': 50},
            {'trigger': 'delivery', 'percent': 20}
          ]
        },
        'artisan',
        'ramesh');
    final quote = records(records(s['inquiries']).first['quotes']).last;
    s = CommerceEngine.apply(s, 'accept',
        {'id': 'test-rfq', 'quote_id': quote['id']}, 'buyer', 'buyer');
    (s['orders'] as List).first['id'] = 'test-order';
    return s;
  }

  for (final language in ['en', 'hi']) {
    for (final page in [
      'home',
      'discover',
      'artisans',
      'product/basket',
      'compare/basket,assam-basket',
      'inquiries',
      'inquiry/test-rfq',
      'order/test-order',
      'create',
      'profile',
      'notifications',
      'channels/basket',
      'help'
    ]) {
      testWidgets('Buyer $page renders at phone width in $language',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({
          'commerce_state_v1': jsonEncode(fixture()),
          'commerce_role': 'buyer'
        });
        final container = ProviderContainer(overrides: [
          selectedLanguageProvider.overrideWith((ref) => language),
          // The workspace is behind the auth guard now, so run as a signed-in
          // buyer account (role is fixed at signup).
          sessionProvider.overrideWith(
              (ref) => signedInSession(AccountRole.buyer)),
        ]);
        final router = container.read(appRouterProvider);
        router.go('/workspace/$page');
        addTearDown(router.dispose);
        addTearDown(container.dispose);
        final boundary = GlobalKey();
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(key: boundary, child: const AakarApp())));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (language == 'en' &&
            ['home', 'discover', 'product/basket'].contains(page)) {
          await tester.runAsync(() async {
            final image = await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final file =
                File('.dart_tool/previews/${page.replaceAll('/', '-')}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        final scrolls = find.byType(Scrollable);
        if (scrolls.evaluate().isNotEmpty &&
            page != 'compare/basket,assam-basket') {
          await tester.drag(scrolls.first, const Offset(0, -500));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}

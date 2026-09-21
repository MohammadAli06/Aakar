import 'package:craft_connect/core/services/app_providers.dart';
import 'package:craft_connect/features/profile/profile_setup_screen.dart';
import 'package:craft_connect/shared/models/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_session_helper.dart';

/// Opens the buyer "Create profile" form tall enough that every field is laid
/// out, so the state and city fields can be driven directly.
Future<void> openProfile(WidgetTester tester) async {
  tester.view.physicalSize = const Size(500, 1700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    sessionProvider.overrideWith((ref) => signedInSession(AccountRole.buyer)),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ProfileSetupScreen())));
  await tester.pumpAndSettle();
}

Finder get stateField => find.byKey(const Key('profile-state'));
Finder get cityField => find.byKey(const Key('profile-city'));

String cityText(WidgetTester tester) => tester
    .widget<TextFormField>(
        find.descendant(of: cityField, matching: find.byType(TextFormField)))
    .controller!
    .text;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the state field suggests states and union territories as typed',
      (tester) async {
    await openProfile(tester);

    await tester.enterText(stateField, 'Lak');
    await tester.pumpAndSettle();
    expect(find.text('Lakshadweep'), findsWidgets);
    expect(find.text('Maharashtra'), findsNothing);

    // Union territories are offered too, not only the 28 states.
    await tester.enterText(stateField, 'Pud');
    await tester.pumpAndSettle();
    expect(find.text('Puducherry'), findsWidgets);

    // Picking a suggestion fills the field.
    await tester.tap(find.text('Puducherry').last);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.descendant(
                of: stateField, matching: find.byType(TextFormField)))
            .controller!
            .text,
        'Puducherry');
  });

  testWidgets('city suggestions follow the chosen state', (tester) async {
    await openProfile(tester);

    // The test buyer arrives with Maharashtra already on the profile.
    await tester.enterText(cityField, 'Mum');
    await tester.pumpAndSettle();
    expect(find.text('Mumbai'), findsWidgets);
    expect(find.text('Ahmedabad'), findsNothing);

    await tester.tap(find.text('Mumbai').last);
    await tester.pumpAndSettle();
    expect(cityText(tester), 'Mumbai');
  });

  testWidgets('a state change drops a city that no longer belongs to it',
      (tester) async {
    await openProfile(tester);

    await tester.enterText(cityField, 'Mumbai');
    await tester.pumpAndSettle();
    expect(cityText(tester), 'Mumbai');

    await tester.enterText(stateField, 'Gujarat');
    await tester.pumpAndSettle();
    expect(cityText(tester), isEmpty);

    await tester.enterText(cityField, 'Ahm');
    await tester.pumpAndSettle();
    expect(find.text('Ahmedabad'), findsWidgets);
  });
}

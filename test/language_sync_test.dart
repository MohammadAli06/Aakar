import 'package:craft_connect/core/services/account_service.dart';
import 'package:craft_connect/core/services/app_providers.dart';
import 'package:craft_connect/core/services/session_controller.dart';
import 'package:craft_connect/features/onboarding/language_selection_screen.dart';
import 'package:craft_connect/shared/models/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_session_helper.dart';

/// Records the language the screen saves and returns the updated account, so
/// the chat bridge on the server would see the new preference.
class FakeAccounts extends AccountService {
  FakeAccounts(this.account);

  Account account;
  final List<String> updates = [];

  Account _withLanguage(String? language) => Account(
        id: account.id,
        firebaseUid: account.firebaseUid,
        role: account.role,
        languagePref: language ?? account.languagePref,
        name: account.name,
        phone: account.phone,
        email: account.email,
        isNew: account.isNew,
        profile: account.profile,
      );

  @override
  Future<Account?> me() async => account;

  @override
  Future<Account> updateArtisanProfile(
      {String? name,
      String? languagePref,
      String? state,
      String? district,
      String? craftCategory}) async {
    updates.add('artisan:$languagePref');
    account = _withLanguage(languagePref);
    return account;
  }

  @override
  Future<Account> updateBuyerProfile(
      {String? workEmail,
      String? website,
      String? name,
      String? languagePref,
      String? businessName,
      String? businessType,
      String? industry,
      String? state,
      String? district}) async {
    updates.add('buyer:$languagePref');
    account = _withLanguage(languagePref);
    return account;
  }
}

Future<void> openLanguageScreen(
    WidgetTester tester, FakeAccounts accounts) async {
  final container = ProviderContainer(overrides: [
    accountServiceProvider.overrideWith((ref) => accounts),
    sessionProvider.overrideWith((ref) =>
        SessionController.signedIn(accounts.account, accounts: accounts)),
    selectedLanguageProvider.overrideWith((ref) => 'hi'),
  ]);
  addTearDown(container.dispose);
  final router = GoRouter(initialLocation: '/language', routes: [
    GoRoute(
        path: '/language', builder: (_, __) => const LanguageSelectionScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const Scaffold()),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container, child: MaterialApp.router(routerConfig: router)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('English').first);
  await tester.pumpAndSettle();
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an artisan language change is saved on the account',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final accounts = FakeAccounts(testAccount(AccountRole.artisan));

    await openLanguageScreen(tester, accounts);

    expect(accounts.updates, ['artisan:en']);
    expect(accounts.account.languagePref, 'en');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a buyer language change is saved on the account',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final accounts = FakeAccounts(testAccount(AccountRole.buyer));

    await openLanguageScreen(tester, accounts);

    expect(accounts.updates, ['buyer:en']);
    expect(accounts.account.languagePref, 'en');
    expect(tester.takeException(), isNull);
  });
}

import 'dart:async';
import 'package:craft_connect/app.dart';
import 'package:craft_connect/core/routing/app_router.dart';
import 'package:craft_connect/core/services/account_service.dart';
import 'package:craft_connect/core/services/api_client.dart';
import 'package:craft_connect/core/services/app_providers.dart';
import 'package:craft_connect/core/services/session_controller.dart';
import 'package:craft_connect/core/theme/role_theme.dart';
import 'package:craft_connect/shared/models/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_session_helper.dart';

class Accounts extends AccountService {
  Account value = testAccount(AccountRole.buyer);
  Map<String, dynamic> review = {'status': 'not_started', 'evidence': {}};
  bool fail = false;
  int submissions = 0;
  @override
  Future<Account?> me() async {
    if (fail) throw ApiError(503, 'Unavailable', null);
    return value;
  }

  @override
  Future<Map<String, dynamic>> verification() async {
    if (fail) throw ApiError(503, 'Unavailable', null);
    return review;
  }

  @override
  Future<void> submitVerification() async {
    submissions++;
    if (fail) throw ApiError(503, 'Unavailable', null);
    review = {...review, 'status': 'pending'};
  }
}

void main() {
  test('Backend outage is not treated as an unregistered identity', () async {
    final api = Accounts()..fail = true;
    final session =
        SessionController(accounts: api, identityChanges: Stream.value(true));
    await session.ready;
    expect(session.status, SessionStatus.unavailable);
    api.fail = false;
    await session.resolveIdentity();
    expect(session.status, SessionStatus.signedIn);
    session.dispose();
  });

  test('Late account response cannot restore a signed-out identity', () async {
    final response = Completer<Account?>();
    final identities = StreamController<bool>();
    final session = SessionController(
        accounts: DelayedAccounts(response.future),
        identityChanges: identities.stream);
    identities.add(true);
    await Future<void>.delayed(Duration.zero);
    identities.add(false);
    await Future<void>.delayed(Duration.zero);
    response.complete(testAccount(AccountRole.artisan));
    await Future<void>.delayed(Duration.zero);
    expect(session.status, SessionStatus.signedOut);
    expect(session.account, isNull);
    session.dispose();
    await identities.close();
  });

  test('Role palettes have distinct surfaces and primary colors', () {
    final artisan = RoleTheme.forRole(AccountRole.artisan);
    final buyer = RoleTheme.forRole(AccountRole.buyer);
    expect(
        artisan.scaffoldBackgroundColor, isNot(buyer.scaffoldBackgroundColor));
    expect(artisan.colorScheme.primary, isNot(buyer.colorScheme.primary));
  });

  Future<void> start(WidgetTester tester, Accounts accounts, String language,
      String route) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(overrides: [
      selectedLanguageProvider.overrideWith((ref) => language),
      accountServiceProvider.overrideWithValue(accounts),
      sessionProvider.overrideWith((ref) =>
          SessionController.signedIn(accounts.value, accounts: accounts)),
    ]);
    final router = container.read(appRouterProvider)..go(route);
    addTearDown(router.dispose);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const AakarApp()));
    await tester.pumpAndSettle();
  }

  for (final role in AccountRole.values) {
    testWidgets('Registered ${role.name} bypasses role choice', (tester) async {
      final api = Accounts()..value = testAccount(role);
      await start(tester, api, 'en', '/role');
      expect(find.text('How will you use Aakar?'), findsNothing);
      expect(find.byType(SegmentedButton<AccountRole>), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Your account'), findsNothing);
    });

    testWidgets('Verified ${role.name} can go home and use workspace tabs',
        (tester) async {
      final account = testAccount(role);
      account.profile['is_verified'] = true;
      final api = Accounts()
        ..value = account
        ..review = {'status': 'verified', 'evidence': {}};
      await start(tester, api, 'en', '/verification');
      await tester.tap(find.text('Go to home'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
          find.textContaining('Demo workspace: sample products'), findsNothing);
      final destinations = find.byType(NavigationDestination);
      await tester.tap(destinations.at(1));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(destinations.last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View verification'));
      await tester.tap(find.text('View verification'));
      await tester.pumpAndSettle();
      expect(find.text('You’re verified!'), findsOneWidget);
      expect(api.value.id, account.id);
      expect(api.value.role, role);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Incomplete ${role.name} keeps its role and can go back',
        (tester) async {
      final api = Accounts()..value = testAccount(role, complete: false);
      await start(tester, api, 'en', '/role');
      expect(find.text('How will you use Aakar?'), findsNothing);
      expect(
          find.text(role == AccountRole.buyer
              ? 'Tell us about your business'
              : 'Tell us about yourself'),
          findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to Aakar'), findsOneWidget);
      expect(api.value.role, role);
      expect(tester.takeException(), isNull);
    });

    for (final language in ['en', 'hi']) {
      testWidgets('${role.name} verification and profile fit in $language',
          (tester) async {
        final api = Accounts()..value = testAccount(role);
        await start(tester, api, language, '/verification');
        expect(find.byType(CheckboxListTile), findsOneWidget);
        await tester.scrollUntilVisible(find.byType(FilledButton), 200);
        final submit =
            tester.widget<FilledButton>(find.byType(FilledButton).first);
        expect(submit.onPressed, isNull);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'Submission needs consent and shows backend pending, never verified',
      (tester) async {
    final api = Accounts()
      ..review = {
        'status': 'not_started',
        'evidence': {'business': '/private/image.jpg'}
      };
    await start(tester, api, 'en', '/verification');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit for verification'));
    await tester.tap(find.text('Submit for verification'));
    await tester.pumpAndSettle();
    expect(api.submissions, 1);
    expect(find.text('Verification in progress'), findsOneWidget);
    expect(find.text('You’re verified!'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Verification load failure offers retry without a success state',
      (tester) async {
    final api = Accounts()..fail = true;
    await start(tester, api, 'en', '/verification');
    expect(find.text('Could not load verification. Please retry.'),
        findsOneWidget);
    expect(find.text('Go to home'), findsNothing);
    api.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsOneWidget);
  });
}

class DelayedAccounts extends AccountService {
  final Future<Account?> response;
  DelayedAccounts(this.response);
  @override
  Future<Account?> me() => response;
}

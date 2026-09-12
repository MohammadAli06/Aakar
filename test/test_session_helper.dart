import 'package:craft_connect/core/services/session_controller.dart';
import 'package:craft_connect/shared/models/account.dart';

/// Builds a role-locked account for widget tests, without Firebase.
///
/// [complete] controls whether the profile is finished: an incomplete artisan
/// profile is what the router guard sends to `/profile-setup`.
Account testAccount(AccountRole role, {bool complete = true}) {
  final isArtisan = role == AccountRole.artisan;
  return Account(
    id: isArtisan ? 'artisan-test' : 'buyer-test',
    firebaseUid: 'test-uid',
    role: role,
    name: complete ? (isArtisan ? 'Ramesh Kumar' : 'Earth Store Buyer') : null,
    languagePref: 'en',
    profile: isArtisan
        ? {
            'craft_category': 'pottery',
            'state': 'Rajasthan',
            'is_verified': false,
          }
        : {
            'business_name': 'The Earth Store',
            'business_type': 'retailer',
            'industry': 'handicrafts',
            'state': 'Maharashtra',
            'is_verified': false,
          },
  );
}

SessionController signedInSession(
  AccountRole role, {
  bool complete = true,
}) =>
    SessionController.signedIn(testAccount(role, complete: complete));

/// A resolved signed-out session, so tests skip the splash/loading route.
SessionController signedOutSession() => SessionController.signedOut();

import 'package:firebase_auth/firebase_auth.dart';

import '../../shared/models/account.dart';
import 'api_client.dart';

/// Backend account operations. Every call is authenticated with the caller's
/// Firebase ID token by [ApiClient]; existing accounts retain their stored role.
class AccountService {
  final ApiClient _api;

  AccountService({ApiClient? api}) : _api = api ?? apiClient;

  static Map<String, dynamic> _asMap(dynamic data) =>
      (data as Map).cast<String, dynamic>();

  /// Exchange the current Firebase identity for an account and initial role.
  /// Called once, immediately after first authentication.
  Future<Account> register(AccountRole role) async {
    final data = await _api
        .post('/auth/verify-token', queryParameters: {'role': role.name});
    return Account.fromJson(_asMap(data));
  }

  /// The signed-in account, or null when the Firebase identity has no backend
  /// account yet (i.e. signup was never completed).
  Future<Account?> me() async {
    try {
      return Account.fromJson(_asMap(await _api.get('/auth/me')));
    } on ApiError catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verification() async =>
      _asMap(await _api.get('/auth/verification'));

  Future<void> uploadEvidence(String kind, String path) async {
    await _api.uploadFile('/auth/verification/evidence', path,
        fields: {'kind': kind});
  }

  Future<void> submitVerification() async {
    await _api.post('/auth/verification/submit', data: {'consent': true});
  }

  Future<Account> updateArtisanProfile({
    String? name,
    String? languagePref,
    String? state,
    String? district,
    String? craftCategory,
  }) async {
    final data = await _api.put('/auth/artisan-profile', data: {
      if (name != null) 'name': name,
      if (languagePref != null) 'language_pref': languagePref,
      if (state != null) 'state': state,
      if (district != null) 'district': district,
      if (craftCategory != null) 'craft_category': craftCategory,
    });
    return Account.fromJson(_asMap(data));
  }

  Future<Account> updateBuyerProfile({
    String? name,
    String? languagePref,
    String? businessName,
    String? businessType,
    String? industry,
    String? state,
    String? district,
  }) async {
    final data = await _api.put('/auth/buyer-profile', data: {
      if (name != null) 'name': name,
      if (languagePref != null) 'language_pref': languagePref,
      if (businessName != null) 'business_name': businessName,
      if (businessType != null) 'business_type': businessType,
      if (industry != null) 'industry': industry,
      if (state != null) 'state': state,
      if (district != null) 'district': district,
    });
    return Account.fromJson(_asMap(data));
  }

  /// True when a Firebase user exists but the backend account does not.
  Future<bool> needsRegistration() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return await me() == null;
  }
}

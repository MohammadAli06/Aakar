import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Firebase authentication only — no local fixtures, no demo bypass.
///
/// Both active role flows use phone OTP. The Firebase ID token authenticates
/// backend account requests; legacy email helpers are not exposed by routing.
class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static String? _verificationId;
  static int? _resendToken;

  static bool get isConfigured => Firebase.apps.isNotEmpty;

  /// Emits the current Firebase user and subsequent changes. When Firebase is
  /// not configured (e.g. tests, or a build without the platform config file)
  /// this reports a signed-out session instead of throwing.
  static Stream<User?> authStateChanges() {
    if (!isConfigured) return Stream<User?>.value(null);
    return _auth.authStateChanges();
  }

  static User? get currentUser => isConfigured ? _auth.currentUser : null;

  static Future<String?> idToken({bool forceRefresh = false}) async {
    if (!isConfigured) return null;
    return await _auth.currentUser?.getIdToken(forceRefresh);
  }

  static void _assertConfigured() {
    if (!isConfigured) {
      throw StateError(
          'Firebase is not configured for this build. Add google-services.json '
          '(Android) or GoogleService-Info.plist (iOS) for the app package.');
    }
  }

  /// Sends an OTP. Returns true when the platform auto-verified the number
  /// (Android instant verification) and no code entry is needed.
  static Future<bool> sendOtp(String phoneNumber) async {
    _assertConfigured();
    final completer = Completer<bool>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: _resendToken,
      verificationCompleted: (credential) async {
        try {
          await _auth.signInWithCredential(credential);
          if (!completer.isCompleted) completer.complete(true);
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
      codeSent: (id, token) {
        _verificationId = id;
        _resendToken = token;
        if (!completer.isCompleted) completer.complete(false);
      },
      codeAutoRetrievalTimeout: (id) {
        _verificationId = id;
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    return completer.future.timeout(const Duration(seconds: 65));
  }

  static Future<void> verifyOtp(String code) async {
    _assertConfigured();
    final id = _verificationId;
    if (id == null) throw StateError('Request a new OTP first.');
    await _auth.signInWithCredential(
        PhoneAuthProvider.credential(verificationId: id, smsCode: code));
  }

  static Future<void> signUpBuyer(String email, String password) async {
    _assertConfigured();
    await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  static Future<void> signInBuyer(String email, String password) async {
    _assertConfigured();
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    if (isConfigured) await _auth.signOut();
  }
}

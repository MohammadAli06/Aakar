import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PhoneAuthService {
  static String? verificationId;
  static Future<bool> send(String phone) async {
    if (Firebase.apps.isEmpty)
      throw StateError(
          'Firebase is not configured. Use Demo Mode, or configure Firebase Phone Authentication.');
    final result = Completer<bool>();
    await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            await saveToken();
            if (!result.isCompleted) result.complete(true);
          } catch (e) {
            if (!result.isCompleted) result.completeError(e);
          }
        },
        verificationFailed: (error) {
          if (!result.isCompleted) result.completeError(error);
        },
        codeSent: (id, _) {
          verificationId = id;
          if (!result.isCompleted) result.complete(false);
        },
        codeAutoRetrievalTimeout: (id) {
          verificationId = id;
          if (!result.isCompleted) result.complete(false);
        });
    return result.future.timeout(const Duration(seconds: 65));
  }

  static Future<void> verify(String code) async {
    if (verificationId == null) throw StateError('Request a new OTP first.');
    await FirebaseAuth.instance.signInWithCredential(
        PhoneAuthProvider.credential(
            verificationId: verificationId!, smsCode: code));
    await saveToken();
  }

  static Future<void> saveToken() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null)
      throw StateError('Authentication did not return a token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/models.dart';
import 'account_service.dart';
import 'session_controller.dart';

// Selected language provider
final selectedLanguageProvider = StateProvider<String>((ref) => 'hi');

Future<String> loadSelectedLanguage() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('selected_language') == 'en' ? 'en' : 'hi';
}

final accountServiceProvider = Provider<AccountService>((ref) => AccountService());

/// Authentication session — the source of truth for role-locked access.
final sessionProvider = ChangeNotifierProvider<SessionController>((ref) {
  final controller = SessionController(accounts: ref.watch(accountServiceProvider));
  ref.onDispose(controller.dispose);
  return controller;
});

// User profile provider
final artisanProfileProvider = StateProvider<ArtisanProfile?>((ref) => null);

// Onboarding completed provider
final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_completed') ?? false;
});

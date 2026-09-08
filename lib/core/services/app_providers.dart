import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/models.dart';

// Selected language provider
final selectedLanguageProvider = StateProvider<String>((ref) => 'hi');

// Auth state provider
final authStateProvider = StateProvider<AuthState>((ref) => AuthState.unauthenticated);

enum AuthState { unauthenticated, authenticating, authenticated }

// User profile provider
final artisanProfileProvider = StateProvider<ArtisanProfile?>((ref) => null);

// Onboarding completed provider
final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_completed') ?? false;
});

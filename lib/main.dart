import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'core/services/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Hive local storage
  await Hive.initFlutter();

  // Firebase initialization
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init error (running without Firebase): $e');
  }

  final savedLanguage = await loadSelectedLanguage();
  runApp(ProviderScope(
    overrides: [selectedLanguageProvider.overrideWith((ref) => savedLanguage)],
    child: const AakarApp(),
  ));
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:showcaseview/showcaseview.dart';
import 'core/theme/role_theme.dart';
import 'core/services/app_providers.dart';
import 'core/routing/app_router.dart';

class AakarApp extends ConsumerStatefulWidget {
  const AakarApp({super.key});

  @override
  ConsumerState<AakarApp> createState() => _AakarAppState();
}

class _AakarAppState extends ConsumerState<AakarApp> {
  @override
  void initState() {
    super.initState();
    // Registers the coach-mark scope the first-run app tour draws into. Done
    // here rather than in `main` so the scope exists wherever the app widget is
    // built — including widget tests. Registering an existing scope is a no-op.
    ShowcaseView.register();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Aakar',
      locale: Locale(ref.watch(selectedLanguageProvider)),
      debugShowCheckedModeBanner: false,
      theme: RoleTheme.forRole(ref.watch(sessionProvider).role),
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
      ],
    );
  }
}

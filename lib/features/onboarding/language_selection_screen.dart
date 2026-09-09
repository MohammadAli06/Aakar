import '../../core/localization/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/app_providers.dart';

class LanguageSelectionScreen extends ConsumerWidget {
  const LanguageSelectionScreen({super.key});

  static const _languages = [
    {'code': 'hi', 'name': 'हिंदी', 'sub': 'Hindi', 'flag': '🇮🇳'},
    {'code': 'en', 'name': 'English', 'sub': 'English', 'flag': '🇬🇧'},
    {'code': 'mr', 'name': 'मराठी', 'sub': 'Marathi', 'flag': '🇮🇳'},
    {'code': 'ta', 'name': 'தமிழ்', 'sub': 'Tamil', 'flag': '🇮🇳'},
    {'code': 'te', 'name': 'తెలుగు', 'sub': 'Telugu', 'flag': '🇮🇳'},
    {'code': 'kn', 'name': 'ಕನ್ನಡ', 'sub': 'Kannada', 'flag': '🇮🇳'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedLanguageProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              // Header
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ).createShader(b),
                child: const AppText(
                  'भाषा चुनें',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const SizedBox(height: 8),
              const AppText(
                'आप बाद में इसे बदल सकते हैं',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textHint,
                ),
              ),
              const SizedBox(height: 40),
              // Language grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: _languages.length,
                  itemBuilder: (context, i) {
                    final lang = _languages[i];
                    final isSelected = selected == lang['code'];
                    final available =
                        lang['code'] == 'en' || lang['code'] == 'hi';
                    return GestureDetector(
                      onTap: !available
                          ? null
                          : () {
                              ref
                                  .read(selectedLanguageProvider.notifier)
                                  .state = lang['code']!;
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.primary,
                                    AppColors.secondary
                                  ],
                                )
                              : null,
                          color: isSelected ? null : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : AppColors.glassBorder,
                            width: 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppText(
                              lang['flag']!,
                              style: const TextStyle(fontSize: 28),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              lang['name']!,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            AppText(
                              available
                                  ? lang['sub']!
                                  : context.tr('Coming soon'),
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: isSelected
                                    ? Colors.white70
                                    : AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              // Continue button
              ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('selected_language', selected);
                  if (context.mounted) {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/onboarding');
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ).copyWith(
                  backgroundColor: WidgetStateProperty.all(Colors.transparent),
                  shadowColor: WidgetStateProperty.all(Colors.transparent),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const SizedBox(
                    height: 56,
                    child: Center(
                      child: AppText(
                        'आगे बढ़ें  →',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

import '../../core/localization/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _slides = [
    _OnboardingSlide(
      icon: Icons.camera_alt_rounded,
      iconColor: AppColors.primary,
      titleHi: 'फोटो खींचें, हम संवारेंगे',
      titleEn: 'Snap. We enhance.',
      descHi:
          'बस अपने उत्पाद की फोटो लें। हमारी AI उसे e-commerce के लिए तैयार कर देगी — बैकग्राउंड, रोशनी, सब कुछ।',
      descEn:
          'Just click a photo. Our AI makes it e-commerce ready — background, lighting, everything.',
      gradient: [Color(0xFFFF6B35), Color(0xFFFF8A5B)],
    ),
    _OnboardingSlide(
      icon: Icons.mic_rounded,
      iconColor: AppColors.secondary,
      titleHi: 'बोलें, हम लिखेंगे',
      titleEn: 'Speak. We catalog.',
      descHi:
          'अपनी भाषा में बताएं अपना उत्पाद। AI सुनेगा, समझेगा, और Hindi-English में listing तैयार करेगा।',
      descEn:
          'Describe in your language. AI listens, understands, and builds your bilingual listing.',
      gradient: [Color(0xFF6C63FF), Color(0xFF8A84FF)],
    ),
    _OnboardingSlide(
      icon: Icons.price_check_rounded,
      iconColor: AppColors.accent,
      titleHi: 'सही कीमत, सही मुनाफा',
      titleEn: 'Fair price. Real margin.',
      descHi:
          'AI आपकी मेहनत की लागत देखकर कीमत सुझाएगा — मशीन-निर्मित सामान से तुलना नहीं, बस हस्तशिल्प से।',
      descEn:
          'AI suggests prices respecting your labour — compared only to handmade, never to machine-made.',
      gradient: [Color(0xFFF59E0B), Color(0xFFFF6B35)],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, i) => _OnboardingPage(slide: _slides[i]),
          ),
          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.background.withOpacity(0.95),
                    AppColors.background,
                  ],
                ),
              ),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _slides.length,
                    effect: ExpandingDotsEffect(
                      activeDotColor: AppColors.primary,
                      dotColor: AppColors.surfaceHighlight,
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 3,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      if (_currentPage < _slides.length - 1)
                        TextButton(
                          onPressed: _complete,
                          child: const AppText(
                            'Skip',
                            style: TextStyle(color: AppColors.textHint),
                          ),
                        ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          if (_currentPage < _slides.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            _complete();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(140, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _slides[_currentPage].gradient,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: _slides[_currentPage]
                                    .gradient
                                    .first
                                    .withOpacity(0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            height: 52,
                            width: 140,
                            child: Center(
                              child: AppText(
                                _currentPage < _slides.length - 1
                                    ? 'अगला →'
                                    : 'शुरू करें 🎨',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingSlide {
  final IconData icon;
  final Color iconColor;
  final String titleHi;
  final String titleEn;
  final String descHi;
  final String descEn;
  final List<Color> gradient;

  const _OnboardingSlide({
    required this.icon,
    required this.iconColor,
    required this.titleHi,
    required this.titleEn,
    required this.descHi,
    required this.descEn,
    required this.gradient,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingSlide slide;
  const _OnboardingPage({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 80),
          // Animated icon container
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  slide.gradient.first.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
            child: Center(
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: slide.gradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: slide.gradient.first.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(slide.icon, size: 52, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 48),
          AppText(
            context.isHindi ? slide.titleHi : slide.titleEn,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 24),
          AppText(
            context.isHindi ? slide.descHi : slide.descEn,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}

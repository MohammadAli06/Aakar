import '../../core/localization/app_strings.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/mock_ai_service.dart';
import '../../shared/widgets/glass_card.dart';

enum _EnhancementStage { processing, comparison, done }

class EnhancementScreen extends StatefulWidget {
  final String imagePath;
  const EnhancementScreen({super.key, required this.imagePath});

  @override
  State<EnhancementScreen> createState() => _EnhancementScreenState();
}

class _EnhancementScreenState extends State<EnhancementScreen>
    with TickerProviderStateMixin {
  _EnhancementStage _stage = _EnhancementStage.processing;
  Map<String, String>? _result;
  double _sliderValue = 0.5;
  late AnimationController _progressController;
  late AnimationController _checkController;

  final _steps = [
    {'icon': '✂️', 'label': 'Background हटाया जा रहा है', 'done': false},
    {'icon': '☀️', 'label': 'Lighting adjust हो रही है', 'done': false},
    {'icon': '🎨', 'label': 'Colors enhance हो रहे हैं', 'done': false},
    {'icon': '✨', 'label': 'Final polish', 'done': false},
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _runEnhancement();
  }

  Future<void> _runEnhancement() async {
    _progressController.forward();
    // Simulate step-by-step processing
    for (int i = 0; i < _steps.length; i++) {
      await Future.delayed(Duration(milliseconds: 700 + i * 200));
      if (mounted) {
        setState(() => _steps[i]['done'] = true);
      }
    }
    final result = await MockAIService.enhanceImage(widget.imagePath);
    if (mounted) {
      setState(() {
        _result = result;
        _stage = _EnhancementStage.comparison;
      });
      _checkController.forward();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  final String _productId = 'product_${DateTime.now().millisecondsSinceEpoch}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: _stage != _EnhancementStage.processing
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => context.pop(),
              )
            : null,
        title: AppText(
          _stage == _EnhancementStage.processing
              ? 'AI Enhancement'
              : 'पहले / बाद',
        ),
      ),
      body: SafeArea(
        child: _stage == _EnhancementStage.processing
            ? _buildProcessing()
            : _buildComparison(),
      ),
    );
  }

  Widget _buildProcessing() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Processing animation
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.auto_fix_high_rounded,
                  color: Colors.white, size: 50),
            ),
          ),
          const SizedBox(height: 32),
          const AppText(
            'AI आपकी फोटो सुधार रहा है...',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const SizedBox(height: 40),
          // Progress bar
          AnimatedBuilder(
            animation: _progressController,
            builder: (_, __) => Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progressController.value,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceLight,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 6),
                AppText(
                  '${(_progressController.value * 100).toInt()}%',
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Steps
          ...List.generate(_steps.length, (i) {
            final step = _steps[i];
            final isDone = step['done'] as bool;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDone
                    ? AppColors.accentGreen.withOpacity(0.08)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isDone
                        ? AppColors.accentGreen.withOpacity(0.3)
                        : AppColors.glassBorder),
              ),
              child: Row(
                children: [
                  AppText(step['icon'] as String,
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppText(
                      step['label'] as String,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDone
                            ? AppColors.accentGreen
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (isDone)
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.accentGreen, size: 20)
                  else
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textHint,
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildComparison() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Success banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accentGreen.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    color: AppColors.accentGreen, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: AppText(
                    'Enhancement complete! मूल फोटो भी सेव है।',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.accentGreen),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Before / After comparison
          Expanded(
            child: Stack(
              children: [
                // Before image (original)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(
                    File(widget.imagePath),
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                // After image (enhanced) with clip
                ClipRect(
                  clipper: _SliderClipper(_sliderValue),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.surfaceLight, AppColors.surface],
                        ),
                      ),
                      child: Stack(
                        children: [
                          Image.file(
                            File(widget.imagePath),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            color: const Color(0x33FFFFFF),
                            colorBlendMode: BlendMode.screen,
                          ),
                          // Overlay to show "enhanced" effect
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withOpacity(0.05),
                                  Colors.transparent
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Divider line
                Positioned.fill(
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) {
                      final w = context.size?.width ?? 300;
                      setState(() {
                        _sliderValue =
                            (_sliderValue + d.delta.dx / w).clamp(0.0, 1.0);
                      });
                    },
                    child: Align(
                      alignment: Alignment(_sliderValue * 2 - 1, 0),
                      child: Container(
                        width: 3,
                        height: double.infinity,
                        color: Colors.white,
                        child: Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: const Icon(Icons.compare_arrows_rounded,
                                size: 20, color: AppColors.background),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Labels
                Positioned(
                  top: 12,
                  left: 16,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8)),
                    child: const AppText('पहले / Before',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: Colors.white)),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 16,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8)),
                    child: const AppText('✨ बाद / After',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Slider hint
          const AppText(
            '← स्लाइड करें तुलना के लिए  |  Slide to compare →',
            style: TextStyle(
                fontFamily: 'Poppins', fontSize: 11, color: AppColors.textHint),
          ),
          const SizedBox(height: 16),
          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    side: const BorderSide(color: AppColors.glassBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const AppText('🔄 फिर से',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          color: AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () => context.push('/cataloging', extra: _productId),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6))
                      ],
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded, color: Colors.white),
                          SizedBox(width: 6),
                          AppText('सही है! आगे बढ़ें',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SliderClipper extends CustomClipper<Rect> {
  final double value;
  _SliderClipper(this.value);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(size.width * value, 0, size.width, size.height);

  @override
  bool shouldReclip(_SliderClipper old) => old.value != value;
}

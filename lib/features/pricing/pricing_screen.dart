import '../../core/localization/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/api_client.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/verification_status_chip.dart';

// ── AI analysis result from /pricing/analyze-image ───────────────────────

class _AiAnalysis {
  final double complexityScore;
  final String detectedCategory;
  final String materialTier;
  final String reasoningEn;
  final String reasoningHi;
  final bool isFallback;

  const _AiAnalysis({
    required this.complexityScore,
    required this.detectedCategory,
    required this.materialTier,
    required this.reasoningEn,
    required this.reasoningHi,
    required this.isFallback,
  });

  factory _AiAnalysis.fromJson(Map<String, dynamic> j) => _AiAnalysis(
        complexityScore: (j['complexity_score'] as num).toDouble(),
        detectedCategory: j['detected_category'] as String? ?? 'other',
        materialTier: j['material_tier'] as String? ?? 'medium',
        reasoningEn: j['reasoning_en'] as String? ?? '',
        reasoningHi: j['reasoning_hi'] as String? ?? '',
        isFallback: j['is_fallback'] as bool? ?? true,
      );
}

// ── Main screen ──────────────────────────────────────────────────────────

class PricingScreen extends StatefulWidget {
  final String productId;
  const PricingScreen({super.key, required this.productId});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  // Cost inputs
  double _materialCost = 800;
  double _labourHours = 4;
  double _wagePerHour = 150;
  double _overhead = 200;
  double _craftsmanshipComplexity = 0.5; // overridden by AI

  // AI image analysis state
  _AiAnalysis? _aiAnalysis;
  bool _aiLoading = true;
  bool _aiChipExpanded = false;

  // Pricing recommendation state
  PriceRecommendation? _recommendation;
  bool _loading = false;
  bool _showCalculation = false;
  bool _approved = false;
  bool _approving = false;
  double? _finalPrice;

  double get _labourCost => _labourHours * _wagePerHour;
  double get _costFloor => _materialCost + _labourCost + _overhead;

  @override
  void initState() {
    super.initState();
    _analyzeImageWithAI();
  }

  // ── Step 1: Auto-assess complexity via GPT Vision ────────────────────

  Future<void> _analyzeImageWithAI() async {
    try {
      final data = await apiClient.post(
        '/pricing/analyze-image',
        data: {'product_id': widget.productId},
      );
      final analysis = _AiAnalysis.fromJson(data as Map<String, dynamic>);
      if (mounted) {
        setState(() {
          _aiAnalysis = analysis;
          _aiLoading = false;
          // Pre-fill slider with AI score
          _craftsmanshipComplexity = analysis.complexityScore;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  // ── Step 2: Get full pricing recommendation from backend ─────────────

  Future<void> _calculate() async {
    setState(() => _loading = true);
    try {
      final data = await apiClient.post(
        '/pricing/recommend',
        data: {
          'product_id': widget.productId,
          'craft_category': _aiAnalysis?.detectedCategory ?? 'other',
          'material_cost': _materialCost,
          'labour_hours': _labourHours,
          'wage_per_hour': _wagePerHour,
          'overhead': _overhead,
          'craftsmanship_complexity': _craftsmanshipComplexity,
        },
      );
      final json = data as Map<String, dynamic>;
      final comparables = (json['comparables'] as List<dynamic>? ?? [])
          .map((c) => MarketComparable(
                name: c['name'] as String? ?? '',
                price: (c['price'] as num).toDouble(),
                source: c['source'] as String? ?? '',
              ))
          .toList();

      final rec = PriceRecommendation(
        id: json['id'] as String,
        productId: json['product_id'] as String,
        materialCost: (json['material_cost'] as num).toDouble(),
        labourCost: (json['labour_cost'] as num).toDouble(),
        overhead: (json['overhead'] as num).toDouble(),
        craftsmanshipScore: (json['craftsmanship_score'] as num).toDouble(),
        recommendedMin: (json['recommended_min'] as num).toDouble(),
        recommendedMax: (json['recommended_max'] as num).toDouble(),
        explanationText: json['explanation_text_en'] as String? ?? '',
        explanationTextHi: json['explanation_text_hi'] as String? ?? '',
        comparables: comparables,
        verificationStatus: VerificationStatus.aiGenerated,
      );

      if (mounted) {
        setState(() {
          _recommendation = rec;
          _finalPrice = rec.recommendedMin;
          _loading = false;
          _showCalculation = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get recommendation: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  // ── Step 3: Persist final price to backend ───────────────────────────

  Future<void> _approveFinalPrice() async {
    if (_finalPrice == null) return;
    setState(() => _approving = true);
    try {
      await apiClient.post(
        '/pricing/set-final-price',
        data: {
          'product_id': widget.productId,
          'final_price': _finalPrice,
          'artisan_action': 'accept',
        },
      );
      if (mounted) {
        setState(() {
          _approved = true;
          _approving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _approving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save price: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
        title: const AppText('💰 मूल्य निर्धारण'),
        actions: [
          if (_recommendation != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: VerificationStatusChip(
                status: _approved
                    ? VerificationStatus.approved
                    : _recommendation!.verificationStatus,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── AI Assessment Chip ─────────────────────────────────────
            _buildAiChip(context),
            const SizedBox(height: 12),

            // ── Cost inputs section ────────────────────────────────────
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText('लागत विवरण  •  Cost Breakdown',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  _CostInputRow(
                    emoji: '🧱',
                    labelHi: 'सामग्री लागत',
                    labelEn: 'Material Cost',
                    value: _materialCost,
                    min: 0,
                    max: 5000,
                    onChanged: (v) => setState(() => _materialCost = v),
                  ),
                  const SizedBox(height: 12),
                  _CostInputRow(
                    emoji: '⏰',
                    labelHi: 'काम के घंटे',
                    labelEn: 'Labour Hours',
                    value: _labourHours,
                    min: 0.5,
                    max: 40,
                    suffix: 'hrs',
                    isRupee: false,
                    onChanged: (v) => setState(() => _labourHours = v),
                  ),
                  const SizedBox(height: 12),
                  _CostInputRow(
                    emoji: '👷',
                    labelHi: 'प्रति घंटा दर',
                    labelEn: 'Wage per Hour',
                    value: _wagePerHour,
                    min: 50,
                    max: 500,
                    onChanged: (v) => setState(() => _wagePerHour = v),
                  ),
                  const SizedBox(height: 12),
                  _CostInputRow(
                    emoji: '📦',
                    labelHi: 'अन्य खर्च',
                    labelEn: 'Overhead',
                    value: _overhead,
                    min: 0,
                    max: 1000,
                    onChanged: (v) => setState(() => _overhead = v),
                  ),
                  const Divider(color: AppColors.divider, height: 24),
                  // Cost floor summary
                  Row(
                    children: [
                      const AppText('कुल लागत (Cost Floor)',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      const Spacer(),
                      AppText(
                        '₹${_costFloor.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent),
                      ),
                    ],
                  ),

                  // ── Craftsmanship slider (AI pre-filled) ──────────────
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const AppText('शिल्पकारी जटिलता  •  Craftsmanship',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary)),
                      const Spacer(),
                      if (_aiAnalysis != null && !_aiAnalysis!.isFallback)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(children: [
                            const Text('🤖', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 3),
                            AppText('AI',
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 9,
                                    color: AppColors.accentGreen,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _craftsmanshipComplexity,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          activeColor: AppColors.primary,
                          inactiveColor: AppColors.surfaceLight,
                          onChanged: (v) =>
                              setState(() => _craftsmanshipComplexity = v),
                        ),
                      ),
                      SizedBox(
                        width: 42,
                        child: AppText(
                          '${(_craftsmanshipComplexity * 100).toInt()}%',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Calculate button ───────────────────────────────────────
            if (!_showCalculation)
              GestureDetector(
                onTap: _loading ? null : _calculate,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calculate_rounded,
                                  color: Colors.white),
                              SizedBox(width: 8),
                              AppText(
                                  'सुझाव पाएं  •  Get AI Price Recommendation',
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

            if (_recommendation != null) ...[
              // ── Recommendation card ────────────────────────────────
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withOpacity(0.2),
                      AppColors.secondary.withOpacity(0.15)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const AppText('🤖', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        const AppText('AI सुझाव  •  AI Recommendation',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const AppText('मेहनत-आधारित',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Price range
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                                  colors: [AppColors.accent, AppColors.primary])
                              .createShader(b),
                          child: AppText(
                            '₹${_recommendation!.recommendedMin.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: AppText('—',
                              style: TextStyle(
                                  fontSize: 24, color: AppColors.textHint)),
                        ),
                        ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                                  colors: [AppColors.accent, AppColors.primary])
                              .createShader(b),
                          child: AppText(
                            '₹${_recommendation!.recommendedMax.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Explanation
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lightbulb_outline_rounded,
                                  color: AppColors.accent, size: 16),
                              SizedBox(width: 6),
                              AppText('क्यों?  •  Why?',
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.accent)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          AppText(
                              context.isHindi
                                  ? _recommendation!.explanationTextHi
                                  : _recommendation!.explanationText,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.5)),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // ── Comparable products ────────────────────────────────
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.compare_arrows_rounded,
                            color: AppColors.secondary, size: 18),
                        SizedBox(width: 8),
                        AppText('हस्तनिर्मित तुलनाएं  •  Handmade Comparables',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const AppText('Machine-made excluded',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            color: AppColors.accentGreen)),
                    const SizedBox(height: 12),
                    ..._recommendation!.comparables.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.store_rounded,
                                  color: AppColors.textHint, size: 14),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: AppText(c.name,
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          color: AppColors.textSecondary))),
                              AppText('₹${c.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.accent)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // ── Price slider ───────────────────────────────────────
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText('अपनी कीमत चुनें  •  Set Your Price',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 16),
                    AppText(
                      '₹${_finalPrice?.toStringAsFixed(0) ?? '—'}',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary),
                    ),
                    Slider(
                      value: _finalPrice ?? _recommendation!.recommendedMin,
                      min: _costFloor,
                      max: _recommendation!.recommendedMax * 1.3,
                      divisions: 50,
                      activeColor: AppColors.primary,
                      inactiveColor: AppColors.surfaceLight,
                      onChanged: (v) => setState(() => _finalPrice = v),
                    ),
                    Row(
                      children: [
                        AppText(
                            '${context.tr('Min')}: ₹${_costFloor.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                color: AppColors.textHint)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accentGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppColors.accentGreen.withOpacity(0.25)),
                          ),
                          child: AppText(
                              '${context.tr('Recommended')}: ₹${_recommendation!.recommendedMin.toStringAsFixed(0)}–₹${_recommendation!.recommendedMax.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 9,
                                  color: AppColors.accentGreen)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Approve / Next ─────────────────────────────────────
              GestureDetector(
                onTap: _approving
                    ? null
                    : _approved
                        ? () => context.push('/b2b', extra: widget.productId)
                        : _approveFinalPrice,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _approved
                          ? [AppColors.accentGreen, AppColors.primary]
                          : [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (_approved
                                ? AppColors.accentGreen
                                : AppColors.primary)
                            .withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _approving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : AppText(
                            _approved
                                ? '✓ कीमत तय! B2B देखें →'
                                : '✅ यह कीमत सही है',
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  // ── AI Chip widget ─────────────────────────────────────────────────────

  Widget _buildAiChip(BuildContext context) {
    if (_aiLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.accent),
            ),
            SizedBox(width: 10),
            AppText('🤖  Analyzing your product photo…',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    final analysis = _aiAnalysis;
    if (analysis == null) return const SizedBox.shrink();

    final isHindi = context.isHindi;
    final reasoning = isHindi ? analysis.reasoningHi : analysis.reasoningEn;
    final pct = (analysis.complexityScore * 100).toInt();
    final chipColor =
        analysis.isFallback ? AppColors.textHint : AppColors.accentGreen;
    final tierEmoji = {
          'low': '🔵',
          'medium': '🟡',
          'premium': '🟢',
        }[analysis.materialTier] ??
        '⚪';

    return GestureDetector(
      onTap: () => setState(() => _aiChipExpanded = !_aiChipExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: analysis.isFallback
              ? AppColors.surface
              : AppColors.accentGreen.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: chipColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(analysis.isFallback ? '⚙️' : '🤖',
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: AppText(
                  analysis.isFallback
                      ? 'Adjust craftsmanship manually'
                      : '🤖  AI assessed: $pct% craftsmanship  $tierEmoji ${analysis.materialTier}',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: chipColor),
                ),
              ),
              if (!analysis.isFallback)
                Icon(
                  _aiChipExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: AppColors.textHint,
                ),
            ]),
            // Complexity bar
            if (!analysis.isFallback) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: analysis.complexityScore,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceLight,
                  color: AppColors.accentGreen,
                ),
              ),
            ],
            // Expandable reasoning
            if (_aiChipExpanded && !analysis.isFallback && reasoning.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: AppText(
                  reasoning,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Cost Input Row ─────────────────────────────────────────────────────────

class _CostInputRow extends StatelessWidget {
  final String emoji;
  final String labelHi;
  final String labelEn;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String? suffix;
  final bool isRupee;

  const _CostInputRow({
    required this.emoji,
    required this.labelHi,
    required this.labelEn,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix,
    this.isRupee = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppText(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(labelHi,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AppText(
              isRupee
                  ? '₹${value.toStringAsFixed(0)}'
                  : '${value.toStringAsFixed(1)} ${suffix ?? ''}',
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary),
            ),
          ],
        ),
        SizedBox(
          width: 120,
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.surfaceLight,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

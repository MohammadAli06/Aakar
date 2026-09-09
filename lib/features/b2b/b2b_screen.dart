import '../../core/localization/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/mock_ai_service.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/verification_status_chip.dart';

class B2BScreen extends StatefulWidget {
  final String productId;
  const B2BScreen({super.key, required this.productId});

  @override
  State<B2BScreen> createState() => _B2BScreenState();
}

class _B2BScreenState extends State<B2BScreen> {
  String? _selectedChannelId;
  B2BReadiness? _readiness;
  bool _loading = false;

  static const _channels = [
    _Channel(
      id: 'gem',
      name: 'GeM Portal',
      nameHi: 'सरकारी ई-मार्केट',
      desc: 'Government e-Marketplace',
      emoji: '🏛️',
      color: Color(0xFF2563EB),
    ),
    _Channel(
      id: 'ondc',
      name: 'ONDC Network',
      nameHi: 'राष्ट्रीय डिजिटल व्यापार',
      desc: 'Open Network for Digital Commerce',
      emoji: '🌐',
      color: Color(0xFF7C3AED),
    ),
    _Channel(
      id: 'state_board',
      name: 'State Handicraft Board',
      nameHi: 'राज्य हस्तशिल्प बोर्ड',
      desc: 'Rajasthan / Maharashtra / etc.',
      emoji: '🎨',
      color: Color(0xFFD97706),
    ),
  ];

  Future<void> _checkReadiness(String channelId) async {
    setState(() {
      _selectedChannelId = channelId;
      _loading = true;
      _readiness = null;
    });
    final result = await MockAIService.checkB2BReadiness(
      widget.productId,
      channelId,
      ProductListing(
          id: '',
          productId: '',
          titleEn: '',
          titleHi: '',
          descEn: '',
          descHi: '',
          attributes: [],
          tags: [],
          verificationStatus: VerificationStatus.approved),
      null,
    );
    if (mounted)
      setState(() {
        _readiness = result;
        _loading = false;
      });
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
        title: const AppText('B2B / सरकारी बाज़ार'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A0F40), Color(0xFF0F1040)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  AppText('🤝', style: TextStyle(fontSize: 36)),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText('B2B बाज़ार तक पहुँचें',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        SizedBox(height: 4),
                        AppText(
                            'Check what you need to list on govt. & B2B platforms. We\'ll tell you exactly what\'s missing.',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const AppText('बाज़ार चुनें  •  Choose Marketplace',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            // Channel cards
            ..._channels.map((ch) {
              final isSelected = _selectedChannelId == ch.id;
              return GestureDetector(
                onTap: () => _checkReadiness(ch.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ch.color.withOpacity(0.1)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? ch.color.withOpacity(0.5)
                          : AppColors.glassBorder,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: ch.color.withOpacity(0.15),
                                blurRadius: 12)
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ch.color.withOpacity(0.15),
                          border: Border.all(color: ch.color.withOpacity(0.3)),
                        ),
                        child: Center(
                            child: AppText(ch.emoji,
                                style: const TextStyle(fontSize: 24))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(context.isHindi ? ch.nameHi : ch.name,
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    color: AppColors.textHint)),
                            AppText(ch.desc,
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ch.color,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 16),
                        )
                      else
                        Icon(Icons.arrow_forward_ios_rounded,
                            color: AppColors.textHint, size: 14),
                    ],
                  ),
                ),
              );
            }),

            // Readiness result
            if (_loading) ...[
              const SizedBox(height: 20),
              const Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
              const SizedBox(height: 12),
              const Center(
                  child: AppText('जाँच रहे हैं...',
                      style: TextStyle(
                          fontFamily: 'Poppins', color: AppColors.textHint))),
            ],

            if (_readiness != null && !_loading) ...[
              const SizedBox(height: 20),
              // Readiness score
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const AppText('तैयारी स्कोर  •  Readiness Score',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        const Spacer(),
                        AppText(
                          '${(_readiness!.readinessScore * 100).toInt()}%',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: _readiness!.readinessScore >= 0.8
                                ? AppColors.accentGreen
                                : _readiness!.readinessScore >= 0.5
                                    ? AppColors.warning
                                    : AppColors.accentRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _readiness!.readinessScore,
                        minHeight: 10,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor: AlwaysStoppedAnimation(
                          _readiness!.readinessScore >= 0.8
                              ? AppColors.accentGreen
                              : _readiness!.readinessScore >= 0.5
                                  ? AppColors.warning
                                  : AppColors.accentRed,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Missing fields
                    if (_readiness!.missingFields.isNotEmpty) ...[
                      const Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: AppColors.warning, size: 18),
                          SizedBox(width: 8),
                          AppText('क्या चाहिए  •  What\'s Missing',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warning)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._readiness!.missingFields.map((f) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.warning),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: AppText(f,
                                        style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 13,
                                            color: AppColors.textSecondary))),
                                TextButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: AppText(
                                              '${context.tr('Fill in')}: ${context.tr(f)}')),
                                    );
                                  },
                                  child: const AppText('भरें',
                                      style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          color: AppColors.primary)),
                                ),
                              ],
                            ),
                          )),
                    ] else ...[
                      const Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: AppColors.accentGreen, size: 20),
                          SizedBox(width: 8),
                          AppText('सब कुछ तैयार है!  •  All requirements met!',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accentGreen)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Connect button
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: const AppText('🎉 आवेदन भेजा गया!',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      content: const AppText(
                        'आपका listing B2B channel पर भेज दिया गया है। खरीदार जल्द संपर्क करेंगे।\n\nYour listing has been submitted. Buyers will contact you soon.',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5),
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            context.go('/dashboard');
                          },
                          child: const AppText('Dashboard पर जाएं'),
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.secondary, Color(0xFF8A84FF)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.secondary.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        AppText('B2B Channel से जोड़ें  •  Connect Now',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ],
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
}

class _Channel {
  final String id;
  final String name;
  final String nameHi;
  final String desc;
  final String emoji;
  final Color color;
  const _Channel(
      {required this.id,
      required this.name,
      required this.nameHi,
      required this.desc,
      required this.emoji,
      required this.color});
}

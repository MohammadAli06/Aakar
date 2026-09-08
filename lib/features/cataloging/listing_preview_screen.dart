import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/mock_ai_service.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/verification_status_chip.dart';

class ListingPreviewScreen extends StatefulWidget {
  final String productId;
  const ListingPreviewScreen({super.key, required this.productId});

  @override
  State<ListingPreviewScreen> createState() => _ListingPreviewScreenState();
}

class _ListingPreviewScreenState extends State<ListingPreviewScreen>
    with SingleTickerProviderStateMixin {
  ProductListing? _listing;
  bool _loading = true;
  bool _readingBack = false;
  bool _approved = false;
  bool _showHindi = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _generateListing();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generateListing() async {
    setState(() => _loading = true);
    final listing = await MockAIService.generateListing(widget.productId, [], 'Kalakar');
    if (mounted) setState(() { _listing = listing; _loading = false; });
  }

  Future<void> _readBack() async {
    setState(() => _readingBack = true);
    // Simulate TTS read-back delay
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _readingBack = false);
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
        title: const Text('Listing Preview'),
        actions: [
          if (_listing != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: VerificationStatusChip(
                status: _approved ? VerificationStatus.approved : _listing!.verificationStatus,
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          labelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [Tab(text: 'हिंदी'), Tab(text: 'English')],
        ),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 24)],
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 38),
                  ),
                  const SizedBox(height: 20),
                  const Text('Listing तैयार हो रही है...', style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('Generating bilingual listing...', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textHint)),
                  const SizedBox(height: 20),
                  const SizedBox(width: 200, child: LinearProgressIndicator(color: AppColors.primary, backgroundColor: AppColors.surface)),
                ],
              ),
            )
          : _buildContent(),
      bottomNavigationBar: _listing != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Read back button
                    if (!_approved)
                      OutlinedButton(
                        onPressed: _readingBack ? null : _readBack,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          side: const BorderSide(color: AppColors.glassBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _readingBack ? Icons.volume_up_rounded : Icons.volume_up_outlined,
                              color: _readingBack ? AppColors.primary : AppColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _readingBack ? 'पढ़ा जा रहा है...' : '🔊 सुनें — Read Back',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                color: _readingBack ? AppColors.primary : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (!_approved)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                // Edit mode — for demo, just show a snackbar
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Edit mode coming soon!')),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 52),
                                side: const BorderSide(color: AppColors.glassBorder),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('✏️ संपादित', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textSecondary)),
                            ),
                          ),
                        if (!_approved) const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: _approved
                                ? () => context.push('/pricing', extra: widget.productId)
                                : () => setState(() => _approved = true),
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _approved
                                      ? [AppColors.accentGreen, const Color(0xFF059669)]
                                      : [AppColors.primary, AppColors.secondary],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_approved ? AppColors.accentGreen : AppColors.primary).withOpacity(0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  _approved ? '✓ Approved! Price Set करें →' : '✅ हाँ, सही है! Approve',
                                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
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
            )
          : null,
    );
  }

  Widget _buildContent() {
    final l = _listing!;
    return TabBarView(
      controller: _tabController,
      children: [
        _buildListingTab(l.titleHi, l.descHi, isHindi: true),
        _buildListingTab(l.titleEn, l.descEn, isHindi: false),
      ],
    );
  }

  Widget _buildListingTab(String title, String desc, {required bool isHindi}) {
    final l = _listing!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // AI badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.statusGenerated.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.statusGenerated.withOpacity(0.25)),
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppColors.statusGenerated, size: 16),
              SizedBox(width: 8),
              Text(
                'AI द्वारा तैयार — कृपया जाँचें  |  AI-generated — please verify',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.statusGenerated),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Title
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('शीर्षक / Title', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textHint)),
              const SizedBox(height: 6),
              Text(title, style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.4)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Description
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('विवरण / Description', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textHint)),
              const SizedBox(height: 6),
              Text(desc, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textSecondary, height: 1.6)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Tags
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tags / Keywords', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textHint)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: l.tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                  ),
                  child: Text('#$tag', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primary)),
                )).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Craft term preservation note
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent.withOpacity(0.2)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🎨', style: TextStyle(fontSize: 16)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '"Matka" और "Terracotta" जैसे शिल्प-शब्द संरक्षित हैं\nCraft terms like "Matka" & "Terracotta" preserved verbatim',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.accent, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }
}

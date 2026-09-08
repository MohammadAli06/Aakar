import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/verification_status_chip.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _artisanName = 'Kalakar';
  String _craftCategory = 'pottery';
  int _selectedTab = 0;

  // Mock product data
  final List<_MockProduct> _products = [
    _MockProduct(
      id: 'p1',
      name: 'टेराकोटा मटका',
      nameEn: 'Terracotta Matka',
      category: CraftCategory.pottery,
      status: ProductStatus.published,
      price: 2450,
      imageEmoji: '🏺',
      verificationStatus: VerificationStatus.approved,
      b2bReady: true,
    ),
    _MockProduct(
      id: 'p2',
      name: 'बाँधनी दुपट्टा',
      nameEn: 'Bandhani Dupatta',
      category: CraftCategory.weaving,
      status: ProductStatus.verified,
      price: 1850,
      imageEmoji: '🧣',
      verificationStatus: VerificationStatus.artisanReviewed,
      b2bReady: false,
    ),
    _MockProduct(
      id: 'p3',
      name: 'लकड़ी का हाथी',
      nameEn: 'Wooden Elephant',
      category: CraftCategory.woodcraft,
      status: ProductStatus.draft,
      price: null,
      imageEmoji: '🐘',
      verificationStatus: VerificationStatus.aiGenerated,
      b2bReady: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _artisanName = prefs.getString('artisan_name') ?? 'Kalakar';
      _craftCategory = prefs.getString('craft_category') ?? 'pottery';
    });
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'सुप्रभात';
    if (hour < 17) return 'नमस्ते';
    return 'शुभ संध्या';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A0A2E), Color(0xFF0A1A2E), AppColors.background],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Avatar
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.secondary],
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _artisanName.isNotEmpty ? _artisanName[0].toUpperCase() : 'K',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$_greeting, $_artisanName! 🎨',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _craftCategory.capitalize(),
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Notification icon
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.surface,
                                border: Border.all(color: AppColors.glassBorder),
                              ),
                              child: const Icon(Icons.notifications_outlined,
                                  color: AppColors.textSecondary, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Stats row
                        Row(
                          children: [
                            _StatCard(label: 'उत्पाद', labelEn: 'Products', value: '${_products.length}', icon: Icons.inventory_2_rounded, color: AppColors.primary),
                            const SizedBox(width: 10),
                            _StatCard(
                              label: 'सत्यापित',
                              labelEn: 'Approved',
                              value: '${_products.where((p) => p.verificationStatus == VerificationStatus.approved).length}',
                              icon: Icons.verified_rounded,
                              color: AppColors.accentGreen,
                            ),
                            const SizedBox(width: 10),
                            _StatCard(
                              label: 'B2B तैयार',
                              labelEn: 'B2B Ready',
                              value: '${_products.where((p) => p.b2bReady).length}',
                              icon: Icons.business_rounded,
                              color: AppColors.secondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Products section
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const Text(
                    'मेरे उत्पाद',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 6),
                  const Text('My Products', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textHint)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {},
                    child: const Text('सभी देखें', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.primary)),
                  ),
                ],
              ),
            ),
          ),
          // Product cards
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _ProductCard(
                  product: _products[i],
                  onTap: () => context.push('/photo-capture'),
                ),
                childCount: _products.length,
              ),
            ),
          ),
          // B2B Section banner
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            sliver: SliverToBoxAdapter(
              child: GestureDetector(
                onTap: () => context.push('/b2b', extra: 'p1'),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A1040), Color(0xFF0D1040)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [AppColors.secondary, Color(0xFF8A84FF)]),
                          boxShadow: [BoxShadow(color: AppColors.secondary.withOpacity(0.3), blurRadius: 12)],
                        ),
                        child: const Icon(Icons.business_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('B2B / सरकारी बाज़ार', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            const Text('GeM · ONDC · State Boards तक पहुँचें', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.secondary, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            onPressed: () => context.push('/photo-capture'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            label: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 6))],
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('नया उत्पाद जोड़ें', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension StringExt on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
}

class _StatCard extends StatelessWidget {
  final String label;
  final String labelEn;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.labelEn,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: color),
            ),
            Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}

class _MockProduct {
  final String id;
  final String name;
  final String nameEn;
  final CraftCategory category;
  final ProductStatus status;
  final double? price;
  final String imageEmoji;
  final VerificationStatus verificationStatus;
  final bool b2bReady;

  const _MockProduct({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.category,
    required this.status,
    required this.price,
    required this.imageEmoji,
    required this.verificationStatus,
    required this.b2bReady,
  });
}

class _ProductCard extends StatelessWidget {
  final _MockProduct product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            // Product image placeholder
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(product.imageEmoji, style: const TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  Text(
                    product.nameEn,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textHint),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      VerificationStatusChip(status: product.verificationStatus),
                      const SizedBox(width: 6),
                      if (product.b2bReady)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                          ),
                          child: const Text('B2B', style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.secondary)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (product.price != null)
                  Text(
                    '₹${product.price!.toStringAsFixed(0)}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.accent),
                  ),
                const SizedBox(height: 6),
                const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textHint, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

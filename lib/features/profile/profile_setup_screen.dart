import '../../core/localization/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/models.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  CraftCategory _selectedCategory = CraftCategory.pottery;
  String _selectedState = 'Rajasthan';
  int _step = 0;
  bool _saving = false;

  static const _craftCategories = [
    {
      'category': CraftCategory.pottery,
      'icon': '🏺',
      'labelHi': 'कुम्हारी',
      'labelEn': 'Pottery'
    },
    {
      'category': CraftCategory.weaving,
      'icon': '🧵',
      'labelHi': 'बुनाई',
      'labelEn': 'Weaving'
    },
    {
      'category': CraftCategory.embroidery,
      'icon': '🪡',
      'labelHi': 'कढ़ाई',
      'labelEn': 'Embroidery'
    },
    {
      'category': CraftCategory.woodcraft,
      'icon': '🪵',
      'labelHi': 'लकड़ी',
      'labelEn': 'Woodcraft'
    },
    {
      'category': CraftCategory.metalcraft,
      'icon': '⚙️',
      'labelHi': 'धातु',
      'labelEn': 'Metalcraft'
    },
    {
      'category': CraftCategory.painting,
      'icon': '🎨',
      'labelHi': 'चित्रकारी',
      'labelEn': 'Painting'
    },
    {
      'category': CraftCategory.leathercraft,
      'icon': '👜',
      'labelHi': 'चर्म',
      'labelEn': 'Leather'
    },
    {
      'category': CraftCategory.jewelry,
      'icon': '💍',
      'labelHi': 'आभूषण',
      'labelEn': 'Jewelry'
    },
  ];

  static const _states = [
    'Rajasthan',
    'Uttar Pradesh',
    'Gujarat',
    'West Bengal',
    'Madhya Pradesh',
    'Odisha',
    'Tamil Nadu',
    'Karnataka',
    'Maharashtra',
    'Assam',
    'Other',
  ];

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await Future.delayed(const Duration(seconds: 1));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('profile_setup_done', true);
    await prefs.setString('artisan_name', _nameController.text.trim());
    await prefs.setString('craft_category', _selectedCategory.name);
    await prefs.setString('artisan_state', _selectedState);
    setState(() => _saving = false);
    if (mounted) context.go('/dashboard');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => setState(() => _step--),
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
              2,
              (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _step ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i == _step
                          ? AppColors.primary
                          : AppColors.surfaceHighlight,
                    ),
                  )),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _step == 0 ? _buildStep0() : _buildStep1(),
        ),
      ),
    );
  }

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const AppText(
          'आपका नाम क्या है?',
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        const SizedBox(height: 32),
        TextField(
          controller: _nameController,
          style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: context.isHindi ? 'राम लाल' : 'Ramesh Kumar',
            hintStyle: const TextStyle(
                fontFamily: 'Poppins', fontSize: 18, color: AppColors.textHint),
            prefixIcon: const Padding(
              padding: EdgeInsets.all(16),
              child: AppText('👤', style: TextStyle(fontSize: 20)),
            ),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),
        // State selector
        const AppText('राज्य / State',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedState,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  color: AppColors.textPrimary),
              items: _states
                  .map((s) => DropdownMenuItem(value: s, child: AppText(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedState = v!),
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {
            if (_nameController.text.trim().isEmpty) return;
            setState(() => _step = 1);
          },
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6))
              ],
            ),
            child: const Center(
              child: AppText('अगला →',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const AppText(
          'आपकी कला?',
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const AppText('Select your craft category',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.textHint)),
        const SizedBox(height: 24),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: _craftCategories.length,
            itemBuilder: (context, i) {
              final c = _craftCategories[i];
              final cat = c['category'] as CraftCategory;
              final isSelected = _selectedCategory == cat;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight)
                        : null,
                    color: isSelected ? null : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : AppColors.glassBorder,
                        width: 1.5),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 1)
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppText(c['icon'] as String,
                          style: const TextStyle(fontSize: 32)),
                      const SizedBox(height: 6),
                      AppText(c['labelHi'] as String,
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _saving ? null : _save,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6))
              ],
            ),
            child: Center(
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const AppText('शुरू करें 🎨',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

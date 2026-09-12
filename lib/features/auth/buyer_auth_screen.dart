import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';
import '../../core/services/app_providers.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/account.dart';

String _b(BuildContext context, String en, String hi) =>
    context.isHindi ? hi : en;

/// Buyer signup: email + password, plus the business details the buyer profile
/// needs. Sign-in uses the same screen (existing email/password).
class BuyerAuthScreen extends ConsumerStatefulWidget {
  const BuyerAuthScreen({super.key});

  @override
  ConsumerState<BuyerAuthScreen> createState() => _BuyerAuthScreenState();
}

class _BuyerAuthScreenState extends ConsumerState<BuyerAuthScreen> {
  final _name = TextEditingController();
  final _businessName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  String _businessType = 'retailer';
  String _industry = 'handicrafts';
  String? _state;
  bool _loading = false;
  bool _obscure = true;

  static const _businessTypes = {
    'retailer': ['Retailer', 'खुदरा विक्रेता'],
    'wholesaler': ['Wholesaler', 'थोक विक्रेता'],
    'exporter': ['Exporter', 'निर्यातक'],
    'hospitality': ['Hotel / Hospitality', 'होटल / आतिथ्य'],
    'corporate': ['Corporate / Gifting', 'कॉर्पोरेट / गिफ़्टिंग'],
    'other': ['Other', 'अन्य'],
  };

  static const _industries = {
    'handicrafts': ['Handicrafts', 'हस्तशिल्प'],
    'home_decor': ['Home Decor', 'गृह सजावट'],
    'fashion': ['Fashion / Textiles', 'फ़ैशन / वस्त्र'],
    'food_service': ['Food Service', 'खाद्य सेवा'],
    'gifting': ['Gifting', 'उपहार'],
    'other': ['Other', 'अन्य'],
  };

  static const _states = [
    'Rajasthan',
    'Gujarat',
    'Uttar Pradesh',
    'Madhya Pradesh',
    'West Bengal',
    'Odisha',
    'Tamil Nadu',
    'Karnataka',
    'Maharashtra',
    'Assam',
    'Other',
  ];

  @override
  void dispose() {
    _name.dispose();
    _businessName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;

    if (_name.text.trim().isEmpty) {
      return _showError(_b(context, 'Enter your name', 'अपना नाम दर्ज करें'));
    }
    if (!email.contains('@')) {
      return _showError(
          _b(context, 'Enter a valid email', 'सही ईमेल दर्ज करें'));
    }
    if (password.length < 6) {
      return _showError(_b(context, 'Password must be at least 6 characters',
          'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए'));
    }

    setState(() => _loading = true);
    try {
      // An existing buyer signs in; a new one is created. Either way the
      // backend account is role-locked to buyer.
      try {
        await AuthService.signInBuyer(email, password);
      } catch (_) {
        await AuthService.signUpBuyer(email, password);
      }

      final session = ref.read(sessionProvider);
      final account = await session.register(AccountRole.buyer);

      // Persist the business details collected here.
      await ref.read(accountServiceProvider).updateBuyerProfile(
            name: _name.text.trim(),
            businessName: _businessName.text.trim().isEmpty
                ? null
                : _businessName.text.trim(),
            businessType: _businessType,
            industry: _industry,
            state: _state,
            languagePref: account.languagePref,
          );
      await session.refresh();
      // The router guard routes a completed buyer profile to the dashboard.
    } catch (e) {
      if (mounted) _showError(_describe(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _describe(Object e) {
    final text = '$e';
    if (text.contains('not configured')) {
      return _b(
        context,
        'Sign-in is unavailable in this build. Contact support.',
        'इस बिल्ड में साइन-इन उपलब्ध नहीं है। सहायता से संपर्क करें।',
      );
    }
    if (text.contains('account-exists-with-different-credential') ||
        text.contains('email-already-in-use')) {
      return _b(context, 'That email is already registered.',
          'यह ईमेल पहले से पंजीकृत है।');
    }
    if (text.contains('wrong-password') || text.contains('invalid-credential')) {
      return _b(context, 'Incorrect email or password.',
          'ईमेल या पासवर्ड गलत है।');
    }
    if (text.contains('This account is registered as a')) {
      return _b(
        context,
        'This email already belongs to an artisan account. Use a different email for a buyer account.',
        'यह ईमेल पहले से कारीगर खाते का है। खरीदार खाते के लिए दूसरा ईमेल लें।',
      );
    }
    return text;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary),
          onPressed: () => context.go('/role'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                _b(context, 'Buyer sign up', 'खरीदार पंजीकरण'),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _b(context, 'Tell us about your business',
                    'अपने व्यवसाय के बारे में बताएं'),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              _Field(
                controller: _name,
                label: _b(context, 'Your name', 'आपका नाम'),
                icon: Icons.person_outline,
              ),
              _Field(
                controller: _businessName,
                label: _b(context, 'Business name', 'व्यवसाय का नाम'),
                icon: Icons.storefront_outlined,
              ),
              _Dropdown(
                label: _b(context, 'Business type', 'व्यवसाय प्रकार'),
                value: _businessType,
                items: _businessTypes,
                onChanged: (v) => setState(() => _businessType = v!),
              ),
              _Dropdown(
                label: _b(context, 'Industry', 'उद्योग'),
                value: _industry,
                items: _industries,
                onChanged: (v) => setState(() => _industry = v!),
              ),
              _Dropdown(
                label: _b(context, 'State', 'राज्य'),
                value: _state,
                options: _states,
                onChanged: (v) => setState(() => _state = v),
              ),
              _Field(
                controller: _email,
                label: _b(context, 'Email', 'ईमेल'),
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextField(
                  controller: _password,
                  obscureText: _obscure,
                  style: const TextStyle(
                      fontFamily: 'Poppins', color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: _b(context, 'Password', 'पासवर्ड'),
                    labelStyle: const TextStyle(
                        fontFamily: 'Poppins', color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline,
                        color: AppColors.textHint),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textHint,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: _loading ? null : _submit,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            _b(context, 'Continue', 'आगे बढ़ें'),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  _b(
                    context,
                    'Already registered? Enter the same email and password to sign in.',
                    'पहले से पंजीकृत हैं? साइन इन करने के लिए वही ईमेल और पासवर्ड डालें।',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppColors.textHint,
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

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
            fontFamily: 'Poppins', color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
              fontFamily: 'Poppins', color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.surface,
          prefixIcon: Icon(icon, color: AppColors.textHint),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
        ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final String? value;
  final Map<String, List<String>>? items;
  final List<String>? options;
  final ValueChanged<String?> onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.onChanged,
    this.items,
    this.options,
  });

  @override
  Widget build(BuildContext context) {
    final entries = items != null
        ? items!.entries
            .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(_b(context, e.value[0], e.value[1])),
                ))
            .toList()
        : options!
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
              fontFamily: 'Poppins', color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
        ),
        items: entries,
        onChanged: onChanged,
      ),
    );
  }
}

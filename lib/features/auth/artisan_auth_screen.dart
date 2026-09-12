import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';
import '../../core/services/app_providers.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/account.dart';

String _b(BuildContext context, String en, String hi) =>
    context.isHindi ? hi : en;

/// Artisan signup / sign-in: phone number + OTP.
class ArtisanAuthScreen extends ConsumerStatefulWidget {
  const ArtisanAuthScreen({super.key});

  @override
  ConsumerState<ArtisanAuthScreen> createState() => _ArtisanAuthScreenState();
}

class _ArtisanAuthScreenState extends ConsumerState<ArtisanAuthScreen> {
  final _phoneController = TextEditingController();
  bool _loading = false;
  String _countryCode = '+91';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      _showError(_b(context, 'Enter a valid 10-digit number',
          'कृपया सही 10 अंकों का नंबर दर्ज करें'));
      return;
    }

    setState(() => _loading = true);
    try {
      final automatic = await AuthService.sendOtp('$_countryCode$phone');
      if (!mounted) return;
      if (automatic) {
        await ref.read(sessionProvider).register(AccountRole.artisan);
      } else {
        context.push('/auth/otp', extra: '$_countryCode$phone');
      }
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
    if (text.contains('too-many-requests')) {
      return _b(context, 'Too many attempts. Try again later.',
          'बहुत अधिक प्रयास। बाद में पुनः प्रयास करें।');
    }
    if (text.contains('invalid-phone-number')) {
      return _b(context, 'That phone number is not valid.',
          'यह मोबाइल नंबर मान्य नहीं है।');
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
                _b(context, 'Artisan sign up', 'कारीगर पंजीकरण'),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _b(context, 'Enter your mobile number to continue',
                    'जारी रखने के लिए अपना मोबाइल नंबर दर्ज करें'),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 36),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: AppColors.divider),
                        ),
                      ),
                      child: Text(
                        '$_countryCode',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        maxLength: 10,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          letterSpacing: 2,
                        ),
                        decoration: const InputDecoration(
                          hintText: '98765 43210',
                          hintStyle: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            color: AppColors.textHint,
                            letterSpacing: 2,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                          counterText: '',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _b(context, 'An OTP will be sent to this number.',
                    'इस नंबर पर OTP भेजा जाएगा।'),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textHint,
                ),
              ),
              const SizedBox(height: 36),
              _PrimaryButton(
                label: _b(context, 'Send OTP', 'OTP भेजें'),
                loading: _loading,
                onTap: _loading ? null : _sendOtp,
              ),
              const SizedBox(height: 32),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/role'),
                  child: Text(
                    _b(context, 'Back to account type',
                        'खाते का प्रकार बदलें'),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  _b(
                    context,
                    'By continuing, you agree to our Terms & Privacy Policy',
                    'जारी रखकर, आप हमारी शर्तों और गोपनीयता नीति से सहमत होते हैं',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
          child: loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  '$label  →',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

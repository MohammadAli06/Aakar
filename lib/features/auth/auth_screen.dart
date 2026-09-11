import '../../core/localization/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/phone_auth_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Valid phone number required')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final automatic = await PhoneAuthService.send('$_countryCode$phone');
      if (mounted) {
        if (automatic) { context.go('/dashboard'); }
        else { context.push('/auth/otp', extra: '$_countryCode$phone'); }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              // Logo
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                ),
                child: const Icon(Icons.handshake_rounded,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 28),
              const AppText(
                'नमस्ते! 👋',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const AppText(
                'अपना मोबाइल नंबर दर्ज करें',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),
              // Phone input
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  children: [
                    // Country code selector
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: AppColors.glassBorder),
                        ),
                      ),
                      child: Row(
                        children: [
                          const AppText('🇮🇳', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 6),
                          const AppText(
                            '+91',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down,
                              color: AppColors.textHint, size: 20),
                        ],
                      ),
                    ),
                    // Phone number
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
              AppText(
                'OTP आपके नंबर पर भेजा जाएगा  •  OTP will be sent to this number',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textHint,
                ),
              ),
              const SizedBox(height: 36),
              // Send OTP button
              GestureDetector(
                onTap: _loading ? null : _sendOtp,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 56,
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
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const AppText(
                            'OTP भेजें  →',
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
              const SizedBox(height: 40),
              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: AppColors.divider)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: AppText(
                      'या / or',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: AppColors.divider)),
                ],
              ),
              const SizedBox(height: 20),
              // Demo login
              OutlinedButton(
                onPressed: () async {
                  // Demo bypass for judges
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('auth_token', 'demo_token');
                  if (context.mounted) context.go('/dashboard');
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.glassBorder),
                  foregroundColor: AppColors.textSecondary,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const AppText(
                  '🎭  Demo Mode (Judges)',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: AppText(
                  'By continuing, you agree to our Terms & Privacy Policy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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

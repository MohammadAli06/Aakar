import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../core/localization/app_strings.dart';
import '../../core/services/app_providers.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';

String _b(BuildContext context, String en, String hi) =>
    context.isHindi ? hi : en;

class OtpScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  const OtpScreen({super.key, required this.phoneNumber});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  bool _loading = false;
  int _resendSeconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _timer?.cancel();
    _resendSeconds = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) timer.cancel();
    });
  }

  Future<void> _verifyOtp(String otp) async {
    if (otp.length < 6 || _loading) return;
    setState(() => _loading = true);
    try {
      await AuthService.verifyOtp(otp);
      // Resolve the account before deciding whether role selection is needed.
      await ref.read(sessionProvider).resolveIdentity();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
        _otpController.clear();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      if (_loading || _resendSeconds > 0) return;
      setState(() => _loading = true);
      final automatic = await AuthService.sendOtp(widget.phoneNumber);
      if (automatic) await ref.read(sessionProvider).resolveIdentity();
      if (!mounted) return;
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_b(context, 'OTP resent', 'OTP दोबारा भेजा गया')),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 52,
      height: 60,
      textStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 1.5),
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/auth'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                _b(context, 'Enter OTP', 'OTP दर्ज करें'),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  children: [
                    TextSpan(
                        text: _b(context, 'OTP sent to ', 'OTP भेजा गया: ')),
                    TextSpan(
                      text: widget.phoneNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Center(
                child: Pinput(
                  controller: _otpController,
                  enabled: !_loading,
                  length: 6,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration!.copyWith(
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                  ),
                  submittedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration!.copyWith(
                      color: AppColors.primary.withOpacity(0.1),
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  onCompleted: _verifyOtp,
                ),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _loading ? null : () => _verifyOtp(_otpController.text),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            _b(context, 'Verify & Continue',
                                'सत्यापित करें और आगे बढ़ें'),
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
              const SizedBox(height: 24),
              Center(
                child: _resendSeconds <= 0
                    ? TextButton(
                        onPressed: _resend,
                        child: Text(
                          _b(context, 'Resend OTP', 'OTP दोबारा भेजें'),
                          style: const TextStyle(color: AppColors.primary),
                        ),
                      )
                    : Text(
                        _b(context, 'Resend OTP in $_resendSeconds s',
                            '$_resendSeconds सेकंड में OTP दोबारा भेजें'),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: AppColors.textHint,
                          fontSize: 13,
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

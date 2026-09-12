import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/app_strings.dart';
import '../../core/services/auth_service.dart';

class PhoneSignInScreen extends ConsumerStatefulWidget {
  const PhoneSignInScreen({super.key});
  @override
  ConsumerState<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends ConsumerState<PhoneSignInScreen> {
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;
  String t(String en, String hi) => context.isHindi ? hi : en;
  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(_phone.text)) {
      setState(() => _error = t('Enter a valid 10-digit mobile number.',
          'सही 10 अंकों का मोबाइल नंबर दर्ज करें।'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final automatic = await AuthService.sendOtp('+91${_phone.text}');
      if (!mounted) return;
      if (automatic) {
        // Auto-verified: the account type is fixed at signup, so send the
        // number's owner to the role choice before any signup form.
        context.go('/role');
      } else {
        context.push('/auth/otp', extra: '+91${_phone.text}');
      }
    } catch (_) {
      if (mounted)
        setState(() => _error = t(
            'We could not send the code. Check your connection and try again.',
            'कोड नहीं भेज सके। कनेक्शन जाँचें और फिर कोशिश करें।'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Aakar'), actions: [
          IconButton(
              onPressed: () => context.push('/language'),
              icon: const Icon(Icons.language))
        ]),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: ListView(
                      padding: const EdgeInsets.all(28),
                      children: [
                        const SizedBox(height: 40),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: Image.asset('assets/images/logo.png',
                                width: 80, height: 80, semanticLabel: 'Aakar')),
                        const SizedBox(height: 30),
                        Text(t('Welcome to Aakar', 'आकार में आपका स्वागत है'),
                            style: const TextStyle(
                                fontSize: 30, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Text(
                            t('Made by hand. Connected by trust.',
                                'हाथों की कला। भरोसे का साथ।'),
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 36),
                        Text(
                            t('Sign in or create your account',
                                'साइन इन करें या खाता बनाएँ'),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        TextField(
                            controller: _phone,
                            enabled: !_busy,
                            keyboardType: TextInputType.phone,
                            autofillHints: const [
                              AutofillHints.telephoneNumberNational
                            ],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10)
                            ],
                            decoration: InputDecoration(
                                labelText: t('Mobile number', 'मोबाइल नंबर'),
                                prefixText: '+91  ')),
                        const SizedBox(height: 14),
                        Text(t(
                            'We’ll send a one-time code to verify your number.',
                            'नंबर की पुष्टि के लिए हम एक कोड भेजेंगे।')),
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(_error!,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error))),
                        const SizedBox(height: 28),
                        FilledButton(
                            onPressed: _busy ? null : _send,
                            child: Text(_busy
                                ? t('Sending…', 'भेज रहे हैं…')
                                : t('Continue', 'आगे बढ़ें'))),
                        const SizedBox(height: 28),
                        Text(
                            t('For artisans and businesses. Choose how you use Aakar after signing in.',
                                'कारीगरों और व्यवसायों के लिए। साइन इन के बाद अपनी भूमिका चुनें।'),
                            textAlign: TextAlign.center),
                      ],
                    )))),
      );
}

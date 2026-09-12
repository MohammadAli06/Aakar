import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_strings.dart';
import '../../core/services/app_providers.dart';
import '../../shared/models/account.dart';

class RoleSelectScreen extends ConsumerStatefulWidget {
  const RoleSelectScreen({super.key});
  @override
  ConsumerState<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends ConsumerState<RoleSelectScreen> {
  bool _busy = false;
  String? _error;
  String t(String en, String hi) => context.isHindi ? hi : en;
  Future<void> _choose(AccountRole role) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider).register(role);
    } catch (_) {
      if (mounted)
        setState(() => _error = t(
            'Could not save your choice. Please try again.',
            'चुनाव सहेज नहीं सके। फिर कोशिश करें।'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Aakar')),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child:
                        ListView(padding: const EdgeInsets.all(28), children: [
                      const SizedBox(height: 32),
                      Text(
                          t('How will you use Aakar?',
                              'आप आकार का उपयोग कैसे करेंगे?'),
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(t(
                          'Choose the role for your new account. This phone number will stay linked to that role.',
                          'अपने नए खाते की भूमिका चुनें। यह मोबाइल नंबर इसी भूमिका से जुड़ा रहेगा।')),
                      const SizedBox(height: 32),
                      _card(
                          AccountRole.artisan,
                          Icons.handyman_outlined,
                          t("I'm an Artisan", 'मैं कारीगर हूँ'),
                          t('Your craft. Your story. Your business.',
                              'आपकी कला। आपकी कहानी। आपका व्यवसाय।'),
                          const Color(0xFF176344)),
                      const SizedBox(height: 18),
                      _card(
                          AccountRole.buyer,
                          Icons.storefront_outlined,
                          t("I'm a Buyer", 'मैं खरीदार हूँ'),
                          t('Thoughtful sourcing for your business.',
                              'अपने व्यवसाय के लिए हस्तशिल्प खोजें।'),
                          const Color(0xFF28564F)),
                      if (_busy)
                        const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator())),
                      if (_error != null)
                        Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                    ])))),
      );
  Widget _card(AccountRole role, IconData icon, String title, String subtitle,
          Color color) =>
      Card(
          child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _busy ? null : () => _choose(role),
        child: Padding(
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(height: 24),
              Text(title,
                  style: TextStyle(
                      fontSize: 22, color: color, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(subtitle),
              const SizedBox(height: 16),
              Align(
                  alignment: Alignment.centerRight,
                  child: Icon(Icons.arrow_forward, color: color)),
            ])),
      ));
}

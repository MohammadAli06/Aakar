import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/app_strings.dart';
import '../../core/services/app_providers.dart';
import '../../shared/models/account.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  final bool editing;
  const ProfileSetupScreen({super.key, this.editing = false});
  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _business = TextEditingController();
  final _state = TextEditingController();
  final _district = TextEditingController();
  String _craft = 'other';
  String _type = 'retailer';
  String _industry = 'handicrafts';
  bool _saving = false;
  String? _error;
  String t(String en, String hi) => context.isHindi ? hi : en;
  @override
  void initState() {
    super.initState();
    final a = ref.read(sessionProvider).account;
    _name.text = a?.name ?? '';
    _business.text = a?.businessName ?? '';
    _state.text = a?.state ?? '';
    _district.text = a?.profile['district'] as String? ?? '';
    _craft = a?.craftCategory ?? 'other';
    _type = a?.profile['business_type'] as String? ?? 'retailer';
    _industry = a?.profile['industry'] as String? ?? 'handicrafts';
  }

  @override
  void dispose() {
    for (final c in [_name, _business, _state, _district]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(bool artisan) async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(accountServiceProvider);
      final language = ref.read(selectedLanguageProvider);
      if (artisan) {
        await api.updateArtisanProfile(
            name: _name.text.trim(),
            state: _state.text.trim(),
            district: _district.text.trim(),
            craftCategory: _craft,
            languagePref: language);
      } else {
        await api.updateBuyerProfile(
            name: _name.text.trim(),
            businessName: _business.text.trim(),
            businessType: _type,
            industry: _industry,
            state: _state.text.trim(),
            district: _district.text.trim(),
            languagePref: language);
      }
      await ref.read(sessionProvider).refresh();
      if (mounted) context.go('/verification');
    } catch (_) {
      if (mounted)
        setState(() => _error = t(
            'Your profile could not be saved. Check your connection and retry.',
            'प्रोफ़ाइल सहेज नहीं सके। कनेक्शन जाँचकर फिर कोशिश करें।'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final artisan = ref.watch(sessionProvider).role == AccountRole.artisan;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _saving ? null : _back),
        title: Text(t('Create profile', 'प्रोफ़ाइल बनाएँ')),
      ),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Form(
                      key: _form,
                      child: ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          Text(
                              t('01  PROFILE     /     02  VERIFICATION',
                                  '01  प्रोफ़ाइल     /     02  सत्यापन'),
                              style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 1,
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                          const SizedBox(height: 28),
                          Icon(
                              artisan
                                  ? Icons.spa_outlined
                                  : Icons.storefront_outlined,
                              size: 48,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 24),
                          Text(
                              artisan
                                  ? t('Tell us about yourself',
                                      'अपने बारे में बताएँ')
                                  : t('Tell us about your business',
                                      'अपने व्यवसाय के बारे में बताएँ'),
                              style: const TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          Text(artisan
                              ? t('Let your craftsmanship find its people.',
                                  'अपनी कला को नई पहचान दें।')
                              : t('Build lasting connections with skilled makers.',
                                  'कुशल कारीगरों के साथ भरोसेमंद संबंध बनाएँ।')),
                          const SizedBox(height: 28),
                          _field(_name, t('Your name', 'आपका नाम'),
                              Icons.person_outline),
                          if (!artisan) ...[
                            _field(
                                _business,
                                t('Business name', 'व्यवसाय का नाम'),
                                Icons.business_outlined),
                            _dropdown(
                                t('Business type', 'व्यवसाय का प्रकार'),
                                _type,
                                {
                                  'retailer': t('Retailer', 'खुदरा विक्रेता'),
                                  'wholesaler': t('Wholesaler', 'थोक विक्रेता'),
                                  'exporter': t('Exporter', 'निर्यातक'),
                                  'hospitality': t('Hospitality', 'आतिथ्य'),
                                  'corporate': t('Corporate / Gifting',
                                      'कॉर्पोरेट / उपहार'),
                                  'other': t('Other', 'अन्य')
                                },
                                (v) => _type = v),
                            _dropdown(
                                t('Industry', 'उद्योग'),
                                _industry,
                                {
                                  'handicrafts': t('Handicrafts', 'हस्तशिल्प'),
                                  'home_decor': t('Home décor', 'गृह सजावट'),
                                  'fashion':
                                      t('Fashion / Textiles', 'फ़ैशन / वस्त्र'),
                                  'food_service':
                                      t('Food service', 'खाद्य सेवा'),
                                  'gifting': t('Gifting', 'उपहार'),
                                  'other': t('Other', 'अन्य')
                                },
                                (v) => _industry = v),
                          ],
                          if (artisan)
                            _dropdown(
                                t('Your craft', 'आपकी कला'),
                                _craft,
                                {
                                  'pottery': t('Pottery', 'मिट्टी के बर्तन'),
                                  'weaving': t('Weaving', 'बुनाई'),
                                  'embroidery': t('Embroidery', 'कढ़ाई'),
                                  'woodcraft': t('Woodcraft', 'लकड़ी की कला'),
                                  'metalcraft': t('Metalcraft', 'धातु कला'),
                                  'painting': t('Painting', 'चित्रकारी'),
                                  'leathercraft':
                                      t('Leathercraft', 'चर्म शिल्प'),
                                  'jewelry': t('Jewelry', 'आभूषण'),
                                  'other': t('Other', 'अन्य')
                                },
                                (v) => _craft = v),
                          _field(
                              _state,
                              t('State / Union territory',
                                  'राज्य / केंद्र शासित प्रदेश'),
                              Icons.location_on_outlined),
                          _field(_district, t('City / District', 'शहर / जिला'),
                              Icons.location_city_outlined),
                          if (_error != null)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(_error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                          const SizedBox(height: 12),
                          FilledButton(
                              onPressed: _saving ? null : () => _save(artisan),
                              child: Text(_saving
                                  ? t('Saving…', 'सहेज रहे हैं…')
                                  : t('Save and continue',
                                      'सहेजें और आगे बढ़ें'))),
                          const SizedBox(height: 24),
                        ],
                      ))))),
    );
  }

  Future<void> _back() async {
    if (_saving) return;
    if (widget.editing) {
      context.go('/dashboard');
      return;
    }
    try {
      await ref.read(sessionProvider).signOut();
      if (mounted) context.go('/auth');
    } catch (_) {
      if (mounted)
        setState(() => _error = t('Could not go back. Please try again.',
            'वापस नहीं जा सके। फिर कोशिश करें।'));
    }
  }

  Widget _field(
          TextEditingController controller, String label, IconData icon) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: TextFormField(
              controller: controller,
              enabled: !_saving,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (v) => (v?.trim().isEmpty ?? true)
                  ? t('Please complete this field', 'यह जानकारी भरें')
                  : null,
              decoration: InputDecoration(
                  labelText: label, prefixIcon: Icon(icon), counterText: '')));
  Widget _dropdown(String label, String value, Map<String, String> items,
          ValueChanged<String> update) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: DropdownButtonFormField<String>(
              initialValue: items.containsKey(value) ? value : 'other',
              isExpanded: true,
              decoration: InputDecoration(labelText: label),
              items: items.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: _saving ? null : (v) => setState(() => update(v!))));
}

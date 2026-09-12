import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/localization/app_strings.dart';
import '../../core/services/app_providers.dart';
import '../../shared/models/account.dart';
import '../capture/capture_flow.dart';

class AccountVerificationScreen extends ConsumerStatefulWidget {
  const AccountVerificationScreen({super.key});
  @override
  ConsumerState<AccountVerificationScreen> createState() =>
      _AccountVerificationScreenState();
}

class _AccountVerificationScreenState
    extends ConsumerState<AccountVerificationScreen> {
  Map<String, dynamic>? _data;
  bool _busy = false;
  bool _consent = false;
  String? _error;
  String t(String en, String hi) => context.isHindi ? hi : en;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(accountServiceProvider).verification();
      if (!mounted) return;
      await ref.read(sessionProvider).refresh();
      if (mounted)
        setState(() {
          _data = data;
          _error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() => _error = t('Could not load verification. Please retry.',
            'सत्यापन लोड नहीं हुआ। फिर कोशिश करें।'));
    }
  }

  Future<void> _upload(String kind) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // The selfie uses the in-app camera with face guidance; launching the
      // device camera app can destroy the activity and lose the photo.
      final String? path = kind == 'selfie'
          ? await captureSelfie(context)
          : (await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 2400,
                  imageQuality: 90))
              ?.path;
      if (path == null) return;
      if (await File(path).length() > 8 * 1024 * 1024)
        throw StateError('Image too large');
      await ref.read(accountServiceProvider).uploadEvidence(kind, path);
      await _load();
    } catch (_) {
      if (mounted)
        setState(() => _error = t(
            'Upload failed. Choose a JPG or PNG under 8 MB and try again.',
            'अपलोड नहीं हुआ। 8 MB से कम JPG या PNG चुनें और फिर कोशिश करें।'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountServiceProvider).submitVerification();
      await _load();
      await ref.read(sessionProvider).refresh();
    } catch (_) {
      if (mounted)
        setState(() => _error = t(
            'Could not submit. Check your profile and uploads, then retry.',
            'जमा नहीं हुआ। प्रोफ़ाइल और अपलोड जाँचकर फिर कोशिश करें।'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final artisan = ref.watch(sessionProvider).role == AccountRole.artisan;
    final status = _data?['status'] as String? ?? 'not_started';
    final submitted = status == 'pending' || status == 'verified';
    final evidence = _data?['evidence'] as Map? ?? {};
    final kinds = artisan ? ['identity', 'craft', 'selfie'] : ['business'];
    return Scaffold(
        appBar: AppBar(title: Text(t('Verification', 'सत्यापन'))),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child:
                        ListView(padding: const EdgeInsets.all(24), children: [
                      const SizedBox(height: 28),
                      CircleAvatar(
                          radius: 42,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                              status == 'verified'
                                  ? Icons.check_rounded
                                  : submitted
                                      ? Icons.hourglass_top_rounded
                                      : Icons.verified_user_outlined,
                              size: 42,
                              color: Theme.of(context).colorScheme.primary)),
                      const SizedBox(height: 28),
                      Text(
                          status == 'verified'
                              ? t('You’re verified!', 'आपका सत्यापन हो गया!')
                              : submitted
                                  ? t('Verification in progress',
                                      'सत्यापन जारी है')
                                  : artisan
                                      ? t('Verify your identity',
                                          'अपनी पहचान सत्यापित करें')
                                      : t('Verify your business',
                                          'अपने व्यवसाय का सत्यापन करें'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 27, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Text(
                          submitted
                              ? t('Your status is updated after our team reviews your submission. You can return here to check it.',
                                  'हमारी टीम की समीक्षा के बाद स्थिति अपडेट होगी। आप यहाँ स्थिति देख सकते हैं।')
                              : t('Help build trust with the people you work with. Your documents are private and available only to you and authorised reviewers.',
                                  'भरोसा बनाने में मदद करें। दस्तावेज़ केवल आपको और अधिकृत समीक्षकों को दिखते हैं।'),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 28),
                      if (_data == null && _error == null)
                        const Center(child: CircularProgressIndicator()),
                      if (_data?['review_note'] != null)
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Text('${_data!['review_note']}'))),
                      if (!submitted && _data != null) ...[
                        for (final kind in kinds)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Card(
                                  child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(children: [
                                        Icon(
                                            evidence.containsKey(kind)
                                                ? Icons.check_circle_outline
                                                : Icons
                                                    .add_photo_alternate_outlined,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: Text(switch (kind) {
                                          'identity' => t('Identity document',
                                              'पहचान दस्तावेज़'),
                                          'craft' => t(
                                              'Your craft / work photo',
                                              'आपकी कला / काम की फ़ोटो'),
                                          'selfie' =>
                                            t('Your selfie', 'आपकी सेल्फ़ी'),
                                          _ => t('Business document',
                                              'व्यवसाय दस्तावेज़')
                                        })),
                                        TextButton(
                                            onPressed: _busy
                                                ? null
                                                : () => _upload(kind),
                                            child: Text(evidence
                                                    .containsKey(kind)
                                                ? t('Replace', 'बदलें')
                                                : kind == 'selfie'
                                                    ? t('Capture', 'फ़ोटो लें')
                                                    : t('Upload', 'अपलोड'))),
                                      ])))),
                        Text(
                            t('Use a masked identity document where possible. Upload only the information needed for review.',
                                'जहाँ संभव हो मास्क किया हुआ पहचान दस्तावेज़ दें। समीक्षा के लिए आवश्यक जानकारी ही अपलोड करें।'),
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 16),
                        CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _consent,
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _consent = v!),
                            title: Text(t(
                                'I agree to these documents being reviewed to verify my account.',
                                'मैं अपने खाते के सत्यापन के लिए इन दस्तावेज़ों की समीक्षा की अनुमति देता/देती हूँ।'))),
                        FilledButton(
                            onPressed: _busy ||
                                    !_consent ||
                                    !kinds.every(evidence.containsKey)
                                ? null
                                : _submit,
                            child: Text(_busy
                                ? t('Please wait…', 'कृपया प्रतीक्षा करें…')
                                : t('Submit for verification',
                                    'सत्यापन के लिए जमा करें'))),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                        TextButton(
                            onPressed: _busy ? null : _load,
                            child: Text(t('Retry', 'फिर कोशिश करें')))
                      ],
                      if (submitted) ...[
                        FilledButton(
                            onPressed: () => context.go('/dashboard'),
                            child: Text(t('Go to home', 'होम पर जाएँ'))),
                        TextButton(
                            onPressed: _busy ? null : _load,
                            child:
                                Text(t('Refresh status', 'स्थिति अपडेट करें')))
                      ],
                      if (!submitted)
                        TextButton(
                            onPressed:
                                _busy ? null : () => context.go('/dashboard'),
                            child: Text(t('Do this later', 'बाद में करें'))),
                      const SizedBox(height: 24),
                    ])))));
  }
}

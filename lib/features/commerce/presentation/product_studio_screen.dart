import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/studio_service.dart';
import '../data/commerce_repository.dart';
import '../domain/commerce_engine.dart';
import '../domain/photo_enhancement.dart';
import 'craft_forms.dart';
import 'craft_widgets.dart';

class ProductStudioScreen extends ConsumerStatefulWidget {
  final String? productId;
  const ProductStudioScreen({super.key, this.productId});
  @override
  ConsumerState<ProductStudioScreen> createState() =>
      _ProductStudioScreenState();
}

/// Complexity from the vision service, clamped to the documented 0.0-1.0 range.
/// Returns null for a missing, non-numeric or out-of-range value so the caller
/// can show "AI analysis unavailable" rather than crashing on the field.
double? aiComplexityScore(Object? data) {
  if (data is! Map) return null;
  final value = data['complexity_score'];
  if (value is! num) return null;
  final score = value.toDouble();
  if (score.isNaN || score.isInfinite || score < 0 || score > 1) return null;
  return score;
}

class _ProductStudioScreenState extends ConsumerState<ProductStudioScreen> {
  int step = 0;
  Record draft = {};
  bool working = false, verified = false;
  PhotoPrep? prepared;
  PhotoPrep? selectedPrep;
  bool catalogPlainBackground = true;
  bool photoReviewed = true;
  String? photoError;
  final transcript = TextEditingController();

  // AI Vision analysis (shown in pricing step)
  bool _aiLoading = false;
  bool _aiChipExpanded = false;
  Map<String, dynamic>? _aiResult;

  // Back-translation check for the Listen & Verify step
  Map<String, dynamic>? _translation;

  // TTS speaking state — toggled by the Listen button
  bool _speaking = false;

  String t(String en, String hi) => bilingual(context, en, hi);
  String fieldText(CraftField field) {
    final value = draft[field.key];
    if (value == null || '$value'.trim().isEmpty) {
      return t('Not provided', 'नहीं बताया');
    }
    if (value is bool) return value ? t('Yes', 'हाँ') : t('No', 'नहीं');
    return catalogText(field.key);
  }

  String catalogText(String key) => t(
      '${draft[key] ?? ''}',
      '${draft['${key}_hi'] ?? ''}'.trim().isEmpty
          ? '${draft[key] ?? ''}'
          : '${draft['${key}_hi']}');

  /// `title_hi` and `description_hi` are the other-language renderings of the
  /// title and description, not separate catalog attributes. Every list that
  /// shows catalog content resolves the selected language through
  /// [catalogText], so the Hindi companions are never repeated there.
  List<CraftField> get catalogFields => productFields
      .where((f) => f.key != 'title_hi' && f.key != 'description_hi')
      .toList();

  /// Form fields offer the Hindi companions only while the app is in Hindi, so
  /// an English reader is never asked for Hindi wording.
  List<CraftField> get formFields =>
      context.isHindi ? productFields : catalogFields;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(commerceProvider);
    draft = {...?repo.lookup('products', widget.productId)};
    photoReviewed = draft['photo_reviewed'] != false;
    catalogPlainBackground = draft['catalog_plain_background'] != false;
    transcript.text = '${draft['transcript'] ?? ''}';
    prepared = photoPrepOptions
        .where((option) => option.mode.name == '${draft['prepared']}')
        .map((option) => option.mode)
        .firstOrNull;
    if (widget.productId != null) step = 2;
    if (step == 2) _checkTranslation();
    // Reset speaking state when TTS finishes naturally
    craftTts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    craftTts.setCancelHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
  }

  @override
  void dispose() {
    stopCraftSpeech(); // stop TTS if artisan navigates away mid-speech
    transcript.dispose();
    super.dispose();
  }

  void message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Back always moves through the wizard first; only step 0 leaves the studio.
  void handleBack() {
    if (working) return;
    if (step > 0) {
      setState(() => step -= 1);
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/workspace/products');
    }
  }

  void selectPhoto(String source) {
    setState(() {
      draft['image'] = source;
      draft['original_image'] = source;
      draft['prepared'] = 'original';
      draft['photo_provider'] = 'original';
      draft['photo_reviewed'] = true;
      prepared = null;
      selectedPrep = null;
      verified = false;
      photoReviewed = true;
      photoError = null;
    });
  }

  /// Prepare the photo from the untouched original, so switching between
  /// options never stacks one correction on top of another.
  Future<void> prepare(PhotoPrep mode, {bool? plainCatalog}) async {
    if (working) return;
    final source = '${draft['original_image'] ?? draft['image']}';
    if (!StudioService.isPhoto(source)) {
      message(t(
          'Preparation applies to a real photo. This is a sample illustration.',
          'यह तैयारी असली फ़ोटो पर लागू होती है। यह नमूना चित्र है।'));
      return;
    }
    setState(() {
      working = true;
      photoError = null;
      selectedPrep = mode;
    });
    try {
      final plain = plainCatalog ?? catalogPlainBackground;
      final result = await ref
          .read(studioServiceProvider)
          .prepare(source, mode, catalogPlainBackground: plain);
      if (!mounted) return;
      setState(() {
        draft['original_image'] = result.originalPath;
        draft['image'] = result.path;
        draft['prepared'] = mode.name;
        draft['photo_provider'] = result.provider;
        photoReviewed = !result.reviewRequired;
        draft['photo_reviewed'] = photoReviewed;
        verified = false;
        prepared = mode;
        if (mode == PhotoPrep.b2bCatalog) {
          catalogPlainBackground = plain;
          draft['catalog_plain_background'] = plain;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => photoError =
            '${t('Photo preparation failed; your previous photo is unchanged. Tap the option again to retry.', 'फ़ोटो तैयार नहीं हुई; पिछली फ़ोटो सुरक्षित है। फिर कोशिश करने के लिए विकल्प दबाएँ।')} $e');
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  void useOriginal() => setState(() {
        draft['image'] = draft['original_image'];
        draft['prepared'] = 'original';
        prepared = null;
        selectedPrep = null;
        photoReviewed = true;
        draft['photo_reviewed'] = true;
        draft['photo_provider'] = 'original';
        verified = false;
      });

  Future<void> details() async {
    if (working || !photoReviewed) return;
    final editing = step == 2;
    final text = transcript.text.trim();
    Record assistance = {'fields': {}, 'provenance': 'Manual draft'};
    String? catalogNotice;
    final original = '${draft['original_image'] ?? draft['image'] ?? ''}';
    setState(() => working = true);
    if (!editing && StudioService.isPhoto(original)) {
      try {
        assistance = await ref
            .read(studioServiceProvider)
            .analyze(original, text, t('en', 'hi'));
      } catch (e) {
        catalogNotice =
            '${t('Photo suggestions unavailable. Go back to retry, or enter the details manually.', 'फ़ोटो से सुझाव नहीं मिले। फिर कोशिश के लिए वापस जाएँ या विवरण खुद भरें।')} $e';
      }
    }
    if (!mounted) return;
    setState(() => working = false);
    final initial = mergeCatalogSuggestions({
      'description': '',
      'material': '',
      'available': true,
      'location': ref.read(commerceProvider).profile['location'],
      ...draft,
    }, Map<String, dynamic>.from(assistance['fields'] as Map));
    if ('${initial['description'] ?? ''}'.trim().isEmpty) {
      initial['description'] = text;
    }
    final fields = editing
        ? formFields
        : formFields.where((field) {
            final value = initial[field.key];
            return value == null ||
                '$value'.trim().isEmpty ||
                (field.options != null && !field.options!.contains('$value'));
          }).toList();
    var d = fields.isEmpty
        ? initial
        : await craftForm(
            context,
            editing
                ? t('Review catalog details', 'कैटलॉग जाँचें')
                : t('Fill missing details', 'बाकी विवरण भरें'),
            fields,
            initial: initial,
            button: editing
                ? t('Continue to Listen & Verify', 'सुनें और जाँचें')
                : t('Review catalog', 'कैटलॉग जाँचें'),
            description: editing
                ? null
                : [
                    if (catalogNotice != null) catalogNotice,
                    t('Add the missing details. You can review and correct everything on the next screen.',
                        'बाकी विवरण भरें। अगले पन्ने पर सब जाँच और सुधार सकते हैं।')
                  ].join('\n\n'));
    if (d == null || !mounted) return;
    // Keep the completed answers if the artisan backs out of the full review.
    setState(() {
      draft = {...draft, ...d!, 'transcript': text};
      verified = false;
    });
    if (!editing) {
      d = await craftForm(
          context, t('Review catalog details', 'कैटलॉग जाँचें'), formFields,
          initial: draft,
          description: t(
              'Review all details, including the details filled from your photo. Correct anything before listening and verifying.',
              'फ़ोटो से भरे विवरण सहित सब जाँचें। सुनने और पुष्टि करने से पहले सुधार करें।'),
          button: t('Continue to Listen & Verify', 'सुनें और जाँचें'));
    }
    if (d != null && mounted) {
      setState(() {
        draft = {...draft, ...d!, 'transcript': text};
        verified = false;
        step = 2;
      });
      _checkTranslation();
    }
  }

  Future<void> price() async {
    // Pre-fill complexity from AI if available, else keep draft value
    final aiComplexity = aiComplexityScore(_aiResult);
    final d = await craftForm(
        context, t('Explainable pricing', 'समझने योग्य कीमत'), const [
      CraftField('material_cost', 'Material cost per unit (INR)',
          'प्रति इकाई सामग्री (₹)',
          required: true, numeric: true),
      CraftField(
          'labour_hours', 'Labour hours per unit', 'प्रति इकाई श्रम घंटे',
          required: true, numeric: true),
      CraftField('hourly_rate', 'Your hourly labour rate (INR)',
          'आपकी प्रति घंटा मेहनताना (₹)',
          required: true, numeric: true),
      CraftField(
          'overhead', 'Overhead per unit (INR)', 'अन्य प्रति इकाई खर्च (₹)',
          numeric: true),
      CraftField(
          'complexity', 'Craftsmanship complexity (0–1)', 'शिल्प जटिलता (0–1)',
          numeric: true)
    ],
        initial: {
          'material_cost': draft['material_cost'] ?? 0,
          'labour_hours': draft['labour_hours'] ?? 1,
          'hourly_rate': draft['hourly_rate'] ?? draft['labour_cost'] ?? 0,
          'overhead': draft['overhead'] ?? 0,
          // Use AI-assessed complexity if available, else draft value
          'complexity': aiComplexity ?? draft['complexity'] ?? .5
        });
    if (d == null || !mounted) return;
    setState(() {
      draft = {
        ...draft,
        ...d,
        'labour_cost': number(d['labour_hours']) * number(d['hourly_rate'])
      };
      step = 3;
    });
    // Trigger AI image analysis in background when entering pricing step
    _analyzeForPricing();
  }

  /// Calls the pricing vision endpoint to get GPT craftsmanship assessment.
  /// - Saved products (productId known): POST /pricing/analyze-image (uses DB record)
  /// - New products (no productId yet): POST /pricing/analyze-draft (sends image inline)
  Future<void> _analyzeForPricing() async {
    setState(() => _aiLoading = true);
    try {
      final productId = widget.productId ?? draft['id'];
      Map<String, dynamic>? result;

      if (productId != null) {
        // Existing product saved in DB — use the standard endpoint
        final data = await apiClient.post(
          '/pricing/analyze-image',
          data: {'product_id': '$productId'},
        );
        result = _knownAiResult(data);
      } else {
        // Brand-new draft not yet in DB — send image + description inline
        final imagePath = '${draft['image'] ?? draft['original_image'] ?? ''}';
        String? imageB64;
        if (imagePath.isNotEmpty &&
            StudioService.isPhoto(imagePath) &&
            !imagePath.startsWith('http')) {
          try {
            final bytes = await File(imagePath).readAsBytes();
            imageB64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          } catch (_) {
            // Image unreadable — run text-only analysis
          }
        }
        final description =
            '${draft['description'] ?? draft['transcript'] ?? ''}';
        final data = await apiClient.post(
          '/pricing/analyze-draft',
          data: {
            'image_b64': imageB64,
            'description': description,
          },
        );
        result = _knownAiResult(data);
      }

      if (mounted)
        setState(() {
          _aiResult = result;
          _aiLoading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  /// The chip can only render a real assessment, so an unrecognised or scoreless
  /// response is treated as unavailable instead of reaching the UI. A provider
  /// error, an older backend or a proxy must never take the pricing step down.
  Map<String, dynamic>? _knownAiResult(Object? data) {
    if (data is! Map) return null;
    final score = aiComplexityScore(data);
    if (score == null) return null;
    return {...Map<String, dynamic>.from(data), 'complexity_score': score};
  }

  /// Back-translation check for the Listen & Verify step.
  ///
  /// Advisory only: it never blocks the step, and an unavailable check clears any
  /// stored score rather than leaving a stale "checked" claim on the product.
  Future<void> _checkTranslation() async {
    final english = '${draft['description'] ?? ''}'.trim();
    final translated = '${draft['description_hi'] ?? ''}'.trim();
    if (english.isEmpty || translated.isEmpty) {
      if (mounted && _translation != null) setState(() => _translation = null);
      return;
    }
    try {
      final result = await ref
          .read(studioServiceProvider)
          .checkTranslation(english, translated);
      if (!mounted) return;
      setState(() {
        _translation = result;
        if (result['is_fallback'] == true) {
          draft.remove('roundtrip_score');
          draft.remove('translation_confidence');
        } else {
          draft['roundtrip_score'] = result['roundtrip_score'];
          draft['translation_confidence'] = result['confidence_label'];
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _translation = null;
          draft.remove('roundtrip_score');
          draft.remove('translation_confidence');
        });
      }
    }
  }

  Future<void> save() async {
    final d = await craftForm(
        context,
        t('You decide the final price', 'आखिरी कीमत आप तय करें'),
        const [
          CraftField(
              'price', 'Final unit price (INR)', 'आखिरी प्रति इकाई कीमत (₹)',
              numeric: true, required: true)
        ],
        initial: {
          'price': draft['price'] ?? (CommerceEngine.floor(draft) * 1.3).ceil()
        },
        button: t('Save to My Products', 'मेरे उत्पाद में सहेजें'));
    if (d == null) return;
    if (number(d['price']) < CommerceEngine.floor(draft)) {
      message(t('Price must cover your cost floor.',
          'कीमत आपकी लागत से कम नहीं हो सकती।'));
      return;
    }
    try {
      await ref.read(commerceProvider).act('product', {
        ...draft,
        ...d,
        'approved': verified,
        if (widget.productId != null) 'id': widget.productId
      });
      if (mounted) context.go('/workspace/products');
    } catch (e) {
      message('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final floor = CommerceEngine.floor(draft);
    final complexity = number(draft['complexity'], .5).clamp(0, 1);
    final min = floor * (1.25 + complexity * .15),
        max = floor * (1.5 + complexity * .2);
    final comparable = ref
        .watch(commerceProvider)
        .table('products')
        .where((p) =>
            p['category'] == draft['category'] && p['status'] == 'published')
        .toList();
    final prep = prepared;
    final prepLabel = prep == null
        ? t('As photographed', 'जैसी खींची गई')
        : t('Prepared · ${photoPrepOption(prep).labelEn}',
            'तैयार · ${photoPrepOption(prep).labelHi}');
    return PopScope(
        canPop: step == 0 && !working,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || working) return;
          handleBack();
        },
        child: Scaffold(
            appBar: AppBar(
                automaticallyImplyLeading: false,
                title: Text(t('Product studio', 'उत्पाद स्टूडियो')),
                actions: [
                  IconButton(
                      tooltip: step > 0
                          ? t('Previous step', 'पिछला चरण')
                          : t('Close studio', 'स्टूडियो बंद करें'),
                      onPressed: working ? null : handleBack,
                      icon: Icon(
                          step > 0 ? Icons.arrow_back : Icons.close_rounded)),
                  const SizedBox(width: 4),
                ]),
            body: SafeArea(
                child: AbsorbPointer(
                    absorbing: working,
                    child:
                        ListView(padding: const EdgeInsets.all(20), children: [
                      LinearProgressIndicator(
                          value: (step + 1) / 4,
                          color: const Color(0xFF285448),
                          backgroundColor: const Color(0xFFE4E9DE)),
                      const SizedBox(height: 14),
                      if (working) ...[
                        const LinearProgressIndicator(),
                        Text(t('Preparing your photo or catalog suggestions…',
                            'फ़ोटो या कैटलॉग सुझाव तैयार हो रहे हैं…')),
                      ],
                      Text(
                          '${step + 1} / 4 · ${t('Photo → catalog → review → pricing', 'फ़ोटो → कैटलॉग → जाँच → कीमत')}',
                          style: const TextStyle(fontSize: 10)),
                      if (step == 0) ...[
                        CraftHeading(
                            t('Let your craft shine', 'अपने शिल्प को निखारें'),
                            subtitle: t(
                                'Use natural light, center the whole product, choose a clear angle, and keep the original colour and texture visible.',
                                'प्राकृतिक रोशनी में पूरा उत्पाद बीच में रखें। असली रंग और बनावट साफ़ दिखें।')),
                        Center(
                            child: CraftImage('${draft['image'] ?? 'pottery'}',
                                size: 240)),
                        CraftButton(t('Take a photo', 'फ़ोटो लें'),
                            icon: Icons.camera_alt_outlined,
                            onPressed: () async {
                          final path =
                              await pickEvidence(context, camera: true);
                          if (path != null && mounted) selectPhoto(path);
                        }),
                        CraftButton(t('Choose from gallery', 'गैलरी से चुनें'),
                            secondary: true, onPressed: () async {
                          final path = await pickEvidence(context);
                          if (path != null && mounted) selectPhoto(path);
                        }),
                        CraftButton(
                            t('Use sample illustration (demo)',
                                'नमूना चित्र (डेमो)'),
                            secondary: true,
                            onPressed: () => selectPhoto('basket')),
                        if (draft['image'] != null)
                          CraftButton(
                              t('Next: prepare the photo',
                                  'आगे: फ़ोटो तैयार करें'),
                              onPressed: () => setState(() => step = 1))
                      ],
                      if (step == 1) ...[
                        CraftHeading(
                            t('Choose how to prepare this photo',
                                'यह फ़ोटो कैसे तैयार करें'),
                            subtitle: t(
                                'Background removal and photo suggestions keep your original. Compare the result carefully: colour, shape and craft details must be preserved.',
                                'बैकग्राउंड हटाने और फ़ोटो के सुझावों में मूल फ़ोटो सुरक्षित रहती है। परिणाम जाँचें: रंग, आकार और शिल्प के विवरण सुरक्षित होने चाहिए।')),
                        for (final option in photoPrepOptions)
                          _PrepOptionCard(
                              option: option,
                              selected:
                                  (selectedPrep ?? prepared) == option.mode,
                              busy: working,
                              onTap: () => prepare(option.mode)),
                        if ((selectedPrep ?? prepared) == PhotoPrep.b2bCatalog)
                          SwitchListTile.adaptive(
                              title: Text(t('White background for B2B frame',
                                  'B2B फ़्रेम के लिए सफ़ेद बैकग्राउंड')),
                              subtitle: Text(t(
                                  'Turn off to fit your entire natural photo.',
                                  'पूरी प्राकृतिक फ़ोटो रखने के लिए बंद करें।')),
                              value: catalogPlainBackground,
                              onChanged: working
                                  ? null
                                  : (value) {
                                      prepare(PhotoPrep.b2bCatalog,
                                          plainCatalog: value);
                                    }),
                        const SizedBox(height: 18),
                        Row(children: [
                          Expanded(
                              child: Column(children: [
                            CraftImage('${draft['original_image']}',
                                size: 150, fit: BoxFit.contain),
                            const SizedBox(height: 6),
                            Text(t('Original', 'मूल'),
                                style: const TextStyle(fontSize: 11))
                          ])),
                          Expanded(
                              child: Column(children: [
                            CraftImage('${draft['image']}',
                                size: 150, fit: BoxFit.contain),
                            const SizedBox(height: 6),
                            Text(prepLabel,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11))
                          ]))
                        ]),
                        if (const ['gemini', 'openai', 'cloudinary']
                            .contains(draft['photo_provider']))
                          CheckboxListTile(
                              key: const ValueKey('photo-fidelity-review'),
                              contentPadding: EdgeInsets.zero,
                              title: Text(t(
                                  'I compared both photos: the product details are preserved.',
                                  'मैंने दोनों फ़ोटो मिलाई हैं: उत्पाद के विवरण सुरक्षित हैं।')),
                              value: photoReviewed,
                              onChanged: working
                                  ? null
                                  : (value) => setState(() {
                                        photoReviewed = value == true;
                                        draft['photo_reviewed'] = photoReviewed;
                                      })),
                        if (prep != null)
                          CraftButton(
                              t('Use the original photo instead',
                                  'मूल फ़ोटो ही रखें'),
                              secondary: true,
                              onPressed: working ? null : useOriginal),
                        const SizedBox(height: 16),
                        TextField(
                            controller: transcript,
                            enabled: !working,
                            minLines: 4,
                            maxLines: 7,
                            decoration: InputDecoration(
                                labelText: t('Tell us about your product',
                                    'अपने उत्पाद के बारे में बताएँ'),
                                hintText: t(
                                    'Material, size, how it is made, and its story…',
                                    'सामग्री, माप, कैसे बनाया और कहानी…'),
                                suffixIcon:
                                    VoiceFieldButton(controller: transcript))),
                        if (photoError != null)
                          Text(photoError!,
                              key: const ValueKey('photo-preparation-error')),
                        CraftButton(t('Next', 'आगे'),
                            onPressed:
                                working || !photoReviewed ? null : details)
                      ],
                      if (step == 2) ...[
                        CraftHeading(
                            t('Your words. Your approval.',
                                'आपकी बात। आपकी स्वीकृति।'),
                            subtitle: t(
                                'Read or listen, correct any field by voice, then approve. This is product verification, not identity verification.',
                                'पढ़ें या सुनें, बोलकर सुधारें और स्वीकारें। यह उत्पाद की जाँच है, पहचान की नहीं।')),
                        CraftCard(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(catalogText('title'),
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 10),
                              Text(catalogText('description'),
                                  style: const TextStyle(
                                      fontSize: 13, height: 1.6)),
                              DetailRow(t('Photo preparation', 'फ़ोटो तैयारी'),
                                  prepLabel),
                              for (final field in catalogFields.where((f) =>
                                  f.key != 'title' && f.key != 'description'))
                                DetailRow(
                                    t(field.en, field.hi), fieldText(field)),
                              if (_translation != null &&
                                  _translation!['is_fallback'] != true) ...[
                                StatusPill(
                                    _translation!['confidence_label'] ==
                                            'checked'
                                        ? t('Translation checked ✓',
                                            'अनुवाद जाँचा गया ✓')
                                        : t('Please listen carefully',
                                            'ध्यान से सुनें'),
                                    warning:
                                        _translation!['confidence_label'] !=
                                            'checked'),
                                const SizedBox(height: 8),
                              ],
                              CraftButton(
                                  _speaking
                                      ? t('Stop listening', 'रोकें')
                                      : t('Listen to my catalog',
                                          'मेरा कैटलॉग सुनें'),
                                  secondary: true,
                                  icon: _speaking
                                      ? Icons.stop_circle_outlined
                                      : Icons.volume_up_outlined,
                                  onPressed: () async {
                                if (_speaking) {
                                  // Stop — user tapped again while playing
                                  await stopCraftSpeech();
                                  if (mounted)
                                    setState(() => _speaking = false);
                                } else {
                                  // Start speaking
                                  setState(() => _speaking = true);
                                  await speakCraft(
                                      context,
                                      catalogFields
                                          .map((field) =>
                                              '${t(field.en, field.hi)}: ${fieldText(field)}')
                                          .join('. '));
                                }
                              }),
                              CraftButton(
                                  t('Replace product photo',
                                      'उत्पाद की फ़ोटो बदलें'),
                                  secondary: true,
                                  onPressed: () => setState(() {
                                        verified = false;
                                        step = 0;
                                      })),
                              CraftButton(
                                  t('Correct details / voice edit',
                                      'विवरण / आवाज़ से सुधारें'),
                                  secondary: true,
                                  onPressed: working ? null : details),
                              CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                      t('I reviewed and confirm these product details',
                                          'मैंने विवरण जाँचे हैं और सही हैं'),
                                      style: const TextStyle(fontSize: 12)),
                                  value: verified,
                                  onChanged: (v) =>
                                      setState(() => verified = v == true))
                            ])),
                        CraftButton(t('Continue to pricing', 'कीमत तय करें'),
                            onPressed: verified && !working ? price : null)
                      ],
                      if (step == 3) ...[
                        CraftHeading(
                            t('Handmade deserves a fair price',
                                'हस्तनिर्मित की उचित कीमत'),
                            subtitle: t(
                                'Your labour matters. Recommendations never go below your costs.',
                                'आपकी मेहनत की कीमत है। सुझाव लागत से कम नहीं होगा।')),

                        // ── AI Vision Assessment Chip ──────────────────
                        // Only claimed as an assessment when a real score came back;
                        // otherwise it reads as unavailable (see _knownAiResult).
                        Builder(builder: (context) {
                          final score = aiComplexityScore(_aiResult);
                          final assessed = !_aiLoading &&
                              score != null &&
                              _aiResult?['is_fallback'] != true;
                          return GestureDetector(
                            onTap: () => setState(
                                () => _aiChipExpanded = !_aiChipExpanded),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: assessed
                                    ? const Color(0xFFEAF3EA)
                                    : const Color(0xFFF5F5F0),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: assessed
                                      ? const Color(0xFF5A7A5C)
                                          .withValues(alpha: 0.4)
                                      : const Color(0xFFDDDDDD),
                                ),
                              ),
                              child: _aiLoading
                                  ? const Row(children: [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF285448)),
                                      ),
                                      SizedBox(width: 10),
                                      Text('🤖  Analyzing your product photo…',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF6E796A))),
                                    ])
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Text(assessed ? '🤖' : '⚙️',
                                              style: const TextStyle(
                                                  fontSize: 15)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              assessed
                                                  ? '🤖 AI assessed: ${(score * 100).toInt()}% craftsmanship  •  ${_aiResult?['material_tier'] ?? ''} material'
                                                  : score != null
                                                      ? 'Adjust craftsmanship manually (AI unavailable)'
                                                      : 'AI analysis unavailable',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: assessed
                                                    ? const Color(0xFF285448)
                                                    : const Color(0xFF6E796A),
                                              ),
                                            ),
                                          ),
                                          if (assessed)
                                            Icon(
                                              _aiChipExpanded
                                                  ? Icons.expand_less_rounded
                                                  : Icons.expand_more_rounded,
                                              size: 18,
                                              color: const Color(0xFF6E796A),
                                            ),
                                        ]),
                                        // Progress bar for complexity
                                        if (assessed)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: score,
                                                minHeight: 5,
                                                backgroundColor:
                                                    const Color(0xFFDDE7DF),
                                                color: const Color(0xFF5A7A5C),
                                              ),
                                            ),
                                          ),
                                        // Expandable reasoning
                                        if (_aiChipExpanded && assessed)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 10),
                                            child: Text(
                                              bilingual(
                                                  context,
                                                  '${_aiResult?['reasoning_en'] ?? ''}',
                                                  '${_aiResult?['reasoning_hi'] ?? ''}'),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF6E796A),
                                                height: 1.5,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                          );
                        }),

                        CraftCard(
                            child: Column(children: [
                          DetailRow(t('Material', 'सामग्री'),
                              money(draft['material_cost'])),
                          DetailRow(t('Labour', 'श्रम'),
                              '${draft['labour_hours']} h × ${money(draft['hourly_rate'])}'),
                          DetailRow(t('Overhead', 'अन्य खर्च'),
                              money(draft['overhead'])),
                          const Divider(),
                          DetailRow(t('Protected cost floor', 'न्यूनतम लागत'),
                              money(floor)),
                          const SizedBox(height: 16),
                          Text('${money(min)} – ${money(max)}',
                              style: const TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF285448))),
                          Text(
                              t('Suggested range · costs + craftsmanship margin',
                                  'सुझाई सीमा · लागत + शिल्प लाभ'),
                              style: const TextStyle(fontSize: 11)),
                          const SizedBox(height: 12),
                          Text(
                              t('Handmade demo comparables below are context, not live market prices. A low comparable never reduces your cost floor.',
                                  'नीचे हस्तनिर्मित डेमो उदाहरण हैं, लाइव बाज़ार कीमतें नहीं। कम उदाहरण आपकी लागत सीमा नहीं घटाता।'),
                              style: const TextStyle(fontSize: 11)),
                          ...comparable.take(3).map((p) =>
                              DetailRow('${p['title']}', money(p['price']))),
                          CraftButton(t('Adjust costs', 'लागत बदलें'),
                              secondary: true, onPressed: price)
                        ])),
                        CraftButton(
                            t('Set final price & save',
                                'आखिरी कीमत तय करके सहेजें'),
                            onPressed: save),
                        Text(
                            t('This saves a product. Publishing is a separate action in My Products.',
                                'यह उत्पाद सहेजता है। मेरे उत्पाद से अलग से प्रकाशित करें।'),
                            style: const TextStyle(fontSize: 11))
                      ],
                      const SizedBox(height: 30),
                    ])))));
  }
}

/// One preparation choice: a reason to pick it, plus whether it is applied.
class _PrepOptionCard extends StatelessWidget {
  final PhotoPrepOption option;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;
  const _PrepOptionCard(
      {required this.option,
      required this.selected,
      required this.busy,
      required this.onTap});
  @override
  Widget build(BuildContext context) => CraftCard(
      color: selected ? const Color(0xFFE9F2EC) : null,
      child: InkWell(
          onTap: busy ? null : onTap,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: selected
                        ? const Color(0xFF285448)
                        : const Color(0xFF9AA69C))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(bilingual(context, option.labelEn, option.labelHi),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Text(bilingual(context, option.reasonEn, option.reasonHi),
                      style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.55,
                          color: Color(0xFF6E776E))),
                  if (selected) ...[
                    const SizedBox(height: 9),
                    Text(
                        bilingual(
                            context,
                            'Applied to the preview below. Change or undo any time.',
                            'नीचे पूर्वावलोकन में लागू। कभी भी बदलें या हटाएँ।'),
                        style: const TextStyle(
                            fontSize: 10.5, color: Color(0xFF285448)))
                  ],
                  if (busy && selected) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(
                        color: Color(0xFF285448),
                        backgroundColor: Color(0xFFDDE7DF))
                  ]
                ]))
          ])));
}

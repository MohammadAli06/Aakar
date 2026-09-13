import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

class _ProductStudioScreenState extends ConsumerState<ProductStudioScreen> {
  int step = 0;
  Record draft = {};
  bool working = false, verified = false;
  PhotoPrep? prepared;
  PhotoPrep? selectedPrep;
  bool catalogPlainBackground = true;
  bool photoReviewed = true, catalogReviewed = false;
  final transcript = TextEditingController();

  // AI Vision analysis (shown in pricing step)
  bool _aiLoading = false;
  bool _aiChipExpanded = false;
  Map<String, dynamic>? _aiResult;

  String t(String en, String hi) => bilingual(context, en, hi);
  String catalogText(String key) => t(
      '${draft[key] ?? ''}',
      '${draft['${key}_hi'] ?? ''}'.trim().isEmpty
          ? '${draft[key] ?? ''}'
          : '${draft['${key}_hi']}');
  @override
  void initState() {
    super.initState();
    final repo = ref.read(commerceProvider);
    draft = {...?repo.lookup('products', widget.productId)};
    catalogReviewed = widget.productId != null;
    photoReviewed = draft['photo_reviewed'] != false;
    catalogPlainBackground = draft['catalog_plain_background'] != false;
    transcript.text = '${draft['transcript'] ?? ''}';
    prepared = photoPrepOptions
        .where((option) => option.mode.name == '${draft['prepared']}')
        .map((option) => option.mode)
        .firstOrNull;
    if (widget.productId != null) step = 2;
  }

  @override
  void dispose() {
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
      catalogReviewed = false;
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
      message(
          '${t('Photo preparation failed; your previous photo is unchanged.', 'फ़ोटो तैयार नहीं हुई; पिछली फ़ोटो सुरक्षित है।')} $e');
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

  Future<void> details({bool analyzePhoto = false}) async {
    if (working || !photoReviewed) return;
    final text = transcript.text.trim();
    Record assistance = {'fields': {}, 'provenance': 'Manual draft'};
    final original = '${draft['original_image'] ?? draft['image'] ?? ''}';
    setState(() => working = true);
    if ((!catalogReviewed || analyzePhoto) && StudioService.isPhoto(original)) {
      try {
        assistance = await ref
            .read(studioServiceProvider)
            .analyze(original, text, t('en', 'hi'));
      } catch (e) {
        message(
            '${t('Photo suggestions unavailable. You can enter the details manually.', 'फ़ोटो से सुझाव नहीं मिले। विवरण खुद भर सकते हैं।')} $e');
      }
    }
    if (!mounted) return;
    setState(() => working = false);
    final initial = mergeCatalogSuggestions({
      'description': '',
      'material': '',
      'available': true,
      'stock': 0,
      'capacity': 0,
      'location': ref.read(commerceProvider).profile['location'],
      ...draft,
    }, Map<String, dynamic>.from(assistance['fields'] as Map));
    if ('${initial['description'] ?? ''}'.trim().isEmpty) {
      initial['description'] = text;
    }
    final questions = (assistance['questions'] as List? ?? []).join('\n');
    final evidence =
        Map<String, dynamic>.from(assistance['evidence'] as Map? ?? {});
    final evidenceText = evidence.entries.map((e) {
      final label = productFields.where((f) => f.key == e.key).firstOrNull;
      return '${label == null ? e.key : t(label.en, label.hi)}: ${(e.value as Map)['reason']}';
    }).join('\n');
    final d = await craftForm(
        context,
        t('Review catalog & fill gaps', 'कैटलॉग जाँचें और कमी भरें'),
        productFields,
        initial: initial,
        description:
            '${t('Photo suggestions need your review. Price, measurements and capacity stay manual.', 'फ़ोटो के सुझाव जाँचें। कीमत, माप और क्षमता खुद भरें।')}\n$evidenceText\n$questions');
    if (d != null && mounted)
      setState(() {
        draft = {...draft, ...d, 'transcript': text};
        verified = false;
        catalogReviewed = true;
        step = 2;
      });
  }

  Future<void> price() async {
    // Pre-fill complexity from AI if available, else keep draft value
    final aiComplexity = _aiResult?['complexity_score'];
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

  /// Calls /pricing/analyze-image to get GPT vision assessment.
  /// Result is shown as a chip in step 3 UI.
  Future<void> _analyzeForPricing() async {
    final productId = widget.productId ?? draft['id'];
    if (productId == null) return;
    setState(() => _aiLoading = true);
    try {
      final data = await apiClient.post(
        '/pricing/analyze-image',
        data: {'product_id': '$productId'},
      );
      if (mounted) {
        setState(() {
          _aiResult = data as Map<String, dynamic>;
          _aiLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _aiLoading = false);
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
                                'White-background edits and photo suggestions use OpenAI through our backend. Your original is kept. Compare AI edits carefully: colour, shape and craft details can change.',
                                'सफ़ेद बैकग्राउंड और फ़ोटो के सुझाव हमारे सर्वर से OpenAI का उपयोग करते हैं। मूल फ़ोटो सुरक्षित रहती है। AI के बदलाव जाँचें: रंग, आकार या शिल्प बदल सकता है।')),
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
                        if (const ['gemini', 'openai']
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
                        CraftButton(
                            t('Review catalog details', 'कैटलॉग विवरण जाँचें'),
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
                              DetailRow(t('Material', 'सामग्री'),
                                  '${draft['material'] ?? ''}'),
                              DetailRow(t('Dimensions', 'माप'),
                                  '${draft['dimensions'] ?? ''}'),
                              DetailRow(t('Craft', 'शिल्प'),
                                  '${draft['craft'] ?? ''}'),
                              CraftButton(
                                  t('Listen to my catalog',
                                      'मेरा कैटलॉग सुनें'),
                                  secondary: true,
                                  onPressed: () => speakCraft(context,
                                      '${catalogText('title')}. ${catalogText('description')}. ${draft['material'] ?? ''}. ${draft['dimensions'] ?? ''}.')),
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
                              if (StudioService.isPhoto(
                                  '${draft['original_image'] ?? draft['image'] ?? ''}'))
                                CraftButton(
                                    t('Suggest missing details from photo',
                                        'फ़ोटो से बाकी विवरण सुझाएँ'),
                                    secondary: true,
                                    onPressed: working
                                        ? null
                                        : () => details(analyzePhoto: true)),
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
                        GestureDetector(
                          onTap: () => setState(
                              () => _aiChipExpanded = !_aiChipExpanded),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: _aiLoading
                                  ? const Color(0xFFF5F5F0)
                                  : (_aiResult?['is_fallback'] == true)
                                      ? const Color(0xFFF5F5F0)
                                      : const Color(0xFFEAF3EA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _aiLoading
                                    ? const Color(0xFFDDDDDD)
                                    : (_aiResult?['is_fallback'] == true)
                                        ? const Color(0xFFDDDDDD)
                                        : const Color(0xFF5A7A5C)
                                            .withValues(alpha: 0.4),
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
                                    Text(
                                        '🤖  Analyzing your product photo…',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6E796A))),
                                  ])
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Text(
                                          _aiResult?['is_fallback'] == true
                                              ? '⚙️'
                                              : '🤖',
                                          style:
                                              const TextStyle(fontSize: 15),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _aiResult == null
                                                ? 'AI analysis unavailable'
                                                : _aiResult!['is_fallback'] ==
                                                        true
                                                    ? 'Adjust craftsmanship manually (AI unavailable)'
                                                    : '🤖 AI assessed: ${((_aiResult!['complexity_score'] as num) * 100).toInt()}% craftsmanship  •  ${_aiResult!['material_tier']} material',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: _aiResult?[
                                                          'is_fallback'] ==
                                                      true
                                                  ? const Color(0xFF6E796A)
                                                  : const Color(0xFF285448),
                                            ),
                                          ),
                                        ),
                                        if (_aiResult?['is_fallback'] !=
                                            true)
                                          Icon(
                                            _aiChipExpanded
                                                ? Icons.expand_less_rounded
                                                : Icons.expand_more_rounded,
                                            size: 18,
                                            color: const Color(0xFF6E796A),
                                          ),
                                      ]),
                                      // Progress bar for complexity
                                      if (_aiResult?['is_fallback'] != true)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: (_aiResult![
                                                      'complexity_score']
                                                  as num)
                                                  .toDouble(),
                                              minHeight: 5,
                                              backgroundColor:
                                                  const Color(0xFFDDE7DF),
                                              color: const Color(0xFF5A7A5C),
                                            ),
                                          ),
                                        ),
                                      // Expandable reasoning
                                      if (_aiChipExpanded &&
                                          _aiResult?['is_fallback'] != true)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 10),
                                          child: Text(
                                            bilingual(
                                                context,
                                                '${_aiResult!['reasoning_en']}',
                                                '${_aiResult!['reasoning_hi']}'),
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
                        ),

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

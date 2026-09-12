import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  final transcript = TextEditingController();
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

  bool _isPhotoFile(String source) =>
      source.startsWith('/') || source.contains(':\\');

  /// Prepare the photo from the untouched original, so switching between
  /// options never stacks one correction on top of another.
  Future<void> prepare(PhotoPrep mode) async {
    if (working) return;
    final source = '${draft['original_image'] ?? draft['image']}';
    if (!_isPhotoFile(source)) {
      // Sample illustrations are drawn, and a photo already stored on the
      // server would have to be downloaded first — neither can be prepared here.
      message(source.startsWith('http')
          ? t('This photo is stored on the server. Take or choose it again to prepare it here.',
              'यह फ़ोटो सर्वर पर है। यहाँ तैयार करने के लिए इसे दोबारा लें या चुनें।')
          : t('Preparation applies to a real photo. This is a sample illustration.',
              'यह तैयारी असली फ़ोटो पर लागू होती है। यह नमूना चित्र है।'));
      return;
    }
    setState(() => working = true);
    try {
      final path = await preparePhotoFile(source, mode);
      if (!mounted) return;
      setState(() {
        draft['original_image'] = source;
        draft['image'] = path;
        draft['prepared'] = mode.name;
        prepared = mode;
      });
    } catch (_) {
      message(t('Photo could not be processed. Try another photo.',
          'फ़ोटो प्रोसेस नहीं हुई। दूसरी फ़ोटो चुनें।'));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  void useOriginal() => setState(() {
        draft['image'] = draft['original_image'];
        draft['prepared'] = 'original';
        prepared = null;
      });

  Future<void> details() async {
    final text = transcript.text.trim();
    Record assistance = {'fields': {}, 'provenance': 'Manual draft'};
    if (text.isNotEmpty && widget.productId == null) {
      try {
        assistance = await ref
            .read(commerceProvider)
            .assist('catalog', text, t('en', 'hi'));
      } catch (e) {
        message('$e');
      }
    }
    if (!mounted) return;
    final lower = text.toLowerCase();
    // Deterministic fallback extracts only explicitly mentioned terms, leaving unknowns empty.
    final material = lower.contains('bamboo') || lower.contains('बाँस')
        ? 'Bamboo'
        : lower.contains('cotton') || lower.contains('कपास')
            ? 'Cotton'
            : lower.contains('clay') || lower.contains('मिट्टी')
                ? 'Clay'
                : '';
    final d = await craftForm(
        context,
        t('Review catalog & fill gaps', 'कैटलॉग जाँचें और कमी भरें'),
        productFields,
        initial: {
          'description': text,
          'material': material,
          'available': true,
          'stock': 0,
          'capacity': 0,
          'location': ref.read(commerceProvider).profile['location'],
          ...Map<String, dynamic>.from(assistance['fields'] as Map),
          ...draft
        },
        description:
            '${assistance['provenance']} · ${t('Confirm material, size and craft terms. Missing fields remain editable.', 'सामग्री, माप और शिल्प जाँचें। बाकी विवरण भरें।')}');
    if (d != null && mounted)
      setState(() {
        draft = {...draft, ...d, 'transcript': text};
        verified = false;
        step = 2;
      });
  }

  Future<void> price() async {
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
          'complexity': draft['complexity'] ?? .5
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
        canPop: step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          setState(() => step -= 1);
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
                      onPressed: handleBack,
                      icon: Icon(
                          step > 0 ? Icons.arrow_back : Icons.close_rounded)),
                  const SizedBox(width: 4),
                ]),
            body: SafeArea(
                child: ListView(padding: const EdgeInsets.all(20), children: [
              LinearProgressIndicator(
                  value: (step + 1) / 4,
                  color: const Color(0xFF285448),
                  backgroundColor: const Color(0xFFE4E9DE)),
              const SizedBox(height: 14),
              Text(
                  '${step + 1} / 4 · ${t('Photo → catalog → review → pricing', 'फ़ोटो → कैटलॉग → जाँच → कीमत')}',
                  style: const TextStyle(fontSize: 10)),
              if (step == 0) ...[
                CraftHeading(t('Let your craft shine', 'अपने शिल्प को निखारें'),
                    subtitle: t(
                        'Use natural light, center the whole product, choose a clear angle, and keep the original colour and texture visible.',
                        'प्राकृतिक रोशनी में पूरा उत्पाद बीच में रखें। असली रंग और बनावट साफ़ दिखें।')),
                Center(
                    child: CraftImage('${draft['image'] ?? 'pottery'}',
                        size: 240)),
                CraftButton(t('Take a photo', 'फ़ोटो लें'),
                    icon: Icons.camera_alt_outlined, onPressed: () async {
                  final path = await pickEvidence(context, camera: true);
                  if (path != null && mounted)
                    setState(() {
                      draft['image'] = path;
                      draft['original_image'] = path;
                    });
                }),
                CraftButton(t('Choose from gallery', 'गैलरी से चुनें'),
                    secondary: true, onPressed: () async {
                  final path = await pickEvidence(context);
                  if (path != null && mounted)
                    setState(() {
                      draft['image'] = path;
                      draft['original_image'] = path;
                    });
                }),
                CraftButton(
                    t('Use sample illustration (demo)', 'नमूना चित्र (डेमो)'),
                    secondary: true,
                    onPressed: () => setState(() {
                          draft['image'] = 'basket';
                          draft['original_image'] = 'basket';
                        })),
                if (draft['image'] != null)
                  CraftButton(
                      t('Next: prepare the photo', 'आगे: फ़ोटो तैयार करें'),
                      onPressed: () => setState(() => step = 1))
              ],
              if (step == 1) ...[
                CraftHeading(
                    t('Choose how to prepare this photo',
                        'यह फ़ोटो कैसे तैयार करें'),
                    subtitle: t(
                        'Each choice is one plain image operation, not a style or a filter. Your original is kept in full, and nothing about the product is invented.',
                        'हर विकल्प एक सीधा इमेज ऑपरेशन है, कोई स्टाइल या फ़िल्टर नहीं। मूल फ़ोटो पूरी सुरक्षित रहती है और उत्पाद में कुछ जोड़ा नहीं जाता।')),
                for (final option in photoPrepOptions)
                  _PrepOptionCard(
                      option: option,
                      selected: prepared == option.mode,
                      busy: working,
                      onTap: () => prepare(option.mode)),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                      child: Column(children: [
                    CraftImage('${draft['original_image']}', size: 150),
                    const SizedBox(height: 6),
                    Text(t('Original', 'मूल'),
                        style: const TextStyle(fontSize: 11))
                  ])),
                  Expanded(
                      child: Column(children: [
                    CraftImage('${draft['image']}', size: 150),
                    const SizedBox(height: 6),
                    Text(prepLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11))
                  ]))
                ]),
                if (prep != null)
                  CraftButton(
                      t('Use the original photo instead', 'मूल फ़ोटो ही रखें'),
                      secondary: true,
                      onPressed: working ? null : useOriginal),
                const SizedBox(height: 16),
                TextField(
                    controller: transcript,
                    minLines: 4,
                    maxLines: 7,
                    decoration: InputDecoration(
                        labelText: t('Tell us about your product',
                            'अपने उत्पाद के बारे में बताएँ'),
                        hintText: t(
                            'Material, size, how it is made, and its story…',
                            'सामग्री, माप, कैसे बनाया और कहानी…'),
                        suffixIcon: VoiceFieldButton(controller: transcript))),
                CraftButton(t('Review catalog details', 'कैटलॉग विवरण जाँचें'),
                    onPressed: details)
              ],
              if (step == 2) ...[
                CraftHeading(
                    t('Your words. Your approval.', 'आपकी बात। आपकी स्वीकृति।'),
                    subtitle: t(
                        'Read or listen, correct any field by voice, then approve. This is product verification, not identity verification.',
                        'पढ़ें या सुनें, बोलकर सुधारें और स्वीकारें। यह उत्पाद की जाँच है, पहचान की नहीं।')),
                CraftCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(catalogText('title'),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      Text(catalogText('description'),
                          style: const TextStyle(fontSize: 13, height: 1.6)),
                      DetailRow(
                          t('Photo preparation', 'फ़ोटो तैयारी'), prepLabel),
                      DetailRow(t('Material', 'सामग्री'),
                          '${draft['material'] ?? ''}'),
                      DetailRow(t('Dimensions', 'माप'),
                          '${draft['dimensions'] ?? ''}'),
                      DetailRow(t('Craft', 'शिल्प'), '${draft['craft'] ?? ''}'),
                      CraftButton(
                          t('Listen to my catalog', 'मेरा कैटलॉग सुनें'),
                          secondary: true,
                          onPressed: () => speakCraft(context,
                              '${catalogText('title')}. ${catalogText('description')}. ${draft['material'] ?? ''}. ${draft['dimensions'] ?? ''}.')),
                      CraftButton(
                          t('Replace product photo', 'उत्पाद की फ़ोटो बदलें'),
                          secondary: true,
                          onPressed: () => setState(() {
                                verified = false;
                                step = 0;
                              })),
                      CraftButton(
                          t('Correct details / voice edit',
                              'विवरण / आवाज़ से सुधारें'),
                          secondary: true,
                          onPressed: details),
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
                    onPressed: verified ? price : null)
              ],
              if (step == 3) ...[
                CraftHeading(
                    t('Handmade deserves a fair price',
                        'हस्तनिर्मित की उचित कीमत'),
                    subtitle: t(
                        'Your labour matters. Recommendations never go below your costs.',
                        'आपकी मेहनत की कीमत है। सुझाव लागत से कम नहीं होगा।')),
                CraftCard(
                    child: Column(children: [
                  DetailRow(
                      t('Material', 'सामग्री'), money(draft['material_cost'])),
                  DetailRow(t('Labour', 'श्रम'),
                      '${draft['labour_hours']} h × ${money(draft['hourly_rate'])}'),
                  DetailRow(
                      t('Overhead', 'अन्य खर्च'), money(draft['overhead'])),
                  const Divider(),
                  DetailRow(
                      t('Protected cost floor', 'न्यूनतम लागत'), money(floor)),
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
                  ...comparable.take(3).map(
                      (p) => DetailRow('${p['title']}', money(p['price']))),
                  CraftButton(t('Adjust costs', 'लागत बदलें'),
                      secondary: true, onPressed: price)
                ])),
                CraftButton(
                    t('Set final price & save', 'आखिरी कीमत तय करके सहेजें'),
                    onPressed: save),
                Text(
                    t('This saves a product. Publishing is a separate action in My Products.',
                        'यह उत्पाद सहेजता है। मेरे उत्पाद से अलग से प्रकाशित करें।'),
                    style: const TextStyle(fontSize: 11))
              ],
              const SizedBox(height: 30),
            ]))));
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

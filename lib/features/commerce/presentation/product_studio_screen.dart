import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as imaging;
import 'package:path_provider/path_provider.dart';
import '../data/commerce_repository.dart';
import '../domain/commerce_engine.dart';
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

  Future<void> enhance() async {
    if (working) return;
    setState(() => working = true);
    try {
      final source = '${draft['original_image'] ?? draft['image']}';
      if (source == 'basket' || source == 'pottery') {
        draft['image'] = source;
      } else {
        final decoded = imaging.decodeImage(await File(source).readAsBytes());
        if (decoded == null) throw WorkflowError('Cannot decode photo');
        // Modest exposure adjustment only. No generative replacement or shape/colour redesign.
        final result = imaging.adjustColor(decoded, brightness: 1.04);
        final dir = await getApplicationDocumentsDirectory();
        final path =
            '${dir.path}/enhanced-${DateTime.now().microsecondsSinceEpoch}.jpg';
        await File(path).writeAsBytes(imaging.encodeJpg(result, quality: 94));
        draft['image'] = path;
      }
      draft['original_image'] = source;
      if (mounted) setState(() => step = 1);
    } catch (_) {
      message(t('Photo could not be processed. Try another photo.',
          'फ़ोटो प्रोसेस नहीं हुई। दूसरी फ़ोटो चुनें।'));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

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
    return Scaffold(
        appBar: AppBar(title: Text(t('Product studio', 'उत्पाद स्टूडियो'))),
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
                child: CraftImage('${draft['image'] ?? 'pottery'}', size: 240)),
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
                  working
                      ? t('Preparing…', 'तैयार हो रहा है…')
                      : t('Preview gentle enhancement', 'हल्का सुधार देखें'),
                  onPressed: working ? null : enhance)
          ],
          if (step == 1) ...[
            CraftHeading(
                t('Authentic, before everything', 'सबसे पहले प्रामाणिकता'),
                subtitle: t(
                    'Original retained. A small lighting adjustment only; no redesign or generated product details.',
                    'मूल फ़ोटो सुरक्षित। केवल रोशनी का हल्का सुधार; उत्पाद नहीं बदला।')),
            Row(children: [
              Expanded(
                  child: Column(children: [
                CraftImage('${draft['original_image']}', size: 150),
                Text(t('Original', 'मूल'))
              ])),
              Expanded(
                  child: Column(children: [
                CraftImage('${draft['image']}', size: 150),
                Text(t('Enhanced preview', 'सुधार के बाद'))
              ]))
            ]),
            CraftButton(t('Keep original instead', 'मूल फ़ोटो रखें'),
                secondary: true,
                onPressed: () =>
                    setState(() => draft['image'] = draft['original_image'])),
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
                      t('Material', 'सामग्री'), '${draft['material'] ?? ''}'),
                  DetailRow(
                      t('Dimensions', 'माप'), '${draft['dimensions'] ?? ''}'),
                  DetailRow(t('Craft', 'शिल्प'), '${draft['craft'] ?? ''}'),
                  CraftButton(t('Listen to my catalog', 'मेरा कैटलॉग सुनें'),
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
                      onChanged: (v) => setState(() => verified = v == true))
                ])),
            CraftButton(t('Continue to pricing', 'कीमत तय करें'),
                onPressed: verified ? price : null)
          ],
          if (step == 3) ...[
            CraftHeading(
                t('Handmade deserves a fair price', 'हस्तनिर्मित की उचित कीमत'),
                subtitle: t(
                    'Your labour matters. Recommendations never go below your costs.',
                    'आपकी मेहनत की कीमत है। सुझाव लागत से कम नहीं होगा।')),
            CraftCard(
                child: Column(children: [
              DetailRow(
                  t('Material', 'सामग्री'), money(draft['material_cost'])),
              DetailRow(t('Labour', 'श्रम'),
                  '${draft['labour_hours']} h × ${money(draft['hourly_rate'])}'),
              DetailRow(t('Overhead', 'अन्य खर्च'), money(draft['overhead'])),
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
              ...comparable
                  .take(3)
                  .map((p) => DetailRow('${p['title']}', money(p['price']))),
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
        ])));
  }
}

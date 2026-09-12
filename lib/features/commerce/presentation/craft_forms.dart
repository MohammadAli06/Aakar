import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../domain/commerce_engine.dart';
import 'craft_widgets.dart';
import '../../capture/capture_flow.dart';

class CraftField {
  final String key, en, hi;
  final bool required, numeric, toggle, multiline;
  final List<String>? options;
  const CraftField(this.key, this.en, this.hi,
      {this.required = false,
      this.numeric = false,
      this.toggle = false,
      this.multiline = false,
      this.options});
}

Future<Record?> craftForm(
        BuildContext context, String title, List<CraftField> fields,
        {Record initial = const {}, String? description, String? button}) =>
    Navigator.of(context).push<Record>(MaterialPageRoute(
        builder: (_) => _CraftForm(
            title: title,
            fields: fields,
            initial: initial,
            description: description,
            button: button)));

class _CraftForm extends StatefulWidget {
  final String title;
  final List<CraftField> fields;
  final Record initial;
  final String? description, button;
  const _CraftForm(
      {required this.title,
      required this.fields,
      required this.initial,
      this.description,
      this.button});
  @override
  State<_CraftForm> createState() => _CraftFormState();
}

class _CraftFormState extends State<_CraftForm> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  late Record values;
  @override
  void initState() {
    super.initState();
    values = Map.of(widget.initial);
    for (final f in widget.fields) {
      if (!f.toggle)
        _controllers[f.key] =
            TextEditingController(text: '${values[f.key] ?? ''}');
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
          child: Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(20), children: [
                if (widget.description != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(widget.description!,
                          style: const TextStyle(fontSize: 12))),
                for (final f in widget.fields)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: f.toggle
                          ? SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text(bilingual(context, f.en, f.hi),
                                  style: const TextStyle(fontSize: 13)),
                              value: values[f.key] == true,
                              onChanged: (v) =>
                                  setState(() => values[f.key] = v))
                          : f.options != null
                              ? DropdownButtonFormField<String>(
                                  initialValue:
                                      f.options!.contains('${values[f.key]}')
                                          ? '${values[f.key]}'
                                          : null,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                      labelText:
                                          bilingual(context, f.en, f.hi)),
                                  items: f.options!
                                      .map((v) => DropdownMenuItem(
                                          value: v,
                                          child: Text(v.replaceAll('_', ' '),
                                              overflow: TextOverflow.ellipsis)))
                                      .toList(),
                                  onChanged: (v) => values[f.key] = v,
                                  validator: (v) => f.required && v == null
                                      ? bilingual(context, 'Choose an option',
                                          'विकल्प चुनें')
                                      : null)
                              : TextFormField(
                                  controller: _controllers[f.key],
                                  maxLines: f.multiline ? 3 : 1,
                                  keyboardType: f.numeric
                                      ? const TextInputType.numberWithOptions(
                                          decimal: true)
                                      : TextInputType.text,
                                  decoration: InputDecoration(
                                      labelText: bilingual(context, f.en, f.hi),
                                      suffixIcon: ['evidence', 'document', 'reference_image', 'attachment'].contains(f.key)
                                          ? IconButton(
                                              icon: const Icon(Icons.attach_file),
                                              onPressed: () async {
                                                final path =
                                                    await pickEvidence(context);
                                                if (path != null && mounted)
                                                  _controllers[f.key]!.text =
                                                      path;
                                              })
                                          : !f.numeric
                                              ? VoiceFieldButton(controller: _controllers[f.key]!)
                                              : null),
                                  validator: (v) {
                                    if (f.required && (v ?? '').trim().isEmpty)
                                      return bilingual(
                                          context, 'Required', 'ज़रूरी');
                                    if (f.numeric &&
                                        (v ?? '').isNotEmpty &&
                                        (double.tryParse(v!) == null ||
                                            number(v) < 0))
                                      return bilingual(
                                          context,
                                          'Enter a non-negative number',
                                          'सही संख्या भरें');
                                    return null;
                                  })),
                CraftButton(
                    widget.button ??
                        bilingual(
                            context, 'Save & continue', 'सहेजें और आगे बढ़ें'),
                    onPressed: () {
                  if (!_form.currentState!.validate()) return;
                  for (final f in widget.fields) {
                    if (!f.toggle && f.options == null)
                      values[f.key] = f.numeric
                          ? number(_controllers[f.key]!.text)
                          : _controllers[f.key]!.text.trim();
                    if (f.toggle) values[f.key] = values[f.key] == true;
                  }
                  Navigator.pop(context, values);
                }),
                const SizedBox(height: 30),
              ]))));
}

final _speech = SpeechToText();
final _tts = FlutterTts();

Future<void> speakCraft(BuildContext context, String text) async {
  try {
    await _tts.setLanguage(bilingual(context, 'en-IN', 'hi-IN'));
    await _tts.setSpeechRate(.43);
    await _tts.speak(text);
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(bilingual(
              context,
              'Speech playback is unavailable on this device.',
              'इस डिवाइस पर आवाज़ उपलब्ध नहीं है।'))));
  }
}

class VoiceFieldButton extends StatefulWidget {
  final TextEditingController controller;
  const VoiceFieldButton({super.key, required this.controller});
  @override
  State<VoiceFieldButton> createState() => _VoiceFieldButtonState();
}

class _VoiceFieldButtonState extends State<VoiceFieldButton> {
  bool listening = false;
  @override
  void dispose() {
    if (listening) _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
      tooltip: bilingual(
          context, 'Speak or correct this field', 'बोलकर भरें या सुधारें'),
      icon: Icon(listening ? Icons.stop_circle : Icons.mic_none, size: 20),
      onPressed: () async {
        if (listening) {
          await _speech.stop();
          if (mounted) setState(() => listening = false);
          return;
        }
        try {
          final available = await _speech.initialize();
          if (!mounted) return;
          if (!available) throw WorkflowError('Speech recognition unavailable');
          setState(() => listening = true);
          await _speech.listen(
              localeId: bilingual(context, 'en_IN', 'hi_IN'),
              onResult: (result) {
                if (!mounted) return;
                widget.controller.text = result.recognizedWords;
                if (result.finalResult) setState(() => listening = false);
              },
              listenFor: const Duration(seconds: 30));
        } catch (_) {
          if (!mounted) return;
          setState(() => listening = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(bilingual(
                  context,
                  'Allow microphone access and enable speech recognition, or type instead.',
                  'माइक और वॉइस सेवा चालू करें, या टाइप करें।'))));
        }
      });
}

Future<String?> pickEvidence(BuildContext context,
    {bool camera = false}) async {
  try {
    // Camera capture happens inside the app so the photo cannot be lost when
    // Android reclaims the activity behind the device camera app.
    if (camera) {
      return await captureProductPhoto(context);
    }
    final file = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1800, imageQuality: 88);
    if (file == null) return null;
    final directory = await getApplicationDocumentsDirectory();
    final saved = await File(file.path).copy(
        '${directory.path}/craft-${DateTime.now().microsecondsSinceEpoch}.jpg');
    return saved.path;
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(bilingual(
              context,
              'Photo unavailable. Check camera/photo permissions.',
              'फ़ोटो उपलब्ध नहीं। अनुमति जाँचें।'))));
    return null;
  }
}

const requestFields = [
  CraftField('reference_image', 'Reference image / design (optional)',
      'संदर्भ फ़ोटो / डिज़ाइन (वैकल्पिक)'),
  CraftField('product', 'Product needed', 'चाहिए उत्पाद', required: true),
  CraftField('quantity', 'Quantity (units)', 'मात्रा (इकाइयाँ)',
      numeric: true, required: true),
  CraftField('budget', 'Budget per unit (INR, 0 = discuss)',
      'प्रति इकाई बजट (₹, 0 = चर्चा)',
      numeric: true),
  CraftField('lead_days', 'Needed within (days)', 'कितने दिनों में चाहिए',
      numeric: true, required: true),
  CraftField('target_date', 'Target date (YYYY-MM-DD)', 'लक्ष्य तारीख'),
  CraftField('location', 'Delivery location', 'डिलीवरी स्थान', required: true),
  CraftField('customization', 'Customization / size / colour / logo',
      'बदलाव / आकार / रंग / लोगो',
      multiline: true),
  CraftField('specifications', 'Specifications / other requirements',
      'विशेष विवरण / अन्य ज़रूरतें',
      multiline: true),
  CraftField('packaging', 'Packaging preference', 'पैकिंग पसंद'),
  CraftField(
      'sample_required', 'Request sample approval', 'नमूना स्वीकृति चाहिए',
      toggle: true)
];
const productFields = [
  CraftField('title', 'Product title', 'उत्पाद नाम', required: true),
  CraftField('title_hi', 'Hindi product title', 'हिंदी उत्पाद नाम'),
  CraftField('description_hi', 'Hindi description', 'हिंदी विवरण',
      multiline: true),
  CraftField('description', 'Description', 'विवरण',
      required: true, multiline: true),
  CraftField('category', 'Category', 'श्रेणी', required: true, options: [
    'Baskets',
    'Pottery',
    'Textiles',
    'Woodcraft',
    'Metalcraft',
    'Jewelry',
    'Painting',
    'Leathercraft',
    'Other'
  ]),
  CraftField('craft', 'Craft / technique', 'शिल्प / तकनीक'),
  CraftField('material', 'Material', 'सामग्री', required: true),
  CraftField('colour', 'Real colour', 'असली रंग'),
  CraftField('dimensions', 'Size / dimensions', 'आकार / माप'),
  CraftField('usage', 'Usage', 'उपयोग'),
  CraftField('story', 'Craft story', 'शिल्प की कहानी', multiline: true),
  CraftField('location', 'Origin / pickup location', 'स्थान / पिकअप',
      required: true),
  CraftField('moq', 'Minimum order quantity', 'न्यूनतम ऑर्डर मात्रा',
      numeric: true),
  CraftField('stock', 'Current available stock', 'अभी उपलब्ध स्टॉक',
      numeric: true),
  CraftField('capacity', 'Production capacity / month', 'उत्पादन क्षमता / माह',
      numeric: true),
  CraftField(
      'lead_days', 'Average production time (days)', 'औसत उत्पादन समय (दिन)',
      numeric: true),
];

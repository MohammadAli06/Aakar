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

  /// Picks a date from a calendar instead of typing one, stored `yyyy-MM-dd`.
  /// A date field never asks for a time.
  final bool date;

  /// Adds a time picker after the calendar, stored `yyyy-MM-dd HH:mm`. Only for
  /// the few fields that genuinely need a clock time.
  final bool withTime;
  final List<String>? options;
  const CraftField(this.key, this.en, this.hi,
      {this.required = false,
      this.numeric = false,
      this.toggle = false,
      this.multiline = false,
      this.date = false,
      this.withTime = false,
      this.options});
}

Future<Record?> craftForm(
        BuildContext context, String title, List<CraftField> fields,
        {Record initial = const {},
        String? description,
        String? button,
        Map<String, List<String>>? sections}) =>
    Navigator.of(context).push<Record>(MaterialPageRoute(
        builder: (_) => _CraftForm(
            title: title,
            fields: fields,
            initial: initial,
            description: description,
            sections: sections,
            button: button)));

class _CraftForm extends StatefulWidget {
  final String title;
  final List<CraftField> fields;
  final Record initial;
  final String? description, button;
  final Map<String, List<String>>? sections;
  const _CraftForm(
      {required this.title,
      required this.fields,
      required this.initial,
      this.description,
      this.sections,
      this.button});
  @override
  State<_CraftForm> createState() => _CraftFormState();
}

class _CraftFormState extends State<_CraftForm> {
  int _step = 0;
  final _scroll = ScrollController();
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
      if (!f.toggle) {
        final raw = values[f.key];
        String initial;
        if (f.numeric && raw != null) {
          final d = double.tryParse('$raw');
          initial = (d != null && d == d.truncateToDouble())
              ? d.toInt().toString()
              : '$raw';
        } else {
          initial = '${raw ?? ''}';
        }
        _controllers[f.key] = TextEditingController(text: initial);
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  /// Opens the calendar for a date field and writes the chosen value back into
  /// the field's controller, so it flows through the normal save path.
  ///
  /// A date-only field stops after the calendar. Only a field marked [withTime]
  /// continues to a time picker.
  Future<void> _pickDate(CraftField field) async {
    final controller = _controllers[field.key]!;
    final now = DateTime.now();
    final first = DateTime(now.year - 1);
    final last = DateTime(now.year + 5);
    final existing = DateTime.tryParse(controller.text.trim());
    var initial = existing ?? now;
    // showDatePicker asserts when the initial date sits outside the range.
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first,
        lastDate: last);
    if (date == null || !mounted) return;

    var value = '${date.year}-${_two(date.month)}-${_two(date.day)}';
    if (field.withTime) {
      final time = await showTimePicker(
          context: context,
          initialTime: existing == null
              ? TimeOfDay.now()
              : TimeOfDay(hour: existing.hour, minute: existing.minute));
      if (time == null || !mounted) return;
      value = '$value ${_two(time.hour)}:${_two(time.minute)}';
    }
    setState(() => controller.text = value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
          child: Form(
              key: _form,
              child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (widget.description != null)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(widget.description!,
                              style: const TextStyle(fontSize: 12))),
                    if (widget.sections != null) ...[
                      Text(
                          '${_step + 1} / ${widget.sections!.length} · ${widget.sections!.keys.elementAt(_step)}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                          value: (_step + 1) / widget.sections!.length),
                      const SizedBox(height: 20),
                    ],
                    for (final f in widget.fields.where((f) =>
                        widget.sections == null ||
                        widget.sections!.values
                            .elementAt(_step)
                            .contains(f.key)))
                      Padding(
                          key: ValueKey(f.key),
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
                                      initialValue: f.options!
                                              .contains('${values[f.key]}')
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
                                      validator: (v) => f.required && v == null ? bilingual(context, 'Choose an option', 'विकल्प चुनें') : null)
                                  : TextFormField(
                                      controller: _controllers[f.key],
                                      // A date field is filled from the calendar, so
                                      // the keyboard is never used for it.
                                      readOnly: f.date,
                                      onTap: f.date ? () => _pickDate(f) : null,
                                      maxLines: f.multiline ? 3 : 1,
                                      keyboardType: f.numeric ? const TextInputType.numberWithOptions(decimal: false) : TextInputType.text,
                                      decoration: InputDecoration(
                                          labelText: bilingual(context, f.en, f.hi),
                                          hintText: f.date ? (f.withTime ? 'YYYY-MM-DD  HH:MM' : 'YYYY-MM-DD') : null,
                                          suffixIcon: f.date
                                              ? IconButton(tooltip: bilingual(context, 'Pick a date', 'तारीख चुनें'), icon: const Icon(Icons.calendar_month_outlined), onPressed: () => _pickDate(f))
                                              : ['evidence', 'document', 'reference_image', 'attachment'].contains(f.key)
                                                  ? IconButton(
                                                      icon: const Icon(Icons.attach_file),
                                                      onPressed: () async {
                                                        final path =
                                                            await pickEvidence(
                                                                context);
                                                        if (path != null &&
                                                            mounted)
                                                          _controllers[f.key]!
                                                              .text = path;
                                                      })
                                                  : !f.numeric
                                                      ? VoiceFieldButton(controller: _controllers[f.key]!)
                                                      : null),
                                      validator: (v) {
                                        if (f.required &&
                                            (v ?? '').trim().isEmpty)
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
                        widget.sections != null &&
                                _step < widget.sections!.length - 1
                            ? bilingual(context, 'Next', 'आगे')
                            : widget.button ??
                                bilingual(context, 'Save & continue',
                                    'सहेजें और आगे बढ़ें'), onPressed: () {
                      if (!_form.currentState!.validate()) return;
                      for (final f in widget.fields) {
                        if (!f.toggle && f.options == null)
                          values[f.key] = f.numeric
                              ? number(_controllers[f.key]!.text)
                              : _controllers[f.key]!.text.trim();
                        if (f.toggle) values[f.key] = values[f.key] == true;
                      }
                      if (widget.sections != null &&
                          _step < widget.sections!.length - 1) {
                        setState(() => _step++);
                        if (_scroll.hasClients) _scroll.jumpTo(0);
                      } else {
                        Navigator.pop(context, values);
                      }
                    }),
                    if (_step > 0)
                      TextButton(
                          onPressed: () {
                            setState(() => _step--);
                            if (_scroll.hasClients) _scroll.jumpTo(0);
                          },
                          child: Text(bilingual(context, 'Previous', 'पिछला'))),
                    const SizedBox(height: 30),
                  ]))));
}

final _speechToText = SpeechToText();
final _tts = FlutterTts();
int _speechGeneration = 0;

Future<void> stopCraftSpeech() async {
  _speechGeneration++;
  try {
    await _tts.stop();
  } catch (_) {}
}

/// Exposes the shared TTS instance so callers can register lifecycle handlers.
FlutterTts get craftTts => _tts;

Future<void> speakCraft(BuildContext context, String text,
    {bool silent = false}) async {
  final generation = ++_speechGeneration;
  try {
    await _tts.stop();
    if (!context.mounted || generation != _speechGeneration) return;
    await _tts.setLanguage(bilingual(context, 'en-IN', 'hi-IN'));
    await _tts.setSpeechRate(.43);
    if (!context.mounted || generation != _speechGeneration) return;
    await _tts.speak(text);
  } catch (_) {
    if (!silent && context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(bilingual(
              context,
              'Speech playback is unavailable on this device.',
              'इस डिवाइस पर आवाज़ उपलब्ध नहीं है।'))));
  }
}

/// Joins already-typed text with a fresh recognition result. Returns null while
/// there is nothing recognised yet, so typing during dictation is left untouched.
String? joinFieldDictation(String current, String spoken) {
  final words = spoken.trim();
  if (words.isEmpty) return null;
  if (current.trim().isEmpty) return words;
  if (current.endsWith(' ') || current.endsWith('\n')) return current + words;
  return '$current $words';
}

/// The slice of speech recognition a field dictation needs. Production wraps the
/// speech_to_text plugin; tests supply a fake so the append behaviour is verifiable
/// without a device microphone.
abstract class CraftDictation {
  Future<bool> start(
      {required String localeId,
      void Function(String words, bool isFinal)? onResult});
  Future<void> stop();
}

class _DeviceDictation implements CraftDictation {
  @override
  Future<bool> start(
      {required String localeId,
      void Function(String words, bool isFinal)? onResult}) async {
    if (!await _speechToText.initialize()) return false;
    await _speechToText.listen(
        onResult: (result) =>
            onResult?.call(result.recognizedWords, result.finalResult),
        listenOptions: SpeechListenOptions(
            localeId: localeId, listenFor: const Duration(seconds: 30)));
    return true;
  }

  @override
  Future<void> stop() => _speechToText.stop();
}

final _deviceDictation = _DeviceDictation();

class VoiceFieldButton extends StatefulWidget {
  final TextEditingController controller;

  /// Injectable for tests; production uses the shared on-device recognizer.
  final CraftDictation? dictation;
  const VoiceFieldButton({super.key, required this.controller, this.dictation});
  @override
  State<VoiceFieldButton> createState() => _VoiceFieldButtonState();
}

class _VoiceFieldButtonState extends State<VoiceFieldButton> {
  bool listening = false;

  // Dictation appends: the text already in the field is the base every result is
  // composed against, so pressing mic again continues the text instead of replacing it.
  String _base = '';
  String _lastApplied = '';

  CraftDictation get _dictation => widget.dictation ?? _deviceDictation;

  void _apply(String recognized, bool isFinal) {
    if (isFinal && mounted) setState(() => listening = false);
    final joined = joinFieldDictation(_base, recognized);
    if (joined == null || joined == _lastApplied) return;
    _lastApplied = joined;
    widget.controller.value = TextEditingValue(
        text: joined,
        selection: TextSelection.collapsed(offset: joined.length));
  }

  @override
  void dispose() {
    if (listening) _dictation.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = bilingual(context, 'en_IN', 'hi_IN');
    final failed = bilingual(
        context,
        'Allow microphone access and enable speech recognition, or type instead.',
        'माइक और वॉइस सेवा चालू करें, या टाइप करें।');
    return IconButton(
        tooltip: bilingual(
            context, 'Speak or correct this field', 'बोलकर भरें या सुधारें'),
        icon: Icon(listening ? Icons.stop_circle : Icons.mic_none, size: 20),
        onPressed: () async {
          if (listening) {
            await _dictation.stop();
            if (mounted) setState(() => listening = false);
            return;
          }
          try {
            final started = await _dictation.start(
                localeId: locale,
                onResult: (words, isFinal) {
                  if (mounted) _apply(words, isFinal);
                });
            if (!mounted) return;
            if (!started) throw WorkflowError('Speech recognition unavailable');
            // Snapshot the current field content so this session continues it.
            _base = widget.controller.text;
            _lastApplied = '';
            setState(() => listening = true);
          } catch (_) {
            if (!mounted) return;
            setState(() => listening = false);
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(failed)));
          }
        });
  }
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
  CraftField('target_date', 'Target date', 'लक्ष्य तारीख', date: true),
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
  CraftField('customizable', 'Buyer can ask for changes / size / colour',
      'खरीदार बदलाव / आकार / रंग माँग सकते हैं',
      toggle: true),
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

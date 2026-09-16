import 'package:flutter/material.dart';
import '../domain/commerce_engine.dart';
import 'craft_widgets.dart';
import 'craft_forms.dart';

class BuyerReviewPanel extends StatefulWidget {
  final Record order;
  final Future<bool> Function(Record) submit;
  const BuyerReviewPanel(
      {super.key, required this.order, required this.submit});
  @override
  State<BuyerReviewPanel> createState() => _BuyerReviewPanelState();
}

class _BuyerReviewPanelState extends State<BuyerReviewPanel> {
  late final text =
      TextEditingController(text: '${widget.order['review']?['text'] ?? ''}');
  late int rating = number(widget.order['review']?['rating']).toInt();
  late final tags = Set<String>.from(widget.order['review']?['tags'] ?? []);
  bool busy = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String t(String en, String hi) => bilingual(context, en, hi);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CraftHeading(t('Write a review', 'समीक्षा लिखें'),
          subtitle: '${widget.order['product_title']}'),
      if (widget.order['status'] != 'completed')
        Text(t('Reviews open after order completion.',
            'ऑर्डर पूरा होने के बाद समीक्षा करें।'))
      else ...[
        CraftCard(
            child: Column(children: [
          Text(t('How was your experience?', 'आपका अनुभव कैसा रहा?')),
          Wrap(children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                  tooltip: '$star ${t('stars', 'सितारे')}',
                  onPressed: busy ? null : () => setState(() => rating = star),
                  icon: Icon(
                      star <= rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: Colors.amber.shade800,
                      size: 34))
          ]),
          TextField(
              controller: text,
              maxLength: 500,
              maxLines: 5,
              decoration: InputDecoration(
                  labelText: t('Your feedback', 'आपकी प्रतिक्रिया'),
                  suffixIcon: VoiceFieldButton(controller: text))),
        ])),
        Text(t(
            'What did you like? (optional)', 'आपको क्या पसंद आया? (वैकल्पिक)')),
        Wrap(spacing: 6, children: [
          for (final tag in const {
            'Product quality': 'उत्पाद गुणवत्ता',
            'Communication': 'बातचीत',
            'Timely delivery': 'समय पर डिलीवरी',
            'Packaging': 'पैकिंग',
            'Professionalism': 'व्यावसायिक व्यवहार',
            'Value for money': 'उचित मूल्य'
          }.entries)
            FilterChip(
                label: Text(t(tag.key, tag.value)),
                selected: tags.contains(tag.key),
                onSelected: busy
                    ? null
                    : (v) => setState(
                        () => v ? tags.add(tag.key) : tags.remove(tag.key)))
        ]),
        CraftButton(t('Submit review', 'समीक्षा भेजें'),
            onPressed: busy || rating == 0
                ? null
                : () async {
                    setState(() => busy = true);
                    await widget.submit({
                      'id': widget.order['id'],
                      'rating': rating,
                      'text': text.text,
                      'tags': tags.toList()
                    });
                    if (mounted) setState(() => busy = false);
                  }),
      ]
    ]);
  }
}

/// A repeat purchase is a new RFQ using current products, never a copied acceptance.
class BuyerReorderPanel extends StatefulWidget {
  final Record order;
  final List<Record> products;
  final Future<bool> Function(Record) submit;
  const BuyerReorderPanel(
      {super.key,
      required this.order,
      required this.products,
      required this.submit});
  @override
  State<BuyerReorderPanel> createState() => _BuyerReorderPanelState();
}

class _BuyerReorderPanelState extends State<BuyerReorderPanel> {
  int step = 0;
  Record? selected;
  late final quantity =
      TextEditingController(text: '${widget.order['quantity']}');
  late final days = TextEditingController(text: '${widget.order['lead_days']}');
  late final location =
      TextEditingController(text: '${widget.order['location'] ?? ''}');
  late final customization =
      TextEditingController(text: '${widget.order['customization'] ?? ''}');
  final note = TextEditingController();
  bool busy = false, sample = false;
  String? error;
  @override
  void dispose() {
    for (final c in [quantity, days, location, customization, note]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String t(String en, String hi) => bilingual(context, en, hi);
    Widget field(TextEditingController c, String en, String hi,
            {bool numeric = false}) =>
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextField(
                controller: c,
                keyboardType:
                    numeric ? TextInputType.number : TextInputType.text,
                decoration: InputDecoration(
                    labelText: t(en, hi),
                    border: const OutlineInputBorder(),
                    suffixIcon:
                        numeric ? null : VoiceFieldButton(controller: c))));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CraftHeading(t('Repeat purchase', 'फिर खरीदें'),
          subtitle:
              t('Product → Details → Confirm', 'उत्पाद → विवरण → पुष्टि')),
      LinearProgressIndicator(value: (step + 1) / 3),
      const SizedBox(height: 16),
      if (error != null)
        Text(error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      if (step > 0)
        TextButton(
            onPressed: busy ? null : () => setState(() => step--),
            child: Text(t('Back', 'वापस'))),
      if (step == 0) ...[
        Text(t('Choose from this supplier’s current catalogue.',
            'इस आपूर्तिकर्ता के वर्तमान उत्पाद चुनें।')),
        if (widget.products.isEmpty)
          EmptyCraft(
              t('No products available', 'कोई उत्पाद उपलब्ध नहीं'),
              t('This supplier has no published products taking orders. Check again later.',
                  'इस आपूर्तिकर्ता का कोई उत्पाद अभी ऑर्डर नहीं ले रहा है।')),
        for (final p in widget.products)
          CraftCard(
              child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CraftImage('${p['image']}', size: 54),
                  title: Text('${p['title']}'),
                  subtitle: Text('${money(p['price'])} · MOQ ${p['moq']}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() {
                        selected = p;
                        step = 1;
                      }))),
      ],
      if (step == 1) ...[
        Text('${selected!['title']}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        field(quantity, 'Quantity', 'मात्रा', numeric: true),
        field(days, 'Required lead time (days)', 'समय सीमा (दिन)',
            numeric: true),
        field(location, 'Delivery location', 'डिलीवरी स्थान'),
        field(customization, 'Customization (optional)', 'बदलाव (वैकल्पिक)'),
        field(note, 'Note (optional)', 'टिप्पणी (वैकल्पिक)'),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t('Request a sample', 'नमूना माँगें')),
            value: sample,
            onChanged: (v) => setState(() => sample = v)),
        CraftButton(t('Review new request', 'नई माँग जाँचें'),
            onPressed: () => setState(() {
                  final q = double.tryParse(quantity.text),
                      d = double.tryParse(days.text);
                  if (q == null ||
                      !q.isFinite ||
                      q <= 0 ||
                      q < number(selected!['moq']) ||
                      d == null ||
                      !d.isFinite ||
                      d <= 0 ||
                      location.text.trim().isEmpty) {
                    error = t(
                        'Enter valid quantity (at least MOQ), lead time and location.',
                        'न्यूनतम मात्रा, समय और स्थान सही भरें।');
                    return;
                  }
                  error = null;
                  step = 2;
                })),
      ],
      if (step == 2) ...[
        CraftCard(
            child: Column(children: [
          Text('${selected!['title']}'),
          DetailRow(t('Quantity', 'मात्रा'), quantity.text),
          DetailRow(t('Current guide price', 'वर्तमान अनुमानित मूल्य'),
              money(selected!['price'])),
          DetailRow(t('Lead time', 'समय'), days.text),
          DetailRow(t('Delivery', 'डिलीवरी'), location.text),
          DetailRow(t('Customization', 'बदलाव'), customization.text),
          DetailRow(
              t('Sample', 'नमूना'),
              sample
                  ? t('Requested', 'चाहिए')
                  : t('Not requested', 'नहीं चाहिए'))
        ])),
        Text(t(
            'Send a fresh inquiry. Price, capacity, delivery and payment terms must be confirmed again.',
            'नई पूछताछ भेजें। मूल्य, क्षमता, डिलीवरी और भुगतान की शर्तें फिर तय होंगी।')),
        CraftButton(t('Confirm & send inquiry', 'पुष्टि करके पूछताछ भेजें'),
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    await widget.submit({
                      'product_id': selected!['id'],
                      'quantity': number(quantity.text),
                      'lead_days': number(days.text),
                      'location': location.text.trim(),
                      'customization': customization.text,
                      'specifications': note.text,
                      'budget': selected!['price'],
                      'sample_required': sample,
                      'source_order_id': widget.order['id']
                    });
                    if (mounted) setState(() => busy = false);
                  })
      ],
    ]);
  }
}

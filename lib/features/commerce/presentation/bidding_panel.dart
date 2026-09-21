import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/app_providers.dart';
import '../data/bidding_repository.dart';
import '../data/commerce_repository.dart';
import '../domain/commerce_engine.dart';
import 'craft_widgets.dart';

class BiddingPanel extends ConsumerStatefulWidget {
  final String? initialSessionId;
  const BiddingPanel({super.key, this.initialSessionId});
  @override
  ConsumerState<BiddingPanel> createState() => _BiddingPanelState();
}

class _BiddingPanelState extends ConsumerState<BiddingPanel> {
  Timer? timer;
  int step = -1;
  String tab = 'scheduled', query = '', decision = 'single';
  String? sessionId;
  Record? product, matching, editing;
  String? problem;
  bool working = false;
  final quantity = TextEditingController();
  final price = TextEditingController();
  final duration = TextEditingController(text: '120');
  DateTime start = DateTime.now().add(const Duration(hours: 1));
  DateTime end = DateTime.now().add(const Duration(hours: 3));
  final allocations = <String, TextEditingController>{};
  final selected = <String>{};
  String t(String en, String hi) => bilingual(context, en, hi);
  String get account => ref.read(sessionProvider).account?.id ?? 'signed-out';
  BiddingRepository get bids => ref.read(biddingProvider(account));
  CommerceRepository get commerce => ref.read(commerceProvider);
  bool get buyer =>
      (ref.read(sessionProvider).account?.role.name ?? commerce.role) ==
      'buyer';
  @override
  void initState() {
    super.initState();
    sessionId = widget.initialSessionId;
    timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true) && !working)
        bids.refresh();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    quantity.dispose();
    price.dispose();
    duration.dispose();
    for (final c in allocations.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> run(Future<void> Function() task) async {
    if (working) return;
    setState(() {
      working = true;
      problem = null;
    });
    try {
      await task();
    } catch (e) {
      if (mounted) setState(() => problem = '$e');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Widget button(String en, String hi, VoidCallback onTap,
          {bool secondary = false, bool enabled = true}) =>
      CraftButton(t(en, hi),
          secondary: secondary, onPressed: working || !enabled ? null : onTap);
  Widget heading(String en, String hi, [String? subtitle]) =>
      CraftHeading(t(en, hi), subtitle: subtitle);
  Widget info(String en, String hi) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(t(en, hi)));
  Widget input(TextEditingController c, String en, String hi) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
          controller: c,
          onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText: t(en, hi), border: const OutlineInputBorder())));
  void newSession() {
    setState(() {
      step = 0;
      product = null;
      editing = null;
      matching = null;
      sessionId = null;
      problem = null;
      quantity.clear();
      price.clear();
      duration.text = '120';
      start = DateTime.now().add(const Duration(hours: 1));
      end = DateTime.now().add(const Duration(hours: 3));
    });
  }

  String stamp(dynamic value) {
    final date = DateTime.parse('$value').toLocal();
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String label(String status) => switch (status) {
        'scheduled' => t('Upcoming', 'आगामी'),
        'live' => t('Live', 'जारी'),
        'closed' => t('Closed · review offers', 'समाप्त · ऑफ़र देखें'),
        'selected' => t('Offers selected', 'ऑफ़र चुने गए'),
        'quotation' => t('Quotation', 'कोटेशन'),
        'cancelled' => t('Cancelled', 'रद्द'),
        'rejected' => t('No offers selected', 'कोई ऑफ़र नहीं चुना'),
        _ => status,
      };
  @override
  Widget build(BuildContext context) {
    ref.watch(commerceProvider);
    final store = ref.watch(biddingProvider(account));
    final current =
        store.sessions.where((s) => s['id'] == sessionId).firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (step >= 0 || current != null)
        Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                onPressed: working
                    ? null
                    : () => setState(() {
                          if (step > 0) {
                            step--;
                          } else {
                            step = -1;
                            sessionId = null;
                          }
                          problem = null;
                        }),
                icon: const Icon(Icons.arrow_back),
                label: Text(t('Back', 'वापस')))),
      if (working) const LinearProgressIndicator(),
      if (problem != null)
        CraftCard(color: const Color(0xFFFFE9DC), child: Text(problem!)),
      if (store.error != null)
        CraftCard(
            child: Column(children: [
          Text(store.error!),
          button('Retry connection', 'फिर कोशिश करें', () => store.refresh(),
              secondary: true)
        ])),
      if (step >= 0)
        ...wizard()
      else if (current != null)
        ...session(current)
      else
        ...hub(store),
    ]);
  }

  List<Widget> hub(BiddingRepository store) {
    final filtered = store.sessions
        .where((s) => tab == 'completed'
            ? !['scheduled', 'live'].contains(s['status'])
            : s['status'] == tab)
        .toList();
    return [
      heading(
          'Bidding',
          'बोली',
          t('Your products. Your terms. Your decision.',
              'आपके उत्पाद। आपकी शर्तें। आपका निर्णय।')),
      if (!buyer)
        CraftCard(
            color: const Color(0xFFE6F1E8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.gavel_outlined, color: Color(0xFF285448)),
              heading('Create new bidding', 'नई बोली बनाएँ'),
              info(
                  'Choose existing stock and invite relevant verified buyers. Offers remain sealed until closing.',
                  'अपना स्टॉक चुनें और संबंधित सत्यापित खरीदारों को आमंत्रित करें। ऑफ़र अंत तक गुप्त रहेंगे।'),
              button('Select a product', 'उत्पाद चुनें', newSession),
            ])),
      if (buyer)
        info('Sessions matched to your verified account and open requirements.',
            'आपके सत्यापित खाते और खुली ज़रूरतों से मेल खाने वाले सत्र।'),
      Wrap(spacing: 8, children: [
        for (final value in ['scheduled', 'live', 'completed'])
          ChoiceChip(
              selected: tab == value,
              label: Text(
                  '${value == 'completed' ? t('Completed', 'समाप्त') : label(value)} (${store.sessions.where((s) => value == 'completed' ? ![
                      'scheduled',
                      'live'
                    ].contains(s['status']) : s['status'] == value).length})'),
              onSelected: (_) => setState(() => tab = value))
      ]),
      const SizedBox(height: 16),
      if (store.loading && store.sessions.isEmpty)
        const Center(child: CircularProgressIndicator())
      else if (filtered.isEmpty)
        CraftCard(
            child: info('No sessions here yet.', 'अभी कोई सत्र नहीं है।')),
      for (final s in filtered)
        CraftCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StatusPill(label(s['status'])),
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text('${s['product']['title']}'),
              subtitle: Text(
                  '${s['quantity']} ${t('pieces', 'पीस')} · ${money(s['min_price'])} / ${t('piece', 'पीस')}')),
          Text('${stamp(s['starts_at'])} – ${stamp(s['ends_at'])}'),
          button(
              'View session',
              'सत्र देखें',
              () => setState(() {
                    sessionId = s['id'];
                    selected.clear();
                  })),
        ])),
      button('Refresh sessions', 'सत्र अपडेट करें', () => store.refresh(),
          secondary: true),
      info(
          'Status refreshes every 15 seconds while this screen is open. Selection starts quotation; it does not create an order.',
          'यह स्क्रीन खुली होने पर स्थिति हर 15 सेकंड में अपडेट होती है। चयन से कोटेशन शुरू होता है, ऑर्डर नहीं बनता।'),
    ];
  }

  List<Widget> wizard() {
    const titles = [
      'Select a product',
      'Product preview',
      'Set bidding details',
      'Relevant buyers',
      'Confirm & schedule'
    ];
    const hindi = [
      'उत्पाद चुनें',
      'उत्पाद की जाँच',
      'बोली का विवरण',
      'संबंधित खरीदार',
      'जाँचें और तय करें'
    ];
    return [
      Text('${step + 1} / 5'),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: (step + 1) / 5),
      const SizedBox(height: 18),
      heading(titles[step], hindi[step]),
      if (step == 0) ...[
        TextField(
            decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: t('Search your products', 'अपने उत्पाद खोजें')),
            onChanged: (value) => setState(() => query = value.toLowerCase())),
        if (commerce.products.isEmpty)
          info('Save a product in My Products first.',
              'पहले मेरे उत्पाद में उत्पाद सहेजें।'),
        for (final p in commerce.products
            .where((p) => '${p['title']}'.toLowerCase().contains(query)))
          CraftCard(
              child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${p['title']}'),
                  subtitle: Text(
                      '${money(p['price'])} · ${t('Stock', 'स्टॉक')}: ${p['stock'] ?? 0}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() {
                        product = p;
                        step = 1;
                      }))),
      ],
      if (step == 1 && product != null) ...[
        productCard(product!),
        button('Edit product', 'उत्पाद बदलें',
            () => context.push('/workspace/product/${product!['id']}'),
            secondary: true),
        button(
            'Put up for bidding',
            'बोली के लिए रखें',
            () => run(() async {
                  matching = await bids.matches('${product!['id']}',
                      sessionId: editing?['id']);
                  quantity.text = '${matching!['available_stock']}';
                  price.text =
                      '${product!['price'] ?? matching!['cost_floor']}';
                  if (mounted) setState(() => step = 2);
                })),
      ],
      if (step == 2) ...[
        DetailRow(t('Unreserved stock', 'उपलब्ध स्टॉक'),
            '${matching?['available_stock'] ?? product?['stock']}'),
        input(quantity, 'Available quantity (pieces)', 'उपलब्ध मात्रा (पीस)'),
        input(price, 'Minimum unit price (₹)', 'न्यूनतम प्रति पीस मूल्य (₹)'),
        info(
            'Cost floor: ${money(matching?['cost_floor'] ?? product?['cost_floor'])}. Choose your own minimum price.',
            'लागत: ${money(matching?['cost_floor'] ?? product?['cost_floor'])}। न्यूनतम मूल्य आप तय करें।'),
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.play_circle_outline, color: Color(0xFF285448)),
            title: Text(t('Start date & time (local)',
                'शुरू होने की तारीख और समय (स्थानीय)')),
            subtitle: Text(stamp(start.toIso8601String())),
            onTap: () async {
              final date = await showDatePicker(
                  context: context,
                  initialDate:
                      start.isBefore(DateTime.now()) ? DateTime.now() : start,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)));
              if (date == null || !mounted) return;
              final time = await showTimePicker(
                  context: context, initialTime: TimeOfDay.fromDateTime(start));
              if (time != null && mounted) {
                setState(() {
                  final newStart = DateTime(
                      date.year, date.month, date.day, time.hour, time.minute);
                  final diff = end.difference(start);
                  start = newStart;
                  // Keep end after start if start moved past it
                  if (!end.isAfter(start)) {
                    end = start.add(
                        diff.inMinutes > 0 ? diff : const Duration(hours: 2));
                  }
                  duration.text = '${end.difference(start).inMinutes}';
                });
              }
            }),
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.stop_circle_outlined,
                color: Color(0xFFC25E00)),
            title: Text(t('End date & time (local)',
                'समाप्त होने की तारीख और समय (स्थानीय)')),
            subtitle: Text(stamp(end.toIso8601String())),
            onTap: () async {
              final date = await showDatePicker(
                  context: context,
                  initialDate: end.isBefore(start)
                      ? start.add(const Duration(hours: 1))
                      : end,
                  firstDate: start,
                  lastDate: start.add(const Duration(days: 7)));
              if (date == null || !mounted) return;
              final time = await showTimePicker(
                  context: context, initialTime: TimeOfDay.fromDateTime(end));
              if (time != null && mounted) {
                final newEnd = DateTime(
                    date.year, date.month, date.day, time.hour, time.minute);
                if (newEnd.isAfter(start)) {
                  setState(() {
                    end = newEnd;
                    duration.text = '${end.difference(start).inMinutes}';
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(t('End time must be after start time',
                          'समाप्ति का समय शुरू होने के समय के बाद होना चाहिए'))));
                }
              }
            }),
        input(duration, 'Or set duration (minutes)', 'या अवधि भरें (मिनट)'),
        button(
            'Find relevant buyers',
            'संबंधित खरीदार खोजें',
            () => run(() async {
                  // Keep end in sync with duration in case user typed duration
                  final m = int.tryParse(duration.text);
                  if (m != null && m > 0) {
                    end = start.add(Duration(minutes: m));
                  }
                  validate();
                  matching = await bids.matches('${product!['id']}',
                      sessionId: editing?['id']);
                  if (mounted) setState(() => step = 3);
                })),
      ],
      if (step == 3) ...[
        info(
            '${records(matching?['buyers']).length} verified buyers with matching open requirements.',
            '${records(matching?['buyers']).length} सत्यापित खरीदारों की ज़रूरतें मेल खाती हैं।'),
        for (final b in records(matching?['buyers']))
          CraftCard(
              child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text('${b['name']}'),
                  subtitle: Text('${b['type']}\n${b['reason']}'))),
        if (records(matching?['buyers']).isEmpty)
          info(
              'No matches yet. Try again when buyers post relevant requirements.',
              'अभी कोई मेल नहीं मिला। खरीदार की संबंधित ज़रूरत आने पर फिर कोशिश करें।'),
        button('Continue', 'आगे बढ़ें', () => setState(() => step = 4),
            enabled: records(matching?['buyers']).isNotEmpty),
      ],
      if (step == 4) ...[
        productCard(product!),
        CraftCard(
            child: Column(children: [
          DetailRow(t('Quantity', 'मात्रा'), quantity.text),
          DetailRow(t('Minimum / piece', 'न्यूनतम / पीस'), money(price.text)),
          DetailRow(t('Starts', 'शुरू'), stamp(start.toIso8601String())),
          DetailRow(t('Ends', 'समाप्त'), stamp(end.toIso8601String())),
          DetailRow(t('Matched buyers', 'खरीदार'),
              '${records(matching?['buyers']).length}')
        ])),
        info(
            'Offers stay sealed until the end. You can edit or cancel before the start. Unsold quantity stays yours.',
            'ऑफ़र अंत तक गुप्त रहेंगे। शुरू होने से पहले बदलाव या रद्द कर सकते हैं। बचा स्टॉक आपका रहेगा।'),
        button(
            editing == null ? 'Confirm & schedule' : 'Save schedule',
            'सत्र सहेजें',
            () => run(() async {
                  validate();
                  final s = await bids.save({
                    'product_id': product!['id'],
                    'quantity': int.parse(quantity.text),
                    'min_price': double.parse(price.text),
                    'starts_at': start.toUtc().toIso8601String(),
                    'ends_at': end.toUtc().toIso8601String(),
                    if (editing != null) 'revision': editing!['revision']
                  }, id: editing?['id']);
                  if (mounted)
                    setState(() {
                      step = -1;
                      sessionId = s['id'];
                    });
                })),
      ],
    ];
  }

  void validate() {
    final q = int.tryParse(quantity.text),
        p = double.tryParse(price.text),
        minutes = int.tryParse(duration.text);
    if (q == null ||
        q <= 0 ||
        p == null ||
        !p.isFinite ||
        p <= 0 ||
        minutes == null ||
        minutes < 1 ||
        minutes > 10080) {
      throw WorkflowError(t(
          'Enter a positive whole quantity, price and duration (1–10080 minutes).',
          'सही मात्रा, मूल्य और अवधि भरें (1–10080 मिनट)।'));
    }
    if (!start.isAfter(bids.serverNow.toLocal()))
      throw WorkflowError(
          t('Choose a future start time.', 'भविष्य का समय चुनें।'));
    if (!end.isAfter(start))
      throw WorkflowError(t('End time must be after start time.',
          'समाप्ति का समय शुरू होने के बाद होना चाहिए।'));
  }

  Widget productCard(Record p) => CraftCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if ('${p['image'] ?? ''}'.isNotEmpty)
          ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CraftImage('${p['image']}', size: 170)),
        const SizedBox(height: 12),
        Text('${p['title']}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text('${p['description'] ?? ''}'),
        DetailRow(t('Category', 'श्रेणी'), '${p['category'] ?? ''}'),
        DetailRow(t('Material', 'सामग्री'), '${p['material'] ?? ''}'),
        DetailRow(t('Stock', 'स्टॉक'), '${p['stock'] ?? 0}'),
      ]));
  List<Widget> session(Record s) {
    final status = '${s['status']}';
    final offers = records(s['offers'])
      ..sort((a, b) => number(b['price']).compareTo(number(a['price'])));
    final mine = s['my_offer'] as Map?;
    return [
      heading(label(status), label(status)),
      productCard(Map<String, dynamic>.from(s['product'])),
      CraftCard(
          child: Column(children: [
        DetailRow(t('Quantity', 'मात्रा'), '${s['quantity']}'),
        DetailRow(t('Minimum / piece', 'न्यूनतम / पीस'), money(s['min_price'])),
        DetailRow(t('Starts', 'शुरू'), stamp(s['starts_at'])),
        DetailRow(t('Ends', 'समाप्त'), stamp(s['ends_at'])),
        DetailRow(t('Offers received', 'प्राप्त ऑफ़र'), '${s['offer_count']}'),
        if (!buyer)
          DetailRow(
              t('Matched buyers', 'संबंधित खरीदार'), '${s['buyer_count']}'),
      ])),
      if (status == 'scheduled' && !buyer) ...[
        button(
            'Edit session',
            'सत्र बदलें',
            () => run(() async {
                  matching = await bids.matches('${s['product']['id']}',
                      sessionId: s['id']);
                  editing = s;
                  product = Map<String, dynamic>.from(s['product']);
                  quantity.text = '${s['quantity']}';
                  price.text = '${s['min_price']}';
                  start = DateTime.parse(s['starts_at']).toLocal();
                  end = DateTime.parse(s['ends_at']).toLocal();
                  duration.text = '${end.difference(start).inMinutes}';
                  if (mounted) setState(() => step = 2);
                })),
        button(
            'Cancel session',
            'सत्र रद्द करें',
            () => confirmAction(
                s, 'cancel', t('Cancel this session?', 'सत्र रद्द करें?')),
            secondary: true),
      ],
      if (status == 'live') ...[
        CraftCard(
            color: const Color(0xFFE6F1E8),
            child: Column(children: [
              const Icon(Icons.lock_outline),
              info(
                  'Bidding is sealed. Other offers are revealed only to the artisan after closing.',
                  'बोली गुप्त है। अंत के बाद केवल कारीगर को दूसरे ऑफ़र दिखेंगे।'),
              Text(
                  '${t('Time remaining', 'शेष समय')}: ${remaining(s['ends_at'])}')
            ])),
        if (buyer) ...[
          if (mine != null)
            DetailRow(t('Your sealed offer', 'आपका गुप्त ऑफ़र'),
                '${mine['quantity']} × ${money(mine['price'])}'),
          button(
              mine == null ? 'Place sealed offer' : 'Modify offer',
              mine == null ? 'गुप्त ऑफ़र दें' : 'ऑफ़र बदलें',
              () => offerDialog(s)),
          if (mine != null)
            button(
                'Withdraw offer',
                'ऑफ़र वापस लें',
                () => confirmAction(
                    s, 'withdraw', t('Withdraw your offer?', 'ऑफ़र वापस लें?')),
                secondary: true),
        ],
      ],
      if (status == 'closed' && !buyer) ...[
        heading('Compare offers', 'ऑफ़र की तुलना'),
        if (offers.isEmpty)
          info(
              'No acceptable offers? Keep the product available for normal B2B or create another session.',
              'कोई ऑफ़र नहीं? उत्पाद सामान्य B2B के लिए रखें या नया सत्र बनाएँ।'),
        for (final o in offers)
          CraftCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('${o['name']}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                DetailRow(t('Unit price', 'प्रति पीस'), money(o['price'])),
                DetailRow(t('Requested quantity', 'माँगी गई मात्रा'),
                    '${o['quantity']}'),
                Text('${o['reliability']}'),
                Text('${o['fit']}'),
                if ('${o['note']}'.isNotEmpty) Text('${o['note']}'),
              ])),
        if (offers.isNotEmpty) ...[
          heading('Your decision', 'आपका निर्णय'),
          DropdownButtonFormField<String>(
              initialValue: decision,
              isExpanded: true,
              items: [
                DropdownMenuItem(
                    value: 'single',
                    child: Text(t('Select one buyer', 'एक खरीदार चुनें'))),
                DropdownMenuItem(
                    value: 'multiple',
                    child: Text(
                        t('Split between buyers', 'कई खरीदारों में बाँटें')))
              ],
              onChanged: (v) => setState(() {
                    decision = v!;
                    selected.clear();
                  })),
          for (final o in offers)
            Column(children: [
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${o['name']}'),
                  value: selected.contains(o['buyer_id']),
                  onChanged: (v) => setState(() {
                        if (decision == 'single') selected.clear();
                        if (v == true) {
                          selected.add(o['buyer_id']);
                          allocations.putIfAbsent(
                              o['buyer_id'],
                              () => TextEditingController(
                                  text: '${o['quantity']}'));
                        } else {
                          selected.remove(o['buyer_id']);
                        }
                      })),
              if (selected.contains(o['buyer_id']))
                input(
                    allocations[o['buyer_id']]!,
                    'Allocate quantity (max ${o['quantity']})',
                    'मात्रा बाँटें (अधिकतम ${o['quantity']})'),
            ]),
          DetailRow(t('Total allocated', 'कुल आवंटित'),
              '${selected.fold<int>(0, (total, id) => total + (int.tryParse(allocations[id]?.text ?? '') ?? 0))} / ${s['quantity']}'),
          button(
              'Confirm allocation',
              'मात्रा की पुष्टि करें',
              () => run(() async {
                    final values = <String, int>{};
                    for (final id in selected) {
                      final q = int.tryParse(allocations[id]!.text);
                      if (q == null || q <= 0)
                        throw WorkflowError(t(
                            'Enter a positive whole quantity.',
                            'सही मात्रा भरें।'));
                      values[id] = q;
                    }
                    if (values.values.fold<int>(0, (total, q) => total + q) >
                            number(s['quantity']) ||
                        values.entries.any((entry) =>
                            entry.value >
                            number(offers.firstWhere((o) =>
                                o['buyer_id'] == entry.key)['quantity']))) {
                      throw WorkflowError(t(
                          'Allocation exceeds the lot or a buyer offer.',
                          'आवंटन उपलब्ध मात्रा या खरीदार के ऑफ़र से अधिक है।'));
                    }
                    await bids.act(s, 'select', {'allocations': values});
                  }),
              enabled: selected.isNotEmpty),
        ],
        button(
            'Reject all offers',
            'सभी ऑफ़र अस्वीकार करें',
            () => confirmAction(
                s,
                'reject',
                t('Reject all offers and release this stock?',
                    'सभी ऑफ़र अस्वीकार करें और स्टॉक मुक्त करें?')),
            secondary: true),
      ],
      if (buyer && !['scheduled', 'live'].contains(status))
        info(
            (s['allocations'] as Map).isEmpty
                ? 'No quantity allocated to you.'
                : 'Your allocation: ${s['allocations'][account]} pieces. Final terms require a quotation.',
            (s['allocations'] as Map).isEmpty
                ? 'आपको कोई मात्रा नहीं दी गई।'
                : 'आपकी मात्रा: ${s['allocations'][account]} पीस। अंतिम शर्तों के लिए कोटेशन ज़रूरी है।'),
      if (buyer &&
          status == 'selected' &&
          (s['allocations'] as Map).containsKey(account))
        button(
            'Withdraw selected offer',
            'चुना गया ऑफ़र वापस लें',
            () => confirmAction(
                s,
                'withdraw',
                t('Withdraw before quotation?',
                    'कोटेशन से पहले ऑफ़र वापस लें?')),
            secondary: true),
      if (['selected', 'quotation'].contains(status)) ...[
        for (final e in (s['allocations'] as Map).entries)
          DetailRow(
              records(s['buyers'])
                      .where((b) => b['id'] == e.key)
                      .firstOrNull?['name'] ??
                  '${e.key}',
              '${e.value} ${t('pieces', 'पीस')}'),
        info(
            'Continue with quotation, delivery terms and buyer confirmation. Order and payment steps in the current B2B workspace are demo records.',
            'कोटेशन, डिलीवरी की शर्तों और खरीदार की पुष्टि के साथ आगे बढ़ें। वर्तमान B2B में ऑर्डर और भुगतान डेमो रिकॉर्ड हैं।'),
        if (!buyer && status == 'selected')
          button(
              'Proceed to quotation',
              'कोटेशन पर जाएँ',
              () => run(() async {
                    await bids.act(s, 'handoff');
                  })),
        for (final inquiry in records(s['inquiries']))
          if (!buyer || inquiry['buyer_id'] == commerce.actor)
            button(
                buyer
                    ? t('Open quotation', 'कोटेशन खोलें')
                    : '${t('Open quotation', 'कोटेशन खोलें')} · ${inquiry['buyer_name']}',
                buyer
                    ? t('Open quotation', 'कोटेशन खोलें')
                    : '${t('Open quotation', 'कोटेशन खोलें')} · ${inquiry['buyer_name']}',
                () => run(() async {
                      await commerce.importBiddingInquiry(
                          inquiry, Map<String, dynamic>.from(s['product']));
                      if (mounted)
                        context.push('/workspace/inquiry/${inquiry['id']}');
                    })),
      ],
      if (!buyer && ['cancelled', 'rejected', 'quotation'].contains(status))
        button('Create new bidding', 'नई बोली बनाएँ', newSession,
            secondary: true),
    ];
  }

  String remaining(dynamic end) {
    final left = DateTime.parse('$end').difference(bids.serverNow);
    if (left.isNegative)
      return t('Closing · refresh pending', 'समाप्त · अपडेट की प्रतीक्षा');
    return '${left.inHours}h ${left.inMinutes % 60}m ${left.inSeconds % 60}s';
  }

  Future<void> confirmAction(Record s, String action, String title) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(title: Text(title), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(t('Back', 'वापस'))),
              FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(t('Confirm', 'पुष्टि')))
            ]));
    if (yes == true && mounted)
      await run(() async {
        await bids.act(s, action);
      });
  }

  Future<void> offerDialog(Record s) async {
    final mine = s['my_offer'] as Map?;
    final q =
        TextEditingController(text: '${mine?['quantity'] ?? s['quantity']}');
    final p =
        TextEditingController(text: '${mine?['price'] ?? s['min_price']}');
    final note = TextEditingController(text: '${mine?['note'] ?? ''}');
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text(t('Your sealed offer', 'आपका गुप्त ऑफ़र')),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  input(q, 'Quantity', 'मात्रा'),
                  input(p, 'Unit price (₹)', 'प्रति पीस मूल्य (₹)'),
                  TextField(
                      controller: note,
                      maxLength: 1000,
                      decoration: InputDecoration(
                          labelText:
                              t('Requirements / note', 'ज़रूरत / टिप्पणी')))
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(t('Back', 'वापस'))),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(t('Save offer', 'ऑफ़र सहेजें')))
                ]));
    if (ok == true && mounted)
      await run(() async {
        final count = int.tryParse(q.text), amount = double.tryParse(p.text);
        if (count == null || amount == null || !amount.isFinite)
          throw WorkflowError(t(
              'Enter valid quantity and price.', 'सही मात्रा और मूल्य भरें।'));
        await bids.act(s, 'offer',
            {'quantity': count, 'price': amount, 'note': note.text});
      });
    // Dialog route completes its reverse animation before its controllers are disposed.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    q.dispose();
    p.dispose();
    note.dispose();
  }
}

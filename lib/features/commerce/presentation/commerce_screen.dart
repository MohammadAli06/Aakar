import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/app_providers.dart';
import '../../../shared/models/account.dart';
import '../data/commerce_repository.dart';
import '../domain/commerce_engine.dart';
import 'craft_forms.dart';
import 'craft_widgets.dart';

/// Turns an enum-style value such as `pottery` into `Pottery`, which is the key
/// the translation table expects.
String _label(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

class CommerceScreen extends ConsumerStatefulWidget {
  final String page;
  final String? id;
  const CommerceScreen({super.key, this.page = 'home', this.id});
  @override
  ConsumerState<CommerceScreen> createState() => _CommerceScreenState();
}

class _CommerceScreenState extends ConsumerState<CommerceScreen> {
  final search = TextEditingController();
  final selected = <String>{};
  String category = 'All', location = 'All', sort = 'Recommended';
  bool verifiedOnly = false;
  CommerceRepository get repo => ref.read(commerceProvider);
  String t(String en, String hi) => bilingual(context, en, hi);
  void go(String page, [String? id]) =>
      context.push('/workspace/$page${id == null ? '' : '/$id'}');

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return t('GOOD MORNING,', 'सुप्रभात,');
    if (hour >= 12 && hour < 17) return t('GOOD AFTERNOON,', 'नमस्ते,');
    if (hour >= 17 && hour < 21) return t('GOOD EVENING,', 'शुभ संध्या,');
    return t('GOOD NIGHT,', 'शुभ रात्रि,');
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void toast(String message) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> confirm(String title, String body) async =>
      await showDialog<bool>(
          context: context,
          builder: (dialog) =>
              AlertDialog(title: Text(title), content: Text(body), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: Text(t('Enter manually', 'खुद भरें'))),
                FilledButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: Text(t('Review draft', 'मसौदा जांचें')))
              ])) ??
      false;

  Future<bool> action(String name, Record data, {String? success}) async {
    try {
      await repo.act(name, data);
      if (success != null) toast(success);
      return true;
    } catch (e) {
      toast(e is WorkflowError
          ? e.message
          : t('Could not save. Please try again.',
              'सहेजा नहीं गया। फिर कोशिश करें।'));
      return false;
    }
  }

  String supplier(dynamic id) =>
      '${repo.lookup('profiles', '$id')?['name'] ?? 'Artisan'}';
  Record? get current => repo.lookup(
      ['inquiry', 'quote'].contains(widget.page)
          ? 'inquiries'
          : ['order'].contains(widget.page)
              ? 'orders'
              : 'products',
      widget.id);
  @override
  Widget build(BuildContext context) {
    final store = ref.watch(commerceProvider);
    // Role comes from the signed-in account and is fixed at signup; the workspace
    // follows it rather than offering a switch.
    final accountRole = ref.watch(sessionProvider).role?.name;
    if (accountRole != null && accountRole != store.role) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => store.applyAccountRole(accountRole));
    }
    final buyer = (accountRole ?? store.role) == 'buyer';
    final rootPages = [
      'home',
      'discover',
      'products',
      'inquiries',
      'orders',
      'notifications',
      'profile'
    ];
    final isRoot = rootPages.contains(widget.page);
    final items = buyer
        ? ['home', 'discover', 'orders', 'notifications', 'profile']
        : ['home', 'products', 'inquiries', 'orders', 'profile'];
    final index = items.indexOf(widget.page);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F2),
      appBar: AppBar(
          centerTitle: false,
          titleSpacing: isRoot ? 20 : 0,
          automaticallyImplyLeading: !isRoot,
          title: Row(children: [
            const Icon(Icons.spa, color: Color(0xFF8F6E36), size: 27),
            const SizedBox(width: 8),
            Flexible(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Aakar',
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF223C31))),
                  Text(
                      t('Real craft. Real possibilities.',
                          'असली शिल्प। नई संभावनाएँ।'),
                      style: const TextStyle(
                          fontSize: 9, color: Color(0xFF8E734F)))
                ]))
          ]),
          actions: [
            IconButton(
                tooltip: t('Choose your language', 'अपनी भाषा चुनें'),
                onPressed: () => context.push('/language'),
                icon: const Icon(Icons.language, size: 21)),
            IconButton(
                tooltip: t('Sign out', 'साइन आउट'),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialog) => AlertDialog(
                            title: Text(t('Sign out?', 'साइन आउट करें?')),
                            content: Text(t(
                                'You will need to sign in again to continue.',
                                'जारी रखने के लिए दोबारा साइन इन करना होगा।')),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(dialog, false),
                                  child: Text(t('Cancel', 'रद्द करें'))),
                              TextButton(
                                  onPressed: () => Navigator.pop(dialog, true),
                                  child: Text(t('Sign out', 'साइन आउट'))),
                            ],
                          ));
                  if (confirmed == true) {
                    await ref.read(sessionProvider).signOut();
                  }
                },
                icon: const Icon(Icons.logout_rounded, size: 21)),
            const SizedBox(width: 5)
          ]),
      body: SafeArea(
          child: !store.ready
              ? const Center(child: CircularProgressIndicator())
              : Column(children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Row(children: [
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                                color: const Color(0xFFE6F1E8),
                                borderRadius: BorderRadius.circular(20)),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(
                                  buyer
                                      ? Icons.storefront_outlined
                                      : Icons.handyman_outlined,
                                  size: 15,
                                  color: const Color(0xFF286047)),
                              const SizedBox(width: 7),
                              Text(
                                  buyer
                                      ? t('Buyer account', 'खरीदार खाता')
                                      : t('Artisan account', 'कारीगर खाता'),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF286047))),
                            ])),
                        const Spacer(),
                      ])),
                  if (store.busy) const LinearProgressIndicator(minHeight: 2),
                  if (store.error != null)
                    MaterialBanner(
                        content: Text(store.error!,
                            style: const TextStyle(fontSize: 11)),
                        actions: [
                          TextButton(
                              onPressed: () async {
                                try {
                                  await store.refresh();
                                } catch (_) {}
                              },
                              child: Text(t('Retry', 'फिर कोशिश')))
                        ]),
                  Expanded(
                      child: RefreshIndicator(
                          onRefresh: () async {
                            try {
                              await store.refresh();
                            } catch (_) {}
                          },
                          child: ListView(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                              children: body()))),
                ])),
      bottomNavigationBar: NavigationBar(
          height: 68,
          selectedIndex: index < 0 ? 0 : index,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFE4EEE5),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) => context.go('/workspace/${items[i]}'),
          destinations: items
              .map((page) => NavigationDestination(
                  icon: Icon(_icons[page], size: 22), label: navLabel(page)))
              .toList()),
    );
  }

  static const _icons = {
    'home': Icons.home_outlined,
    'discover': Icons.search,
    'orders': Icons.receipt_long_outlined,
    'notifications': Icons.notifications_outlined,
    'profile': Icons.person_outline,
    'products': Icons.inventory_2_outlined,
    'inquiries': Icons.forum_outlined
  };
  String navLabel(String page) => switch (page) {
        'home' => t('Home', 'होम'),
        'discover' => t('Discover', 'खोजें'),
        'orders' => t('Orders', 'ऑर्डर'),
        'notifications' => t('Alerts', 'सूचनाएँ'),
        'profile' => t('Profile', 'प्रोफ़ाइल'),
        'products' => t('Products', 'उत्पाद'),
        _ => t('Inquiries', 'पूछताछ')
      };
  List<Widget> body() {
    switch (widget.page) {
      case 'home':
        return home();
      case 'discover':
      case 'products':
      case 'artisans':
        return discover();
      case 'product':
        return current == null ? missing() : product(current!);
      case 'requirements':
        return requirements();
      case 'matches':
        return matches();
      case 'compare':
        return compare();
      case 'inquiries':
      case 'quotes':
        return inquiryList();
      case 'inquiry':
      case 'quote':
        return current == null ? missing() : inquiry(current!);
      case 'orders':
        return orderList();
      case 'order':
        return current == null ? missing() : orderDetail(current!);
      case 'notifications':
        return notifications();
      case 'profile':
        return profile();
      case 'saved':
        return saved();
      case 'channels':
        return channels();
      case 'help':
        return help();
      default:
        return missing();
    }
  }

  List<Widget> missing() => [
        EmptyCraft(
            t('Nothing here yet', 'अभी कुछ नहीं'),
            t('Return home to continue your craft journey.',
                'आगे बढ़ने के लिए होम पर जाएँ।'),
            action: CraftButton(t('Go home', 'होम पर जाएँ'),
                onPressed: () => context.go('/dashboard')))
      ];
  Widget title(String en, String hi, [String? sub]) =>
      CraftHeading(t(en, hi), subtitle: sub);
  Widget tile(String en, String hi, String sub, IconData icon, VoidCallback tap,
          {Color color = const Color(0xFFF0EEE5)}) =>
      InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(14)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: const Color(0xFF40604B), size: 24),
                    const SizedBox(height: 12),
                    Text(t(en, hi),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    if (sub.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(sub,
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF6E796F)))
                    ]
                  ])));
  Widget stat(String label, int count, VoidCallback tap) => Expanded(
      child: InkWell(
          onTap: tap,
          child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFF1F2EE),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child:
                            Text(label, style: const TextStyle(fontSize: 9))),
                    const SizedBox(height: 6),
                    Text('$count',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 22)),
                    Text(t('View activity', 'गतिविधि देखें'),
                        style: const TextStyle(
                            fontSize: 8, color: Color(0xFF48745B)))
                  ]))));
  List<Widget> home() {
    final buyer = repo.role == 'buyer';
    return [
      CraftCard(
          padding: EdgeInsets.zero,
          color: const Color(0xFFF1EBDD),
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                Expanded(
                    flex: 3,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_timeGreeting(),
                              style: const TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1.6,
                                  color: Color(0xFF6E796A))),
                          const SizedBox(height: 7),
                          Text(
                              ref.watch(sessionProvider).account?.displayName ??
                                  '—',
                              style: const TextStyle(
                                  fontSize: 22,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          Text(
                              buyer
                                  ? t('Thoughtful sourcing starts with a real connection.',
                                      'बेहतर खरीद की शुरुआत, सच्चे जुड़ाव से।')
                                  : t('Your craft. Your price. Your next opportunity.',
                                      'आपका शिल्प। आपकी कीमत। नया अवसर।'),
                              style: const TextStyle(fontSize: 11, height: 1.6))
                        ])),
                const SizedBox(width: 8),
                Expanded(
                    flex: 2,
                    child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8DFD0),
                          borderRadius: BorderRadius.circular(60),
                        ),
                        child: Icon(
                          buyer
                              ? Icons.storefront_outlined
                              : Icons.handshake_outlined,
                          size: 54,
                          color: const Color(0xFF5A7A5C),
                        )))
              ]))),
      if (buyer) ...[
        if (!(ref.watch(sessionProvider).account?.isVerified ?? false))
          CraftButton(
              t('Complete business verification', 'व्यवसाय सत्यापन पूरा करें'),
              secondary: true,
              onPressed: () => go('profile')),
        InkWell(
            onTap: () => go('discover'),
            child: const IgnorePointer(
                child: TextField(
                    decoration: InputDecoration(
                        hintText: 'Search products, artisans…',
                        prefixIcon: Icon(Icons.search),
                        fillColor: Colors.white)))),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: tile('Search products', 'उत्पाद खोजें', '', Icons.search,
                  () => go('discover'),
                  color: const Color(0xFFF4EBE1))),
          const SizedBox(width: 8),
          Expanded(
              child: tile('Browse artisans', 'कारीगर खोजें', '',
                  Icons.people_outline, () => go('artisans'),
                  color: const Color(0xFFE9EEF0))),
          const SizedBox(width: 8),
          Expanded(
              child: tile('Post a requirement', 'ज़रूरत बताएँ', '',
                  Icons.post_add, newRequirement,
                  color: const Color(0xFFF5E7E1)))
        ]),
        const SizedBox(height: 18),
        title('Your activity', 'आपकी गतिविधि'),
        Row(children: [
          stat(t('Requirements', 'ज़रूरतें'), repo.table('requirements').length,
              () => go('requirements')),
          stat(
              t('Quotes', 'भाव'),
              repo.inquiries
                  .where((r) => (r['quotes'] as List).isNotEmpty)
                  .length,
              () => go('quotes')),
          stat(t('Orders', 'ऑर्डर'), repo.orders.length, () => go('orders')),
          stat(t('Suppliers', 'आपूर्तिकर्ता'),
              (repo.state['saved'] as List).length, () => go('saved'))
        ]),
      ] else ...[
        Row(children: [
          stat(t('Products', 'उत्पाद'), repo.products.length,
              () => go('products')),
          stat(t('Inquiries', 'पूछताछ'), repo.inquiries.length,
              () => go('inquiries')),
          stat(t('Orders', 'ऑर्डर'), repo.orders.length, () => go('orders'))
        ]),
        CraftButton(t('Add a product', 'उत्पाद जोड़ें'),
            icon: Icons.add_a_photo_outlined,
            onPressed: () => context.push('/workspace/create')),
        title(
            'My Products',
            'मेरे उत्पाद',
            t('Save first. Publish when you are ready.',
                'पहले सहेजें। तैयार होने पर प्रकाशित करें।')),
        ...repo.products.take(3).map(productCard),
      ],
      const SizedBox(height: 16),
      title('Explore more', 'और देखें'),
      CraftCard(
          child: Column(children: [
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_outlined),
            title: Text(t('Government marketplace', 'सरकारी बाज़ार'),
                style: const TextStyle(fontSize: 13)),
            subtitle: Text(
                t('Readiness & guided preparation', 'तैयारी और मार्गदर्शन'),
                style: const TextStyle(fontSize: 10)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => go('channels')),
        const Divider(),
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.support_agent),
            title: Text(t('Your business assistant', 'आपका व्यवसाय सहायक'),
                style: const TextStyle(fontSize: 13)),
            subtitle: Text(t('Help with every next step', 'हर कदम पर सहायता'),
                style: const TextStyle(fontSize: 10)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => go('help'))
      ])),
      Text(
          t('${repo.modeLabel} · sample catalog illustrations · payments and logistics are simulated.',
              '${repo.modeLabel} · नमूना चित्र · भुगतान व लॉजिस्टिक्स डेमो हैं।'),
          style: const TextStyle(fontSize: 9, color: Color(0xFF828678)),
          textAlign: TextAlign.center),
    ];
  }

  Widget productCard(Record p, {bool select = false}) {
    final profile = repo.lookup('profiles', '${p['artisan_id']}');
    return InkWell(
        onTap: () => go('product', '${p['id']}'),
        child: CraftCard(
            padding: const EdgeInsets.all(13),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CraftImage('${p['image']}', size: 82),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('${p['title']}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text('${money(p['price'])} / ${t('piece', 'इकाई')}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF3E5546))),
                      Text(
                          'MOQ: ${p['moq']} · ${t('Available', 'उपलब्ध')}: ${p['stock']}',
                          style: const TextStyle(fontSize: 10)),
                      Text(
                          '${t('Lead time', 'समय')}: ${p['lead_days']} ${t('days', 'दिन')}',
                          style: const TextStyle(fontSize: 10)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 5, runSpacing: 4, children: [
                        StatusPill(
                            profile?['verification'] == 'verified'
                                ? t('✓ Verified', '✓ सत्यापित')
                                : t('Verification pending', 'सत्यापन बाकी'),
                            warning: profile?['verification'] != 'verified'),
                        if (repo.role == 'artisan')
                          StatusPill('${p['status']}',
                              warning: p['status'] != 'published')
                      ])
                    ])),
                if (select)
                  Checkbox(
                      value: selected.contains(p['id']),
                      onChanged: (v) {
                        if (v == true && selected.length >= 3) {
                          toast(t('Compare up to 3 suppliers',
                              'अधिकतम 3 आपूर्तिकर्ता चुनें'));
                          return;
                        }
                        setState(() {
                          v == true
                              ? selected.add('${p['id']}')
                              : selected.remove(p['id']);
                        });
                      })
              ]),
              if (p['match_score'] != null) ...[
                const Divider(height: 22),
                Row(children: [
                  StatusPill('${p['match_score']}% ${t('fit', 'मेल')}',
                      warning: p['feasible'] != true),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          (p['gaps'] as List).isEmpty
                              ? t('Fits your confirmed requirement',
                                  'आपकी ज़रूरत के अनुकूल')
                              : (p['gaps'] as List).join(' · '),
                          style: const TextStyle(fontSize: 10)))
                ])
              ]
            ])));
  }

  List<Widget> discover() {
    final artisanList = widget.page == 'artisans';
    var products = repo.products;
    if (widget.page != 'products')
      products = repo
          .table('products')
          .where((p) => p['status'] == 'published')
          .toList();
    products = products
        .where((p) =>
            '${p['title']} ${p['material']} ${supplier(p['artisan_id'])}'
                .toLowerCase()
                .contains(search.text.toLowerCase()) &&
            (category == 'All' || p['category'] == category) &&
            (location == 'All' || p['location'] == location) &&
            (!verifiedOnly ||
                repo.lookup(
                        'profiles', '${p['artisan_id']}')?['verification'] ==
                    'verified'))
        .toList();
    if (sort == 'Lowest price')
      products.sort((a, b) => number(a['price']).compareTo(number(b['price'])));
    if (sort == 'Fastest delivery')
      products.sort(
          (a, b) => number(a['lead_days']).compareTo(number(b['lead_days'])));
    final profiles = repo
        .table('profiles')
        .where((p) =>
            p['role'] == 'artisan' &&
            '${p['name']} ${p['craft']}'
                .toLowerCase()
                .contains(search.text.toLowerCase()) &&
            (!verifiedOnly || p['verification'] == 'verified'))
        .toList();
    return [
      title(
          artisanList
              ? 'Meet the makers'
              : widget.page == 'products'
                  ? 'My Products'
                  : 'Discover handmade',
          artisanList
              ? 'कारीगरों से मिलें'
              : widget.page == 'products'
                  ? 'मेरे उत्पाद'
                  : 'हस्तनिर्मित खोजें',
          t('Real people. Remarkable craft.', 'असली लोग। खास शिल्प।')),
      TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
              hintText:
                  t('Search products, artisans…', 'उत्पाद या कारीगर खोजें…'),
              prefixIcon: const Icon(Icons.search))),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        filter(
            'Category',
            category,
            ['All', 'Baskets', 'Pottery', 'Textiles', 'Woodcraft', 'Other'],
            (v) => category = v),
        filter(
            'Location',
            location,
            [
              'All',
              ...repo.table('products').map((p) => '${p['location']}').toSet()
            ],
            (v) => location = v),
        filter(
            'Sort',
            sort,
            ['Recommended', 'Lowest price', 'Fastest delivery'],
            (v) => sort = v),
        FilterChip(
            label: Text(t('Verified only', 'केवल सत्यापित'),
                style: const TextStyle(fontSize: 11)),
            selected: verifiedOnly,
            onSelected: (v) => setState(() => verifiedOnly = v))
      ]),
      const SizedBox(height: 16),
      if (repo.role == 'artisan' && widget.page == 'products')
        CraftButton(t('Add product', 'उत्पाद जोड़ें'),
            onPressed: () => context.push('/workspace/create')),
      if (artisanList)
        ...profiles.map((p) => CraftCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    CircleAvatar(
                        backgroundColor: const Color(0xFFE6E8D9),
                        child: Text('${p['name']}'.substring(0, 1))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text('${p['name']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)))
                  ]),
                  DetailRow(t('Location', 'स्थान'), '${p['location']}'),
                  DetailRow(t('Craft', 'शिल्प'), '${p['craft']}'),
                  DetailRow(
                      t('Experience', 'अनुभव'), '${p['experience']} years'),
                  Text('${p['story']}', style: const TextStyle(fontSize: 12)),
                  CraftButton(t('View products', 'उत्पाद देखें'),
                      secondary: true, onPressed: () {
                    final ps = repo.table('products').where((v) =>
                        v['artisan_id'] == p['id'] &&
                        v['status'] == 'published');
                    if (ps.isNotEmpty) go('product', '${ps.first['id']}');
                  }),
                  if (repo.role == 'buyer')
                    CraftButton(t('Save supplier', 'आपूर्तिकर्ता सहेजें'),
                        onPressed: () =>
                            action('save_supplier', {'artisan_id': p['id']}))
                ])))
      else
        ...products.map((p) => productCard(p, select: repo.role == 'buyer')),
      if ((artisanList ? profiles : products).isEmpty)
        EmptyCraft(
            t('No matches yet', 'कोई मेल नहीं'),
            t('Try another search or clear the filters.',
                'खोज बदलें या फ़िल्टर हटाएँ।')),
      if (selected.length >= 2)
        CraftButton(
            t('Compare ${selected.length} suppliers',
                '${selected.length} की तुलना करें'),
            onPressed: () =>
                context.push('/workspace/compare/${selected.join(',')}')),
    ];
  }

  Widget filter(String label, String value, List<String> options,
          void Function(String) set) =>
      PopupMenuButton<String>(
          initialValue: value,
          onSelected: (v) => setState(() => set(v)),
          itemBuilder: (_) => options
              .map((o) => PopupMenuItem(value: o, child: Text(o)))
              .toList(),
          child: Chip(
              label: Text(value == 'All' ? label : value,
                  style: const TextStyle(fontSize: 10)),
              avatar: const Icon(Icons.expand_more, size: 15)));
  List<Widget> product(Record p) {
    final own = repo.role == 'artisan' && p['artisan_id'] == repo.actor;
    final gaps = CommerceEngine.readiness(p);
    return [
      Center(child: CraftImage('${p['image']}', size: 245)),
      const SizedBox(height: 18),
      title('${p['title']}', '${p['title']}', supplier(p['artisan_id'])),
      CraftCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${p['description']}',
            style: const TextStyle(fontSize: 13, height: 1.7)),
        const SizedBox(height: 10),
        ...{
          'Price / unit': money(p['price']),
          'MOQ': '${p['moq']}',
          'Available stock': '${p['stock']}',
          'Capacity / month': '${p['capacity']}',
          'Lead time': '${p['lead_days']} days',
          'Customization':
              p['customizable'] == true ? 'Available' : 'Not available',
          'Material': '${p['material']}',
          'Craft': '${p['craft']}',
          'Colour': '${p['colour']}',
          'Dimensions': '${p['dimensions']}',
          'Location': '${p['location']}'
        }.entries.map((e) => DetailRow(e.key, e.value)),
        if ('${p['story'] ?? ''}'.isNotEmpty)
          Text('${p['story']}',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic))
      ])),
      if (own) ...[
        CraftCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Aakar B2B readiness', 'आकार B2B तैयारी'),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          StatusPill(
              gaps.isEmpty
                  ? t('Ready to publish', 'प्रकाशन के लिए तैयार')
                  : '${gaps.length} ${t('items to complete', 'विवरण बाकी')}',
              warning: gaps.isNotEmpty),
          ...gaps.map((g) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.error_outline,
                  size: 17, color: Colors.orange),
              title: Text(g, style: const TextStyle(fontSize: 12)))),
          CraftButton(t('Edit & re-verify', 'सुधारें और सत्यापित करें'),
              secondary: true,
              onPressed: () => context.push('/workspace/create/${p['id']}')),
          CraftButton(
              p['status'] == 'published'
                  ? t('Published', 'प्रकाशित')
                  : t('Publish to Aakar', 'आकार पर प्रकाशित करें'),
              onPressed: gaps.isEmpty && p['status'] != 'published'
                  ? () => action('publish', {'id': p['id']},
                      success: t('Product published', 'उत्पाद प्रकाशित'))
                  : null)
        ])),
        CraftButton(t('External channel readiness', 'बाहरी चैनल तैयारी'),
            secondary: true, onPressed: () => go('channels', '${p['id']}')),
      ] else if (repo.role == 'buyer') ...[
        CraftButton(t('Send inquiry / RFQ', 'पूछताछ भेजें'),
            onPressed: () => sendInquiry(p)),
        CraftButton(t('Save / unsave supplier', 'आपूर्तिकर्ता सहेजें / हटाएँ'),
            secondary: true,
            onPressed: () => action(
                'save_supplier', {'artisan_id': p['artisan_id']},
                success: t('Supplier list updated', 'सूची अपडेट हुई')))
      ],
    ];
  }

  Future<void> newRequirement({Record initial = const {}}) async {
    final raw = await craftForm(
        context,
        t('Post a requirement', 'अपनी ज़रूरत बताएँ'),
        const [
          CraftField('original', 'Describe what you need (type or speak)',
              'क्या चाहिए? लिखें या बोलें',
              required: true, multiline: true)
        ],
        initial: {'original': initial['original'] ?? ''},
        description: t(
            'Your words stay attached to the request. You review every structured field.',
            'आपकी बात सुरक्षित रहेगी। हर विवरण जाँचें।'),
        button: t('Structure & review', 'विवरण जाँचें'));
    if (raw == null || !mounted) return;
    final text = '${raw['original']}';
    Record assisted = {'fields': {}, 'provenance': 'Manual review'};
    try {
      assisted = await repo.assist('requirement', text, t('en', 'hi'));
    } catch (e) {
      toast('$e');
    }
    if (!mounted) return;
    final quantity = RegExp(r'(\d+)\s*(units|pieces|baskets|पीस|टोकरी)',
            caseSensitive: false)
        .firstMatch(text)
        ?.group(1);
    final days = RegExp(r'(\d+)\s*(days|दिन)', caseSensitive: false)
        .firstMatch(text)
        ?.group(1);
    final input = await craftForm(context,
        t('Review your requirement', 'अपनी ज़रूरत जाँचें'), requestFields,
        initial: {
          ...initial,
          ...raw,
          'product': initial['product'] ?? text,
          'quantity': quantity ?? initial['quantity'] ?? '',
          'lead_days': days ?? initial['lead_days'] ?? '',
          'budget': initial['budget'] ?? 0,
          ...Map<String, dynamic>.from(assisted['fields'] as Map)
        },
        description:
            '${assisted['provenance']} · ${t('Confirm every field before sending.', 'भेजने से पहले हर विवरण जाँचें।')}',
        button: t('Confirm & find matches', 'पुष्टि करें और मेल खोजें'));
    if (input == null) return;
    if (await action('requirement', {...input, 'confirmed': true}) && mounted)
      go('matches', '${repo.table('requirements').first['id']}');
  }

  List<Widget> requirements() => [
        title('My requirements', 'मेरी ज़रूरतें'),
        CraftButton(t('Post requirement', 'ज़रूरत पोस्ट करें'),
            onPressed: newRequirement),
        ...repo
            .table('requirements')
            .where((r) => r['buyer_id'] == repo.actor)
            .map((r) => CraftCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('${r['product']}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      DetailRow(t('Quantity', 'मात्रा'), '${r['quantity']}'),
                      DetailRow(t('Delivery', 'डिलीवरी'),
                          '${r['location']} · ${r['lead_days']} days'),
                      CraftButton(t('Find matches', 'मेल खोजें'),
                          onPressed: () => go('matches', '${r['id']}'))
                    ])))
      ];
  List<Widget> matches() {
    final r = repo.lookup('requirements', widget.id);
    if (r == null) return missing();
    return [
      title(
          'Top matches for you',
          'आपके लिए उपयुक्त कारीगर',
          t('Explainable capability fit. Artisan confirmation is still required.',
              'क्षमता के आधार पर मेल। कारीगर की पुष्टि बाकी है।')),
      ...CommerceEngine.matches(repo.state, r).map((p) => Column(children: [
            productCard(p, select: true),
            CraftCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(t('Why this matches', 'यह मेल क्यों'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  ...(p['reasons'] as List).map((v) => Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child:
                          Text('✓ $v', style: const TextStyle(fontSize: 11)))),
                  CraftButton(t('Send inquiry', 'पूछताछ भेजें'),
                      onPressed: () => sendInquiry(p, initial: r))
                ]))
          ])),
      if (selected.length >= 2)
        CraftButton(t('Compare selected', 'चुने हुए की तुलना'),
            onPressed: () => go('compare', selected.join(',')))
    ];
  }

  List<Widget> compare() {
    final ps = (widget.id ?? '')
        .split(',')
        .map((id) => repo.lookup('products', id))
        .whereType<Record>()
        .take(3)
        .toList();
    return [
      title(
          'Compare suppliers',
          'आपूर्तिकर्ता तुलना',
          t('Up to 3 suppliers · swipe across the table',
              'अधिकतम 3 · तालिका स्वाइप करें')),
      CraftCard(
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(columnSpacing: 18, columns: [
                const DataColumn(label: Text('Detail')),
                ...ps.map((p) => DataColumn(
                    label: SizedBox(
                        width: 110,
                        child: Text(supplier(p['artisan_id']), maxLines: 3))))
              ], rows: [
                for (final entry in {
                  'price': 'Unit price',
                  'moq': 'MOQ',
                  'stock': 'Available',
                  'capacity': 'Capacity/month',
                  'lead_days': 'Lead days',
                  'customizable': 'Customization',
                  'location': 'Location'
                }.entries)
                  DataRow(cells: [
                    DataCell(Text(entry.value)),
                    ...ps.map((p) => DataCell(Text(entry.key == 'price'
                        ? money(p[entry.key])
                        : '${p[entry.key]}')))
                  ]),
                DataRow(cells: [
                  const DataCell(Text('Verification')),
                  ...ps.map((p) => DataCell(Text(
                      '${repo.lookup('profiles', '${p['artisan_id']}')?['verification']}')))
                ])
              ]))),
      ...ps.map((p) => CraftButton(
          '${t('Select', 'चुनें')} ${supplier(p['artisan_id'])}',
          onPressed: () => sendInquiry(p)))
    ];
  }

  Future<void> sendInquiry(Record p, {Record initial = const {}}) async {
    final data = await craftForm(
        context,
        '${t('Inquiry to', 'पूछताछ')} ${supplier(p['artisan_id'])}',
        requestFields,
        initial: {
          'product': p['title'],
          'quantity': p['moq'],
          'lead_days': p['lead_days'],
          'budget': p['price'],
          'location': repo.profile['location'],
          ...initial
        });
    if (data == null) return;
    if (await action('inquiry', {
          ...data,
          'product_id': p['id'],
          'requirement_id': initial['id']
        }) &&
        mounted) go('inquiry', '${repo.inquiries.first['id']}');
  }

  List<Widget> inquiryList() {
    final rs = repo.inquiries
        .where(
            (r) => widget.page != 'quotes' || (r['quotes'] as List).isNotEmpty)
        .toList();
    return [
      title(
          widget.page == 'quotes'
              ? 'Your quotations'
              : 'Inquiries & conversations',
          widget.page == 'quotes' ? 'आपके भाव' : 'पूछताछ और बातचीत'),
      if (rs.isEmpty)
        EmptyCraft(
            t('A connection starts here', 'यहाँ से जुड़ाव शुरू होता है'),
            t('Send an inquiry from a product or a matched supplier.',
                'उत्पाद या मेल से पूछताछ भेजें।')),
      ...rs.map((r) => InkWell(
          onTap: () => go('inquiry', '${r['id']}'),
          child: CraftCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                      child: Text('${r['product_title']}',
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                  StatusPill('${r['status']}')
                ]),
                DetailRow(
                    t('Supplier', 'आपूर्तिकर्ता'), supplier(r['artisan_id'])),
                DetailRow(t('Quantity', 'मात्रा'), '${r['quantity']}'),
                Text('${r['location']} · ${r['lead_days']} days',
                    style: const TextStyle(fontSize: 11)),
                const SizedBox(height: 8),
                Text(t('View conversation →', 'बातचीत देखें →'),
                    style:
                        const TextStyle(color: Color(0xFF285448), fontSize: 12))
              ]))))
    ];
  }

  List<Widget> inquiry(Record r) {
    final buyer = repo.role == 'buyer';
    final quotes = records(r['quotes']);
    final q = quotes.isEmpty ? null : quotes.last;
    return [
      title('${r['product_title']}', '${r['product_title']}',
          supplier(r['artisan_id'])),
      CraftCard(
          child: Column(children: [
        DetailRow(t('Quantity', 'मात्रा'), '${r['quantity']}'),
        DetailRow(
            t('Requested lead time', 'चाहा समय'), '${r['lead_days']} days'),
        DetailRow(t('Delivery', 'डिलीवरी'), '${r['location']}'),
        DetailRow(t('Customization', 'बदलाव'), '${r['customization'] ?? '—'}'),
        DetailRow(
            t('Specifications', 'विवरण'), '${r['specifications'] ?? '—'}'),
        DetailRow(t('Packaging', 'पैकिंग'), '${r['packaging'] ?? '—'}'),
        DetailRow(
            t('Capacity response', 'क्षमता जवाब'), '${r['capacity_status']}'),
        if (r['confirmed_quantity'] != null)
          DetailRow(t('Offered quantity / time', 'उपलब्ध मात्रा / समय'),
              '${r['confirmed_quantity']} / ${r['offered_lead_days']} days'),
        CraftButton(t('Listen to requirement', 'ज़रूरत सुनें'),
            secondary: true,
            icon: Icons.volume_up_outlined,
            onPressed: () => speakCraft(
                context,
                t('Buyer needs ${r['quantity']} ${r['product_title']} in ${r['lead_days']} days. ${r['customization'] ?? ''}. Deliver to ${r['location']}.',
                    'खरीदार को ${r['quantity']} ${r['product_title']}, ${r['lead_days']} दिन में चाहिए। ${r['customization'] ?? ''}। डिलीवरी ${r['location']}।'))),
        if (!buyer && r['status'] != 'ordered')
          CraftButton(t('Confirm capacity', 'क्षमता की पुष्टि'),
              onPressed: () async {
            final d = await craftForm(
                context, t('Capacity response', 'क्षमता जवाब'), const [
              CraftField('status', 'Response', 'जवाब',
                  required: true,
                  options: ['confirmed', 'partial', 'declined']),
              CraftField('quantity', 'Units possible', 'संभव मात्रा',
                  numeric: true),
              CraftField('lead_days', 'Days required', 'ज़रूरी दिन',
                  numeric: true)
            ],
                initial: {
                  'quantity': r['quantity'],
                  'lead_days': r['lead_days'],
                  'status': 'confirmed'
                });
            if (d != null) await action('capacity', {...d, 'id': r['id']});
          })
      ])),
      if (r['sample_required'] == true)
        CraftCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Sample approval', 'नमूना स्वीकृति'),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          StatusPill('${r['sample_status']}',
              warning: r['sample_status'] != 'approved'),
          if (r['sample_evidence'] != null) evidence('${r['sample_evidence']}'),
          if (r['sample_terms'] != null)
            DetailRow(t('Agreed sample terms', 'नमूने की शर्तें'),
                '${r['sample_terms']}'),
          if ('${r['sample_note'] ?? ''}'.isNotEmpty)
            DetailRow(t('Review note', 'समीक्षा नोट'), '${r['sample_note']}'),
          if (!buyer &&
              ['requested', 'changes_requested', 'rejected']
                  .contains(r['sample_status']))
            CraftButton(t('Submit sample', 'नमूना भेजें'), onPressed: () async {
              final d = await evidenceForm(
                  t('Sample evidence & terms', 'नमूना प्रमाण और शर्तें'),
                  const [
                    CraftField(
                        'terms',
                        'Sample quantity, cost, delivery & payment terms',
                        'नमूना मात्रा, कीमत, डिलीवरी व भुगतान',
                        required: true,
                        multiline: true)
                  ]);
              if (d != null)
                await action(
                    'sample', {...d, 'id': r['id'], 'status': 'submitted'});
            }),
          if (buyer && r['sample_status'] == 'submitted') ...[
            CraftButton(t('Approve sample', 'नमूना स्वीकारें'),
                onPressed: () =>
                    action('sample', {'id': r['id'], 'status': 'approved'})),
            CraftButton(t('Request correction', 'सुधार माँगें'),
                secondary: true, onPressed: () => sampleCorrection(r))
          ]
        ])),
      title(
          'Conversation',
          'बातचीत',
          t('Original messages are preserved. Review any assisted wording before sending.',
              'मूल संदेश सुरक्षित हैं। सहायक मसौदा भेजने से पहले जाँचें।')),
      ...records(r['messages']).map((m) => Align(
          alignment: m['role'] == repo.role
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
              constraints: const BoxConstraints(maxWidth: 290),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                  color: m['role'] == repo.role
                      ? const Color(0xFFE5EEE2)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${m['role']}',
                        style: const TextStyle(
                            fontSize: 9, color: Color(0xFF748173))),
                    Text('${m['text']}',
                        style: const TextStyle(fontSize: 12, height: 1.5)),
                    if ('${m['translation']}'.isNotEmpty) ...[
                      const Divider(),
                      Text('${m['translation']}',
                          style: const TextStyle(fontSize: 11)),
                      Text('${m['provenance']}',
                          style: const TextStyle(fontSize: 9))
                    ],
                    if ('${m['attachment']}'.isNotEmpty)
                      Text('${m['attachment']}',
                          style: const TextStyle(fontSize: 10))
                  ])))),
      CraftButton(t('Write / speak a message', 'लिखें / बोलें'),
          secondary: true, icon: Icons.mic_none, onPressed: () async {
        final original =
            await craftForm(context, t('Your message', 'आपका संदेश'), const [
          CraftField(
              'text', 'Type or speak your message', 'अपना संदेश लिखें या बोलें',
              required: true, multiline: true)
        ]);
        if (original == null || !mounted) return;
        Record assistance = {
          'fields': {},
          'provenance': 'participant-reviewed'
        };
        try {
          assistance = await repo.assist(
              'translate', '${original['text']}', buyer ? 'hi' : 'en');
        } catch (e) {
          toast('$e');
        }
        if (!mounted) return;
        final d = await craftForm(
            context,
            t('Review message', 'संदेश जाँचें'),
            const [
              CraftField('text', 'Original message', 'मूल संदेश',
                  required: true, multiline: true),
              CraftField(
                  'translation',
                  'Reviewed translation / simplified wording (optional)',
                  'जाँचा हुआ अनुवाद / सरल भाषा (वैकल्पिक)',
                  multiline: true),
              CraftField('attachment', 'Attachment reference (optional)',
                  'फ़ाइल संदर्भ (वैकल्पिक)')
            ],
            initial: {
              ...original,
              ...Map<String, dynamic>.from(assistance['fields'] as Map)
            },
            description:
                '${assistance['provenance']} · ${t('Review quantities, prices and deadlines before sending.', 'भेजने से पहले मात्रा, कीमत और समय जाँचें।')}');
        if (d != null)
          await action('message', {
            ...d,
            'id': r['id'],
            'provenance': '${assistance['provenance']} · participant-reviewed'
          });
      }),
      title('Quotation & agreement', 'भाव और सहमति'),
      if (q != null) ...[
        quoteCard(q),
        if (r['status'] != 'ordered' &&
            q['author'] != repo.role &&
            q['status'] == 'proposed')
          CraftButton(t('Accept latest quote', 'नया भाव स्वीकारें'),
              onPressed: () async {
            if (await action('accept', {'id': r['id'], 'quote_id': q['id']}) &&
                mounted)
              go('order',
                  '${repo.lookup('inquiries', '${r['id']}')?['order_id']}');
          }),
        if (r['status'] != 'ordered' && q['author'] != repo.role)
          CraftButton(t('Reject quote', 'भाव अस्वीकारें'),
              secondary: true,
              onPressed: () => action('reject_quote', {'id': r['id']})),
        if (quotes.length > 1)
          ExpansionTile(
              title: Text(
                  t('Quote history (${quotes.length} versions)',
                      'भाव इतिहास (${quotes.length})'),
                  style: const TextStyle(fontSize: 12)),
              children: quotes.reversed.skip(1).map(quoteCard).toList())
      ],
      if (r['status'] != 'ordered')
        CraftButton(
            q == null
                ? t('Create quotation', 'भाव बनाएँ')
                : t('Propose a revision', 'नया प्रस्ताव दें'),
            onPressed: () => editQuote(r, q)),
      if (r['order_id'] != null)
        CraftButton(t('View order', 'ऑर्डर देखें'),
            onPressed: () => go('order', '${r['order_id']}')),
    ];
  }

  Future<void> sampleCorrection(Record r) async {
    final d =
        await craftForm(context, t('Sample review', 'नमूना समीक्षा'), const [
      CraftField(
          'note', 'Correction / rejection reason', 'सुधार / अस्वीकृति कारण',
          required: true, multiline: true),
      CraftField('status', 'Decision', 'निर्णय',
          options: ['changes_requested', 'rejected'], required: true)
    ], initial: {
      'status': 'changes_requested'
    });
    if (d != null) await action('sample', {...d, 'id': r['id']});
  }

  Future<Record?> evidenceForm(String name, List<CraftField> fields,
      {Record initial = const {}}) async {
    final source = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: Text(t('Take photo', 'फ़ोटो लें')),
                  onTap: () => Navigator.pop(context, 'camera')),
              ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(t('Choose photo', 'फ़ोटो चुनें')),
                  onTap: () => Navigator.pop(context, 'gallery')),
              ListTile(
                  leading: const Icon(Icons.link),
                  title:
                      Text(t('Enter evidence reference', 'प्रमाण संदर्भ भरें')),
                  onTap: () => Navigator.pop(context, 'reference'))
            ])));
    if (source == null || !mounted) return null;
    String? photo;
    if (source != 'reference')
      photo = await pickEvidence(context, camera: source == 'camera');
    if (!mounted) return null;
    return craftForm(context, name, [
      const CraftField(
          'evidence', 'Evidence photo / reference', 'प्रमाण फ़ोटो / संदर्भ',
          required: true),
      ...fields
    ], initial: {
      ...initial,
      if (photo != null) 'evidence': photo
    });
  }

  Widget quoteCard(Record q) => CraftCard(
      color: const Color(0xFFF1F4EC),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StatusPill('v${q['version']} · ${q['author']}'),
          const Spacer(),
          StatusPill('${q['status']}')
        ]),
        const SizedBox(height: 10),
        Text('${q['quantity']} × ${money(q['unit_price'])}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        DetailRow(t('Product total', 'उत्पाद राशि'),
            money(number(q['unit_price']) * number(q['quantity']))),
        DetailRow(t('Packaging', 'पैकिंग'), money(q['packaging_cost'])),
        DetailRow(t('Delivery', 'डिलीवरी'), money(q['delivery_cost'])),
        DetailRow(t('Storage / demo', 'भंडारण / डेमो'),
            money(number(q['storage_cost']) + number(q['demo_cost']))),
        const Divider(),
        DetailRow(t('Total (INR)', 'कुल (₹)'), money(q['total'])),
        DetailRow(t('Lead time', 'समय'), '${q['lead_days']} days'),
        DetailRow(
            t('Delivery terms', 'डिलीवरी शर्तें'), '${q['delivery_terms']}'),
        DetailRow(t('Specifications', 'विवरण'), '${q['specifications'] ?? ''}'),
        DetailRow(t('Customization', 'बदलाव'), '${q['customization'] ?? ''}'),
        DetailRow(
            t('Payment milestones', 'भुगतान चरण'),
            records(q['milestones'])
                .map((m) => '${m['percent']}% ${m['trigger']}')
                .join(' · ')),
        DetailRow(t('Inspection window', 'जाँच अवधि'),
            '${q['inspection_hours']} hours'),
        DetailRow(t('Progress checkpoint', 'प्रगति जाँच'),
            '${q['checkpoint_required'] == true}'),
        if ('${q['terms'] ?? ''}'.isNotEmpty)
          Text('${q['terms']}', style: const TextStyle(fontSize: 11))
      ]));
  Future<void> editQuote(Record r, Record? quote) async {
    final p = repo.lookup('products', '${r['product_id']}')!;
    Record suggestions = {};
    final conversation = records(r['messages']);
    if (conversation.isNotEmpty &&
        await confirm(
            t('Draft terms from the conversation?',
                'बातचीत से शर्तों का मसौदा बनाएं?'),
            t('Review every suggested value before sending your quotation. Original requested terms stay visible.',
                'भाव भेजने से पहले हर सुझाव जांचें। मूल मांग अलग दिखाई देगी।'))) {
      try {
        final result = await repo.assist(
            'negotiation',
            conversation.map((m) => '${m['role']}: ${m['text']}').join('\n'),
            t('en', 'hi'));
        suggestions = Map<String, dynamic>.from(result['fields'] as Map);
        toast('${result['provenance']}');
      } catch (e) {
        toast('$e');
      }
    }
    if (!mounted) return;
    final q = await craftForm(
        context,
        t('Structured quotation', 'भाव का विवरण'),
        const [
          CraftField('unit_price', 'Unit price (INR)', 'प्रति इकाई कीमत (₹)',
              numeric: true, required: true),
          CraftField('quantity', 'Quantity', 'मात्रा',
              numeric: true, required: true),
          CraftField(
              'lead_days', 'Offered lead time (days)', 'प्रस्तावित समय (दिन)',
              numeric: true, required: true),
          CraftField('target_date', 'Target date', 'लक्ष्य तारीख'),
          CraftField(
              'customization',
              'Size / colour / pattern / logo / other changes',
              'आकार / रंग / डिज़ाइन / लोगो',
              multiline: true),
          CraftField('specifications', 'Agreed specifications', 'तय विवरण',
              multiline: true),
          CraftField('packaging_cost', 'Packaging cost', 'पैकिंग खर्च',
              numeric: true),
          CraftField('delivery_cost', 'Delivery cost', 'डिलीवरी खर्च',
              numeric: true),
          CraftField('storage_cost', 'Storage cost', 'भंडारण खर्च',
              numeric: true),
          CraftField('demo_cost', 'On-site demo cost', 'मौके पर डेमो खर्च',
              numeric: true),
          CraftField(
              'delivery_terms',
              'Who packs, who ships, proposed route & costs',
              'पैकिंग, डिलीवरी जिम्मेदारी और रास्ता',
              required: true,
              multiline: true),
          CraftField('location', 'Delivery location', 'डिलीवरी स्थान',
              required: true),
          CraftField('advance_percent', 'Advance %', 'अग्रिम %',
              numeric: true, required: true),
          CraftField('middle_percent', 'QC / dispatch % (0 to omit)',
              'जाँच / डिस्पैच % (0 = नहीं)',
              numeric: true),
          CraftField('middle_trigger', 'Middle milestone trigger',
              'बीच के भुगतान का चरण',
              options: ['checkpoint', 'dispatch']),
          CraftField('final_percent', 'After inspection % (0 to omit)',
              'निरीक्षण के बाद %',
              numeric: true),
          CraftField('checkpoint_required', 'Include one progress review',
              'एक प्रगति जाँच रखें',
              toggle: true),
          CraftField('inspection_hours', 'Agreed inspection window (hours)',
              'तय जाँच अवधि (घंटे)',
              numeric: true, required: true),
          CraftField('terms', 'Other agreed terms', 'अन्य तय शर्तें',
              multiline: true),
        ],
        initial: {
          'unit_price': p['price'],
          'quantity': r['confirmed_quantity'] ?? r['quantity'],
          'lead_days': r['offered_lead_days'] ?? r['lead_days'],
          'location': r['location'],
          'customization': r['customization'],
          'specifications': r['specifications'],
          'packaging_cost': 0,
          'delivery_cost': 0,
          'storage_cost': 0,
          'demo_cost': 0,
          'advance_percent': 30,
          'middle_percent': 50,
          'middle_trigger': 'dispatch',
          'final_percent': 20,
          'inspection_hours': 48,
          'delivery_terms': '',
          ...?quote,
          ...suggestions
        },
        description: t(
            'Example percentages are editable and must total 100. Payment status only; no money is held. Cost floor: ${money(CommerceEngine.floor(p))}.',
            'प्रतिशत बदल सकते हैं; कुल 100 होना चाहिए। भुगतान केवल डेमो रिकॉर्ड है। लागत: ${money(CommerceEngine.floor(p))}।'));
    if (q == null) return;
    final ms = [
      {'trigger': 'advance', 'percent': number(q['advance_percent'])},
      if (number(q['middle_percent']) > 0)
        {
          'trigger': q['middle_trigger'] ?? 'dispatch',
          'percent': number(q['middle_percent'])
        },
      if (number(q['final_percent']) > 0)
        {'trigger': 'delivery', 'percent': number(q['final_percent'])}
    ];
    await action('quote', {...q, 'id': r['id'], 'milestones': ms});
  }

  List<Widget> orderList() => [
        title(
            'Your orders',
            'आपके ऑर्डर',
            t('Know the next step. Keep every commitment visible.',
                'अगला कदम जानें। हर वादा साफ़ रखें।')),
        if (repo.orders.isEmpty)
          EmptyCraft(
              t('No orders yet', 'अभी कोई ऑर्डर नहीं'),
              t('An accepted quotation becomes your first order.',
                  'स्वीकृत भाव से पहला ऑर्डर बनेगा।')),
        ...repo.orders
            .where((o) => widget.id == null || o['artisan_id'] == widget.id)
            .map((o) => InkWell(
                onTap: () => go('order', '${o['id']}'),
                child: CraftCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        const Icon(Icons.receipt_long_outlined,
                            color: Color(0xFF285448)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text('${o['product_title']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13))),
                        StatusPill('${o['status']}')
                      ]),
                      DetailRow('${o['quantity']} units', money(o['total'])),
                      Text(supplier(o['artisan_id']),
                          style: const TextStyle(fontSize: 11)),
                      const SizedBox(height: 8),
                      Text(t('View order →', 'ऑर्डर देखें →'),
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF285448)))
                    ]))))
      ];
  List<Widget> orderDetail(Record o) {
    final buyer = repo.role == 'buyer';
    final issues =
        repo.table('issues').where((i) => i['order_id'] == o['id']).toList();
    final open = issues.any((i) => i['status'] != 'resolved');
    final p = repo.lookup('products', '${o['product_id']}')!;
    final route = CommerceEngine.route(
        p, {'quantity': o['quantity'], 'location': o['location']});
    return [
      title('${o['product_title']}', '${o['product_title']}',
          '${o['quantity']} units · ${supplier(o['artisan_id'])}'),
      CraftCard(
          child: Column(children: [
        Row(children: [
          const Icon(Icons.check_circle, color: Color(0xFF34734D)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(t('Order confirmed', 'ऑर्डर की पुष्टि'),
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          StatusPill('${o['status']}')
        ]),
        DetailRow(t('Order reference', 'ऑर्डर संदर्भ'), '${o['id']}'),
        DetailRow(t('Agreed total', 'तय कुल'), money(o['total'])),
        DetailRow(t('Quote version', 'भाव संस्करण'), 'v${o['version']}'),
        DetailRow(t('Lead time', 'समय'), '${o['lead_days']} days'),
        DetailRow(
            t('Delivery terms', 'डिलीवरी शर्तें'), '${o['delivery_terms']}'),
        DetailRow(t('Customization', 'बदलाव'), '${o['customization'] ?? ''}')
      ])),
      title(
          'Payment commitments',
          'भुगतान के वादे',
          t('Demo records only. Aakar does not hold or transfer money.',
              'केवल डेमो रिकॉर्ड। ऐप पैसे नहीं रखता या भेजता।')),
      CraftCard(
          child: Column(
              children: records(o['milestones'])
                  .map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(children: [
                        Row(children: [
                          CircleAvatar(
                              radius: 15,
                              backgroundColor: m['status'] == 'confirmed'
                                  ? const Color(0xFF285448)
                                  : const Color(0xFFE9E4D7),
                              child: Icon(
                                  m['status'] == 'confirmed'
                                      ? Icons.check
                                      : Icons.schedule,
                                  size: 17,
                                  color: m['status'] == 'confirmed'
                                      ? Colors.white
                                      : const Color(0xFF826B44))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text('${m['trigger']} · ${m['percent']}%',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600))),
                          Text(money(m['amount']),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600))
                        ]),
                        const SizedBox(height: 6),
                        StatusPill('${m['status']}',
                            warning: m['status'] != 'confirmed'),
                        if (buyer &&
                            m['status'] != 'confirmed' &&
                            o['status'] != 'completed')
                          CraftButton(
                              t('Record simulated payment',
                                  'डेमो भुगतान दर्ज करें'),
                              secondary: true,
                              onPressed: open
                                  ? null
                                  : () => action('pay', {
                                        'id': o['id'],
                                        'milestone_id': m['id'],
                                        'reference':
                                            'Demo confirmation — no funds transferred'
                                      }))
                      ])))
                  .toList())),
      title('Production & progress', 'उत्पादन और प्रगति'),
      CraftCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final step in ['started', 'in_progress', 'ready', 'dispatched'])
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Icon(
                    [
                              'not_started',
                              'started',
                              'in_progress',
                              'ready',
                              'dispatched'
                            ].indexOf('${o['production']}') >=
                            [
                              'not_started',
                              'started',
                              'in_progress',
                              'ready',
                              'dispatched'
                            ].indexOf(step)
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: const Color(0xFF3D6B52)),
                const SizedBox(width: 12),
                Text(step.replaceAll('_', ' '),
                    style: const TextStyle(fontSize: 13))
              ])),
        if (!buyer &&
            ['not_started', 'started', 'in_progress'].contains(o['production']))
          CraftButton(t('Update production', 'उत्पादन अपडेट करें'),
              onPressed: open
                  ? null
                  : () {
                      final next = {
                        'not_started': 'started',
                        'started': 'in_progress',
                        'in_progress': 'ready'
                      }[o['production']];
                      action('production', {'id': o['id'], 'status': next});
                    }),
        if (o['checkpoint_required'] == true) ...[
          const Divider(height: 22),
          Text(t('Agreed progress checkpoint', 'तय प्रगति जाँच'),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          StatusPill('${o['checkpoint']}',
              warning: o['checkpoint'] != 'approved'),
          if (o['checkpoint_quantity'] != null)
            DetailRow(t('Completed units', 'तैयार इकाइयाँ'),
                '${o['checkpoint_quantity']} / ${o['quantity']}'),
          if (o['checkpoint_evidence'] != null)
            evidence('${o['checkpoint_evidence']}'),
          if (!buyer &&
              ['not_submitted', 'changes_requested'].contains(o['checkpoint']))
            CraftButton(t('Upload progress update', 'प्रगति भेजें'),
                secondary: true, onPressed: () async {
              final d = await evidenceForm(
                  t('Progress checkpoint', 'प्रगति जाँच'), const [
                CraftField('quantity', 'Units completed', 'तैयार इकाइयाँ',
                    numeric: true, required: true)
              ]);
              if (d != null) await action('checkpoint', {...d, 'id': o['id']});
            }),
          if (buyer && o['checkpoint'] == 'submitted') ...[
            CraftButton(t('Approve progress', 'प्रगति स्वीकारें'),
                onPressed: () => action(
                    'checkpoint', {'id': o['id'], 'status': 'approved'})),
            CraftButton(t('Request correction', 'सुधार माँगें'),
                secondary: true,
                onPressed: () => action('checkpoint',
                    {'id': o['id'], 'status': 'changes_requested'}))
          ],
          const SizedBox(height: 8),
          Text(
              t('Photos support review; AI does not guarantee quality.',
                  'फ़ोटो समीक्षा में मदद करती है; AI गुणवत्ता की गारंटी नहीं देता।'),
              style: const TextStyle(fontSize: 10))
        ]
      ])),
      title('Packaging & delivery', 'पैकिंग और डिलीवरी'),
      CraftCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        StatusPill('${o['shipment']}'),
        const SizedBox(height: 12),
        DetailRow(t('Suggested route', 'सुझाया रास्ता'), '${route['route']}'),
        Text('${route['reason']}',
            style: const TextStyle(fontSize: 11, height: 1.5)),
        const SizedBox(height: 12),
        Text(
            p['fragile'] == true
                ? t('Cushion each item, separate fragile surfaces, secure the inner pack, and seal a strong outer box.',
                    'हर नाज़ुक वस्तु सुरक्षित करें, अलग रखें, अंदर की पैकिंग बाँधें और मजबूत बॉक्स सील करें।')
                : t('Protect against moisture and scratches, confirm count, secure inner packaging, and seal the outer carton.',
                    'नमी और खरोंच से बचाएँ, गिनती जाँचें, अंदर सुरक्षित रखें और कार्टन सील करें।'),
            style: const TextStyle(fontSize: 12)),
        if (o['shipping'] is Map) ...[
          DetailRow(t('Shipping method', 'शिपिंग तरीका'),
              '${o['shipping']['method']}'),
          DetailRow(t('Tracking / label reference', 'ट्रैकिंग / लेबल संदर्भ'),
              '${o['shipping']['tracking']}'),
          DetailRow(t('Route', 'रास्ता'), '${o['shipping']['route']}'),
          DetailRow(t('Hub / storage / handoff', 'हब / भंडारण / हस्तांतरण'),
              '${o['shipping']['hub_details'] ?? '—'}'),
          evidence('${o['shipping']['evidence']}')
        ],
        if (!buyer && o['production'] == 'ready')
          CraftButton(t('Prepare & dispatch', 'तैयार करें और भेजें'),
              onPressed: open ? null : () => dispatch(o, p)),
        if (!buyer && o['shipment'] == 'dispatched')
          CraftButton(t('Mark in transit', 'रास्ते में है'),
              secondary: true,
              onPressed: () =>
                  action('shipping', {'id': o['id'], 'status': 'in_transit'})),
        if (buyer && ['dispatched', 'in_transit'].contains(o['shipment']))
          CraftButton(t('Confirm delivery received', 'डिलीवरी प्राप्त हुई'),
              onPressed: () => action('delivery', {'id': o['id']}))
      ])),
      if (o['shipment'] == 'delivered') ...[
        title('Buyer inspection', 'खरीदार की जाँच'),
        CraftCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StatusPill('${o['inspection']}'),
          DetailRow(
              t('Agreed window', 'तय अवधि'), '${o['inspection_hours']} hours'),
          DetailRow(t('Inspection deadline', 'जाँच समय सीमा'),
              '${o['inspection_deadline']}'),
          Text(
              t('No automatic acceptance on expiry. Flag an issue if quantity, condition or specifications differ.',
                  'समय बीतने पर अपने आप स्वीकृति नहीं। मात्रा, हालत या विवरण गलत हो तो समस्या बताएँ।'),
              style: const TextStyle(fontSize: 11)),
          if (buyer && o['inspection'] != 'accepted')
            CraftButton(t('Inspect & accept', 'जाँचकर स्वीकारें'),
                onPressed: open
                    ? null
                    : () async {
                        final d = await craftForm(context,
                            t('Delivery inspection', 'डिलीवरी जाँच'), const [
                          CraftField(
                              'quantity', 'Quantity received', 'प्राप्त मात्रा',
                              required: true, numeric: true),
                          CraftField('note', 'Quality / specification review',
                              'गुणवत्ता / विवरण की जाँच',
                              required: true, multiline: true)
                        ],
                            initial: {
                              'quantity': o['quantity']
                            });
                        if (d != null)
                          await action('inspection', {...d, 'id': o['id']});
                      }),
          if (buyer && o['status'] != 'completed')
            CraftButton(t('Complete order', 'ऑर्डर पूरा करें'),
                onPressed:
                    open ? null : () => action('complete', {'id': o['id']}))
        ]))
      ],
      if (o['status'] != 'completed')
        CraftButton(t('Flag an issue', 'समस्या बताएँ'),
            secondary: true, icon: Icons.flag_outlined, onPressed: () async {
          final d = await evidenceForm(
              t('Report order issue', 'ऑर्डर की समस्या'), const [
            CraftField('category', 'Issue type', 'समस्या का प्रकार',
                required: true,
                options: [
                  'Quality / specification mismatch',
                  'Cannot fulfill quantity',
                  'Shipment damaged',
                  'Buyer cancellation',
                  'Quantity mismatch',
                  'Payment milestone disputed'
                ]),
            CraftField('description', 'What happened?', 'क्या हुआ?',
                required: true, multiline: true)
          ]);
          if (d != null) await action('issue', {...d, 'id': o['id']});
        }),
      ...issues.map((i) => CraftCard(
          color: const Color(0xFFFFF0E5),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StatusPill('${i['status']}', warning: i['status'] != 'resolved'),
            const SizedBox(height: 8),
            Text('${i['category']}',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            Text('${i['description']}', style: const TextStyle(fontSize: 12)),
            if (i['resolution'] != null)
              Text('${i['resolution']}', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Text(
                t('Manual admin review. No automatic refunds or penalties.',
                    'एडमिन मैन्युअल समीक्षा करेगा। स्वतः रिफंड या जुर्माना नहीं।'),
                style: const TextStyle(fontSize: 10))
          ]))),
      ExpansionTile(
          title: Text(t('On-site product demonstration', 'मौके पर उत्पाद डेमो'),
              style: const TextStyle(fontSize: 13)),
          subtitle: Text(
              t('Optional coordination request', 'वैकल्पिक व्यवस्था'),
              style: const TextStyle(fontSize: 10)),
          children: [
            if (o['representation'] is Map)
              CraftCard(
                  child: Column(children: [
                DetailRow(
                    t('Status', 'स्थिति'), '${o['representation']['status']}'),
                DetailRow(t('Representative', 'प्रतिनिधि'),
                    '${o['representation']['person']}'),
                DetailRow(t('Where / when', 'कहाँ / कब'),
                    '${o['representation']['location']} · ${o['representation']['date']}')
              ])),
            CraftButton(
                t('Request / propose representative',
                    'प्रतिनिधि का अनुरोध / प्रस्ताव'),
                secondary: true,
                onPressed: () => representation(o)),
            if (o['representation'] is Map &&
                o['representation']['author'] != repo.role)
              CraftButton(t('Confirm arrangement', 'व्यवस्था स्वीकारें'),
                  onPressed: () => action('representation', {
                        ...Map<String, dynamic>.from(
                            o['representation'] as Map),
                        'id': o['id'],
                        'status': 'confirmed'
                      }))
          ]),
      if (buyer && o['status'] == 'completed') ...[
        CraftButton(t('Save supplier', 'आपूर्तिकर्ता सहेजें'),
            onPressed: () =>
                action('save_supplier', {'artisan_id': o['artisan_id']})),
        CraftButton(
            t('Reorder · create a new requirement',
                'फिर ऑर्डर · नई ज़रूरत बनाएँ'),
            secondary: true,
            onPressed: () => newRequirement(initial: {
                  'product': o['product_title'],
                  'quantity': o['quantity'],
                  'lead_days': o['lead_days'],
                  'location': o['location'],
                  'customization': o['customization'],
                  'budget': o['unit_price'],
                  'source_order_id': o['id'],
                  'original':
                      '${o['quantity']} ${o['product_title']} in ${o['lead_days']} days'
                }))
      ],
      ExpansionTile(
          title: Text(t('Order history & evidence', 'ऑर्डर इतिहास और प्रमाण'),
              style: const TextStyle(fontSize: 13)),
          children: records(o['events'])
              .reversed
              .map((e) => ListTile(
                  leading: const Icon(Icons.circle,
                      size: 8, color: Color(0xFF285448)),
                  title: Text('${e['title']}',
                      style: const TextStyle(fontSize: 11)),
                  subtitle: Text('${e['role']} · ${e['time']}',
                      style: const TextStyle(fontSize: 9))))
              .toList()),
    ];
  }

  Widget evidence(String source) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        if (source.startsWith('/') ||
            source.contains(':\\') ||
            source.startsWith('http'))
          CraftImage(source, size: 150),
        SelectableText(source, style: const TextStyle(fontSize: 10)),
        const SizedBox(height: 8)
      ]);
  Future<void> dispatch(Record o, Record p) async {
    final d = await evidenceForm(
        t('Packaging & dispatch', 'पैकिंग और डिस्पैच'), const [
      CraftField('method', 'Artisan-booked carrier / shipping method',
          'कूरियर / शिपिंग तरीका',
          required: true),
      CraftField('tracking', 'Tracking ID / shipping label reference',
          'ट्रैकिंग ID / लेबल संदर्भ',
          required: true),
      CraftField('packed_dimensions', 'Packed dimensions / weight if known',
          'पैक माप / वजन, यदि पता हो'),
      CraftField('pickup_location', 'Pickup / packaging location',
          'पिकअप / पैकिंग स्थान'),
      CraftField('responsible_person', 'Packaging and carrier handoff person',
          'पैकिंग और हस्तांतरण व्यक्ति'),
      CraftField('estimated_transit_days', 'Estimated transit days',
          'अनुमानित यात्रा दिन',
          numeric: true),
      CraftField('hub_available', 'Suitable hub availability confirmed (demo)',
          'उपयुक्त हब उपलब्ध है (डेमो)',
          toggle: true),
      CraftField('storage_needed', 'Storage / consolidation needed',
          'भंडारण / एकत्रीकरण चाहिए',
          toggle: true),
      CraftField(
          'hub_details',
          'Hub, storage duration/cost, packaging & handoff responsibility',
          'हब, भंडारण समय/खर्च, पैकिंग और जिम्मेदारी',
          multiline: true),
      CraftField(
          'protection',
          'Protection/cushioning appropriate for this product',
          'उत्पाद के अनुसार सुरक्षा की',
          toggle: true),
      CraftField(
          'count', 'Count & specifications checked', 'मात्रा और विवरण जाँचे',
          toggle: true),
      CraftField('inner', 'Inner packaging secured', 'अंदर की पैकिंग सुरक्षित',
          toggle: true),
      CraftField('outer', 'Outer carton sealed and labeled',
          'बाहरी बॉक्स सील और लेबल किया',
          toggle: true)
    ]);
    if (d == null) return;
    final selectedRoute = CommerceEngine.route(p, {...o, ...d});
    if (selectedRoute['route'] == 'Via hub' &&
        '${d['hub_details'] ?? ''}'.isEmpty) {
      toast(
          t('Record hub and handoff details', 'हब और हस्तांतरण का विवरण भरें'));
      return;
    }
    await action('shipping', {
      ...d,
      'id': o['id'],
      'status': 'dispatched',
      'route': selectedRoute['route'],
      'checks': ['protection', 'count', 'inner', 'outer']
          .where((k) => d[k] == true)
          .toList()
    });
  }

  Future<void> representation(Record o) async {
    final d = await craftForm(
        context, t('On-site demonstration', 'मौके पर डेमो'), const [
      CraftField(
          'purpose', 'Purpose / skills required', 'उद्देश्य / ज़रूरी कौशल',
          required: true),
      CraftField('person', 'Artisan / proposed representative',
          'कारीगर / प्रस्तावित प्रतिनिधि',
          required: true),
      CraftField('location', 'Location', 'स्थान', required: true),
      CraftField('date', 'Date & time', 'तारीख और समय', required: true),
      CraftField('sample_transport', 'Sample / product transport',
          'नमूना / उत्पाद पहुँचाना'),
      CraftField('cost', 'Travel / service cost (INR)', 'यात्रा / सेवा खर्च',
          numeric: true),
      CraftField('terms', 'Responsibilities and confirmation notes',
          'जिम्मेदारी और शर्तें',
          multiline: true)
    ]);
    if (d != null)
      await action(
          'representation', {...d, 'id': o['id'], 'status': 'proposed'});
  }

  List<Widget> notifications() => [
        title('Notifications', 'सूचनाएँ'),
        CraftButton(t('Mark all as read', 'सभी पढ़े हुए करें'),
            secondary: true, onPressed: () => action('read_notifications', {})),
        if (repo.notifications.isEmpty)
          EmptyCraft(
              t('You’re all caught up', 'आप अपडेट हैं'),
              t('New messages, quotes and order updates appear here.',
                  'नए संदेश, भाव और ऑर्डर यहाँ दिखेंगे।')),
        ...repo.notifications.map((n) => CraftCard(
            child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(n['read'] == true
                    ? Icons.notifications_none
                    : Icons.notifications_active_outlined),
                title:
                    Text('${n['title']}', style: const TextStyle(fontSize: 12)),
                subtitle:
                    Text('${n['time']}', style: const TextStyle(fontSize: 9)),
                onTap: n['link'] == null
                    ? null
                    : () => context.push('/workspace/${n['link']}'))))
      ];
  List<Widget> profile() {
    final session = ref.watch(sessionProvider);
    final account = session.account;
    final isArtisan =
        (account?.role ?? AccountRole.artisan) == AccountRole.artisan;
    final name = account == null ? '—' : account.displayName;
    final location = [
      if (account?.state != null && account!.state!.isNotEmpty) account.state,
      if (account?.district != null && account!.district!.isNotEmpty)
        account.district,
    ].join(', ');
    final contact = account?.phone ?? account?.email ?? '—';
    final verified = account?.isVerified ?? false;
    final initial = name.trim().isEmpty ? '?' : name.trim().substring(0, 1);

    return [
      title(isArtisan ? 'Your artisan profile' : 'Your business profile',
          isArtisan ? 'आपकी कारीगर प्रोफ़ाइल' : 'आपकी व्यवसाय प्रोफ़ाइल'),
      CraftCard(
          child: Column(children: [
        CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFFE3E9DA),
            child: Text(initial,
                style:
                    const TextStyle(fontSize: 28, color: Color(0xFF285448)))),
        const SizedBox(height: 12),
        Text(name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        StatusPill(verified ? 'verified' : 'pending', warning: !verified),
        const SizedBox(height: 8),
        if (isArtisan)
          DetailRow(
              t('Craft', 'शिल्प'),
              account?.craftCategory == null
                  ? '—'
                  : context.tr(_label(account!.craftCategory!))),
        if (!isArtisan)
          DetailRow(t('Business', 'व्यवसाय'),
              account?.businessName ?? account?.industry ?? '—'),
        DetailRow(t('Location', 'स्थान'), location.isEmpty ? '—' : location),
        DetailRow(t('Contact', 'संपर्क'), contact),
      ])),
      CraftButton(t('Edit profile', 'प्रोफ़ाइल बदलें'),
          onPressed: () => context.push('/profile/edit')),
      CraftButton(t('View verification', 'सत्यापन देखें'),
          secondary: true, onPressed: () => context.push('/verification')),
      CraftCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('Verification', 'सत्यापन'),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        StatusPill(verified ? 'verified' : 'pending', warning: !verified),
        const SizedBox(height: 10),
        Text(
            verified
                ? t('Your account is verified. Buyers can see your verified badge.',
                    'आपका खाता सत्यापित है। खरीदार सत्यापित बैज देख सकते हैं।')
                : t('Verification is reviewed manually by an administrator. You can keep using your account while it is pending.',
                    'सत्यापन एडमिन मैन्युअल रूप से देखेगा। समीक्षा के दौरान भी खाता चलेगा।'),
            style: const TextStyle(fontSize: 11, height: 1.6))
      ])),
      CraftButton(t('Sign out', 'साइन आउट'), secondary: true,
          onPressed: () async {
        final yes = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
                    title: Text(t('Sign out?', 'साइन आउट करें?')),
                    content: Text(t(
                        'You will need to sign in again to continue.',
                        'जारी रखने के लिए दोबारा साइन इन करना होगा।')),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: Text(t('Cancel', 'रद्द करें'))),
                      TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: Text(t('Sign out', 'साइन आउट')))
                    ]));
        if (yes == true) await ref.read(sessionProvider).signOut();
      }),
      CraftButton(t('Help & scope', 'मदद और जानकारी'),
          secondary: true, onPressed: () => go('help')),
    ];
  }

  List<Widget> saved() => [
        title('Saved suppliers', 'सहेजे आपूर्तिकर्ता'),
        ...repo
            .table('profiles')
            .where((p) => (repo.state['saved'] as List)
                .contains('${repo.actor}:${p['id']}'))
            .map((p) => CraftCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('${p['name']}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${p['location']}',
                          style: const TextStyle(fontSize: 11)),
                      CraftButton(
                          t('Order history & reorder',
                              'ऑर्डर इतिहास और फिर खरीदें'),
                          onPressed: () => go('orders', '${p['id']}')),
                      CraftButton(
                          t('Remove saved supplier', 'सहेजी सूची से हटाएँ'),
                          secondary: true,
                          onPressed: () =>
                              action('save_supplier', {'artisan_id': p['id']}))
                    ])))
      ];
  List<Widget> channels() {
    final p = repo.lookup('products', widget.id);
    return [
      title(
          'External channel readiness',
          'बाहरी चैनल तैयारी',
          t('Separate from Aakar B2B readiness. Prepare information; no live submission.',
              'आकार की तैयारी से अलग। विवरण तैयार करें; लाइव सबमिशन नहीं।')),
      if (p == null) ...[
        CraftCard(
            child: Text(
                t('Select a product to prepare GeM, ONDC or State Board information. Buyers can explore the internal catalog now.',
                    'GeM, ONDC या राज्य बोर्ड की जानकारी तैयार करने के लिए उत्पाद चुनें।'),
                style: const TextStyle(fontSize: 12))),
        ...repo.products.map((p) => CraftButton('${p['title']}',
            secondary: true, onPressed: () => go('channels', '${p['id']}')))
      ] else
        ...['gem', 'ondc', 'state_board'].map((channel) => CraftCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      channel == 'gem'
                          ? 'GeM Portal'
                          : channel == 'ondc'
                              ? 'ONDC Network'
                              : 'State Handicraft Board',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  StatusPill(
                      '${(p['external'] as Map?)?[channel]?['status'] ?? 'not_prepared'}',
                      warning: true),
                  Text(
                      t('Demo checklist. Channel-specific rules need official verification; this does not certify eligibility.',
                          'डेमो सूची। आधिकारिक नियम जाँचने होंगे; यह पात्रता प्रमाण नहीं।'),
                      style: const TextStyle(fontSize: 11)),
                  if (repo.role == 'artisan' && p['artisan_id'] == repo.actor)
                    CraftButton(t('Prepare information', 'जानकारी तैयार करें'),
                        onPressed: () async {
                      final d = await craftForm(
                          context,
                          t('Channel preparation', 'चैनल तैयारी'),
                          [
                            const CraftField(
                                'title', 'Product title', 'उत्पाद नाम',
                                required: true),
                            const CraftField(
                                'description', 'Description', 'विवरण',
                                required: true, multiline: true),
                            const CraftField('price', 'Price (INR)', 'कीमत (₹)',
                                numeric: true, required: true),
                            const CraftField('category', 'Category', 'श्रेणी',
                                required: true),
                            const CraftField('images',
                                'Product image references', 'फ़ोटो संदर्भ',
                                required: true),
                            if (channel == 'gem') ...[
                              const CraftField(
                                  'gst_number',
                                  'GST registration (demo field)',
                                  'GST पंजीकरण (डेमो)',
                                  required: true),
                              const CraftField('moq', 'MOQ', 'न्यूनतम मात्रा',
                                  numeric: true, required: true),
                              const CraftField('capacity',
                                  'Production capacity', 'उत्पादन क्षमता',
                                  numeric: true, required: true)
                            ],
                            if (channel == 'ondc') ...[
                              const CraftField('hsn_code',
                                  'HSN code (demo field)', 'HSN कोड (डेमो)',
                                  required: true),
                              const CraftField('fulfillment_type',
                                  'Fulfillment type', 'डिलीवरी प्रकार')
                            ],
                            if (channel == 'state_board') ...[
                              const CraftField(
                                  'artisan_name', 'Artisan name', 'कारीगर नाम',
                                  required: true),
                              const CraftField(
                                  'origin_state', 'Origin state', 'राज्य',
                                  required: true),
                              const CraftField('craft_category',
                                  'Craft category', 'शिल्प श्रेणी',
                                  required: true),
                              const CraftField('gi_tag',
                                  'GI tag (if applicable)', 'GI टैग (यदि लागू)')
                            ]
                          ],
                          initial: {
                            ...p,
                            'images': p['image'],
                            'artisan_name': supplier(p['artisan_id'])
                          },
                          button: t('Save preparation · simulation',
                              'तैयारी सहेजें · डेमो'));
                      if (d != null)
                        await action('channel',
                            {'id': p['id'], 'channel': channel, 'fields': d});
                    })
                ])))
    ];
  }

  List<Widget> help() => [
        CraftCard(
            child: Text(t(
                'Demo workspace: sample products and orders, separate from your verified account.',
                'डेमो कार्यक्षेत्र: नमूना उत्पाद और ऑर्डर आपके सत्यापित खाते से अलग हैं।'))),
        title('A little help, at every step', 'हर कदम पर थोड़ी मदद'),
        ...[
          [
            t('Create, then publish', 'बनाएँ, फिर प्रकाशित करें'),
            t('Capture a clear photo, describe your craft, review the details and set your own price. Save to My Products. Publish separately when internal readiness is complete.',
                'साफ़ फ़ोटो लें, शिल्प बताएँ, विवरण जाँचें और कीमत तय करें। मेरे उत्पाद में सहेजें। तैयार होने पर अलग से प्रकाशित करें।')
          ],
          [
            t('A protected workflow', 'सुरक्षित प्रक्रिया'),
            t('Agree samples and milestones, confirm the advance, review progress when needed, inspect delivery and flag problems for manual admin review.',
                'नमूना और भुगतान चरण तय करें, अग्रिम पुष्टि करें, प्रगति जाँचें, डिलीवरी देखें और समस्या पर एडमिन की मदद लें।')
          ],
          [
            t('Payments & logistics', 'भुगतान और लॉजिस्टिक्स'),
            t('This build records simulated payments and coordinates shipping. It does not hold money, book couriers or guarantee product quality.',
                'यह बिल्ड डेमो भुगतान और शिपिंग व्यवस्था दर्ज करता है। पैसे रखना, कूरियर बुक करना या गुणवत्ता गारंटी देना शामिल नहीं।')
          ],
          [
            t('Designed for later', 'भविष्य के लिए'),
            t('Artisan-initiated Bulk Clearance, live external marketplace integrations and desktop buyer layouts are future work. The hackathon demonstrates both roles on one phone.',
                'कारीगर बल्क क्लियरेंस, लाइव बाहरी बाज़ार और डेस्कटॉप खरीदार लेआउट भविष्य में हैं। डेमो में दोनों मोड एक फ़ोन पर हैं।')
          ],
        ].map((item) => CraftCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(item[0],
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Text(item[1],
                      style: const TextStyle(fontSize: 12, height: 1.7)),
                  IconButton(
                      tooltip: t('Listen', 'सुनें'),
                      onPressed: () => speakCraft(context, item[1]),
                      icon: const Icon(Icons.volume_up_outlined))
                ])))
      ];
}

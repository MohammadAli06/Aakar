import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/app_providers.dart';
import '../../../shared/models/account.dart';
import '../data/commerce_repository.dart';
import '../domain/commerce_engine.dart';
import 'app_tour.dart';
import 'craft_forms.dart';
import 'bidding_panel.dart';
import '../data/bidding_repository.dart';
import 'craft_widgets.dart';
import 'buyer_flow_widgets.dart';
import 'inquiry_workspace.dart';
import 'artisan_insights_flow.dart';

part 'buyer_experience.dart';

/// Turns an enum-style value such as `pottery` into `Pottery`, which is the key
/// the translation table expects.
String _label(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

class CommerceScreen extends ConsumerStatefulWidget {
  final String page;
  final String? id;

  /// Optional tab to open, supplied by a deep link (e.g. a message notification
  /// asks for the inquiry's chat tab).
  final String? tab;
  const CommerceScreen({super.key, this.page = 'home', this.id, this.tab});
  @override
  ConsumerState<CommerceScreen> createState() => _CommerceScreenState();
}

class _CommerceScreenState extends ConsumerState<CommerceScreen> {
  final search = TextEditingController();
  final selected = <String>{};
  String category = 'All', location = 'All', sort = 'Recommended';
  bool verifiedOnly = false;
  String notificationFilter = 'All',
      supplierSection = 'Overview',
      priceBand = 'All';
  bool _languageAligned = false;

  /// Tour targets, one key per spotlighted widget. Built per screen state; the
  /// package registers them on build and disposes them with the state.
  final Map<String, GlobalKey> _tourKeys = {
    for (final target in const [
      'home',
      'discover',
      'products',
      'bidding',
      'inquiries',
      'orders',
      'add_product'
    ])
      target: GlobalKey()
  };
  bool _tourStarted = false;
  void _updateBuyer(VoidCallback change) => setState(change);
  CommerceRepository get repo => ref.read(commerceProvider);
  String t(String en, String hi) => bilingual(context, en, hi);
  void go(String page, [String? id]) => context.push(
      '/workspace/$page${id == null || id.isEmpty ? '' : '/${Uri.encodeComponent(id)}'}');

  /// Follows a notification's link. A message notification must land on the
  /// linked inquiry's Chat tab, even for a stored link that predates `tab=chat`.
  void openNotification(Record n) {
    final link = '${n['link'] ?? ''}';
    if (link.isEmpty) return;
    final target = link.startsWith('inquiry/') && !link.contains('tab=')
        ? '$link?tab=chat'
        : link;
    context.push('/workspace/$target');
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return t('GOOD MORNING,', 'सुप्रभात,');
    if (hour >= 12 && hour < 17) return t('GOOD AFTERNOON,', 'नमस्ते,');
    if (hour >= 17 && hour < 21) return t('GOOD EVENING,', 'शुभ संध्या,');
    return t('GOOD NIGHT,', 'शुभ रात्रि,');
  }

  /// First letter of the signed-in account for the app bar avatar.
  String _profileInitial() {
    final name = ref.watch(sessionProvider).account?.displayName.trim() ?? '';
    return name.isEmpty ? '?' : name.characters.first.toUpperCase();
  }

  /// Keeps the account's preferred language in step with this device's choice.
  ///
  /// The chat bridge reads each participant's language from their account, so a
  /// language picked before that was wired up would keep its stale server value
  /// and the two sides would look like they share a language. Runs once per
  /// screen; a failed write is retried on a later build.
  Future<void> _alignAccountLanguage(Account account) async {
    if (_languageAligned) return;
    final chosen = ref.read(selectedLanguageProvider);
    if (account.languagePref == chosen) {
      _languageAligned = true;
      return;
    }
    _languageAligned = true;
    try {
      final accounts = ref.read(accountServiceProvider);
      if (account.role == AccountRole.artisan) {
        await accounts.updateArtisanProfile(languagePref: chosen);
      } else {
        await accounts.updateBuyerProfile(languagePref: chosen);
      }
      await ref.read(sessionProvider).refresh();
    } catch (_) {
      _languageAligned = false;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.page == 'discover' && widget.id != null)
      search.text = widget.id!;
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTourIfNeeded());
  }

  @override
  void didUpdateWidget(covariant CommerceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The workspace keeps one State across tab changes, so arriving back on Home
    // (Profile → App guide, or any tab switch) has to re-check the tour here —
    // initState only runs for the first page this state ever showed.
    if (widget.page != oldWidget.page) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startTourIfNeeded());
    }
  }

  /// Runs the first-run tour once per role on Home, or replays it when Profile
  /// asked for it. Purely local: no network, no stored account state.
  Future<void> _startTourIfNeeded() async {
    if (!mounted || widget.page != 'home') return;
    final replay = ref.read(appTourReplayProvider);
    final account = ref.read(sessionProvider).account;
    final buyer =
        ((account?.role.name ?? ref.read(commerceProvider).role) == 'buyer');

    if (!replay) {
      // Already offered in this screen state, or shown on an earlier run.
      if (_tourStarted) return;
      if (await AppTour.seen(buyer: buyer)) return;
      if (!mounted) return;
    }

    final keys = AppTour.targets(buyer: buyer)
        .map((target) => _tourKeys[target]!)
        .toList(growable: false);
    if (keys.isEmpty) return;

    _tourStarted = true;
    try {
      ShowcaseView.get()
          .startShowCase(keys, delay: const Duration(milliseconds: 350));
    } catch (_) {
      // The tour is a nicety. If the coach-mark scope is unavailable it must
      // not break Home, and it must stay unrecorded so it is offered again.
      _tourStarted = false;
      return;
    }
    // An explicit replay ignores the stored flag and leaves it alone, so a new
    // account still gets its own first-run tour.
    if (replay) {
      ref.read(appTourReplayProvider.notifier).state = false;
    } else {
      await AppTour.markSeen(buyer: buyer);
    }
  }

  /// Wraps one tour target. Inert while no tour is running, so screens render
  /// exactly as before outside a tour.
  Widget _tourTarget(String target, Widget child, {required bool buyer}) {
    final order = AppTour.targets(buyer: buyer);
    final position = order.indexOf(target);
    final copy = AppTour.copy[target]!;
    return Showcase(
        key: _tourKeys[target]!,
        title: position < 0
            ? t(copy.titleEn, copy.titleHi)
            : '${position + 1}/${order.length} · ${t(copy.titleEn, copy.titleHi)}',
        description: t(copy.bodyEn, copy.bodyHi),
        // A bouncing tooltip never settles, which both distracts this audience
        // and stalls widget tests.
        disableMovingAnimation: true,
        targetBorderRadius: BorderRadius.circular(12),
        tooltipBorderRadius: BorderRadius.circular(14),
        tooltipBackgroundColor: const Color(0xFFF8F7F2),
        textColor: const Color(0xFF223C31),
        titleTextStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF223C31)),
        descTextStyle: const TextStyle(
            fontSize: 12, height: 1.4, color: Color(0xFF4A5248)),
        tooltipActions: const [
          TooltipActionButton(type: TooltipDefaultActionType.skip),
          TooltipActionButton(type: TooltipDefaultActionType.next),
        ],
        tooltipActionConfig: const TooltipActionConfig(
            position: TooltipActionPosition.inside,
            alignment: MainAxisAlignment.spaceBetween),
        child: child);
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
    // The catalogue and role follow the signed-in account; role is fixed at
    // signup rather than offered as a switch.
    final account = ref.watch(sessionProvider).account;
    if (store.ready && account != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        store.applyAccount(account);
        _alignAccountLanguage(account);
      });
    }
    final buyer = (account?.role.name ?? store.role) == 'buyer';
    final rootPages = [
      'home',
      'discover',
      'products',
      'bidding',
      'inquiries',
      'orders',
      'profile'
    ];
    final isRoot = rootPages.contains(widget.page);
    // Profile is no longer a tab: it is reached from the app bar avatar instead,
    // for both roles, so the bar keeps five destinations that are all workflows.
    // Alerts moved to the app bar bell, freeing the buyer's fifth slot for the
    // inquiry & quotation workspace that mirrors the artisan's tab.
    final items = buyer
        ? ['home', 'discover', 'inquiries', 'bidding', 'orders']
        : ['home', 'products', 'bidding', 'inquiries', 'orders'];
    final unreadNotifications =
        store.notifications.where((n) => n['read'] != true).length;
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
            // Alerts left the bottom bar and now live next to language/profile.
            IconButton(
                tooltip: t('Alerts', 'सूचनाएँ'),
                onPressed: () => go('notifications'),
                icon: Stack(clipBehavior: Clip.none, children: [
                  const Icon(Icons.notifications_outlined, size: 21),
                  if (unreadNotifications > 0)
                    Positioned(
                        right: -5,
                        top: -5,
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            constraints: const BoxConstraints(minWidth: 15),
                            decoration: BoxDecoration(
                                color: const Color(0xFFB3261E),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text('$unreadNotifications',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700))))
                ])),
            IconButton(
                tooltip: t('Choose your language', 'अपनी भाषा चुनें'),
                onPressed: () => context.push('/language'),
                icon: const Icon(Icons.language, size: 21)),
            // Profile moved here when it left the bottom bar. Sign out stays inside
            // the profile screen so it is never one stray tap from the home screen.
            Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Tooltip(
                    message: t('Your profile', 'आपकी प्रोफ़ाइल'),
                    child: InkWell(
                        onTap: () => context.go('/workspace/profile'),
                        customBorder: const CircleBorder(),
                        child: CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFFE4EEE5),
                            child: Text(_profileInitial(),
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF285448)))))))
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
                      child: widget.page == 'inquiry' && current != null
                          ? InquiryWorkspace(
                              key: ValueKey(current!['id']),
                              inquiry: current!,
                              repository: repo,
                              initialTab: widget.tab == 'chat' ? 1 : 0,
                              request: inquiry(current!),
                              quotation: inquiryQuotations(current!))
                          : RefreshIndicator(
                              onRefresh: () async {
                                try {
                                  await store.refresh();
                                } catch (_) {}
                              },
                              child: ListView(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                  icon: _tourTarget(page, Icon(_icons[page], size: 22),
                      buyer: buyer),
                  label: navLabel(page)))
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
    'bidding': Icons.gavel_outlined,
    'inquiries': Icons.forum_outlined
  };
  String navLabel(String page) => switch (page) {
        'home' => t('Home', 'होम'),
        'discover' => t('Discover', 'खोजें'),
        'orders' => t('Orders', 'ऑर्डर'),
        'notifications' => t('Alerts', 'सूचनाएँ'),
        'profile' => t('Profile', 'प्रोफ़ाइल'),
        'products' => t('Products', 'उत्पाद'),
        'bidding' => t('Bidding', 'बोली'),
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
      case 'bidding':
        return bidding();
      case 'notifications':
        return repo.role == 'buyer' ? buyerNotifications() : notifications();
      case 'profile':
        return profile();
      case 'saved':
        return savedDirectory();
      case 'supplier':
        return supplierHub();
      case 'reorder':
        return repeatPurchase();
      case 'review':
        return reviewOrder();
      case 'government':
        return governmentMarketplace();
      case 'insights':
        return [
          ArtisanInsightsFlow(
            subPage: widget.id ?? 'insights',
            products: repo.products,
            orders: repo.orders,
            inquiries: repo.inquiries,
            onNavigate: (page, [id]) => go(page, id),
          ),
        ];
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

  int get _bidCount => ref
      .watch(biddingProvider(
          ref.watch(sessionProvider).account?.id ?? 'signed-out'))
      .sessions
      .where((s) => s['status'] == 'live')
      .length;

  List<Widget> bidding() => [BiddingPanel(initialSessionId: widget.id)];

  Widget biddingSummary() => CraftCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        title('Bulk Bidding Hub', 'बल्क बोली केंद्र'),
        Text(t('Schedule your stock, review sealed offers and choose buyers.',
            'अपने स्टॉक का सत्र तय करें, गुप्त ऑफ़र देखें और खरीदार चुनें।')),
        CraftButton(t('View bidding sessions', 'बोली सत्र देखें'),
            onPressed: () => go('bidding')),
      ]));

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

  /// Home summary tile. [sub] replaces the default "View activity" caption, and
  /// [live] adds the small status dot the Bidding tile carries.
  Widget stat(String label, int count, VoidCallback tap,
          {String? sub, bool live = false}) =>
      Expanded(
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
                        Row(children: [
                          Flexible(
                              child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(label,
                                      style: const TextStyle(fontSize: 9)))),
                          if (live) ...[
                            const SizedBox(width: 4),
                            Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                    color: Color(0xFF3E9B58),
                                    shape: BoxShape.circle))
                          ]
                        ]),
                        const SizedBox(height: 6),
                        Text('$count',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 22)),
                        Text(sub ?? t('View activity', 'गतिविधि देखें'),
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
              onPressed: () => context.push('/verification')),
        TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => go('discover', search.text.trim()),
            decoration: InputDecoration(
                hintText:
                    t('Search products, artisans…', 'उत्पाद, कारीगर खोजें…'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => go('discover', search.text.trim())))),
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
          stat(
              t('Requirements', 'ज़रूरतें'),
              repo
                  .table('requirements')
                  .where((r) => r['buyer_id'] == repo.actor)
                  .length,
              () => go('requirements')),
          stat(
              t('Quotes', 'भाव'),
              repo.inquiries
                  .where((r) => (r['quotes'] as List).isNotEmpty)
                  .length,
              () => go('quotes')),
          stat(t('Orders', 'ऑर्डर'), repo.orders.length, () => go('orders')),
          stat(t('Suppliers', 'आपूर्तिकर्ता'), savedProfiles.length,
              () => go('saved'))
        ]),
        const SizedBox(height: 12),
        CraftButton(t('Bidding sessions', 'बोली सत्र'),
            secondary: true,
            icon: Icons.gavel_outlined,
            onPressed: () => go('bidding')),
        CraftButton(t('Saved suppliers', 'सहेजे आपूर्तिकर्ता'),
            secondary: true,
            icon: Icons.bookmark_outline,
            onPressed: () => go('saved')),
      ] else ...[
        Row(children: [
          stat(t('Products', 'उत्पाद'), repo.products.length,
              () => go('products')),
          stat(t('Bidding', 'बोली'), _bidCount, () => go('bidding'),
              sub: t('Live Sessions', 'लाइव सत्र'), live: _bidCount > 0),
          stat(t('Inquiries', 'पूछताछ'), repo.inquiries.length,
              () => go('inquiries')),
          stat(t('Orders', 'ऑर्डर'), repo.orders.length, () => go('orders'))
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: _tourTarget(
                  'add_product',
                  CraftButton(t('Add product', 'उत्पाद जोड़ें'),
                      icon: Icons.add,
                      expand: false,
                      compact: true,
                      onPressed: () => context.push('/workspace/create')),
                  buyer: buyer)),
          const SizedBox(width: 10),
          Expanded(
              child: CraftButton(t('Host Bidding', 'बोली शुरू करें'),
                  secondary: true,
                  icon: Icons.gavel_outlined,
                  expand: false,
                  compact: true,
                  onPressed: () => go('bidding')))
        ]),
        const SizedBox(height: 10),
        CraftButton(
          t('Business Insights', 'व्यावसायिक इनसाइट्स (Insights)'),
          icon: Icons.auto_graph_rounded,
          badge: t('NEW', 'नया'),
          onPressed: () => go('insights'),
        ),
        const SizedBox(height: 6),
        biddingSummary(),
        ...repo.products.take(2).map(productCard),
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
            onTap: () => go(buyer ? 'government' : 'channels')),
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
          t('${repo.modeLabel} · ${repo.signedIn ? 'payments and logistics are simulated.' : 'sample catalog illustrations · payments and logistics are simulated.'}',
              '${repo.modeLabel} · भुगतान व लॉजिस्टिक्स डेमो हैं।'),
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
                        StatusPill(availabilityLabel(p),
                            warning: p['available'] != true),
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
              ],
              // ── Artisan quick-action buttons ────────────────────────
              if (repo.role == 'artisan' && !select) ...[
                const SizedBox(height: 10),
                Row(children: [
                  // Left button: View (published) or Edit (draft)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => p['status'] == 'published'
                          ? go('product', '${p['id']}')
                          : context.push('/workspace/create/${p['id']}'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: const BorderSide(color: Color(0xFF285448)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        p['status'] == 'published'
                            ? t('View', 'देखें')
                            : t('Edit', 'संपादित'),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF285448)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Right button: Update (published) or Publish (draft)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => p['status'] == 'published'
                          ? context.push('/workspace/create/${p['id']}')
                          : action('publish', {'id': p['id']},
                              success:
                                  t('Product published', 'उत्पाद प्रकाशित')),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        backgroundColor: const Color(0xFF285448),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        p['status'] == 'published'
                            ? t('Update', 'अपडेट')
                            : t('Publish', 'प्रकाशित'),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ]),
              ],
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
            (priceBand == 'All' ||
                (priceBand == 'Under ₹500' && number(p['price']) < 500) ||
                (priceBand == '₹500–₹2,000' &&
                    number(p['price']) >= 500 &&
                    number(p['price']) <= 2000) ||
                (priceBand == 'Above ₹2,000' && number(p['price']) > 2000)) &&
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
            (category == 'All' || p['craft'] == category) &&
            (location == 'All' || p['location'] == location) &&
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
            artisanList ? t('Craft', 'शिल्प') : t('Category', 'श्रेणी'),
            category,
            [
              'All',
              ...(artisanList
                      ? repo
                          .table('profiles')
                          .where((p) => p['role'] == 'artisan')
                          .map((p) => '${p['craft'] ?? ''}')
                      : repo
                          .table('products')
                          .map((p) => '${p['category'] ?? ''}'))
                  .where((v) => v.isNotEmpty)
                  .toSet()
            ],
            (v) => category = v),
        filter(
            'Location',
            location,
            [
              'All',
              ...(artisanList
                      ? repo
                          .table('profiles')
                          .where((p) => p['role'] == 'artisan')
                      : repo.table('products'))
                  .map((p) => '${p['location'] ?? ''}')
                  .where((v) => v.isNotEmpty)
                  .toSet()
            ],
            (v) => location = v),
        if (!artisanList)
          filter(
              t('Price', 'मूल्य'),
              priceBand,
              ['All', 'Under ₹500', '₹500–₹2,000', 'Above ₹2,000'],
              (v) => priceBand = v),
        if (!artisanList)
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
                  CraftButton(t('View supplier', 'आपूर्तिकर्ता देखें'),
                      secondary: true, onPressed: () {
                    go('supplier', '${p['id']}');
                  }),
                  if (repo.role == 'buyer')
                    CraftButton(
                        t(
                            savedSupplier('${p['id']}')
                                ? 'Remove saved supplier'
                                : 'Save supplier',
                            savedSupplier('${p['id']}')
                                ? 'सहेजी सूची से हटाएँ'
                                : 'आपूर्तिकर्ता सहेजें'),
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
  String availabilityLabel(Record p) => p['available'] == true
      ? t('Available Now', 'अभी उपलब्ध')
      : t('Not Taking Orders', 'अभी ऑर्डर नहीं ले रहे');

  List<Widget> product(Record p) {
    final own = repo.role == 'artisan' && p['artisan_id'] == repo.actor;
    final gaps = CommerceEngine.readiness(p);
    return [
      Center(child: CraftImage('${p['image']}', size: 245)),
      const SizedBox(height: 18),
      title('${p['title']}', '${p['title']}', supplier(p['artisan_id'])),
      if (own)
        CraftCard(
            child: SwitchListTile.adaptive(
                key: const ValueKey('product-availability'),
                contentPadding: EdgeInsets.zero,
                title: Text(availabilityLabel(p),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(t('Accept new inquiries for this product.',
                    'इस उत्पाद के लिए नई पूछताछ स्वीकार करें।')),
                value: p['available'] == true,
                onChanged: repo.busy || !repo.ready
                    ? null
                    : (value) => action(
                        'availability', {'id': p['id'], 'available': value})))
      else
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
                alignment: Alignment.centerLeft,
                child: StatusPill(availabilityLabel(p),
                    warning: p['available'] != true))),
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
          Text(
              t('Edit stock, MOQ, monthly capacity and lead time in catalog details.',
                  'कैटलॉग विवरण में स्टॉक, न्यूनतम मात्रा, मासिक क्षमता और समय बदलें।'),
              style: const TextStyle(fontSize: 11)),
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
        CraftButton(t('View supplier profile', 'आपूर्तिकर्ता की प्रोफ़ाइल'),
            secondary: true,
            onPressed: () => go('supplier', '${p['artisan_id']}')),
        CraftButton(t('Send inquiry / RFQ', 'पूछताछ भेजें'),
            onPressed: p['available'] == true && !repo.busy
                ? () => sendInquiry(p)
                : null),
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
              multiline: true),
          CraftField('reference_image', 'Reference image / design (optional)',
              'संदर्भ फ़ोटो / डिज़ाइन (वैकल्पिक)'),
        ],
        initial: {
          'original': initial['original'] ?? '',
          'reference_image': initial['reference_image'] ?? ''
        },
        description: t(
            'Your words stay attached to the request. You review every structured field.',
            'आपकी बात सुरक्षित रहेगी। हर विवरण जाँचें।'),
        button: t('Structure & review', 'विवरण जाँचें'));
    if (raw == null || !mounted) return;
    final text = '${raw['original'] ?? ''}'.trim();
    if (text.isEmpty && '${raw['reference_image'] ?? ''}'.trim().isEmpty) {
      toast(t('Describe your requirement or attach a reference image.',
          'अपनी ज़रूरत बताएँ या संदर्भ फ़ोटो जोड़ें।'));
      return;
    }
    Record assisted = {'fields': {}, 'provenance': 'Manual review'};
    try {
      if (text.isNotEmpty)
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
    final matchedProducts = CommerceEngine.matches(repo.state, r);

    return [
      title(
          'Top matches for you',
          'आपके लिए उपयुक्त कारीगर',
          t('Explainable capability fit. Artisan confirmation is still required.',
              'क्षमता के आधार पर मेल। कारीगर की पुष्टि बाकी है।')),
      // Requirement summary card
      CraftCard(
        color: const Color(0xFFF3F7F3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded,
                    size: 18, color: Color(0xFF285448)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${r['product']}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF233C32)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  '${t('Qty', 'मात्रा')}: ${r['quantity']}',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600),
                ),
                Text(
                  '· ${t('Lead', 'समय')}: ${r['lead_days']} ${t('days', 'दिन')}',
                  style: const TextStyle(fontSize: 11),
                ),
                if (number(r['budget']) > 0)
                  Text(
                    '· ${t('Budget', 'बजट')}: ₹${number(r['budget']).toInt()}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF285448),
                        fontWeight: FontWeight.w600),
                  ),
                if ('${r['location'] ?? ''}'.isNotEmpty)
                  Text(
                    '· ${r['location']}',
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF6B7268)),
                  ),
              ],
            ),
          ],
        ),
      ),
      if (matchedProducts.isEmpty)
        EmptyCraft(
          t('No matching artisan products found',
              'कोई उपयुक्त उत्पाद नहीं मिला'),
          t('Try posting a requirement with broader craft categories.',
              'अलग या विस्तृत शिल्प श्रेणी के साथ खोजें।'),
        )
      else
        ...matchedProducts.map((p) {
          final score = p['match_score'] as int? ?? 50;
          final isStrongMatch = score >= 75;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Match score header above product card
              Padding(
                padding: const EdgeInsets.only(bottom: 6, top: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isStrongMatch
                            ? const Color(0xFF285448)
                            : const Color(0xFF6B8071),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '$score% ${t('Match', 'मेल')}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isStrongMatch)
                      Text(
                        t('High fit with your requirement',
                            'आपकी ज़रूरत से गहरा मेल'),
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF285448),
                            fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              productCard(p, select: true),
              CraftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('Why this matches', 'यह मेल क्यों'),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    ...(p['reasons'] as List).map((v) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('✓ $v',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF233C32))))),
                    if ((p['gaps'] as List).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(t('Things to negotiate', 'वार्ता के बिंदु'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              color: Color(0xFF9E6534))),
                      ...(p['gaps'] as List).map((g) => Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text('• $g',
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xFF9E6534))))),
                    ],
                    const SizedBox(height: 8),
                    CraftButton(t('Send inquiry', 'पूछताछ भेजें'),
                        onPressed: () => sendInquiry(p, initial: r)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          );
        }),
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
    if (data == null || !mounted) return;
    final original = [
      'Product: ${p['title']}',
      'Quantity: ${data['quantity']}',
      'Specifications: ${data['specifications'] ?? ''}',
      'Customization: ${data['customization'] ?? ''}',
      'Lead time: ${data['lead_days']} days',
      'Deadline: ${data['target_date'] ?? ''}',
      'Delivery: ${data['location']}',
      'Other requirements / packaging: ${data['packaging'] ?? ''}'
    ].join('\n');
    Record preview;
    try {
      preview = await repo.previewMessage(original, productId: '${p['id']}');
    } catch (_) {
      preview = {'text': original, 'translation': '', 'status': 'unavailable'};
    }
    if (!mounted) return;
    final reviewed = await reviewCommunication(context, preview);
    if (reviewed == null || !mounted) return;
    if (await action('inquiry', {
          'communication': reviewed,
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
              : 'Inquiries & quotations',
          widget.page == 'quotes' ? 'आपके भाव' : 'पूछताछ और भाव'),
      if (rs.isEmpty)
        EmptyCraft(
            t('A connection starts here', 'यहाँ से जुड़ाव शुरू होता है'),
            t('Send an inquiry from a product or a matched supplier.',
                'उत्पाद या मेल से पूछताछ भेजें।')),
      ...rs.map((r) {
        final quotes = records(r['quotes']);
        final latest = quotes.isEmpty ? null : quotes.last;
        final needsReview = latest != null &&
            latest['author'] != repo.role &&
            latest['status'] == 'proposed';
        return InkWell(
            onTap: () => go('inquiry', '${r['id']}'),
            child: CraftCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Expanded(
                        child: Text('${r['product_title']}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600))),
                    StatusPill('${r['status']}')
                  ]),
                  DetailRow(t('Supplier', 'आपूर्तिकर्ता'),
                      '${r[repo.role == 'buyer' ? 'artisan_name' : 'buyer_name'] ?? repo.lookup('profiles', '${r[repo.role == 'buyer' ? 'artisan_id' : 'buyer_id']}')?['name'] ?? 'Participant'}'),
                  DetailRow(t('Quantity', 'मात्रा'), '${r['quantity']}'),
                  Text('${r['location']} · ${r['lead_days']} days',
                      style: const TextStyle(fontSize: 11)),
                  if (latest != null) ...[
                    const SizedBox(height: 6),
                    DetailRow(t('Latest quotation', 'नया भाव'),
                        '${money(latest['total'])} · ${latest['status']}'),
                    if (needsReview)
                      StatusPill(
                          t('Awaiting your response', 'आपके जवाब का इंतज़ार'))
                  ],
                  const SizedBox(height: 8),
                  Text(
                      latest == null
                          ? t('View conversation →', 'बातचीत देखें →')
                          : t('View quotation →', 'भाव देखें →'),
                      style: const TextStyle(
                          color: Color(0xFF285448), fontSize: 12))
                ])));
      })
    ];
  }

  List<Widget> inquiry(Record r) {
    final buyer = repo.role == 'buyer';
    return [
      title('${r['product_title']}', '${r['product_title']}',
          '${r[buyer ? 'artisan_name' : 'buyer_name'] ?? supplier(r['artisan_id'])}'),
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
    ];
  }

  List<Widget> inquiryQuotations(Record r) {
    final buyer = repo.role == 'buyer';
    final quotes = records(r['quotes']);
    final q = quotes.isEmpty ? null : quotes.last;
    final capacityReady =
        ['confirmed', 'partial'].contains(r['capacity_status']) ||
            quotes.isNotEmpty ||
            r['bidding_session_id'] != null;
    return [
      if (!capacityReady)
        Text(t(
            'The artisan must confirm capacity before a quotation can be sent.',
            'भाव भेजने से पहले कारीगर को क्षमता की पुष्टि करनी होगी।')),
      if (capacityReady && q == null && buyer)
        Text(t(
            'Capacity received. Your artisan will prepare the first quotation.',
            'क्षमता प्राप्त हो गई। कारीगर पहला भाव तैयार करेंगे।')),
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
        if (r['status'] != 'ordered' &&
            q['author'] != repo.role &&
            q['status'] == 'proposed')
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
      if (r['status'] != 'ordered' &&
          buyer &&
          q != null &&
          q['author'] != repo.role &&
          q['status'] == 'proposed')
        CraftButton(t('Request changes', 'बदलाव माँगें'),
            secondary: true, onPressed: () => requestQuoteChange(r, q)),
      if (r['status'] != 'ordered' && capacityReady && !buyer)
        CraftButton(
            q == null
                ? t('Create quotation', 'भाव बनाएँ')
                : t('Send revised quotation', 'नया प्रस्ताव दें'),
            onPressed: () => editQuote(r, q)),
      if (r['order_id'] != null)
        CraftButton(t('View order', 'ऑर्डर देखें'),
            onPressed: () => go('order', '${r['order_id']}')),
    ];
  }

  /// Ask the artisan to revise an open quotation. The request travels as a
  /// reviewed message: the buyer's own wording is kept and any translation is
  /// optional, so quantities and deadlines are never changed silently.
  Future<void> requestQuoteChange(Record r, Record q) async {
    final d = await craftForm(
        context,
        t('Request changes', 'बदलाव माँगें'),
        const [
          CraftField('text', 'What should change?', 'क्या बदलना चाहिए?',
              required: true, multiline: true)
        ],
        description: t(
            'Describe the change you need. The artisan can then send a revised quotation.',
            'जो बदलाव चाहिए वह बताएँ। कारीगर नया भाव भेज सकेंगे।'));
    if (d == null || !mounted) return;
    final original = '${d['text'] ?? ''}'.trim();
    if (original.isEmpty) return;
    Record preview;
    try {
      preview = await repo.previewMessage(original, inquiry: r);
    } catch (_) {
      preview = {'text': original, 'translation': '', 'status': 'unavailable'};
    }
    if (!mounted) return;
    final reviewed = preview['status'] == 'same_language'
        ? preview
        : await reviewCommunication(context, preview);
    if (reviewed == null || !mounted) return;
    await action('request_change',
        {...reviewed, 'text': original, 'id': r['id'], 'quote_id': q['id']});
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
          CraftField('target_date', 'Target date', 'लक्ष्य तारीख', date: true),
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
          'unit_price':
              r['bidding_session_id'] != null ? r['budget'] : p['price'],
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

  // ── Order step helper ──────────────────────────────────────────────────────
  /// Returns a human-readable "next action" label for an artisan order card.
  String _orderNextAction(Record o) {
    final status = '${o['status']}';
    if (status == 'confirmed') return t('Review & Accept', 'स्वीकार करें');
    if (status == 'artisan_accepted' && o['prod_start_date'] == null)
      return t('Set Production Plan', 'उत्पादन योजना');
    if (status == 'artisan_accepted' || status == 'in_production')
      return t('Update Progress', 'प्रगति अपडेट करें');
    if (status == 'ready' && o['packaging_type'] == null)
      return t('Add Packaging', 'पैकिंग दर्ज करें');
    if (status == 'ready') return t('Dispatch', 'भेजें');
    if (status == 'dispatched') return t('Update Delivery', 'डिलीवरी अपडेट');
    if (status == 'in_transit') return t('Update Delivery', 'डिलीवरी अपडेट');
    if (status == 'out_for_delivery')
      return t('Update Delivery', 'डिलीवरी अपडेट');
    if (status == 'delivered')
      return t('Awaiting Completion', 'पूर्णता की प्रतीक्षा');
    if (status == 'completed') return t('Completed ✓', 'पूर्ण ✓');
    if (status == 'cancelled') return t('Cancelled', 'रद्द');
    return t('View', 'देखें');
  }

  Widget _orderCard(Record o) {
    final buyer = repo.role == 'buyer';
    final buyerName = repo.lookup('profiles', '${o['buyer_id']}')?['name'] ??
        t('Buyer', 'खरीदार');
    final artisanName = supplier(o['artisan_id']);
    final nextAction = buyer ? null : _orderNextAction(o);
    return InkWell(
        onTap: () => go('order', '${o['id']}'),
        child: CraftCard(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.receipt_long_outlined,
                    color: Color(0xFF285448)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('${o['product_title']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13))),
                StatusPill('${o['status']}')
              ]),
              const SizedBox(height: 6),
              DetailRow('${o['quantity']} ${t('units', 'इकाइयाँ')}',
                  money(o['total'])),
              Text(buyer ? artisanName : buyerName,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF6E7B6F))),
              if (nextAction != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.arrow_forward_ios,
                      size: 11, color: Color(0xFF285448)),
                  const SizedBox(width: 4),
                  Text(nextAction,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF285448),
                          fontWeight: FontWeight.w600))
                ])
              ]
            ])));
  }

  List<Widget> orderList() {
    final buyer = repo.role == 'buyer';
    final all = repo.orders
        .where((o) => widget.id == null || o['artisan_id'] == widget.id)
        .toList();

    if (buyer) {
      // Buyer sees a simple flat list, rendered once by the shared card. The
      // list previously also drew its own inline card, so every order appeared
      // twice.
      return [
        title('Your orders', 'आपके ऑर्डर',
            t('Know the next step.', 'अगला कदम जानें।')),
        if (all.isEmpty)
          EmptyCraft(
              t('No orders yet', 'अभी कोई ऑर्डर नहीं'),
              t('An accepted quotation becomes your first order.',
                  'स्वीकृत भाव से पहला ऑर्डर बनेगा।')),
        ...all.map(_orderCard),
      ];
    }

    // Artisan — tabbed: New / In Progress / Completed
    const newStatuses = {'confirmed'};
    const progressStatuses = {
      'artisan_accepted',
      'in_production',
      'ready',
      'dispatched',
      'in_transit',
      'out_for_delivery',
    };
    const doneStatuses = {'delivered', 'completed', 'cancelled'};

    final newOrders =
        all.where((o) => newStatuses.contains('${o['status']}')).toList();
    final inProgress =
        all.where((o) => progressStatuses.contains('${o['status']}')).toList();
    final done =
        all.where((o) => doneStatuses.contains('${o['status']}')).toList();

    Widget tabContent(List<Record> list, String emptyLabel, String emptyHi) =>
        list.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: EmptyCraft(emptyLabel, emptyHi))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: list.map(_orderCard).toList());

    return [
      title(
          'Your orders',
          'आपके ऑर्डर',
          t('Manage every order from receipt to delivery.',
              'रसीद से डिलीवरी तक हर ऑर्डर संभालें।')),
      // Inline tab bar using DefaultTabController.
      SizedBox(
          height: 480,
          child: DefaultTabController(
              length: 3,
              child: Column(children: [
                TabBar(
                    labelColor: const Color(0xFF285448),
                    unselectedLabelColor: const Color(0xFF828678),
                    indicatorColor: const Color(0xFF285448),
                    labelStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    tabs: [
                      Tab(text: '${t('New', 'नए')} (${newOrders.length})'),
                      Tab(
                          text:
                              '${t('In Progress', 'चल रहे')} (${inProgress.length})'),
                      Tab(text: '${t('Completed', 'पूर्ण')} (${done.length})'),
                    ]),
                Expanded(
                    child: TabBarView(children: [
                  SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: tabContent(
                          newOrders,
                          t('No new orders', 'कोई नया ऑर्डर नहीं'),
                          t('New orders from buyers appear here.',
                              'खरीदारों के नए ऑर्डर यहाँ दिखेंगे।'))),
                  SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: tabContent(
                          inProgress,
                          t('No orders in progress', 'कोई चल रहा ऑर्डर नहीं'),
                          t('Accepted orders being fulfilled appear here.',
                              'स्वीकृत ऑर्डर यहाँ दिखेंगे।'))),
                  SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: tabContent(
                          done,
                          t('No completed orders', 'कोई पूर्ण ऑर्डर नहीं'),
                          t('Delivered and completed orders appear here.',
                              'वितरित और पूर्ण ऑर्डर यहाँ दिखेंगे।'))),
                ]))
              ]))),
    ];
  }

  // ── ORDER DETAIL ──────────────────────────────────────────────────────────
  List<Widget> orderDetail(Record o) {
    final buyer = repo.role == 'buyer';
    final issues =
        repo.table('issues').where((i) => i['order_id'] == o['id']).toList();
    final open = issues.any((i) => i['status'] != 'resolved');
    final p = repo.lookup('products', '${o['product_id']}') ?? {};

    // ── Buyer view ─────────────────────────────────────────────────────────
    if (buyer) {
      final route = CommerceEngine.route(
          p, {'quantity': o['quantity'], 'location': o['location']});
      return [
        if (o['status'] == 'completed') ...completedActions(o),
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
          DetailRow(t('Lead time', 'समय'), '${o['lead_days']} days'),
          DetailRow(
              t('Delivery terms', 'डिलीवरी शर्तें'), '${o['delivery_terms']}'),
          DetailRow(t('Customization', 'बदलाव'), '${o['customization'] ?? ''}')
        ])),
        // Production tracking (read-only for buyer)
        title('Production', 'उत्पादन'),
        CraftCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StatusPill('${o['production'] ?? 'not_started'}'),
          const SizedBox(height: 8),
          if (o['prod_start_date'] != null)
            DetailRow(t('Start date', 'शुरू तारीख'), '${o['prod_start_date']}'),
          if (o['prod_completion_date'] != null)
            DetailRow(t('Expected completion', 'अपेक्षित पूर्णता'),
                '${o['prod_completion_date']}'),
          if (o['completed_units'] != null)
            DetailRow(t('Units completed', 'तैयार इकाइयाँ'),
                '${o['completed_units']} / ${o['quantity']}'),
          // Progress proofs
          for (final proof in records(o['progress_proofs']))
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${proof['milestone']}',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600)),
                      if ('${proof['note']}'.isNotEmpty)
                        Text('${proof['note']}',
                            style: const TextStyle(fontSize: 11)),
                      if ('${proof['photo_url']}'.isNotEmpty)
                        evidence('${proof['photo_url']}'),
                    ])),
        ])),
        // Shipping
        title('Packaging & delivery', 'पैकिंग और डिलीवरी'),
        CraftCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StatusPill('${o['shipment'] ?? 'not_dispatched'}'),
          const SizedBox(height: 12),
          DetailRow(t('Suggested route', 'सुझाया रास्ता'), '${route['route']}'),
          if (o['shipping'] is Map) ...[
            DetailRow(t('Courier', 'कूरियर'),
                '${(o['shipping'] as Map)['courier'] ?? ''}'),
            DetailRow(t('AWB / Tracking', 'AWB / ट्रैकिंग'),
                '${(o['shipping'] as Map)['awb_number'] ?? ''}'),
            DetailRow(t('Dispatch date', 'भेजने की तारीख'),
                '${(o['shipping'] as Map)['dispatch_date'] ?? ''}'),
            DetailRow(t('Estimated delivery', 'अनुमानित डिलीवरी'),
                '${(o['shipping'] as Map)['estimated_delivery'] ?? ''}'),
          ],
          if (['dispatched', 'in_transit'].contains(o['shipment']))
            CraftButton(t('Confirm delivery received', 'डिलीवरी प्राप्त हुई'),
                onPressed: () => action(
                    'delivery_status', {'id': o['id'], 'status': 'delivered'})),
        ])),
        // Buyer inspection
        if (o['shipment'] == 'delivered' || o['status'] == 'delivered') ...[
          title('Buyer inspection', 'खरीदार की जाँच'),
          CraftCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                StatusPill('${o['inspection'] ?? 'pending'}',
                    warning: o['inspection'] != 'accepted'),
                DetailRow(t('Agreed window', 'तय अवधि'),
                    '${o['inspection_hours'] ?? 48} hours'),
                if (o['inspection'] != 'accepted')
                  CraftButton(t('Inspect & accept', 'जाँचकर स्वीकारें'),
                      onPressed: open
                          ? null
                          : () async {
                              final d = await craftForm(
                                  context,
                                  t('Delivery inspection', 'डिलीवरी जाँच'),
                                  const [
                                    CraftField('quantity', 'Quantity received',
                                        'प्राप्त मात्रा',
                                        required: true, numeric: true),
                                    CraftField('note', 'Quality review',
                                        'गुणवत्ता जाँच',
                                        required: true, multiline: true)
                                  ],
                                  initial: {
                                    'quantity': o['quantity']
                                  });
                              if (d != null)
                                await action(
                                    'inspection', {...d, 'id': o['id']});
                            }),
                if (o['inspection'] == 'accepted' && o['status'] != 'completed')
                  CraftButton(t('Complete order', 'ऑर्डर पूरा करें'),
                      onPressed: open
                          ? null
                          : () => action('complete', {'id': o['id']}))
              ])),
        ],
        // Order progress stepper
        title('Order progress', 'ऑर्डर प्रगति'),
        CraftCard(
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(children: [
                  for (final step in const [
                    ['confirmed', 'Confirmed', 'पुष्टि'],
                    ['in_production', 'In Production', 'उत्पादन में'],
                    ['ready', 'Ready', 'तैयार'],
                    ['dispatched', 'Dispatched', 'भेज दिया'],
                    ['delivered', 'Delivered', 'पहुँच गया'],
                    ['completed', 'Completed', 'पूरा हुआ'],
                  ]) ...[
                    _buildOrderProgressStep(
                        stepKey: step[0],
                        label: t(step[1], step[2]),
                        currentStatus: '${o['status']}',
                        shipment: '${o['shipment'] ?? ''}'),
                    if (step[0] != 'completed')
                      Container(
                          width: 2,
                          height: 20,
                          margin: const EdgeInsets.only(left: 14),
                          color: const Color(0xFFD3CFC4)),
                  ]
                ]))),
        // Payment milestones
        title(
            'Payment commitments',
            'भुगतान के वादे',
            t('Demo records only. No money is held or transferred.',
                'केवल डेमो रिकॉर्ड। कोई पैसे नहीं रखे या भेजे जाते।')),
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
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('${m['trigger']}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                  Text('${m['percent']}% of total',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF6B6B6B))),
                                ])),
                            Text(money(m['amount']),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF285448)))
                          ]),
                          const SizedBox(height: 6),
                          StatusPill('${m['status']}',
                              warning: m['status'] != 'confirmed'),
                          if (buyer &&
                              m['status'] != 'confirmed' &&
                              o['status'] != 'completed')
                            Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: CraftButton(
                                    // `money` already renders the ₹ symbol.
                                    t('Pay ${money(m['amount'])} now',
                                        '${money(m['amount'])} अभी भुगतान करें'),
                                    onPressed: open
                                        ? null
                                        : () => _showPaymentSheet(o, m)))
                        ])))
                    .toList())),
        title('Production & progress', 'उत्पादन और प्रगति'),
        // Issue flag
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
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12)),
              Text('${i['description']}', style: const TextStyle(fontSize: 12)),
              if (i['resolution'] != null)
                Text('${i['resolution']}',
                    style: const TextStyle(fontSize: 12)),
            ]))),
        ExpansionTile(
            title: Text(t('Order history', 'ऑर्डर इतिहास'),
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

    // ── ARTISAN VIEW — 14-step flow ────────────────────────────────────────
    final status = '${o['status']}';
    final shipment = '${o['shipment'] ?? 'not_dispatched'}';
    final production = '${o['production'] ?? 'not_started'}';
    final artisanAccepted = o['artisan_accepted'] == true;
    final hasPlan = o['prod_start_date'] != null;
    final packagingDone = o['packaging_done'] == true;
    final shippingMap =
        o['shipping'] is Map ? o['shipping'] as Map : <String, dynamic>{};
    final progressProofs = records(o['progress_proofs']);
    final milestonesDone =
        (o['production_milestones'] as List? ?? []).cast<String>().toSet();
    final totalUnits = number(o['quantity']).toInt();
    final completedUnits = number(o['completed_units']).toInt();
    final pctComplete =
        totalUnits > 0 ? (completedUnits / totalUnits * 100).round() : 0;
    final route = CommerceEngine.route(
        p, {'quantity': o['quantity'], 'location': o['location']});

    // Helper for step header
    Widget stepHeader(int n, String en, String hi,
            {bool done = false, bool active = false}) =>
        Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: Row(children: [
              CircleAvatar(
                  radius: 13,
                  backgroundColor: done
                      ? const Color(0xFF285448)
                      : active
                          ? const Color(0xFFD4A843)
                          : const Color(0xFFE0DDD4),
                  child: done
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text('$n',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? Colors.white
                                  : const Color(0xFF828678)))),
              const SizedBox(width: 10),
              Text(t(en, hi),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: done
                          ? const Color(0xFF285448)
                          : active
                              ? const Color(0xFF6B4E19)
                              : const Color(0xFF828678))),
            ]));

    final List<Widget> widgets = [];

    // ─── Step 1 – Order details ───────────────────────────────────────────
    widgets.addAll([
      stepHeader(1, 'Order Details', 'ऑर्डर विवरण', done: true, active: false),
      CraftCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('${o['product_title']}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14))),
          StatusPill(status),
        ]),
        const SizedBox(height: 10),
        DetailRow(t('Quantity', 'मात्रा'), '${o['quantity']} units'),
        DetailRow(
            t('Price per unit', 'प्रति इकाई कीमत'), money(o['unit_price'])),
        DetailRow(t('Total amount', 'कुल राशि'), money(o['total'])),
        DetailRow(
            t('Buyer', 'खरीदार'),
            repo.lookup('profiles', '${o['buyer_id']}')?['name'] ??
                t('Buyer', 'खरीदार')),
        DetailRow(t('Lead time', 'समय'), '${o['lead_days']} days'),
        if ('${o['location'] ?? ''}'.isNotEmpty)
          DetailRow(t('Shipping address', 'शिपिंग पता'), '${o['location']}'),
        if ('${o['customization'] ?? ''}'.isNotEmpty)
          DetailRow(t('Customization', 'बदलाव'), '${o['customization']}'),
      ])),
    ]);

    // ─── Step 2-3 – Accept / Decline (only when status == confirmed) ──────
    final isNew = status == 'confirmed';
    final isDeclined = status == 'cancelled' && o['artisan_accepted'] == false;
    widgets.addAll([
      stepHeader(2, 'Accept or Decline', 'स्वीकार या अस्वीकार करें',
          done: artisanAccepted || isDeclined, active: isNew),
    ]);
    if (isNew) {
      widgets.add(CraftCard(
          color: const Color(0xFFF1FAF3),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                t('Review the order terms above and accept or decline.',
                    'ऊपर दिए ऑर्डर की शर्तें देखें और स्वीकार या अस्वीकार करें।'),
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: CraftButton(t('Accept Order', 'ऑर्डर स्वीकारें'),
                      expand: false,
                      compact: true,
                      onPressed: open
                          ? null
                          : () => action('order_accept', {'id': o['id']},
                              success: t('Order accepted!',
                                  'ऑर्डर स्वीकार कर लिया।')))),
              const SizedBox(width: 10),
              Expanded(
                  child: CraftButton(t('Decline', 'अस्वीकार करें'),
                      expand: false,
                      compact: true,
                      secondary: true,
                      onPressed: open
                          ? null
                          : () async {
                              final yes = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                          title: Text(t('Decline this order?',
                                              'यह ऑर्डर अस्वीकार करें?')),
                                          content: Text(t(
                                              'This cannot be undone.',
                                              'यह पूर्ववत नहीं किया जा सकता।')),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(c, false),
                                                child: Text(
                                                    t('Cancel', 'रद्द करें'))),
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(c, true),
                                                child: Text(
                                                    t('Decline', 'अस्वीकार')))
                                          ]));
                              if (yes == true)
                                await action('order_decline', {'id': o['id']},
                                    success: t('Order declined.',
                                        'ऑर्डर अस्वीकार किया।'));
                            }))
            ])
          ])));
    } else if (artisanAccepted) {
      widgets.add(CraftCard(
          color: const Color(0xFFF0FAF3),
          child: Row(children: [
            const Icon(Icons.check_circle, color: Color(0xFF34734D)),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(t('Order Confirmed!', 'ऑर्डर की पुष्टि!'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF285448))),
                  if (o['artisan_accepted_at'] != null)
                    Text('${o['artisan_accepted_at']}'.substring(0, 10),
                        style: const TextStyle(fontSize: 10))
                ]))
          ])));
    } else if (isDeclined) {
      widgets.add(CraftCard(
          color: const Color(0xFFFFF0E5),
          child: Row(children: [
            const Icon(Icons.cancel_outlined, color: Color(0xFFB3261E)),
            const SizedBox(width: 8),
            Text(t('You declined this order.', 'आपने यह ऑर्डर अस्वीकार किया।'))
          ])));
    }

    if (!artisanAccepted && !isNew && !isDeclined) {
      // Fallback for legacy orders that pre-date the accept step
      widgets.add(CraftCard(
          child: Row(children: [
        const Icon(Icons.check_circle, color: Color(0xFF34734D)),
        const SizedBox(width: 8),
        Text(t('Order accepted', 'ऑर्डर स्वीकार किया'))
      ])));
    }

    if (isDeclined) return widgets;

    // ─── Step 4 – Confirm (shown once accepted) ───────────────────────────
    if (artisanAccepted ||
        [
          'in_production',
          'ready',
          'dispatched',
          'in_transit',
          'out_for_delivery',
          'delivered',
          'completed'
        ].contains(status)) {
      widgets.addAll([
        stepHeader(4, 'Confirm Order', 'ऑर्डर की पुष्टि', done: true),
        CraftCard(
            color: const Color(0xFFF8FAF8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DetailRow(t('Product', 'उत्पाद'), '${o['product_title']}'),
              DetailRow(t('Quantity', 'मात्रा'), '${o['quantity']} units'),
              DetailRow(t('Total', 'कुल'), money(o['total'])),
              if (o['lead_days'] != null)
                DetailRow(
                    t('Expected dispatch', 'अनुमानित डिस्पैच'),
                    t('In ${o['lead_days']} days',
                        '${o['lead_days']} दिन में')),
            ])),
      ]);
    }

    // ─── Step 5 – Production Plan ─────────────────────────────────────────
    final canSetPlan = artisanAccepted ||
        status == 'in_production' ||
        (!artisanAccepted &&
            !isNew &&
            ![
              'ready',
              'dispatched',
              'in_transit',
              'out_for_delivery',
              'delivered',
              'completed'
            ].contains(status));
    widgets.addAll([
      stepHeader(5, 'Production Plan', 'उत्पादन योजना',
          done: hasPlan, active: canSetPlan && !hasPlan),
      if (hasPlan)
        CraftCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DetailRow(t('Start date', 'शुरू तारीख'), '${o['prod_start_date']}'),
          DetailRow(t('Expected completion', 'अपेक्षित पूर्णता'),
              '${o['prod_completion_date']}'),
          if (o['daily_target'] != null)
            DetailRow(
                t('Daily target', 'दैनिक लक्ष्य'), '${o['daily_target']}'),
          if (![
            'ready',
            'dispatched',
            'in_transit',
            'out_for_delivery',
            'delivered',
            'completed'
          ].contains(status))
            CraftButton(t('Update plan', 'योजना बदलें'),
                secondary: true,
                onPressed: () async => _showProductionPlanForm(o))
        ])),
      if (!hasPlan && canSetPlan)
        CraftCard(
            color: const Color(0xFFFFFBF0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  t('Set your production schedule to track progress.',
                      'प्रगति ट्रैक करने के लिए उत्पादन समय-सारणी सेट करें।'),
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              CraftButton(t('Set Production Plan', 'उत्पादन योजना सेट करें'),
                  onPressed: () async => _showProductionPlanForm(o))
            ])),
    ]);

    // ─── Step 6 – Track Production ────────────────────────────────────────
    const milestoneLabels = {
      'material_ready': 'Material Ready',
      'production_started': 'Production Started',
      'in_progress': 'In Progress',
      'production_complete': 'Production Completed',
    };
    const milestoneLabelsHi = {
      'material_ready': 'सामग्री तैयार',
      'production_started': 'उत्पादन शुरू',
      'in_progress': 'काम जारी',
      'production_complete': 'उत्पादन पूर्ण',
    };
    final inProd = ['in_production', 'ready'].contains(status) || hasPlan;
    widgets.addAll([
      stepHeader(6, 'Track Production', 'उत्पादन ट्रैक करें',
          done: production == 'ready' ||
              production == 'dispatched' ||
              milestonesDone.contains('production_complete'),
          active: inProd && !milestonesDone.contains('production_complete')),
      CraftCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Progress circle
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('$pctComplete% complete', '$pctComplete% पूर्ण'),
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text(
                '$completedUnits / $totalUnits ${t('pieces completed', 'इकाइयाँ पूर्ण')}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF828678))),
          ]),
          SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                  value: totalUnits > 0 ? completedUnits / totalUnits : 0,
                  backgroundColor: const Color(0xFFE0DDD4),
                  color: const Color(0xFF285448),
                  strokeWidth: 6)),
        ]),
        const SizedBox(height: 14),
        // Milestone list
        for (final key in milestoneLabels.keys) ...[
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(
                    milestonesDone.contains(key)
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: const Color(0xFF3D6B52)),
                const SizedBox(width: 10),
                Text(t(milestoneLabels[key]!, milestoneLabelsHi[key]!),
                    style: TextStyle(
                        fontSize: 12,
                        color: milestonesDone.contains(key)
                            ? const Color(0xFF285448)
                            : const Color(0xFF4A524C))),
              ]))
        ],
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
              onPressed: () => action(
                  'delivery_status', {'id': o['id'], 'status': 'in_transit'})),
        if (buyer && ['dispatched', 'in_transit'].contains(o['shipment']))
          CraftButton(t('Confirm delivery received', 'डिलीवरी प्राप्त हुई'),
              onPressed: () => action(
                  'delivery_status', {'id': o['id'], 'status': 'delivered'})),
        // Update progress button
        if (!milestonesDone.contains('production_complete') && hasPlan)
          CraftButton(t('Update Progress', 'प्रगति अपडेट करें'),
              onPressed: open ? null : () async => _showProgressForm(o)),
      ])),
      if (o['shipment'] == 'delivered') ...[
        title('Buyer inspection', 'खरीदार की जाँच'),
      ]
    ]);

    // ─── Step 7 – Progress Proof ──────────────────────────────────────────
    widgets.addAll([
      stepHeader(7, 'Add Progress Proof (Optional)', 'प्रगति प्रमाण (वैकल्पिक)',
          done: progressProofs.isNotEmpty, active: inProd),
      if (progressProofs.isNotEmpty)
        CraftCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StatusPill('${o['inspection']}'),
          Text(t('${progressProofs.length} update(s) shared',
              '${progressProofs.length} अपडेट साझा किए')),
          ...progressProofs.take(2).map((pr) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                const Icon(Icons.photo_outlined,
                    size: 16, color: Color(0xFF285448)),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(
                        '${pr['milestone']} · ${pr['note'].toString().isNotEmpty ? pr['note'] : t('No note', 'नोट नहीं')}',
                        style: const TextStyle(fontSize: 11))),
              ]))),
        ])),
      if (inProd)
        CraftButton(t('Upload Progress Photo', 'फ़ोटो अपलोड करें'),
            secondary: true,
            icon: Icons.add_a_photo_outlined,
            onPressed: () async => _showProgressProofForm(o)),
    ]);

    // ─── Step 8 – Mark Production Complete ───────────────────────────────
    final productionComplete = milestonesDone.contains('production_complete') ||
        production == 'ready' ||
        production == 'dispatched';
    widgets.addAll([
      stepHeader(8, 'Mark Production Complete', 'उत्पादन पूर्ण करें',
          done: productionComplete, active: inProd && !productionComplete),
      if (!productionComplete && hasPlan)
        CraftCard(
            color: const Color(0xFFFFFBF0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  t('All units ready? Mark production as complete.',
                      'सभी इकाइयाँ तैयार? उत्पादन पूर्ण करें।'),
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              CraftButton(t('Production Complete', 'उत्पादन पूर्ण'),
                  onPressed: open
                      ? null
                      : () async {
                          final d = await craftForm(context,
                              t('Production Complete', 'उत्पादन पूर्ण'), [
                            CraftField('completed_units',
                                'Total units completed', 'कुल तैयार इकाइयाँ',
                                numeric: true, required: true)
                          ],
                              initial: {
                                'completed_units': o['quantity']
                              });
                          if (d != null)
                            await action(
                                'production_complete',
                                {
                                  'id': o['id'],
                                  'completed_units':
                                      int.tryParse('${d['completed_units']}') ??
                                          0
                                },
                                success: t('Production marked complete!',
                                    'उत्पादन पूर्ण हो गया!'));
                        })
            ])),
      if (productionComplete)
        CraftCard(
            color: const Color(0xFFF0FAF3),
            child: Row(children: [
              const Icon(Icons.check_circle, color: Color(0xFF34734D)),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(t('Production Completed!', 'उत्पादन पूर्ण!'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF285448))),
                    Text('$completedUnits ${t('units ready', 'इकाइयाँ तैयार')}',
                        style: const TextStyle(fontSize: 11))
                  ]))
            ])),
    ]);

    // ─── Step 9 – Packaging Details ───────────────────────────────────────
    widgets.addAll([
      stepHeader(9, 'Packaging Details', 'पैकिंग विवरण',
          done: packagingDone, active: productionComplete && !packagingDone),
      if (packagingDone)
        CraftCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        ])),
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
                onPressed: () => representation(o)),
            DetailRow(
                t('Number of boxes', 'डिब्बों की संख्या'), '${o['num_boxes']}'),
            if (o['total_weight'] != null)
              DetailRow(t('Total weight', 'कुल वजन'), '${o['total_weight']}'),
            if (o['packaging_photo'] != null)
              evidence('${o['packaging_photo']}'),
            if (!shipmentDispatched(o))
              CraftButton(t('Edit packaging', 'पैकिंग बदलें'),
                  secondary: true, onPressed: () => representation(o)),
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
      if (!packagingDone && productionComplete)
        CraftCard(
            color: const Color(0xFFFFFBF0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  t('Enter packaging details before dispatching.',
                      'डिस्पैच से पहले पैकिंग विवरण दर्ज करें।'),
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              CraftButton(t('Add Packaging Details', 'पैकिंग विवरण जोड़ें'),
                  onPressed: () => _showPackagingForm(o))
            ])),
    ]);

    // ─── Step 10 – Dispatch Order ─────────────────────────────────────────
    final dispatched = shipmentDispatched(o);
    widgets.addAll([
      stepHeader(10, 'Dispatch Order', 'ऑर्डर भेजें',
          done: dispatched, active: packagingDone && !dispatched),
      if (!dispatched && packagingDone)
        CraftCard(
            color: const Color(0xFFFFFBF0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  t('Enter courier and tracking details to dispatch.',
                      'डिस्पैच के लिए कूरियर और ट्रैकिंग विवरण दर्ज करें।'),
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              CraftButton(t('Mark as Dispatched', 'डिस्पैच करें'),
                  onPressed: open ? null : () => _showDispatchForm(o))
            ])),
    ]);

    // ─── Step 11 – Dispatch Confirmation ─────────────────────────────────
    if (dispatched) {
      widgets.addAll([
        stepHeader(11, 'Dispatch Confirmation', 'डिस्पैच की पुष्टि',
            done: true),
        CraftCard(
            color: const Color(0xFFF0FAF3),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.local_shipping,
                    color: Color(0xFF285448), size: 28),
                const SizedBox(width: 10),
                Text(t('Order Dispatched!', 'ऑर्डर भेज दिया!'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF285448))),
              ]),
              ExpansionTile(
                  title: Text(
                      t('Order history & evidence', 'ऑर्डर इतिहास और प्रमाण'),
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
              const SizedBox(height: 10),
              if (shippingMap['awb_number'] != null)
                DetailRow(t('Tracking ID', 'ट्रैकिंग ID'),
                    '${shippingMap['awb_number']}'),
              if (shippingMap['courier'] != null)
                DetailRow(t('Courier', 'कूरियर'), '${shippingMap['courier']}'),
              if (shippingMap['dispatch_date'] != null)
                DetailRow(t('Dispatch date', 'भेजने की तारीख'),
                    '${shippingMap['dispatch_date']}'),
              if (shippingMap['estimated_delivery'] != null)
                DetailRow(t('Estimated delivery', 'अनुमानित डिलीवरी'),
                    '${shippingMap['estimated_delivery']}'),
            ])),
      ]);
    }

    // ─── Step 12 – Delivery Status ────────────────────────────────────────
    final deliveryStatus = '${shippingMap['status'] ?? shipment}';
    final deliveryStatuses = [
      'dispatched',
      'in_transit',
      'out_for_delivery',
      'delivered'
    ];
    widgets.addAll([
      stepHeader(12, 'Delivery Status', 'डिलीवरी स्थिति',
          done: deliveryStatus == 'delivered',
          active: dispatched && deliveryStatus != 'delivered'),
      CraftCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final ds in deliveryStatuses) ...[
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Icon(
                    deliveryStatuses.indexOf(deliveryStatus) >=
                            deliveryStatuses.indexOf(ds)
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: deliveryStatuses.indexOf(deliveryStatus) >=
                            deliveryStatuses.indexOf(ds)
                        ? const Color(0xFF285448)
                        : const Color(0xFFB0B5A8)),
                const SizedBox(width: 10),
                Text(
                    t(
                        ds
                            .replaceAll('_', ' ')
                            .split(' ')
                            .map((w) => w.isEmpty
                                ? w
                                : w[0].toUpperCase() + w.substring(1))
                            .join(' '),
                        {
                          'dispatched': 'भेजा गया',
                          'in_transit': 'रास्ते में',
                          'out_for_delivery': 'डिलीवरी के लिए',
                          'delivered': 'डिलीवर हो गया'
                        }[ds]!),
                    style: TextStyle(
                        fontSize: 12,
                        color: deliveryStatuses.indexOf(deliveryStatus) >=
                                deliveryStatuses.indexOf(ds)
                            ? const Color(0xFF285448)
                            : const Color(0xFF828678)))
              ]))
        ],
        const SizedBox(height: 6),
        Text(
            t('Tracking updates are manual. Aakar does not operate logistics.',
                'ट्रैकिंग अपडेट मैन्युअल हैं। ऐप लॉजिस्टिक्स नहीं चलाता।'),
            style: const TextStyle(fontSize: 10, color: Color(0xFF828678))),
        if (dispatched && deliveryStatus != 'delivered') ...[
          const SizedBox(height: 8),
          CraftButton(t('Update Delivery Status', 'डिलीवरी स्थिति अपडेट करें'),
              secondary: true, onPressed: () async {
            final currentIdx = deliveryStatuses.indexOf(deliveryStatus);
            final nextStatuses = deliveryStatuses.skip(currentIdx + 1).toList();
            if (nextStatuses.isEmpty) return;
            final d = await craftForm(
                context, t('Update Delivery', 'डिलीवरी अपडेट'), [
              CraftField('status', 'Delivery status', 'डिलीवरी स्थिति',
                  options: nextStatuses, required: true)
            ]);
            if (d != null)
              await action(
                  'delivery_status', {'id': o['id'], 'status': d['status']},
                  success: t(
                      'Delivery status updated.', 'डिलीवरी स्थिति अपडेट हुई।'));
          })
        ],
      ])),
    ]);

    // ─── Step 13 – Order Completed ────────────────────────────────────────
    final isCompleted = status == 'completed' || deliveryStatus == 'delivered';
    widgets.addAll([
      stepHeader(13, 'Order Completed', 'ऑर्डर पूर्ण',
          done: status == 'completed',
          active: deliveryStatus == 'delivered' && status != 'completed'),
      if (status == 'completed')
        CraftCard(
            color: const Color(0xFFF0FAF3),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.celebration,
                    color: Color(0xFF285448), size: 28),
                const SizedBox(width: 10),
                Text(t('Order Completed!', 'ऑर्डर पूर्ण!'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xFF285448))),
              ]),
              const SizedBox(height: 10),
              Text(
                  t('Great work! Your order has been delivered successfully.',
                      'शाबाश! आपका ऑर्डर सफलतापूर्वक डिलीवर हो गया।'),
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              CraftButton(t('Go to My Orders', 'मेरे ऑर्डर'),
                  secondary: true, onPressed: () => go('orders')),
            ])),
    ]);

    // ─── Step 14 – Buyer Connect ──────────────────────────────────────────
    widgets.addAll([
      stepHeader(14, 'Reorder / Buyer Connect', 'खरीदार से जुड़ें',
          done: false, active: isCompleted),
      CraftCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('Stay Connected', 'जुड़े रहें'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 6),
        Text(
            t('Save this buyer for future opportunities and repeat orders.',
                'भविष्य के अवसरों के लिए इस खरीदार को सहेजें।'),
            style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: CraftButton(t('Save Buyer', 'खरीदार सहेजें'),
                  expand: false,
                  compact: true,
                  onPressed: () => action(
                      'save_supplier', {'artisan_id': o['buyer_id']},
                      success: t('Buyer saved!', 'खरीदार सहेजा गया!')))),
          const SizedBox(width: 10),
          Expanded(
              child: CraftButton(t('View All Buyers', 'सभी खरीदार'),
                  secondary: true,
                  expand: false,
                  compact: true,
                  onPressed: () => go('saved'))),
        ])
      ])),
    ]);

    // Issue flagging (always available for artisan on non-completed orders)
    if (status != 'completed') {
      widgets.add(CraftButton(t('Flag an issue', 'समस्या बताएँ'),
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
      }));
    }
    // Issues
    widgets.addAll(issues.map((i) => CraftCard(
        color: const Color(0xFFFFF0E5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              t('Manual admin review. No automatic refunds.',
                  'एडमिन समीक्षा करेगा।'),
              style: const TextStyle(fontSize: 10))
        ]))));

    // Order history
    widgets.add(ExpansionTile(
        title: Text(t('Order history', 'ऑर्डर इतिहास'),
            style: const TextStyle(fontSize: 13)),
        children: records(o['events'])
            .reversed
            .map((e) => ListTile(
                leading:
                    const Icon(Icons.circle, size: 8, color: Color(0xFF285448)),
                title:
                    Text('${e['title']}', style: const TextStyle(fontSize: 11)),
                subtitle: Text('${e['role']} · ${e['time']}',
                    style: const TextStyle(fontSize: 9))))
            .toList()));

    return widgets;
  }

  bool shipmentDispatched(Record o) {
    final s = '${o['status']}';
    return [
      'dispatched',
      'in_transit',
      'out_for_delivery',
      'delivered',
      'completed'
    ].contains(s);
  }

  Future<void> _showProductionPlanForm(Record o) async {
    final d = await craftForm(
        context,
        t('Plan Your Production', 'उत्पादन योजना बनाएँ'),
        const [
          CraftField('prod_start_date', 'Start date', 'शुरू तारीख',
              required: true, date: true),
          CraftField(
              'prod_completion_date', 'Expected completion', 'अपेक्षित पूर्णता',
              required: true, date: true),
          CraftField(
              'daily_target',
              'Daily target (optional, e.g. 5 pieces/day)',
              'दैनिक लक्ष्य (वैकल्पिक)'),
        ],
        initial: {
          'prod_start_date': o['prod_start_date'] ?? '',
          'prod_completion_date': o['prod_completion_date'] ?? '',
          'daily_target': o['daily_target'] ?? '',
        },
        button: t('Save Plan', 'योजना सहेजें'));
    if (d != null)
      await action('production_plan', {...d, 'id': o['id']},
          success: t('Production plan saved.', 'उत्पादन योजना सहेजी गई।'));
  }

  Future<void> _showProgressForm(Record o) async {
    final milestones = ['material_ready', 'production_started', 'in_progress'];
    final done =
        (o['production_milestones'] as List? ?? []).cast<String>().toSet();
    final remaining = milestones.where((m) => !done.contains(m)).toList();
    if (remaining.isEmpty) {
      toast(t('All milestones done. Mark production complete.',
          'सभी मील के पत्थर पूर्ण। उत्पादन पूर्ण करें।'));
      return;
    }
    final d =
        await craftForm(context, t('Update Production', 'उत्पादन अपडेट करें'), [
      CraftField('milestone', 'Milestone reached', 'पहुँचा मील का पत्थर',
          options: remaining, required: true),
      const CraftField(
          'completed_units', 'Units completed so far', 'अब तक तैयार इकाइयाँ',
          numeric: true, required: true),
    ], initial: {
      'milestone': remaining.first,
      'completed_units': o['completed_units'] ?? 0
    });
    if (d != null)
      await action(
          'production_progress',
          {
            ...d,
            'id': o['id'],
            'completed_units': int.tryParse('${d['completed_units']}') ?? 0,
          },
          success: t('Progress updated.', 'प्रगति अपडेट हुई।'));
  }

  Future<void> _showProgressProofForm(Record o) async {
    final d = await evidenceForm(
        t('Add Progress Proof', 'प्रगति प्रमाण जोड़ें'), const [
      CraftField('milestone', 'Milestone / stage', 'मील का पत्थर / चरण',
          required: true,
          options: ['material_ready', 'production_started', 'in_progress']),
      CraftField('note', 'Note for buyer (optional)', 'खरीदार के लिए नोट'),
    ]);
    if (d != null)
      await action(
          'production_progress',
          {
            ...d,
            'id': o['id'],
            'completed_units': o['completed_units'] ?? 0,
            if (d['evidence'] != null) 'photo_url': d['evidence'],
          },
          success: t('Proof uploaded.', 'प्रमाण अपलोड हुआ।'));
  }

  Future<void> _showPackagingForm(Record o) async {
    final d = await craftForm(
        context,
        t('Packaging Details', 'पैकिंग विवरण'),
        const [
          CraftField('packaging_type', 'Type of packaging', 'पैकिंग का प्रकार',
              required: true,
              options: ['Carton Box', 'Jute Bag', 'Bubble Wrap', 'Custom']),
          CraftField('num_boxes', 'Number of boxes', 'डिब्बों की संख्या',
              numeric: true, required: true),
          CraftField('total_weight', 'Total weight (e.g. 5.2 kg)',
              'कुल वजन (जैसे 5.2 kg)'),
        ],
        initial: {
          'packaging_type': o['packaging_type'] ?? '',
          'num_boxes': o['num_boxes'] ?? 1,
          'total_weight': o['total_weight'] ?? '',
        },
        button: t('Save & Continue', 'सहेजें और जारी रखें'));
    if (d != null)
      await action(
          'packaging',
          {
            ...d,
            'id': o['id'],
            'num_boxes': int.tryParse('${d['num_boxes']}') ?? 1,
          },
          success: t('Packaging details saved.', 'पैकिंग विवरण सहेजा गया।'));
  }

  Future<void> _showDispatchForm(Record o) async {
    final d = await craftForm(
        context,
        t('Dispatch Order', 'ऑर्डर भेजें'),
        const [
          CraftField(
              'courier', 'Courier / transport partner', 'कूरियर / ट्रांसपोर्ट',
              required: true),
          CraftField(
              'awb_number', 'Tracking ID / AWB number', 'ट्रैकिंग ID / AWB',
              required: true),
          CraftField('dispatch_date', 'Dispatch date', 'भेजने की तारीख',
              required: true, date: true),
          CraftField(
              'estimated_delivery', 'Estimated delivery', 'अनुमानित डिलीवरी',
              required: true, date: true),
        ],
        button: t('Mark as Dispatched', 'डिस्पैच करें'));
    if (d != null)
      await action('dispatch_order', {...d, 'id': o['id']},
          success: t('Order dispatched!', 'ऑर्डर भेज दिया!'));
  }

  // ── Payment method bottom sheet (demo) ────────────────────────────────────
  Future<void> _showPaymentSheet(Record o, Record milestone) async {
    String? selected;
    const methods = {
      'upi': ['UPI / Google Pay / PhonePe', 'UPI आईडी से भुगतान'],
      'card': ['Credit / Debit Card', 'क्रेडिट / डेबिट कार्ड'],
      'netbanking': ['Net Banking', 'नेट बैंकिंग'],
      'cod': ['Cash on Delivery', 'नकद डिलीवरी पर'],
    };
    final chosen = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          String t(String en, String hi) => bilingual(ctx, en, hi);
          return StatefulBuilder(
              builder: (ctx, setState) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(t('Choose Payment Method', 'भुगतान का तरीका'),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close))
                        ]),
                        Text(
                            '${t('Amount:', 'राशि:')} ${money(milestone['amount'])} · ${t('Demo mode — no real transaction', 'डेमो — वास्तविक लेन-देन नहीं')}',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF6B6B6B))),
                        const SizedBox(height: 16),
                        for (final m in methods.entries)
                          RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              title: Text(t(m.value[0], m.value[1])),
                              value: m.key,
                              groupValue: selected,
                              activeColor: const Color(0xFF285448),
                              onChanged: (v) => setState(() => selected = v)),
                        const SizedBox(height: 12),
                        SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF285448),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14)),
                                onPressed: selected == null
                                    ? null
                                    : () => Navigator.pop(ctx, selected),
                                child: Text(t('Confirm Payment', 'भुगतान करें'),
                                    style: const TextStyle(fontSize: 15)))),
                        const SizedBox(height: 8),
                        Center(
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.lock_outline,
                              size: 12, color: Color(0xFF6B6B6B)),
                          const SizedBox(width: 4),
                          Text(
                              t('100% Safe & Secure · Demo only',
                                  '100% सुरक्षित · केवल डेमो'),
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xFF6B6B6B)))
                        ])),
                      ])));
        });
    if (chosen == null || !mounted) return;
    // Only confirm once the payment is actually recorded. Previously this
    // celebrated regardless, so a failed write still read "Order Received!".
    final recorded = await action('pay', {
      'id': o['id'],
      'milestone_id': milestone['id'],
      'reference':
          'Demo payment via ${methods[chosen]![0]} — no funds transferred'
    });
    if (!recorded || !mounted) return;
    await showDialog(
        context: context,
        builder: (ctx) {
          String t(String en, String hi) => bilingual(ctx, en, hi);
          return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_rounded,
                    size: 64, color: Color(0xFF34734D)),
                const SizedBox(height: 16),
                Text(t('Order Received!', 'ऑर्डर मिल गया!'),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                    t('Payment confirmed. The artisan has been notified and will begin production soon.',
                        'भुगतान की पुष्टि हो गई। कारीगर को सूचित किया गया है और वे जल्द उत्पादन शुरू करेंगे।'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF1EBDD),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                        t('Demo record only. Aakar does not hold money or book carriers.',
                            'केवल डेमो रिकॉर्ड। ऐप पैसे नहीं रखता या कूरियर बुक नहीं करता।'),
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF6B6B6B)))),
                const SizedBox(height: 16),
                FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF285448)),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(t('View Order', 'ऑर्डर देखें')))
              ]));
        });
  }

  // ── Order progress step widget ─────────────────────────────────────────────
  static const _orderStatusOrder = [
    'confirmed',
    'artisan_accepted',
    'in_production',
    'ready',
    'dispatched',
    'in_transit',
    'out_for_delivery',
    'delivered',
    'completed',
  ];

  Widget _buildOrderProgressStep({
    required String stepKey,
    required String label,
    required String currentStatus,
    required String shipment,
  }) {
    // Resolve "dispatched" via either status or shipment field
    final resolvedStatus =
        ['dispatched', 'in_transit', 'out_for_delivery'].contains(shipment)
            ? shipment
            : currentStatus;
    final currentIdx = _orderStatusOrder.indexOf(resolvedStatus);
    final stepIdx = _orderStatusOrder.indexOf(stepKey);
    final isDone = currentIdx >= stepIdx && stepIdx >= 0 && currentIdx >= 0;
    final isActive = resolvedStatus == stepKey ||
        (stepKey == 'dispatched' &&
            ['dispatched', 'in_transit', 'out_for_delivery']
                .contains(resolvedStatus));
    return Row(children: [
      Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? const Color(0xFF285448)
                  : isActive
                      ? const Color(0xFF6BAA88)
                      : const Color(0xFFE9E4D7),
              border: isActive && !isDone
                  ? Border.all(color: const Color(0xFF285448), width: 2)
                  : null),
          child: Icon(isDone ? Icons.check : Icons.circle,
              size: isDone ? 16 : 8,
              color: isDone
                  ? Colors.white
                  : isActive
                      ? const Color(0xFF285448)
                      : const Color(0xFFACA9A2))),
      const SizedBox(width: 12),
      Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight:
                  isDone || isActive ? FontWeight.w600 : FontWeight.normal,
              color: isDone
                  ? const Color(0xFF285448)
                  : isActive
                      ? const Color(0xFF285448)
                      : const Color(0xFF9B9790))),
      if (isActive && !isDone) ...[
        const SizedBox(width: 8),
        StatusPill('active')
      ]
    ]);
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
      // The only date field that also needs a clock time.
      CraftField('date', 'Date & time', 'तारीख और समय',
          required: true, date: true, withTime: true),
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
                onTap: n['link'] == null ? null : () => openNotification(n))))
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
        if (!isArtisan) ...[
          DetailRow(t('Business type', 'व्यवसाय का प्रकार'),
              account?.businessType ?? '—'),
          DetailRow(t('Industry / category', 'उद्योग / श्रेणी'),
              account?.industry ?? '—'),
          DetailRow(t('Work email', 'कार्य ईमेल'),
              '${account?.profile['work_email'] ?? ''}'),
          DetailRow(
              t('Website', 'वेबसाइट'), '${account?.profile['website'] ?? ''}'),
        ],
        DetailRow(t('Location', 'स्थान'), location.isEmpty ? '—' : location),
        DetailRow(t('Contact', 'संपर्क'), contact),
      ])),
      CraftButton(t('Edit profile', 'प्रोफ़ाइल बदलें'),
          onPressed: () => context.push('/profile/edit')),
      CraftButton(t('View verification', 'सत्यापन देखें'),
          secondary: true, onPressed: () => context.push('/verification')),
      // Replays the same tour without touching the stored "seen" flag, so a new
      // account still gets its first-run walkthrough.
      CraftButton(t('App guide', 'ऐप गाइड'),
          secondary: true,
          icon: Icons.tips_and_updates_outlined, onPressed: () {
        ref.read(appTourReplayProvider.notifier).state = true;
        context.go('/workspace/home');
      }),
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
                'Your products are saved to your Aakar account on the shared backend. Orders, payments and shipping in this build are simulated.',
                'आपके उत्पाद आकार खाते में साझा बैकएंड पर सहेजे जाते हैं। इस बिल्ड में ऑर्डर, भुगतान और शिपिंग डेमो हैं।'))),
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

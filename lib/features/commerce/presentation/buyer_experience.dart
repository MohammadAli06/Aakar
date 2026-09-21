part of 'commerce_screen.dart';

extension _BuyerExperience on _CommerceScreenState {
  bool savedSupplier(String id) =>
      (repo.state['saved'] as List).contains('${repo.actor}:$id');
  List<Record> get savedProfiles => repo
      .table('profiles')
      .where((p) => p['role'] == 'artisan' && savedSupplier('${p['id']}'))
      .toList();

  List<Widget> supplierHub() {
    final p = repo.lookup('profiles', widget.id);
    if (p == null || p['role'] != 'artisan') return missing();
    final products = repo
        .table('products')
        .where((v) => v['artisan_id'] == p['id'] && v['status'] == 'published')
        .toList();
    final orders =
        repo.orders.where((o) => o['artisan_id'] == p['id']).toList();
    final reviews = repo
        .table('orders')
        .where((o) =>
            o['artisan_id'] == p['id'] &&
            o['status'] == 'completed' &&
            o['review'] is Map)
        .map((o) => o['review'] as Map)
        .toList();
    return [
      title(
          '${p['name']}',
          '${p['name']}',
          t('Continue your supplier relationship',
              'आपूर्तिकर्ता से जुड़ाव बनाए रखें')),
      Wrap(spacing: 8, children: [
        for (final tab in const {
          'Overview': 'परिचय',
          'Products': 'उत्पाद',
          'Past orders': 'पुराने ऑर्डर'
        }.entries)
          ChoiceChip(
              label: Text(t(tab.key, tab.value)),
              selected: supplierSection == tab.key,
              onSelected: (_) => _updateBuyer(() => supplierSection = tab.key))
      ]),
      const SizedBox(height: 14),
      if (supplierSection == 'Overview') ...[
        CraftCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.storefront_outlined, size: 38),
            const SizedBox(width: 12),
            Expanded(
                child: Text('${p['name']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 20)))
          ]),
          const SizedBox(height: 12),
          StatusPill('${p['verification']}'),
          DetailRow(t('Region', 'क्षेत्र'), '${p['location'] ?? ''}'),
          DetailRow(t('Specialization', 'विशेषज्ञता'), '${p['craft'] ?? ''}'),
          if (number(p['experience']) > 0)
            DetailRow(t('Experience', 'अनुभव'),
                '${p['experience']} ${t('years', 'वर्ष')}'),
          if ('${p['story'] ?? ''}'.isNotEmpty) Text('${p['story']}'),
          DetailRow(
              t('Published products', 'प्रकाशित उत्पाद'), '${products.length}'),
          DetailRow(t('Your orders', 'आपके ऑर्डर'), '${orders.length}'),
          DetailRow(
              t('Workspace buyer reviews', 'वर्कस्पेस की समीक्षाएँ'),
              reviews.isEmpty
                  ? t('No reviews yet', 'अभी कोई समीक्षा नहीं')
                  : '${(reviews.fold<double>(0, (s, r) => s + number(r['rating'])) / reviews.length).toStringAsFixed(1)} / 5 (${reviews.length})'),
        ])),
        CraftButton(t('View catalogue', 'उत्पाद देखें'),
            onPressed: () => _updateBuyer(() => supplierSection = 'Products')),
        CraftButton(
            t(
                savedSupplier('${p['id']}')
                    ? 'Remove saved supplier'
                    : 'Save supplier',
                savedSupplier('${p['id']}')
                    ? 'सहेजी सूची से हटाएँ'
                    : 'आपूर्तिकर्ता सहेजें'),
            secondary: true,
            onPressed: () => action('save_supplier', {'artisan_id': p['id']})),
        CraftCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          title('Start a new inquiry', 'नई पूछताछ शुरू करें'),
          Text(t(
              'Choose a current product to discuss quantity, customization and delivery.',
              'मात्रा, बदलाव और डिलीवरी पर बात करने के लिए वर्तमान उत्पाद चुनें।')),
          CraftButton(t('Choose product & inquire', 'उत्पाद चुनें और पूछें'),
              onPressed: () => _updateBuyer(() => supplierSection = 'Products'))
        ])),
      ],
      if (supplierSection == 'Products') ...[
        if (products.isEmpty)
          EmptyCraft(t('No published products', 'कोई प्रकाशित उत्पाद नहीं'),
              t('Check this supplier again later.', 'बाद में फिर देखें।')),
        ...products.map((p) => productCard(p)),
      ],
      if (supplierSection == 'Past orders') ...[
        if (orders.isEmpty)
          EmptyCraft(
              t('No orders with this supplier yet',
                  'इस आपूर्तिकर्ता से अभी कोई ऑर्डर नहीं'),
              t('Start with a product inquiry.',
                  'उत्पाद के बारे में पूछताछ करें।')),
        for (final o in orders)
          CraftCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('${o['product_title']}'),
                StatusPill('${o['status']}'),
                DetailRow(t('Quantity', 'मात्रा'), '${o['quantity']}'),
                CraftButton(t('View order', 'ऑर्डर देखें'),
                    onPressed: () => go('order', '${o['id']}')),
                if (o['status'] == 'completed')
                  CraftButton(t('Reorder', 'फिर खरीदें'),
                      secondary: true,
                      onPressed: () => go('reorder', '${o['id']}')),
              ])),
      ],
    ];
  }

  List<Widget> savedDirectory() => [
        title(
            'Saved suppliers',
            'सहेजे आपूर्तिकर्ता',
            t('Your partner network for future purchases.',
                'आगामी खरीद के लिए आपके सहयोगी।')),
        if (savedProfiles.isEmpty)
          EmptyCraft(
              t('Build your supplier network', 'अपने आपूर्तिकर्ता जोड़ें'),
              t('Save an artisan from their profile or a completed order.',
                  'कारीगर की प्रोफ़ाइल या पूरे ऑर्डर से सहेजें।')),
        for (final p in savedProfiles)
          CraftCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text('${p['name']}'),
                    subtitle: Text('${p['location'] ?? ''}')),
                StatusPill('${p['verification']}'),
                CraftButton(t('View supplier', 'आपूर्तिकर्ता देखें'),
                    onPressed: () => go('supplier', '${p['id']}')),
                CraftButton(
                    t('Order history & reorder', 'ऑर्डर इतिहास और फिर खरीदें'),
                    secondary: true,
                    onPressed: () => go('orders', '${p['id']}')),
                TextButton(
                    onPressed: () =>
                        action('save_supplier', {'artisan_id': p['id']}),
                    child: Text(
                        t('Remove saved supplier', 'सहेजी सूची से हटाएँ'))),
              ])),
        CraftButton(t('Find more suppliers', 'और आपूर्तिकर्ता खोजें'),
            onPressed: () => go('artisans')),
      ];

  List<Widget> repeatPurchase() {
    final order = repo.lookup('orders', widget.id);
    if (order == null ||
        order['buyer_id'] != repo.actor ||
        order['status'] != 'completed') return missing();
    return [
      BuyerReorderPanel(
          key: ValueKey(order['id']),
          order: order,
          products: repo
              .table('products')
              .where((p) =>
                  p['artisan_id'] == order['artisan_id'] &&
                  p['status'] == 'published' &&
                  p['available'] == true)
              .toList(),
          submit: (data) async {
            final ok = await action('inquiry', data);
            if (ok && mounted) go('inquiry', '${repo.inquiries.first['id']}');
            return ok;
          })
    ];
  }

  List<Widget> reviewOrder() {
    final order = repo.lookup('orders', widget.id);
    if (order == null || order['buyer_id'] != repo.actor) return missing();
    return [
      BuyerReviewPanel(
          key: ValueKey(order['id']),
          order: order,
          submit: (data) async {
            final ok = await action('review_order', data,
                success: t('Review saved', 'समीक्षा सहेजी गई'));
            if (ok && mounted) go('order', '${order['id']}');
            return ok;
          })
    ];
  }

  List<Widget> completedActions(Record o) => [
        CraftCard(
            color: const Color(0xFFF3F8F4),
            child: Column(children: [
              Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Color(0xFF285448)),
                  child:
                      const Icon(Icons.check, size: 36, color: Colors.white)),
              const SizedBox(height: 12),
              Text(t('Order Completed!', 'ऑर्डर पूरा हुआ!'),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF285448))),
              const SizedBox(height: 4),
              Text('Order #${o['id']}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B6B6B))),
              const SizedBox(height: 4),
              Text(
                  '${o['product_title']} · ${o['quantity']} ${t('units', 'इकाइयाँ')}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDCE8DF))),
                  child: Row(children: [
                    const Icon(Icons.celebration_outlined,
                        size: 20, color: Color(0xFF285448)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            t('Thank you for supporting Indian artisans. Your order has been successfully delivered.',
                                'भारतीय कारीगरों का समर्थन करने के लिए धन्यवाद। आपका ऑर्डर सफलतापूर्वक डिलीवर हो गया है।'),
                            style: const TextStyle(fontSize: 11, height: 1.4))),
                  ])),
              const SizedBox(height: 14),
              CraftButton(t('Reorder', 'फिर खरीदें'),
                  onPressed: () => go('reorder', '${o['id']}')),
              CraftButton(
                  t(o['review'] == null ? 'Write a review' : 'Edit your review',
                      o['review'] == null ? 'समीक्षा लिखें' : 'समीक्षा बदलें'),
                  secondary: true,
                  onPressed: () => go('review', '${o['id']}')),
              CraftButton(
                  t(
                      savedSupplier('${o['artisan_id']}')
                          ? 'View saved supplier'
                          : 'Save supplier',
                      savedSupplier('${o['artisan_id']}')
                          ? 'सहेजा आपूर्तिकर्ता देखें'
                          : 'आपूर्तिकर्ता सहेजें'),
                  secondary: true,
                  onPressed: () => savedSupplier('${o['artisan_id']}')
                      ? go('supplier', '${o['artisan_id']}')
                      : action(
                          'save_supplier', {'artisan_id': o['artisan_id']})),
              if (o['review'] is Map) ...[
                const SizedBox(height: 8),
                Text('${o['review']['rating']} ★ · ${o['review']['text']}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF285448))),
              ]
            ])),
      ];

  String noticeCategory(Record n) {
    if (n['category'] != null) return '${n['category']}';
    final link = '${n['link'] ?? ''}', title = '${n['title']}'.toLowerCase();
    if (link.startsWith('order/')) return 'Orders';
    if (title.contains('quote') || title.contains('quotation')) return 'Quotes';
    if (link.startsWith('bidding')) return 'Bidding';
    return 'Others';
  }

  List<Widget> buyerNotifications() {
    final sessions = ref
        .watch(biddingProvider(
            ref.watch(sessionProvider).account?.id ?? 'signed-out'))
        .sessions;
    final items = repo.notifications
        .where((n) =>
            notificationFilter == 'All' ||
            noticeCategory(n) == notificationFilter)
        .toList();
    return [
      title('Notifications', 'सूचनाएँ'),
      Wrap(spacing: 6, children: [
        for (final e in const {
          'All': 'सभी',
          'Orders': 'ऑर्डर',
          'Quotes': 'कोटेशन',
          'Bidding': 'बोली',
          'Others': 'अन्य'
        }.entries)
          ChoiceChip(
              label: Text(t(e.key, e.value)),
              selected: notificationFilter == e.key,
              onSelected: (_) => _updateBuyer(() => notificationFilter = e.key))
      ]),
      const SizedBox(height: 12),
      if (notificationFilter != 'Bidding')
        CraftButton(t('Mark all as read', 'सभी पढ़े हुए करें'),
            secondary: true, onPressed: () => action('read_notifications', {})),
      if (items.isEmpty &&
          (!(notificationFilter == 'All' || notificationFilter == 'Bidding') ||
              sessions.isEmpty))
        EmptyCraft(t('You’re all caught up', 'आप अपडेट हैं'),
            t('Your activity will appear here.', 'आपकी गतिविधि यहाँ दिखेगी।')),
      for (final n in items)
        CraftCard(
            child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(n['read'] == true
                    ? Icons.notifications_none
                    : Icons.notifications_active_outlined),
                title: Text('${n['title']}'),
                subtitle: Text('${n['time']}'),
                onTap: n['link'] == null
                    ? null
                    : () => openNotification(n))),
      if (notificationFilter == 'All' || notificationFilter == 'Bidding') ...[
        if (sessions.isNotEmpty)
          Text(t('Current bidding activity', 'वर्तमान बोली गतिविधि')),
        for (final s in sessions)
          CraftCard(
              child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.gavel_outlined),
                  title: Text('${s['product']['title']}'),
                  subtitle: Text(
                      '${s['status']} · ${s['my_offer'] == null ? t('No offer placed', 'ऑफ़र नहीं दिया') : t('Your offer saved', 'आपका ऑफ़र सहेजा गया')}'),
                  onTap: () => go('bidding', '${s['id']}'))),
      ],
    ];
  }

  List<Widget> governmentMarketplace() => [
        title('Government marketplace', 'सरकारी बाज़ार'),
        CraftCard(
            color: const Color(0xFFF1EBDD),
            child: Column(children: [
              const Icon(Icons.account_balance_outlined, size: 58),
              StatusPill(t('Coming soon', 'जल्द आ रहा है')),
              const SizedBox(height: 14),
              Text(
                  t('Government procurement opportunities',
                      'सरकारी खरीद के अवसर'),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              Text(t(
                  'Government marketplace integration is planned. Tender discovery, applications and procurement are not available in this app yet.',
                  'सरकारी बाज़ार से जुड़ने की योजना है। टेंडर, आवेदन और सरकारी खरीद अभी इस ऐप में उपलब्ध नहीं हैं।')),
            ])),
        CraftButton(t('Browse handmade products', 'हस्तशिल्प उत्पाद देखें'),
            onPressed: () => go('discover')),
        CraftButton(t('Your business profile', 'आपकी व्यवसाय प्रोफ़ाइल'),
            secondary: true, onPressed: () => go('profile')),
      ];
}

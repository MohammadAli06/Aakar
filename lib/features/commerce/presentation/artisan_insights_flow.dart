import 'package:flutter/material.dart';
import '../domain/commerce_engine.dart';
import 'craft_widgets.dart';

class ArtisanInsightsFlow extends StatefulWidget {
  final String subPage;
  final String? initialId;
  final List<Record> products;
  final List<Record> orders;
  final List<Record> inquiries;
  final void Function(String page, [String? id]) onNavigate;

  const ArtisanInsightsFlow({
    super.key,
    required this.subPage,
    this.initialId,
    required this.products,
    required this.orders,
    required this.inquiries,
    required this.onNavigate,
  });

  @override
  State<ArtisanInsightsFlow> createState() => _ArtisanInsightsFlowState();
}

class _ArtisanInsightsFlowState extends State<ArtisanInsightsFlow> {
  String _activePage = 'insights';
  String _performanceTab = 'views'; // 'views', 'interest', 'orders'
  String _ordersSummaryTab = 'month'; // 'month', '3months'
  String _overviewRange = 'Last 30 Days';
  String? _selectedProductId;

  // Goal state
  String _goalType = 'inquiries'; // 'inquiries', 'orders', 'buyers', 'capacity'
  int _goalTarget = 20;
  int _goalCurrent = 12;
  bool _hasCustomGoal = false;

  @override
  void initState() {
    super.initState();
    _activePage = widget.subPage.isNotEmpty ? widget.subPage : 'insights';
    _selectedProductId = widget.initialId;
  }

  @override
  void didUpdateWidget(covariant ArtisanInsightsFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.subPage != oldWidget.subPage && widget.subPage.isNotEmpty) {
      _activePage = widget.subPage;
    }
    if (widget.initialId != oldWidget.initialId && widget.initialId != null) {
      _selectedProductId = widget.initialId;
    }
  }

  void _nav(String page, [String? id]) {
    setState(() {
      _activePage = page;
      if (id != null) _selectedProductId = id;
    });
  }

  String t(String en, String hi) => bilingual(context, en, hi);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_activePage != 'insights')
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                InkWell(
                  onTap: () => _nav('insights'),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAE7DE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back, size: 16, color: Color(0xFF285448)),
                        const SizedBox(width: 4),
                        Text(
                          t('Back to Insights', 'वापस इनसाइट्स'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF285448),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ..._buildCurrentSubPage(),
      ],
    );
  }

  List<Widget> _buildCurrentSubPage() {
    switch (_activePage) {
      case 'insights':
        return _buildHub();
      case 'overview':
        return _buildOverview();
      case 'performance':
        return _buildProductPerformance();
      case 'trends':
        return _buildBuyerTrends();
      case 'ai_insights':
        return _buildAiInsights();
      case 'actions':
        return _buildActionChecklist();
      case 'product_insight':
        return _buildProductDetailInsight();
      case 'inquiries_summary':
        return _buildBuyerInquiriesList();
      case 'orders_summary':
        return _buildOrdersSummary();
      case 'goal_set':
        return _buildSetGoal();
      case 'goal_progress':
        return _buildGoalProgress();
      case 'growing':
        return _buildKeepGrowing();
      default:
        return _buildHub();
    }
  }

  // ── 2. BUSINESS INSIGHTS HUB (SCREEN 2) ───────────────────────────────────
  List<Widget> _buildHub() {
    return [
      CraftCard(
        color: const Color(0xFFF3F7F3),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: Color(0xFF285448),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.eco_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 12),
            Text(
              t('Business Insights', 'व्यावसायिक इनसाइट्स'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF233C32),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t('Get a clear view of your growth and simple suggestions to grow.',
                  'अपनी प्रगति का स्पष्ट अवलोकन और व्यवसाय बढ़ाने के आसान सुझाव पाएँ।'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7268), height: 1.4),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),

      _hubMenuItem(
        icon: Icons.dashboard_customize_outlined,
        title: t('Overview', 'अवलोकन (Overview)'),
        sub: t('Key highlights in simple numbers', 'मुख्य आँकड़े और विकास प्रतिशत'),
        badge: t('Active', 'सक्रिय'),
        onTap: () => _nav('overview'),
      ),
      _hubMenuItem(
        icon: Icons.inventory_2_outlined,
        title: t('My Products Performance', 'उत्पाद प्रदर्शन'),
        sub: t('See how each product is performing', 'व्यूज, खरीदार रुचि व ऑर्डर'),
        onTap: () => _nav('performance'),
      ),
      _hubMenuItem(
        icon: Icons.trending_up_rounded,
        title: t('What Buyers Are Looking For', 'खरीदार क्या खोज रहे हैं'),
        sub: t('Trending categories and common requirements', 'बाज़ार की मांग और नई जरूरतें'),
        onTap: () => _nav('trends'),
      ),
      _hubMenuItem(
        icon: Icons.smart_toy_outlined,
        title: t('AI Insights & Suggestions', 'AI सुझाव और सलाह'),
        sub: t('Simple advice in easy language', 'आपके शिल्प के लिए आसान मार्गदर्शन'),
        badge: t('New Tips', 'नए टिप्स'),
        onTap: () => _nav('ai_insights'),
      ),
      _hubMenuItem(
        icon: Icons.flag_outlined,
        title: t('My Goals & Targets', 'मेरे लक्ष्य (Goals)'),
        sub: t('Set simple targets and monitor progress', 'मासिक लक्ष्य और प्रगति ट्रैकर'),
        onTap: () => _nav(_hasCustomGoal ? 'goal_progress' : 'goal_set'),
      ),
      _hubMenuItem(
        icon: Icons.playlist_add_check_rounded,
        title: t('Take Action', 'कार्य सूची (Next Steps)'),
        sub: t('Actionable next steps to boost growth', 'अगले कदम जो आप तुरंत उठा सकते हैं'),
        onTap: () => _nav('actions'),
      ),
    ];
  }

  Widget _hubMenuItem({
    required IconData icon,
    required String title,
    required String sub,
    String? badge,
    required VoidCallback onTap,
  }) {
    return CraftCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8EFE9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF285448), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF243B30),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF357A50),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF6E756B)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9E9E9E), size: 20),
          ],
        ),
      ),
    );
  }

  // ── 3. BUSINESS OVERVIEW (SCREEN 3) ───────────────────────────────────────
  List<Widget> _buildOverview() {
    final orderCount = widget.orders.length;
    final inqCount = widget.inquiries.length;
    final calculatedViews = (widget.products.length * 48) + (inqCount * 18) + 120;
    final calculatedInterests = (widget.products.length * 12) + (inqCount * 4) + 16;

    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            t('Business Overview', 'व्यापार अवलोकन'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF243B30)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD6D6CC)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _overviewRange,
                isDense: true,
                style: const TextStyle(fontSize: 11, color: Color(0xFF285448), fontWeight: FontWeight.w600),
                items: const [
                  DropdownMenuItem(value: 'Last 7 Days', child: Text('Last 7 Days')),
                  DropdownMenuItem(value: 'Last 30 Days', child: Text('Last 30 Days')),
                  DropdownMenuItem(value: 'Last 3 Months', child: Text('Last 3 Months')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _overviewRange = val);
                },
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),

      // 4 Metric cards in a 2x2 grid
      Row(
        children: [
          Expanded(
            child: _metricBox(
              label: t('Product Views', 'उत्पाद व्यूज़'),
              value: '$calculatedViews',
              growth: '+25%',
              isPositive: true,
              icon: Icons.visibility_outlined,
              onTap: () => _nav('performance'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricBox(
              label: t('Buyer Interests', 'खरीदार रुचि'),
              value: '$calculatedInterests',
              growth: '+40%',
              isPositive: true,
              icon: Icons.favorite_border_rounded,
              onTap: () => _nav('trends'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _metricBox(
              label: t('Inquiries', 'पूछताछ'),
              value: '$inqCount',
              growth: '+20%',
              isPositive: true,
              icon: Icons.chat_bubble_outline_rounded,
              onTap: () => _nav('inquiries_summary'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricBox(
              label: t('Orders', 'ऑर्डर'),
              value: '$orderCount',
              growth: '+33%',
              isPositive: true,
              icon: Icons.shopping_bag_outlined,
              onTap: () => _nav('orders_summary'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),

      // Progress motivation card
      CraftCard(
        color: const Color(0xFFF3F7F3),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF285448),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.thumb_up_alt_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('Good progress!', 'शानदार प्रगति!'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF285448)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    t('Your products are getting more interest and inquiries than last month. Keep it up!',
                        'आपके उत्पादों को पिछले महीने से अधिक रुचि और पूछताछ मिल रही है।'),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF5D655A)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),

      CraftButton(
        t('View Products Performance', 'उत्पाद प्रदर्शन देखें'),
        icon: Icons.arrow_forward,
        onPressed: () => _nav('performance'),
      ),
      CraftButton(
        t('Orders & Earnings Summary', 'ऑर्डर और आय सारांश'),
        secondary: true,
        icon: Icons.receipt_long,
        onPressed: () => _nav('orders_summary'),
      ),
    ];
  }

  Widget _metricBox({
    required String label,
    required String value,
    required String growth,
    required bool isPositive,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4E6DD)),
          boxShadow: const [
            BoxShadow(color: Color(0x060E3026), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF285448)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPositive ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    growth,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isPositive ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF233C32)),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF70776C)),
            ),
          ],
        ),
      ),
    );
  }

  // ── 4. MY PRODUCTS PERFORMANCE (SCREEN 4) ─────────────────────────────────
  List<Widget> _buildProductPerformance() {
    return [
      Text(
        t('My Products Performance', 'मेरे उत्पाद प्रदर्शन'),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF243B30)),
      ),
      const SizedBox(height: 10),

      // Tabs: Most Viewed, Most Interested, Most Orders
      Row(
        children: [
          for (final tab in [
            ['views', t('Most Viewed', 'सबसे ज्यादा देखे गए')],
            ['interest', t('Most Interested', 'सबसे ज्यादा रुचि')],
            ['orders', t('Most Orders', 'सबसे ज्यादा ऑर्डर')],
          ])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ChoiceChip(
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(tab[1], style: const TextStyle(fontSize: 11)),
                  ),
                  selected: _performanceTab == tab[0],
                  selectedColor: const Color(0xFF285448),
                  labelStyle: TextStyle(
                    color: _performanceTab == tab[0] ? Colors.white : const Color(0xFF285448),
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => setState(() => _performanceTab = tab[0]),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),

      if (widget.products.isEmpty)
        EmptyCraft(
          t('No products listed yet', 'अभी कोई उत्पाद नहीं'),
          t('Add your craft products to see performance insights.', 'उत्पाद जोड़ें ताकि इनसाइट्स दिख सकें।'),
        )
      else
        ...widget.products.map((p) {
          final pId = '${p['id']}';
          final title = '${p['title']}';
          final img = '${p['image'] ?? ''}';
          // Derived realistic counters
          final views = 45 + (title.length * 4);
          final interests = 6 + (title.length % 7);
          final inqs = 1 + (title.length % 4);

          return CraftCard(
            padding: const EdgeInsets.all(12),
            child: InkWell(
              onTap: () => _nav('product_insight', pId),
              child: Row(
                children: [
                  CraftImage(img, size: 68),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.visibility_outlined, size: 13, color: Color(0xFF526154)),
                            const SizedBox(width: 4),
                            Text('$views ${t('views', 'व्यूज')}', style: const TextStyle(fontSize: 11)),
                            const SizedBox(width: 10),
                            const Icon(Icons.favorite_border, size: 13, color: Color(0xFFC24138)),
                            const SizedBox(width: 4),
                            Text('$interests ${t('interested', 'रुचि')}', style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline, size: 13, color: Color(0xFF285448)),
                            const SizedBox(width: 4),
                            Text('$inqs ${t('inquiries', 'पूछताछ')}', style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF9E9E9E)),
                ],
              ),
            ),
          );
        }),
    ];
  }

  // ── 5. WHAT BUYERS ARE LOOKING FOR (SCREEN 5) ──────────────────────────────
  List<Widget> _buildBuyerTrends() {
    final topCategories = [
      {'name': t('Handwoven Cotton Sarees', 'हथकरघा सूती साड़ियाँ'), 'requests': 28},
      {'name': t('Customized Terracotta Pottery', 'टेराकोटा मिट्टी के बर्तन'), 'requests': 16},
      {'name': t('Bulk Home Decor Items', 'होम डेकोर थोक ऑर्डर'), 'requests': 12},
      {'name': t('Eco-friendly Bamboo & Cane', 'इको-फ्रेंडली बाँस शिल्प'), 'requests': 8},
      {'name': t('Tribal Brass Artifacts', 'पारंपरिक पीतल कलाकृतियाँ'), 'requests': 6},
    ];

    final commonRequirements = [
      t('“Looking for natural vegetable dyes only”', '“केवल प्राकृतिक रंगों से बनी वस्तुएँ चाहिए”'),
      t('“Need 50+ pieces for wedding gifting”', '“विवाह उपहार के लिए 50+ इकाइयों की आवश्यकता”'),
      t('“Custom logo embossing on wooden crafts”', '“लकड़ी के शिल्प पर कस्टम लोगो का काम”'),
      t('“Immediate dispatch for export samples”', '“निर्यात नमूनों के लिए तत्काल डिलीवरी”'),
    ];

    return [
      Text(
        t('Buyer Trends & Interests', 'खरीदार क्या खोज रहे हैं'),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF243B30)),
      ),
      const SizedBox(height: 12),

      Text(
        t('Most Requested Categories in Your Region', 'आपके क्षेत्र में सबसे लोकप्रिय श्रेणियाँ'),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF425244)),
      ),
      const SizedBox(height: 8),

      CraftCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: topCategories.map((c) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, size: 18, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${c['name']}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F6F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${c['requests']} ${t('requests', 'मांग')}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF285448)),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),

      const SizedBox(height: 12),
      Text(
        t('Common Buyer Requirements', 'खरीदारों की आम आवश्यकताएँ'),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF425244)),
      ),
      const SizedBox(height: 8),

      CraftCard(
        child: Column(
          children: commonRequirements.map((req) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote_rounded, size: 16, color: Color(0xFF7A6B48)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      req,
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF333333)),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),

      const SizedBox(height: 10),
      CraftButton(
        t('See AI Advice on these Trends', 'इन ट्रेंड्स पर AI सलाह देखें'),
        icon: Icons.smart_toy_outlined,
        onPressed: () => _nav('ai_insights'),
      ),
    ];
  }

  // ── 6. AI INSIGHTS (SCREEN 6) ──────────────────────────────────────────────
  List<Widget> _buildAiInsights() {
    return [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF285448),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('AI Insights for You', 'आपके लिए AI सुझाव'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF233C32)),
                ),
                Text(
                  t('Personalized suggestions based on your orders & catalog', 'आपके कैटलॉग और ऑर्डर्स के आधार पर तैयार'),
                  style: const TextStyle(fontSize: 10, color: Color(0xFF6B7268)),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),

      _aiSuggestionCard(
        title: t('Highlight Handwoven Work', 'हथकरघा काम को प्रमुखता दें'),
        body: t('Your handwoven products are receiving high buyer interest. Upload 2-3 new close-up photos showing the intricate weaving texture.',
            'आपके हथकरघा उत्पादों को अधिक देखा जा रहा है। बुनाई का काम साफ दिखाने वाली 2-3 नई तस्वीरें अपलोड करें।'),
        icon: Icons.photo_camera_back_outlined,
        actionLabel: t('Update Product Photos', 'फ़ोटो जोड़ें'),
        onAction: () => widget.onNavigate('products'),
      ),

      _aiSuggestionCard(
        title: t('Offer Custom Gifting Packs', 'कस्टम गिफ्टिंग विकल्प दें'),
        body: t('Many buyers are inquiring about wedding gift sets (50+ units). Adding customization options can turn inquiries into confirmed bulk orders.',
            'कई खरीदार शादी उपहार सेट (50+ पीस) के लिए पूछ रहे हैं। कस्टमाइज़ेशन विकल्प जोड़ने से थोक ऑर्डर मिल सकते हैं।'),
        icon: Icons.card_giftcard_outlined,
        actionLabel: t('Add Customization Info', 'कस्टमाइज़ेशन जोड़ें'),
        onAction: () => _nav('actions'),
      ),

      _aiSuggestionCard(
        title: t('Update Production Capacity', 'उत्पादन क्षमता अपडेट रखें'),
        body: t('Bulk orders are increasing in festive season. Keeping your lead time and monthly capacity accurate helps buyers place high-volume orders with confidence.',
            'त्योहारी सीजन में मांग बढ़ रही है। अपनी उत्पादन क्षमता व समय सही रखें ताकि खरीदार बेझिझक बड़े ऑर्डर दे सकें।'),
        icon: Icons.precision_manufacturing_outlined,
        actionLabel: t('Update Capacity', 'क्षमता अपडेट करें'),
        onAction: () => _nav('actions'),
      ),

      const SizedBox(height: 10),
      CraftButton(
        t('View Recommended Actions', 'सुझाई गई कार्य सूची देखें'),
        icon: Icons.check_circle_outline,
        onPressed: () => _nav('actions'),
      ),
    ];
  }

  Widget _aiSuggestionCard({
    required String title,
    required String body,
    required IconData icon,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return CraftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF285448), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF243B30)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF4A5248)),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF285448)),
              label: Text(
                actionLabel,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF285448)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 7. TAKE ACTION CHECKLIST (SCREEN 7) ───────────────────────────────────
  List<Widget> _buildActionChecklist() {
    return [
      Text(
        t('What Would You Like to Do?', 'आप क्या कदम उठाना चाहते हैं?'),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF243B30)),
      ),
      const SizedBox(height: 6),
      Text(
        t('Small steps today bring bigger opportunities tomorrow.', 'आज के छोटे कदम कल नए अवसर खोलेंगे।'),
        style: const TextStyle(fontSize: 11, color: Color(0xFF6E756B)),
      ),
      const SizedBox(height: 14),

      _actionTile(
        title: t('Update Product Details & Photos', 'उत्पाद विवरण व फ़ोटो अपडेट करें'),
        sub: t('Add clear photos, dimensions, and craft technique', 'साफ तस्वीरें और शिल्प की खासियत जोड़ें'),
        icon: Icons.edit_note_rounded,
        onTap: () => widget.onNavigate('products'),
      ),
      _actionTile(
        title: t('Add Customization Options', 'कस्टमाइज़ेशन विकल्प जोड़ें'),
        sub: t('Mention colors, gift wrapping, logo engraving', 'रंग, पैकिंग या व्यक्तिगत नाम विकल्प'),
        onTap: () => widget.onNavigate('products'),
      ),
      _actionTile(
        title: t('Update Production Capacity', 'उत्पादन क्षमता अपडेट करें'),
        sub: t('Specify your daily pieces & lead time accurately', 'समय पर आपूर्ति के लिए सही समय सीमा रखें'),
        onTap: () => widget.onNavigate('profile'),
      ),
      _actionTile(
        title: t('Explore Bulk Bidding Sessions', 'थोक बोली (Bidding) अवसर देखें'),
        sub: t('Participate in scheduled buyer demand requests', 'संभावित खरीदारों को अपने ऑफ़र दें'),
        icon: Icons.gavel_outlined,
        onTap: () => widget.onNavigate('bidding'),
      ),
      _actionTile(
        title: t('Set a Goal for Next Month', 'अगले महीने के लिए लक्ष्य तय करें'),
        sub: t('Target orders, new buyers or higher inquiries', 'ऑर्डर या आय का सरल लक्ष्य निर्धारित करें'),
        icon: Icons.flag_outlined,
        onTap: () => _nav('goal_set'),
      ),
    ];
  }

  Widget _actionTile({
    required String title,
    required String sub,
    IconData icon = Icons.check_circle_outline,
    required VoidCallback onTap,
  }) {
    return CraftCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F6F2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF285448), size: 22),
        ),
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7268))),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: onTap,
      ),
    );
  }

  // ── 8. PRODUCT DETAIL INSIGHT (SCREEN 8) ──────────────────────────────────
  List<Widget> _buildProductDetailInsight() {
    Record? prod;
    if (_selectedProductId != null) {
      prod = widget.products.cast<Record?>().firstWhere(
            (p) => '${p?['id']}' == _selectedProductId,
            orElse: () => widget.products.isNotEmpty ? widget.products.first : null,
          );
    } else if (widget.products.isNotEmpty) {
      prod = widget.products.first;
    }

    if (prod == null) {
      return [
        EmptyCraft(t('Product not found', 'उत्पाद नहीं मिला'), t('Please select a valid product.', 'कृपया सही उत्पाद चुनें।'))
      ];
    }

    final title = '${prod['title']}';
    final img = '${prod['image'] ?? ''}';

    return [
      CraftCard(
        child: Column(
          children: [
            CraftImage(img, size: 90),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniStat(t('Views', 'व्यूज़'), '120'),
                _miniStat(t('Interests', 'रुचि'), '18'),
                _miniStat(t('Inquiries', 'पूछताछ'), '5'),
                _miniStat(t('Orders', 'ऑर्डर'), '3'),
              ],
            ),
          ],
        ),
      ),

      Text(
        t('What Buyers Like About This Product', 'खरीदारों को क्या पसंद आ रहा है'),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF233C32)),
      ),
      const SizedBox(height: 8),

      CraftCard(
        child: Column(
          children: [
            _featureItem(Icons.check_circle, t('Authentic handmade technique verified', 'प्रमाणित हस्तशिल्प तकनीक')),
            _featureItem(Icons.check_circle, t('Natural eco-friendly materials', 'प्राकृतिक एवं पर्यावरण अनुकूल सामग्री')),
            _featureItem(Icons.check_circle, t('Custom size availability requested by 4 buyers', '4 खरीदारों ने विभिन्न साइज की मांग की')),
          ],
        ),
      ),

      const SizedBox(height: 8),
      CraftButton(
        t('Edit Product Details', 'उत्पाद में सुधार करें'),
        icon: Icons.edit,
        onPressed: () => widget.onNavigate('product', '${prod?['id']}'),
      ),
    ];
  }

  Widget _miniStat(String label, String val) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF285448))),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7268))),
      ],
    );
  }

  Widget _featureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  // ── 9. BUYER INQUIRIES LIST (SCREEN 9) ────────────────────────────────────
  List<Widget> _buildBuyerInquiriesList() {
    return [
      Text(
        t('Recent Buyer Inquiries', 'हालिया खरीदार पूछताछ'),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF233C32)),
      ),
      const SizedBox(height: 10),

      if (widget.inquiries.isEmpty)
        EmptyCraft(t('No inquiries yet', 'कोई पूछताछ नहीं'), t('Inquiries from buyers will appear here.', 'खरीदारों की पूछताछ यहाँ दिखेगी।'))
      else
        ...widget.inquiries.map((inq) {
          final prodTitle = '${inq['product_title'] ?? inq['title'] ?? t('Handmade Craft', 'हस्तशिल्प')}';
          final spec = '${inq['specifications'] ?? inq['customization'] ?? t('Inquiry regarding bulk quantity & delivery', 'थोक मात्रा व डिलीवरी पर पूछताछ')}';
          final q = inq['quantity'] ?? inq['target_quantity'] ?? 10;

          return CraftCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF2EC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.chat_bubble_outline, color: Color(0xFF285448)),
              ),
              title: Text('$prodTitle ($q pcs)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              subtitle: Text(spec, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => widget.onNavigate('inquiry', '${inq['id']}'),
            ),
          );
        }),

      const SizedBox(height: 10),
      CraftButton(
        t('View All Inquiries & Quotes', 'सभी पूछताछ और भाव देखें'),
        onPressed: () => widget.onNavigate('inquiries'),
      ),
    ];
  }

  // ── 10. ORDERS SUMMARY (SCREEN 10) ────────────────────────────────────────
  List<Widget> _buildOrdersSummary() {
    final orderCount = widget.orders.length;
    final totalUnits = widget.orders.fold<int>(0, (sum, o) => sum + (o['quantity'] as int? ?? 1));
    final totalEarnings = widget.orders.fold<double>(0, (sum, o) => sum + (number(o['total'] ?? o['amount'] ?? 1200)));

    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            t('Orders Summary', 'ऑर्डर सारांश'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF243B30)),
          ),
          Wrap(
            spacing: 6,
            children: [
              ChoiceChip(
                label: Text(t('This Month', 'इस महीने')),
                selected: _ordersSummaryTab == 'month',
                selectedColor: const Color(0xFF285448),
                labelStyle: TextStyle(
                  color: _ordersSummaryTab == 'month' ? Colors.white : const Color(0xFF285448),
                  fontSize: 11,
                ),
                onSelected: (_) => setState(() => _ordersSummaryTab = 'month'),
              ),
              ChoiceChip(
                label: Text(t('Last 3 Months', '3 महीने')),
                selected: _ordersSummaryTab == '3months',
                selectedColor: const Color(0xFF285448),
                labelStyle: TextStyle(
                  color: _ordersSummaryTab == '3months' ? Colors.white : const Color(0xFF285448),
                  fontSize: 11,
                ),
                onSelected: (_) => setState(() => _ordersSummaryTab = '3months'),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 14),

      CraftCard(
        child: Column(
          children: [
            DetailRow(t('Total Orders', 'कुल ऑर्डर'), '$orderCount'),
            DetailRow(t('Total Quantity Sold', 'कुल बेची गई वस्तुएँ'), '$totalUnits ${t('pieces', 'पीस')}'),
            DetailRow(t('Total Earnings', 'कुल कमाई'), money(totalEarnings)),
          ],
        ),
      ),

      CraftCard(
        color: const Color(0xFFF3F7F3),
        child: Row(
          children: [
            const Icon(Icons.celebration_outlined, color: Color(0xFF285448), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t('You’re doing great! You have fulfilled $orderCount orders successfully.',
                    'शानदार काम! आपने $orderCount ऑर्डर सफलतापूर्वक पूरे किए हैं।'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF285448)),
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 10),
      CraftButton(
        t('View All Orders', 'सभी ऑर्डर देखें'),
        onPressed: () => widget.onNavigate('orders'),
      ),
    ];
  }

  // ── 11. SET A GOAL (SCREEN 11) ────────────────────────────────────────────
  List<Widget> _buildSetGoal() {
    return [
      Text(
        t('Set Your Goal', 'अपना लक्ष्य तय करें'),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF243B30)),
      ),
      const SizedBox(height: 6),
      Text(
        t('Pick a simple target to keep your craftsmanship thriving.', 'अपने व्यवसाय को आगे बढ़ाने के लिए एक लक्ष्य चुनें।'),
        style: const TextStyle(fontSize: 11, color: Color(0xFF6E756B)),
      ),
      const SizedBox(height: 14),

      _goalOptionTile(
        key: 'inquiries',
        icon: Icons.chat_outlined,
        title: t('Get More Inquiries', 'अधिक पूछताछ प्राप्त करें'),
        sub: t('Target: 20 inquiries this month', 'लक्ष्य: इस महीने 20 पूछताछ'),
        targetVal: 20,
      ),
      _goalOptionTile(
        key: 'orders',
        icon: Icons.shopping_bag_outlined,
        title: t('Complete More Orders', 'अधिक ऑर्डर पूरे करें'),
        sub: t('Target: 10 completed orders', 'लक्ष्य: 10 पूर्ण ऑर्डर'),
        targetVal: 10,
      ),
      _goalOptionTile(
        key: 'buyers',
        icon: Icons.people_outline,
        title: t('Work with New Buyers', 'नए खरीदारों से जुड़ें'),
        sub: t('Target: 5 new buyer connections', 'लक्ष्य: 5 नए खरीदार'),
        targetVal: 5,
      ),
      _goalOptionTile(
        key: 'capacity',
        icon: Icons.speed_outlined,
        title: t('Increase Production Capacity', 'उत्पादन क्षमता बढ़ाएँ'),
        sub: t('Target: 50 pieces crafted per month', 'लक्ष्य: 50 पीस/महीना'),
        targetVal: 50,
      ),

      const SizedBox(height: 14),
      CraftButton(
        t('Save Goal & Track Progress', 'लक्ष्य सहेजें और ट्रैक करें'),
        icon: Icons.check,
        onPressed: () {
          setState(() {
            _hasCustomGoal = true;
            _goalCurrent = (_goalTarget * 0.6).round();
          });
          _nav('goal_progress');
        },
      ),
    ];
  }

  Widget _goalOptionTile({
    required String key,
    required IconData icon,
    required String title,
    required String sub,
    required int targetVal,
  }) {
    final isSelected = _goalType == key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => setState(() {
          _goalType = key;
          _goalTarget = targetVal;
        }),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF1F6F2) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF285448) : const Color(0xFFE4E6DD),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF285448) : const Color(0xFFEBF0EC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: isSelected ? Colors.white : const Color(0xFF285448), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7268))),
                  ],
                ),
              ),
              if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF285448), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── 12. TRACK GOAL PROGRESS (SCREEN 12) ───────────────────────────────────
  List<Widget> _buildGoalProgress() {
    final percent = (_goalCurrent / (_goalTarget == 0 ? 1 : _goalTarget)).clamp(0.0, 1.0);

    return [
      Text(
        t('Your Goal Progress', 'लक्ष्य प्रगति'),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF243B30)),
      ),
      const SizedBox(height: 14),

      CraftCard(
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF285448),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.track_changes, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _goalType == 'orders'
                            ? t('Complete Orders', 'ऑर्डर पूरे करें')
                            : t('Get More Inquiries', 'अधिक पूछताछ पाएँ'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${t('Target', 'लक्ष्य')}: $_goalTarget · ${t('Current', 'वर्तमान')}: $_goalCurrent',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7268)),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(percent * 100).toInt()}%',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF285448)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: percent,
              minHeight: 10,
              backgroundColor: const Color(0xFFE4E9E5),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF285448)),
              borderRadius: BorderRadius.circular(5),
            ),
          ],
        ),
      ),

      CraftCard(
        color: const Color(0xFFF3F7F3),
        child: Row(
          children: [
            const Icon(Icons.trending_up, color: Color(0xFF285448)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t('Keep going! You are 60% towards your goal. Just a few more to reach your milestone!',
                    'बहुत बढ़िया! आप लक्ष्य के 60% तक पहुँच चुके हैं। थोड़ा और प्रयास आपको सफलता दिलाएगा!'),
                style: const TextStyle(fontSize: 11, color: Color(0xFF334438), height: 1.4),
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 10),
      CraftButton(
        t('Keep Growing!', 'आगे बढ़ते रहें (Keep Growing)'),
        icon: Icons.celebration,
        onPressed: () => _nav('growing'),
      ),
      CraftButton(
        t('Change Goal', 'लक्ष्य बदलें'),
        secondary: true,
        onPressed: () => _nav('goal_set'),
      ),
    ];
  }

  // ── 13. KEEP GROWING (SCREEN 13) ──────────────────────────────────────────
  List<Widget> _buildKeepGrowing() {
    return [
      CraftCard(
        color: const Color(0xFFF4F8F4),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFF285448),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 16),
            Text(
              t('Your Craft Creates Opportunities!', 'आपका शिल्प, नए अवसरों की शुरुआत!'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF233C32)),
            ),
            const SizedBox(height: 8),
            Text(
              t('“Traditional Skills, Modern Opportunities”', '“पारंपरिक हुनर, आधुनिक अवसर”'),
              style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF5A6658)),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                t('Keep creating, keep growing. Aakar connects your genuine craftsmanship to buyers who value authentic Indian heritage.',
                    'नया रचते रहें, आगे बढ़ते रहें। आकार आपके असली शिल्प को ऐसे खरीदारों तक पहुँचाता है जो आपकी कला की कद्र करते हैं।'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, height: 1.5, color: Color(0xFF384236)),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      CraftButton(
        t('Back to Business Insights', 'वापस बिजनेस इनसाइट्स'),
        icon: Icons.dashboard_outlined,
        onPressed: () => _nav('insights'),
      ),
      CraftButton(
        t('Explore What Buyers Want', 'देखें खरीदार क्या चाहते हैं'),
        secondary: true,
        icon: Icons.trending_up,
        onPressed: () => _nav('trends'),
      ),
    ];
  }
}


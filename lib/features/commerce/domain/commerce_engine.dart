import 'dart:convert';
import 'dart:math';

typedef Record = Map<String, dynamic>;

Record copyRecord(Record value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
List<Record> records(dynamic value) => (value as List? ?? [])
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();
double number(dynamic value, [double fallback = 0]) {
  final parsed = double.tryParse('$value');
  return parsed != null && parsed.isFinite ? parsed : fallback;
}

String money(dynamic value) =>
    '₹${number(value).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

class WorkflowError implements Exception {
  final String message;
  WorkflowError(this.message);
  @override
  String toString() => message;
}

/// Pure state transitions. Persistence and network transport live in the repository.
/// Demo identities never represent authenticated production accounts.
class CommerceEngine {
  static Record seed() => {
        'version': 0,
        'schema': 1,
        'profiles': [
          {
            'id': 'buyer',
            'role': 'buyer',
            'name': 'The Earth Store',
            'email': '',
            'phone': '',
            'type': 'Retail & lifestyle',
            'industry': 'Home & living',
            'location': 'Mumbai, Maharashtra',
            'website': '',
            'verification': 'not_submitted',
            'document': '',
            'contact_verified': false,
            'terms': false
          },
          {
            'id': 'ramesh',
            'role': 'artisan',
            'name': 'Ramesh Handicrafts',
            'location': 'Jaipur, Rajasthan',
            'craft': 'Bamboo & cane',
            'experience': 15,
            'story':
                'Handwoven by a family of makers. Traditional skills, thoughtful everyday objects.',
            'verification': 'verified',
            'phone': '',
            'document': 'Demo verification fixture'
          },
          {
            'id': 'greenhands',
            'role': 'artisan',
            'name': 'GreenHands Artisan Group',
            'location': 'Guwahati, Assam',
            'craft': 'Bamboo & natural fibre',
            'experience': 8,
            'story':
                'A community collective weaving local bamboo into lasting objects.',
            'verification': 'verified',
            'document': 'Demo verification fixture'
          },
          {
            'id': 'sakhi',
            'role': 'artisan',
            'name': 'Sakhi Women’s Collective',
            'location': 'Kutch, Gujarat',
            'craft': 'Textile & embroidery',
            'experience': 10,
            'story': 'Women-led handloom craft, made slowly and with care.',
            'verification': 'verified',
            'document': 'Demo verification fixture'
          },
        ],
        'products': [
          {
            'id': 'basket',
            'artisan_id': 'ramesh',
            'title': 'Handmade Bamboo Basket',
            'description':
                'Handwoven bamboo storage basket. Natural finish with a fitted lid; suitable for thoughtful hotel gifting.',
            'category': 'Baskets',
            'craft': 'Bamboo & cane',
            'material': 'Bamboo',
            'colour': 'Natural',
            'dimensions': '30 × 25 cm',
            'usage': 'Storage and gifting',
            'story': 'Woven by hand in Jaipur',
            'price': 300,
            'material_cost': 90,
            'labour_cost': 100,
            'overhead': 30,
            'moq': 50,
            'stock': 250,
            'capacity': 500,
            'lead_days': 20,
            'available': true,
            'customizable': true,
            'location': 'Jaipur, Rajasthan',
            'image': 'basket',
            'approved': true,
            'status': 'published',
            'fragile': false,
            'can_pack': true,
            'external': {}
          },
          {
            'id': 'assam-basket',
            'artisan_id': 'greenhands',
            'title': 'Bamboo Storage Basket',
            'description':
                'Handwoven natural-fibre basket with lid, crafted by the GreenHands collective.',
            'category': 'Baskets',
            'craft': 'Bamboo & natural fibre',
            'material': 'Bamboo',
            'colour': 'Natural',
            'dimensions': '32 × 24 cm',
            'usage': 'Storage',
            'price': 320,
            'material_cost': 100,
            'labour_cost': 110,
            'overhead': 30,
            'moq': 100,
            'stock': 400,
            'capacity': 450,
            'lead_days': 25,
            'available': true,
            'customizable': true,
            'location': 'Guwahati, Assam',
            'image': 'basket2',
            'approved': true,
            'status': 'published',
            'fragile': false,
            'can_pack': true,
            'external': {}
          },
          {
            'id': 'tote',
            'artisan_id': 'sakhi',
            'title': 'Cotton Handwoven Tote',
            'description':
                'Reusable cotton tote with traditional woven detail. Custom colours available.',
            'category': 'Textiles',
            'craft': 'Handloom',
            'material': 'Cotton',
            'colour': 'Indigo',
            'dimensions': '40 × 35 cm',
            'usage': 'Everyday carry',
            'price': 200,
            'material_cost': 55,
            'labour_cost': 85,
            'overhead': 20,
            'moq': 50,
            'stock': 500,
            'capacity': 700,
            'lead_days': 15,
            'available': true,
            'customizable': true,
            'location': 'Kutch, Gujarat',
            'image': 'tote',
            'approved': true,
            'status': 'published',
            'fragile': false,
            'can_pack': true,
            'external': {}
          },
          {
            'id': 'planter',
            'artisan_id': 'ramesh',
            'title': 'Terracotta Planter',
            'description':
                'Hand-finished clay planter with a warm, unglazed surface.',
            'category': 'Pottery',
            'craft': 'Pottery',
            'material': 'Terracotta',
            'colour': 'Earth brown',
            'dimensions': '20 × 18 cm',
            'usage': 'Home & garden',
            'price': 180,
            'material_cost': 35,
            'labour_cost': 70,
            'overhead': 20,
            'moq': 50,
            'stock': 300,
            'capacity': 600,
            'lead_days': 25,
            'available': true,
            'customizable': false,
            'location': 'Jaipur, Rajasthan',
            'image': 'pottery',
            'approved': true,
            'status': 'published',
            'fragile': true,
            'can_pack': false,
            'external': {}
          },
        ],
        'requirements': [],
        'inquiries': [],
        'orders': [],
        'issues': [],
        'notifications': [],
        'saved': [],
      };

  static List<String> readiness(Record p) {
    final missing = <String>[];
    for (final key in [
      'title',
      'description',
      'image',
      'location',
      'category'
    ]) {
      if ('${p[key] ?? ''}'.trim().isEmpty) missing.add(key);
    }
    for (final key in ['price', 'moq', 'lead_days']) {
      if (number(p[key]) <= 0) missing.add(key);
    }
    if (!p.containsKey('stock') || number(p['stock']) < 0) missing.add('stock');
    if (!p.containsKey('capacity') || number(p['capacity']) < 0)
      missing.add('capacity');
    if (number(p['stock']) + number(p['capacity']) <= 0)
      missing.add('stock or production capacity');
    for (final key in ['available', 'customizable']) {
      if (p[key] is! bool) missing.add(key);
    }
    if (p['approved'] != true) missing.add('artisan approval');
    if (const ['gemini', 'openai'].contains(p['photo_provider']) &&
        p['photo_reviewed'] != true) {
      missing.add('photo review');
    }
    if (number(p['price']) < floor(p)) missing.add('price below cost floor');
    return missing;
  }

  static double floor(Record p) =>
      number(p['material_cost']) +
      number(p['labour_cost']) +
      number(p['overhead']);

  static List<Record> matches(Record state, Record request) {
    return records(state['products'])
        .where((p) => p['status'] == 'published' && p['approved'] == true)
        .map((p) {
      final reasons = <String>[];
      final gaps = <String>[];
      var query = '${request['product'] ?? ''}'.toLowerCase();
      for (final term in {
        'बाँस': 'bamboo',
        'बांस': 'bamboo',
        'टोकरी': 'basket',
        'मिट्टी': 'clay',
        'कपास': 'cotton',
        'बैग': 'bag',
        'गमला': 'planter'
      }.entries) {
        query = query.replaceAll(term.key, term.value);
      }
      final words = query
          .split(RegExp(r'[\s,.;!?]+'))
          .where((w) => w.length > 2)
          .toList();
      final description =
          '${p['title']} ${p['category']} ${p['material']} ${p['craft']}'
              .toLowerCase();
      final productFit = words.isEmpty || words.any(description.contains);
      (productFit ? reasons : gaps).add(
          productFit ? 'Product and craft fit' : 'Different product / craft');
      void check(bool ok, String yes, String no) =>
          (ok ? reasons : gaps).add(ok ? yes : no);
      check(number(request['quantity']) >= number(p['moq']),
          'Meets minimum order', 'Below MOQ');
      final committed = records(state['orders'])
          .where(
              (o) => o['product_id'] == p['id'] && o['status'] != 'completed')
          .fold<double>(0, (sum, o) => sum + number(o['quantity']));
      final possible = max(
          0,
          number(p['stock']) +
              number(p['capacity']) * number(request['lead_days'], 30) / 30 -
              committed);
      check(possible >= number(request['quantity']),
          'Quantity and capacity available', 'Partial capacity only');
      check(number(p['lead_days']) <= number(request['lead_days'], 30),
          'Within requested lead time', 'Lead time needs negotiation');
      check(
          number(request['budget']) == 0 ||
              number(p['price']) <= number(request['budget']),
          'Within unit budget',
          'Above unit budget');
      check(
          '${request['customization'] ?? ''}'.isEmpty ||
              p['customizable'] == true,
          'Customization fit',
          'Customization not available');
      check(p['available'] == true, 'Supplier available',
          'Currently unavailable');
      if ('${request['location'] ?? ''}'.isNotEmpty)
        reasons.add(
            '${p['location']} to ${request['location']}; delivery serviceability needs confirmation');
      return {
        ...p,
        'match_score': ((7 - gaps.length) / 7 * 100).round(),
        'reasons': reasons,
        'gaps': gaps,
        'feasible': gaps.isEmpty,
        'available_capacity': possible.floor()
      };
    }).toList()
      ..sort((a, b) =>
          number(b['match_score']).compareTo(number(a['match_score'])));
  }

  static Record route(Record p, Record input) {
    final location = '${input['location'] ?? ''}'.trim();
    if (location.isEmpty ||
        input['hub_available'] == null &&
            (p['can_pack'] != true ||
                number(input['quantity']) > 500 ||
                input['storage_needed'] == true)) {
      return {
        'route': 'Needs review',
        'reason':
            'Confirm destination, packaging help and hub availability before agreeing delivery.',
        'mode': 'demo estimate'
      };
    }
    final hub = input['hub_available'] == true &&
        (p['can_pack'] != true ||
            number(input['quantity']) > 500 ||
            input['storage_needed'] == true);
    return {
      'route': hub
          ? 'Via hub'
          : p['can_pack'] == true && input['storage_needed'] != true
              ? 'Direct'
              : 'Needs review',
      'reason': hub
          ? 'Packaging help or consolidation is needed; proposed hub availability was confirmed for this demo.'
          : p['can_pack'] == true && input['storage_needed'] != true
              ? 'Artisan can pack; no confirmed consolidation need. Confirm courier serviceability.'
              : 'Packaging support is unavailable. Confirm an alternative before dispatch.',
      'mode': 'demo estimate'
    };
  }

  static Record apply(
      Record original, String action, Record input, String role, String actor) {
    final state = copyRecord(original);
    final now = DateTime.now().toUtc().toIso8601String();
    String id(String prefix) =>
        '$prefix-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(9999)}';
    List<dynamic> list(String key) => state[key] as List<dynamic>;
    Record find(String table, dynamic key) {
      final index = list(table).indexWhere((e) => e['id'] == key);
      if (index < 0) throw WorkflowError('Record not found');
      return list(table)[index] as Record;
    }

    void require(bool condition, String message) {
      if (!condition) throw WorkflowError(message);
    }

    void asRole(String required) =>
        require(role == required, 'Switch to $required mode for this action');
    void owner(Record r) => require(role == 'admin' || r['${role}_id'] == actor,
        'This record belongs to another participant');
    void notify(String title, String target, String targetRole,
        [String? link]) {
      list('notifications').insert(0, {
        'id': id('notice'),
        'title': title,
        'actor_id': target,
        'role': targetRole,
        'link': link,
        'read': false,
        'time': now
      });
    }

    Record inquiry() {
      final r = find('inquiries', input['id']);
      owner(r);
      return r;
    }

    Record order() {
      final r = find('orders', input['id']);
      owner(r);
      return r;
    }

    void event(Record r, String text) {
      (r['events'] as List)
          .add({'title': text, 'time': now, 'actor': actor, 'role': role});
      if (r.containsKey('production')) {
        for (final targetRole in ['buyer', 'artisan']) {
          if (role != targetRole)
            notify(text, '${r['${targetRole}_id']}', targetRole,
                'order/${r['id']}');
        }
      }
    }

    void unblocked(Record o) => require(
        !list('issues')
            .any((i) => i['order_id'] == o['id'] && i['status'] != 'resolved'),
        'Resolve the open issue before continuing this order');
    bool duePaid(Record o, String trigger) => records(o['milestones'])
        .where((m) => m['trigger'] == trigger)
        .every((m) => m['status'] == 'confirmed');
    switch (action) {
      case 'profile':
        final profile = find('profiles', actor);
        require(profile['role'] == role, 'Profile role mismatch');
        final allowed = [
          'name',
          'email',
          'phone',
          'type',
          'industry',
          'location',
          'website',
          'document',
          'contact_verified',
          'terms',
          'craft',
          'experience',
          'story'
        ];
        for (final key in allowed) {
          if (input.containsKey(key)) profile[key] = input[key];
        }
        require(
            '${profile['name']}'.trim().isNotEmpty &&
                '${profile['location']}'.trim().isNotEmpty,
            'Name and location are required');
        if (input['submit'] == true) {
          require(
              '${profile['document'] ?? ''}'.isNotEmpty &&
                  profile['terms'] == true &&
                  profile['contact_verified'] == true,
              'Add verification evidence, confirm contact details and accept terms');
          profile['verification'] = 'pending';
        }
        break;
      case 'product':
        asRole('artisan');
        final exists = input['id'] != null;
        final p = exists
            ? find('products', input['id'])
            : <String, dynamic>{
                'id': id('product'),
                'artisan_id': actor,
                'status': 'draft',
                'external': {}
              };
        owner(p);
        for (final key in [
          'title',
          'title_hi',
          'description_hi',
          'description',
          'category',
          'craft',
          'material',
          'colour',
          'dimensions',
          'usage',
          'story',
          'price',
          'material_cost',
          'labour_cost',
          'labour_hours',
          'hourly_rate',
          'complexity',
          'overhead',
          'moq',
          'stock',
          'capacity',
          'lead_days',
          'available',
          'customizable',
          'location',
          'image',
          'original_image',
          'fragile',
          'can_pack',
          'transcript',
          'approved'
        ]) {
          if (input.containsKey(key)) p[key] = input[key];
        }
        for (final key in [
          'price',
          'material_cost',
          'labour_cost',
          'overhead',
          'stock',
          'capacity'
        ]) {
          require(number(p[key]) >= 0, 'Costs and capacity cannot be negative');
        }
        p['status'] = p['status'] == 'published'
            ? 'needs_update'
            : readiness(p).isEmpty
                ? 'ready'
                : 'draft';
        if (!exists) list('products').add(p);
        break;
      case 'availability':
        asRole('artisan');
        final p = find('products', input['id']);
        owner(p);
        require(input['available'] is bool, 'Choose an availability status');
        // Operational availability does not change catalog approval/publication.
        p['available'] = input['available'];
        break;
      case 'publish':
        asRole('artisan');
        final p = find('products', input['id']);
        owner(p);
        require(readiness(p).isEmpty,
            'Complete readiness: ${readiness(p).join(', ')}');
        require(p['moderation'] != 'flagged',
            'Resolve moderation before publishing');
        p['status'] = 'published';
        break;
      case 'channel':
        asRole('artisan');
        final p = find('products', input['id']);
        owner(p);
        final channel = '${input['channel']}';
        require(['gem', 'ondc', 'state_board'].contains(channel),
            'Unknown channel');
        (p['external'] as Map)[channel] = {
          'fields': input['fields'],
          'status': 'prepared_demo',
          'time': now
        };
        break;
      case 'requirement':
        asRole('buyer');
        require(
            '${input['product'] ?? ''}'.trim().isNotEmpty &&
                number(input['quantity']) > 0 &&
                number(input['lead_days']) > 0 &&
                '${input['location'] ?? ''}'.trim().isNotEmpty,
            'Product, quantity, lead time and destination are required');
        require(input['confirmed'] == true,
            'Review and confirm the structured requirement');
        list('requirements').insert(0, {
          ...input,
          'id': id('req'),
          'buyer_id': actor,
          'status': 'open',
          'time': now
        });
        break;
      case 'inquiry':
        asRole('buyer');
        final p = find('products', input['product_id']);
        require(p['status'] == 'published', 'Product is not published');
        require(p['available'] == true, 'This product is not taking orders');
        require(number(input['quantity']) >= number(p['moq']),
            'Requested quantity is below MOQ');
        require(
            number(input['lead_days']) > 0 &&
                '${input['location'] ?? ''}'.isNotEmpty,
            'Lead time and delivery location are required');
        final r = {
          ...input,
          'id': id('rfq'),
          'buyer_id': actor,
          'artisan_id': p['artisan_id'],
          'product_title': p['title'],
          'status': 'sent',
          'capacity_status': 'pending',
          'sample_status':
              input['sample_required'] == true ? 'requested' : 'not_required',
          'messages': <dynamic>[],
          'quotes': <dynamic>[],
          'events': <dynamic>[],
          'time': now
        };
        event(r, 'Inquiry sent');
        list('inquiries').insert(0, r);
        notify('New inquiry · ${p['title']}', '${p['artisan_id']}', 'artisan',
            'inquiry/${r['id']}');
        break;
      case 'message':
        final r = inquiry();
        require('${input['text'] ?? ''}'.trim().isNotEmpty, 'Enter a message');
        (r['messages'] as List).add({
          'id': id('message'),
          'text': input['text'],
          'translation': input['translation'] ?? '',
          'role': role,
          'actor': actor,
          'time': now,
          'attachment': input['attachment'] ?? '',
          'provenance': input['provenance'] ?? 'original'
        });
        notify(
            'New message · ${r['product_title']}',
            '${r[role == 'buyer' ? 'artisan_id' : 'buyer_id']}',
            role == 'buyer' ? 'artisan' : 'buyer',
            'inquiry/${r['id']}');
        break;
      case 'capacity':
        asRole('artisan');
        final r = inquiry();
        require(['confirmed', 'partial', 'declined'].contains(input['status']),
            'Choose a capacity response');
        require(
            input['status'] == 'declined' ||
                number(input['quantity']) > 0 && number(input['lead_days']) > 0,
            'Confirm quantity and lead time');
        require(
            input['status'] != 'confirmed' ||
                number(input['quantity']) >= number(r['quantity']),
            'Use Partial for a smaller quantity');
        r['capacity_status'] = input['status'];
        r['confirmed_quantity'] = input['quantity'];
        r['offered_lead_days'] = input['lead_days'];
        event(r, 'Capacity ${input['status']}');
        break;
      case 'sample':
        final r = inquiry();
        require(r['sample_required'] == true, 'No sample was requested');
        final next = input['status'];
        if (role == 'artisan') {
          require(
              next == 'submitted' &&
                  ['requested', 'changes_requested', 'rejected']
                      .contains(r['sample_status']),
              'Submit a requested or revised sample');
          require('${input['evidence'] ?? ''}'.isNotEmpty,
              'Add sample evidence or reference');
          r['sample_evidence'] = input['evidence'];
          r['sample_terms'] = input['terms'] ?? '';
        } else {
          asRole('buyer');
          require(
              r['sample_status'] == 'submitted' &&
                  ['approved', 'changes_requested', 'rejected'].contains(next),
              'Review the submitted sample');
        }
        r['sample_status'] = next;
        if (next == 'approved') {
          final basis = (r['quotes'] as List).isEmpty
              ? r
              : (r['quotes'] as List).last as Record;
          r['sample_basis'] = {
            for (final key in ['customization', 'specifications'])
              key: basis[key] ?? ''
          };
        }
        r['sample_note'] = input['note'] ?? '';
        event(r, 'Sample $next');
        break;
      case 'quote':
        final r = inquiry();
        require(r['status'] != 'ordered', 'Order terms are already agreed');
        require(['confirmed', 'partial'].contains(r['capacity_status']),
            'Artisan must confirm capacity first');
        final p = find('products', r['product_id']);
        require(
            number(input['quantity']) >= number(p['moq']) &&
                number(input['quantity']) <= number(r['confirmed_quantity']),
            'Quantity must satisfy MOQ and confirmed capacity');
        require(number(input['unit_price']) >= floor(p),
            'Price must cover material, labour and overhead');
        require(
            number(input['lead_days']) > 0 &&
                number(input['inspection_hours']) > 0,
            'Lead time and inspection window are required');
        final milestones = records(input['milestones']);
        require(
            milestones.isNotEmpty &&
                (milestones.fold<double>(
                                0, (s, m) => s + number(m['percent'])) -
                            100)
                        .abs() <
                    .01,
            'Milestone percentages must total 100');
        require(
            milestones.every((m) =>
                number(m['percent']) > 0 &&
                ['advance', 'checkpoint', 'dispatch', 'delivery']
                    .contains(m['trigger'])),
            'Use positive milestones with known triggers');
        require(milestones.any((m) => m['trigger'] == 'advance'),
            'Agree an advance before production');
        require(
            !milestones.any((m) => m['trigger'] == 'checkpoint') ||
                input['checkpoint_required'] == true,
            'A QC milestone requires a progress checkpoint');
        for (final key in [
          'packaging_cost',
          'delivery_cost',
          'storage_cost',
          'demo_cost'
        ]) {
          require(number(input[key]) >= 0, 'Charges cannot be negative');
        }
        final total = number(input['unit_price']) * number(input['quantity']) +
            number(input['packaging_cost']) +
            number(input['delivery_cost']) +
            number(input['storage_cost']) +
            number(input['demo_cost']);
        final quotes = r['quotes'] as List;
        if (r['sample_required'] == true &&
            r['sample_status'] == 'approved' &&
            r['sample_basis'] is Map) {
          if (['customization', 'specifications'].any((key) =>
              '${input[key] ?? ''}' != '${r['sample_basis'][key] ?? ''}')) {
            r['sample_status'] = 'requested';
            event(r, 'Specifications changed; sample approval required again');
          }
        }
        final q = {
          ...input,
          'id': id('quote'),
          'version': quotes.length + 1,
          'author': role,
          'time': now,
          'total': total,
          'currency': 'INR',
          'status': 'proposed'
        };
        quotes.add(q);
        r['status'] = 'negotiating';
        event(r, 'Quote v${q['version']} proposed');
        notify(
            'Quote v${q['version']} · ${r['product_title']}',
            '${r[role == 'buyer' ? 'artisan_id' : 'buyer_id']}',
            role == 'buyer' ? 'artisan' : 'buyer',
            'inquiry/${r['id']}');
        break;
      case 'reject_quote':
        final r = inquiry();
        final qs = r['quotes'] as List;
        require(qs.isNotEmpty && r['status'] != 'ordered', 'No open quote');
        require(qs.last['author'] != role,
            'Only the other participant can reject a quote');
        qs.last['status'] = 'rejected';
        event(r, 'Quote rejected');
        break;
      case 'accept':
        final r = inquiry();
        final qs = r['quotes'] as List;
        require(qs.isNotEmpty, 'No quotation');
        final q = qs.last as Record;
        require(q['id'] == input['quote_id'],
            'Quote changed. Review the latest version');
        if (r['status'] == 'ordered') break;
        require(q['author'] != role,
            'The other participant must accept this quote');
        require(q['status'] == 'proposed', 'This quote is no longer open');
        require(
            r['sample_required'] != true || r['sample_status'] == 'approved',
            'Approve the required sample before the bulk order');
        final p = find('products', r['product_id']);
        final committed = list('orders')
            .where(
                (o) => o['product_id'] == p['id'] && o['status'] != 'completed')
            .fold<double>(0, (s, o) => s + number(o['quantity']));
        require(
            number(p['stock']) +
                    number(p['capacity']) * number(q['lead_days']) / 30 -
                    committed >=
                number(q['quantity']),
            'Capacity changed. Ask for a revised quantity or deadline');
        final o = {
          ...copyRecord(q),
          'id': id('order'),
          'inquiry_id': r['id'],
          'product_id': r['product_id'],
          'product_title': r['product_title'],
          'buyer_id': r['buyer_id'],
          'artisan_id': r['artisan_id'],
          'quote_id': q['id'],
          'status': 'confirmed',
          'production': 'not_started',
          'shipment': 'not_dispatched',
          'inspection': 'pending',
          'checkpoint': 'not_submitted',
          'events': <dynamic>[],
          'packaging_checks': <dynamic>[],
          'time': now,
          'payment_mode': 'demo'
        };
        o['milestones'] = records(q['milestones'])
            .asMap()
            .entries
            .map((entry) => {
                  ...entry.value,
                  'id': 'm${entry.key}',
                  'amount':
                      (number(q['total']) * number(entry.value['percent']))
                              .round() /
                          100,
                  'status': 'pending'
                })
            .toList();
        event(o, 'Order confirmed · quote v${q['version']}');
        list('orders').insert(0, o);
        r['status'] = 'ordered';
        r['order_id'] = o['id'];
        q['status'] = 'accepted';
        notify('Order confirmed · ${r['product_title']}', '${r['buyer_id']}',
            'buyer', 'order/${o['id']}');
        notify('Order confirmed · ${r['product_title']}', '${r['artisan_id']}',
            'artisan', 'order/${o['id']}');
        break;
      case 'pay':
        asRole('buyer');
        final o = order();
        unblocked(o);
        final ms = o['milestones'] as List;
        final index = ms.indexWhere((m) => m['id'] == input['milestone_id']);
        require(index >= 0, 'Unknown milestone');
        final m = ms[index];
        require(m['trigger'] != 'checkpoint' || o['checkpoint'] == 'approved',
            'Progress review must be approved first');
        require(
            m['trigger'] != 'dispatch' ||
                ['ready', 'dispatched'].contains(o['production']),
            'Production must be ready for the dispatch milestone');
        require(m['trigger'] != 'delivery' || o['inspection'] == 'accepted',
            'Accept delivery inspection before final settlement');
        m['status'] = 'confirmed';
        m['reference'] = input['reference'] ?? 'Simulated payment';
        m['confirmed_at'] = now;
        m['mode'] = 'demo';
        event(o, '${m['trigger']} payment recorded · simulation');
        break;
      case 'production':
        asRole('artisan');
        final o = order();
        unblocked(o);
        const steps = ['not_started', 'started', 'in_progress', 'ready'];
        final current = steps.indexOf('${o['production']}');
        final next = input['status'];
        require(
            current >= 0 &&
                current + 1 < steps.length &&
                steps[current + 1] == next,
            'Follow the production steps in order');
        require(duePaid(o, 'advance'),
            'Confirm the agreed advance before production');
        if (next == 'ready') {
          require(
              o['checkpoint_required'] != true || o['checkpoint'] == 'approved',
              'Complete the agreed progress review');
          require(duePaid(o, 'checkpoint'), 'Confirm the agreed QC milestone');
        }
        o['production'] = next;
        o['status'] = next == 'ready' ? 'ready' : 'in_production';
        event(o, 'Production $next');
        break;
      case 'checkpoint':
        final o = order();
        unblocked(o);
        require(o['checkpoint_required'] == true, 'No checkpoint agreed');
        require(['started', 'in_progress'].contains(o['production']),
            'Start production before a progress check');
        if (role == 'artisan') {
          require(
              number(input['quantity']) > 0 &&
                  number(input['quantity']) <= number(o['quantity']) &&
                  '${input['evidence'] ?? ''}'.isNotEmpty,
              'Provide completed quantity and photo/reference');
          o['checkpoint'] = 'submitted';
          o['checkpoint_quantity'] = input['quantity'];
          o['checkpoint_evidence'] = input['evidence'];
        } else {
          require(
              ['buyer', 'admin'].contains(role) &&
                  o['checkpoint'] == 'submitted',
              'Review a submitted checkpoint');
          require(['approved', 'changes_requested'].contains(input['status']),
              'Choose a review decision');
          o['checkpoint'] = input['status'];
        }
        event(o, 'Progress checkpoint ${o['checkpoint']}');
        break;
      case 'shipping':
        asRole('artisan');
        final o = order();
        unblocked(o);
        if (input['status'] == 'dispatched') {
          require(o['production'] == 'ready' && duePaid(o, 'dispatch'),
              'Mark production Ready and confirm dispatch milestones');
          require(
              '${input['method'] ?? ''}'.isNotEmpty &&
                  '${input['tracking'] ?? ''}'.isNotEmpty &&
                  '${input['evidence'] ?? ''}'.isNotEmpty,
              'Add shipping method, tracking/reference and packaging evidence');
          require(
              ['protection', 'count', 'inner', 'outer'].every((key) =>
                      (input['checks'] as List? ?? []).contains(key)) &&
                  ['Direct', 'Via hub'].contains(input['route']),
              'Complete packaging checks and confirm a feasible route');
          require(
              input['route'] != 'Via hub' ||
                  input['hub_available'] == true &&
                      '${input['hub_details'] ?? ''}'.isNotEmpty,
              'Confirm hub availability and handoff details');
          require(
              route(find('products', o['product_id']), {...o, ...input})[
                      'route'] ==
                  input['route'],
              'Confirm a route supported by packaging, storage and hub availability');
          o['production'] = 'dispatched';
          o['shipment'] = 'dispatched';
          o['status'] = 'dispatched';
          o['shipping'] = copyRecord(input);
        } else {
          require(
              input['status'] == 'in_transit' && o['shipment'] == 'dispatched',
              'Dispatch before marking in transit');
          o['shipment'] = 'in_transit';
          o['status'] = 'in_transit';
        }
        event(o, 'Shipment ${o['shipment']} · manual tracking');
        break;
      case 'delivery':
        asRole('buyer');
        final o = order();
        require(['dispatched', 'in_transit'].contains(o['shipment']),
            'Shipment must be dispatched');
        o['shipment'] = 'delivered';
        o['status'] = 'delivered';
        o['delivered_at'] = now;
        o['inspection_deadline'] = DateTime.now()
            .toUtc()
            .add(Duration(hours: number(o['inspection_hours'], 48).round()))
            .toIso8601String();
        event(o, 'Buyer confirmed receipt; inspection pending');
        break;
      case 'inspection':
        asRole('buyer');
        final o = order();
        unblocked(o);
        require(
            o['shipment'] == 'delivered', 'Confirm physical delivery first');
        require(number(input['quantity']) == number(o['quantity']),
            'Quantity mismatch: flag an issue for review');
        o['inspection'] = 'accepted';
        o['inspection_note'] = input['note'] ?? '';
        event(o, 'Buyer accepted inspection');
        break;
      case 'complete':
        asRole('buyer');
        final o = order();
        unblocked(o);
        require(
            o['shipment'] == 'delivered' &&
                o['inspection'] == 'accepted' &&
                records(o['milestones'])
                    .every((m) => m['status'] == 'confirmed'),
            'Delivery, inspection and all due milestones must be complete');
        if (o['status'] == 'completed') break;
        o['status'] = 'completed';
        final p = find('products', o['product_id']);
        p['stock'] = max(0, number(p['stock']) - number(o['quantity']));
        event(o, 'Order completed');
        break;
      case 'issue':
        final o = order();
        require(o['status'] != 'completed',
            'This order is complete; contact support');
        require('${input['description'] ?? ''}'.trim().isNotEmpty,
            'Describe the issue');
        list('issues').insert(0, {
          ...input,
          'id': id('issue'),
          'order_id': o['id'],
          'buyer_id': o['buyer_id'],
          'artisan_id': o['artisan_id'],
          'reporter': actor,
          'status': 'open',
          'time': now
        });
        event(o, 'Issue flagged: ${input['category']}');
        break;
      case 'resolve':
        asRole('admin');
        final issue = find('issues', input['id']);
        require('${input['note'] ?? ''}'.trim().isNotEmpty,
            'Record the manual review outcome');
        require(['under_review', 'resolved'].contains(input['status']),
            'Invalid issue status');
        issue['status'] = input['status'];
        issue['resolution'] = input['note'];
        issue['reviewed_at'] = now;
        event(find('orders', issue['order_id']),
            'Admin issue review: ${input['status']}');
        break;
      case 'verify':
        asRole('admin');
        final p = find('profiles', input['id']);
        require(
            ['verified', 'rejected', 'correction_requested']
                .contains(input['status']),
            'Invalid verification decision');
        p['verification'] = input['status'];
        p['verification_note'] = input['note'] ?? '';
        notify('Verification ${input['status']}', '${p['id']}', '${p['role']}');
        break;
      case 'moderate':
        asRole('admin');
        final p = find('products', input['id']);
        require(['flagged', 'clear'].contains(input['status']),
            'Invalid moderation decision');
        p['moderation'] = input['status'];
        p['moderation_note'] = input['note'];
        if (input['status'] == 'flagged') p['status'] = 'needs_update';
        break;
      case 'save_supplier':
        asRole('buyer');
        final key = '$actor:${input['artisan_id']}';
        if (list('saved').contains(key)) {
          list('saved').remove(key);
        } else {
          list('saved').add(key);
        }
        break;
      case 'representation':
        final o = order();
        require(
            '${input['purpose'] ?? ''}'.isNotEmpty &&
                '${input['location'] ?? ''}'.isNotEmpty &&
                '${input['date'] ?? ''}'.isNotEmpty,
            'Add purpose, location and date');
        final existing = o['representation'];
        if (input['status'] == 'confirmed') {
          require(existing != null && existing['author'] != role,
              'The other participant must confirm the proposed representative');
        }
        o['representation'] = {
          ...input,
          'author': role,
          'mode': 'demo coordination'
        };
        event(o, 'On-site demo ${input['status']}');
        break;
      case 'read_notifications':
        for (final n in list('notifications')) {
          if (n['actor_id'] == actor && n['role'] == role) n['read'] = true;
        }
        break;
      default:
        throw WorkflowError('Unknown action: $action');
    }
    state['version'] = number(state['version']).toInt() + 1;
    return state;
  }
}

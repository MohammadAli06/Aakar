import 'package:flutter_test/flutter_test.dart';
import 'package:craft_connect/features/commerce/domain/commerce_engine.dart';

void main() {
  late Record state;
  late String inquiryId;
  void act(String action, Record input, String role, [String? actor]) {
    state = CommerceEngine.apply(
        state,
        action,
        input,
        role,
        actor ??
            (role == 'buyer'
                ? 'buyer'
                : role == 'admin'
                    ? 'admin'
                    : 'ramesh'));
  }

  void inquire({bool sample = false}) {
    act(
        'inquiry',
        {
          'product_id': 'basket',
          'quantity': 500,
          'lead_days': 30,
          'location': 'Mumbai',
          'sample_required': sample
        },
        'buyer');
    inquiryId = '${records(state['inquiries']).first['id']}';
    act(
        'capacity',
        {
          'id': inquiryId,
          'status': 'confirmed',
          'quantity': 500,
          'lead_days': 30
        },
        'artisan');
  }

  Record quote({bool checkpoint = false}) => {
        'id': inquiryId,
        'quantity': 500,
        'unit_price': 300,
        'lead_days': 30,
        'inspection_hours': 36,
        'checkpoint_required': checkpoint,
        'location': 'Mumbai',
        'delivery_terms': 'Artisan packs and books courier; cost included.',
        'milestones': [
          {'trigger': 'advance', 'percent': 30},
          {'trigger': 'dispatch', 'percent': 50},
          {'trigger': 'delivery', 'percent': 20}
        ]
      };
  String accept() {
    final q = records(records(state['inquiries']).first['quotes']).last;
    act('accept', {'id': inquiryId, 'quote_id': q['id']}, 'buyer');
    return '${records(state['orders']).first['id']}';
  }

  setUp(() => state = CommerceEngine.seed());

  test('Availability changes only the owned product operational status', () {
    final before = copyRecord(state);
    for (final identity in [('buyer', 'buyer'), ('artisan', 'sakhi')]) {
      expect(
          () => act('availability', {'id': 'basket', 'available': false},
              identity.$1, identity.$2),
          throwsA(isA<WorkflowError>()));
      expect(state, before);
    }
    for (final value in [null, 'false', 0]) {
      expect(
          () => act(
              'availability', {'id': 'basket', 'available': value}, 'artisan'),
          throwsA(isA<WorkflowError>()));
      expect(state, before);
    }
    final product = copyRecord(records(state['products']).first);
    act('availability', {'id': 'basket', 'available': false, 'price': 1},
        'artisan');
    expect(records(state['products']).first, {...product, 'available': false});
    expect(inquire, throwsA(isA<WorkflowError>()));
    final matches = CommerceEngine.matches(state, {
      'product': 'bamboo basket',
      'quantity': 50,
      'lead_days': 30,
      'location': 'Mumbai',
    });
    final paused = matches.firstWhere((p) => p['id'] == 'basket');
    expect(paused['feasible'], false);
    expect(paused['gaps'], contains('Currently unavailable'));
    act('availability', {'id': 'basket', 'available': true}, 'artisan');
    inquire();
    expect(records(state['inquiries']), hasLength(1));
  });

  test('Pausing availability preserves existing order commitments', () {
    inquire();
    act('quote', quote(), 'artisan');
    accept();
    final orders = copyRecord(state)['orders'];
    act('availability', {'id': 'basket', 'available': false}, 'artisan');
    expect(state['orders'], orders);
  });

  test(
      'Internal readiness is independent of external readiness and accepts false customization / zero stock',
      () {
    final p = records(state['products']).first;
    p['external'] = {};
    p['stock'] = 0;
    p['customizable'] = false;
    expect(CommerceEngine.readiness(p), isEmpty);
    p['approved'] = false;
    expect(CommerceEngine.readiness(p), contains('artisan approval'));
  });
  test(
      'Unapproved product cannot publish and rejected command does not mutate input',
      () {
    final before = copyRecord(state);
    expect(() => act('publish', {'id': 'basket'}, 'artisan', 'sakhi'),
        throwsA(isA<WorkflowError>()));
    expect(state, equals(before));
  });
  test('Product creation saves without publishing', () {
    final p = records(state['products']).first..remove('id');
    act('product', p, 'artisan');
    expect(records(state['products']).last['status'], 'ready');
  });
  test('Matching excludes unpublished and reveals partial capacity / lead gaps',
      () {
    (state['products'] as List).first['status'] = 'draft';
    final result = CommerceEngine.matches(state, {
      'product': 'bamboo basket',
      'quantity': 10000,
      'lead_days': 3,
      'location': 'Mumbai'
    });
    expect(result.any((p) => p['id'] == 'basket'), false);
    expect(result.every((p) => p['feasible'] == false), true);
  });
  test('Optional sample gates bulk acceptance, not every order', () {
    inquire(sample: true);
    act('quote', quote(), 'artisan');
    expect(accept, throwsA(isA<WorkflowError>()));
    act(
        'sample',
        {
          'id': inquiryId,
          'status': 'submitted',
          'evidence': 'sample-photo',
          'terms': 'One sample, cost agreed separately'
        },
        'artisan');
    act('sample', {'id': inquiryId, 'status': 'approved'}, 'buyer');
    accept();
    expect(records(state['orders']), hasLength(1));
  });
  test('Changed specifications invalidate the previous sample approval', () {
    inquire(sample: true);
    act('quote', quote(), 'artisan');
    act(
        'sample',
        {'id': inquiryId, 'status': 'submitted', 'evidence': 'sample-photo'},
        'artisan');
    act('sample', {'id': inquiryId, 'status': 'approved'}, 'buyer');
    act('quote', {...quote(), 'customization': 'New lid design'}, 'artisan');
    expect(records(state['inquiries']).first['sample_status'], 'requested');
    expect(accept, throwsA(isA<WorkflowError>()));
  });
  test(
      'Invalid percentage totals and prices below labour-aware floor are rejected',
      () {
    inquire();
    expect(() => act('quote', {...quote(), 'unit_price': 1}, 'artisan'),
        throwsA(isA<WorkflowError>()));
    expect(
        () => act(
            'quote',
            {
              ...quote(),
              'milestones': [
                {'trigger': 'advance', 'percent': 90}
              ]
            },
            'artisan'),
        throwsA(isA<WorkflowError>()));
  });
  test(
      'Stale quote rejected, own quote cannot be accepted, double accept creates one order',
      () {
    inquire();
    act('quote', quote(), 'artisan');
    final old = records(records(state['inquiries']).first['quotes']).last['id'];
    act('quote', {...quote(), 'unit_price': 310}, 'artisan');
    expect(() => act('accept', {'id': inquiryId, 'quote_id': old}, 'buyer'),
        throwsA(isA<WorkflowError>()));
    final latest =
        records(records(state['inquiries']).first['quotes']).last['id'];
    expect(
        () => act('accept', {'id': inquiryId, 'quote_id': latest}, 'artisan'),
        throwsA(isA<WorkflowError>()));
    accept();
    accept();
    expect(records(state['orders']), hasLength(1));
  });
  test(
      'Full lifecycle requires advance, review, shipment, inspection and settlement',
      () {
    inquire();
    act('quote', quote(checkpoint: true), 'artisan');
    final id = accept();
    expect(() => act('production', {'id': id, 'status': 'started'}, 'artisan'),
        throwsA(isA<WorkflowError>()));
    act('pay', {'id': id, 'milestone_id': 'm0'}, 'buyer');
    act('production', {'id': id, 'status': 'started'}, 'artisan');
    act('production', {'id': id, 'status': 'in_progress'}, 'artisan');
    expect(() => act('production', {'id': id, 'status': 'ready'}, 'artisan'),
        throwsA(isA<WorkflowError>()));
    act('checkpoint', {'id': id, 'quantity': 250, 'evidence': 'progress-photo'},
        'artisan');
    act('checkpoint', {'id': id, 'status': 'approved'}, 'buyer');
    act('production', {'id': id, 'status': 'ready'}, 'artisan');
    act('pay', {'id': id, 'milestone_id': 'm1'}, 'buyer');
    act(
        'shipping',
        {
          'id': id,
          'status': 'dispatched',
          'method': 'Manual courier',
          'tracking': 'DEMO-123',
          'evidence': 'packing-photo',
          'route': 'Direct',
          'checks': ['protection', 'count', 'inner', 'outer']
        },
        'artisan');
    expect(() => act('complete', {'id': id}, 'buyer'),
        throwsA(isA<WorkflowError>()));
    act('delivery', {'id': id}, 'buyer');
    expect(() => act('inspection', {'id': id, 'quantity': 470}, 'buyer'),
        throwsA(isA<WorkflowError>()));
    act('inspection', {'id': id, 'quantity': 500}, 'buyer');
    act('pay', {'id': id, 'milestone_id': 'm2'}, 'buyer');
    act('complete', {'id': id}, 'buyer');
    expect(records(state['orders']).first['status'], 'completed');
    expect(records(state['orders']).first['inspection_hours'], 36);
  });
  test('Open issues block progress and only admin resolves them', () {
    inquire();
    act('quote', quote(), 'artisan');
    final id = accept();
    act(
        'issue',
        {
          'id': id,
          'category': 'Quantity mismatch',
          'description': '470 of 500',
          'evidence': 'photo'
        },
        'buyer');
    final issue = records(state['issues']).first['id'];
    expect(() => act('pay', {'id': id, 'milestone_id': 'm0'}, 'buyer'),
        throwsA(isA<WorkflowError>()));
    expect(
        () => act(
            'resolve',
            {'id': issue, 'status': 'resolved', 'note': 'Replacement agreed'},
            'buyer'),
        throwsA(isA<WorkflowError>()));
    act(
        'resolve',
        {'id': issue, 'status': 'resolved', 'note': 'Replacement agreed'},
        'admin');
    act('pay', {'id': id, 'milestone_id': 'm0'}, 'buyer');
  });
  test(
      'Routing exposes direct, hub and unknown rather than inventing a provider',
      () {
    final p = records(state['products']).first;
    expect(
        CommerceEngine.route(
            p, {'quantity': 100, 'location': 'Mumbai'})['route'],
        'Direct');
    expect(
        CommerceEngine.route(p, {
          'quantity': 100,
          'location': 'Mumbai',
          'storage_needed': true,
          'hub_available': false
        })['route'],
        'Needs review');
    expect(
        CommerceEngine.route(
            p, {'quantity': 900, 'location': 'Mumbai'})['route'],
        'Needs review');
    expect(
        CommerceEngine.route(p, {
          'quantity': 900,
          'location': 'Mumbai',
          'hub_available': true
        })['route'],
        'Via hub');
  });
  test('Reorder requirement is fresh state, not old payment / acceptance', () {
    act(
        'requirement',
        {
          'product': 'Baskets',
          'quantity': 700,
          'lead_days': 40,
          'location': 'Mumbai',
          'source_order_id': 'old-order',
          'confirmed': true
        },
        'buyer');
    final r = records(state['requirements']).first;
    expect(r['quantity'], 700);
    expect(r['status'], 'open');
    expect(state['orders'], isEmpty);
  });
}

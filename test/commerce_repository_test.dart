import 'package:craft_connect/core/services/inquiry_service.dart';
import 'package:craft_connect/core/services/notification_service.dart';
import 'package:craft_connect/core/services/product_service.dart';
import 'package:craft_connect/core/services/requirement_service.dart';
import 'package:craft_connect/features/commerce/data/commerce_repository.dart';
import 'package:craft_connect/features/commerce/domain/commerce_engine.dart';
import 'package:craft_connect/shared/models/account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_session_helper.dart';

List<Map<String, dynamic>> seedProducts() =>
    (CommerceEngine.seed()['products'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

class FakeCatalogue extends ProductService {
  @override
  Future<List<Map<String, dynamic>>> mine() async => seedProducts();

  @override
  Future<List<Map<String, dynamic>>> published() async => seedProducts();
}

class FakeRequirements extends RequirementService {
  @override
  Future<List<Map<String, dynamic>>> mine() async => [];

  @override
  Future<String?> resolveImage(String? value) async => null;
}

class FakeInquiries extends InquiryService {
  FakeInquiries([this.rows = const []]);

  List<Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> created = [];
  final List<String> actions = [];

  @override
  Future<List<Map<String, dynamic>>> mine() async => rows;

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> draft) async {
    created.add(draft);
    return {'id': 'rfq-new', ...draft};
  }

  @override
  Future<Map<String, dynamic>> act(
      String id, String action, Map<String, dynamic> data) async {
    actions.add('$id/$action');
    return {'id': id};
  }
}

class FakeOrders extends OrderService {
  FakeOrders([this.rows = const []]);

  List<Map<String, dynamic>> rows;
  final List<String> actions = [];

  @override
  Future<List<Map<String, dynamic>>> mine() async => rows;

  @override
  Future<Map<String, dynamic>> act(
      String id, String segment, Map<String, dynamic> data) async {
    actions.add('$id/$segment');
    return {'id': id};
  }
}

class FakeNotifications extends NotificationService {
  FakeNotifications([this.rows = const []]);

  List<Map<String, dynamic>> rows;
  int readCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> mine() async => rows;

  @override
  Future<List<Map<String, dynamic>>> markAllRead() async {
    readCalls++;
    rows = rows.map((row) => {...row, 'read': true}).toList();
    return rows;
  }
}

Account signedInArtisan() => const Account(
    id: 'artisan-user',
    firebaseUid: 'test-uid',
    role: AccountRole.artisan,
    languagePref: 'en',
    name: 'Ramesh Kumar',
    profile: {'id': 'artisan-1', 'craft_category': 'pottery'});

Account withLanguage(Account account, String language) => Account(
    id: account.id,
    firebaseUid: account.firebaseUid,
    role: account.role,
    languagePref: language,
    name: account.name,
    phone: account.phone,
    email: account.email,
    isNew: account.isNew,
    profile: account.profile);

Future<CommerceRepository> openRepository(
    {InquiryService? inquiries,
    OrderService? orders,
    NotificationService? notifications}) async {
  final repository = CommerceRepository(
      catalogue: FakeCatalogue(),
      requirements: FakeRequirements(),
      inquiries: inquiries,
      orders: orders,
      notifications: notifications);
  while (!repository.ready) {
    await Future<void>.delayed(Duration.zero);
  }
  return repository;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Availability persists for buyers and after restart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = CommerceRepository();
    while (!first.ready) {
      await Future<void>.delayed(Duration.zero);
    }
    await first.act('availability', {'id': 'basket', 'available': false});
    await first.switchRole('buyer');
    expect(first.products.firstWhere((p) => p['id'] == 'basket')['available'],
        false);
    first.dispose();
    final restored = CommerceRepository();
    while (!restored.ready) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(restored.lookup('products', 'basket')!['available'], false);
    expect(restored.lookup('products', 'basket')!['status'], 'published');
    restored.dispose();
  });
  test('A requirement survives role changes and repository restart', () async {
    SharedPreferences.setMockInitialValues({});
    Future<CommerceRepository> open() async {
      final repository = CommerceRepository();
      while (!repository.ready) {
        await Future<void>.delayed(Duration.zero);
      }
      return repository;
    }

    final first = await open();
    await first.switchRole('buyer');
    await first.act('requirement', {
      'product': 'Bamboo baskets',
      'quantity': 500,
      'lead_days': 30,
      'location': 'Mumbai',
      'confirmed': true
    });
    final id = first.table('requirements').single['id'];
    await first.switchRole('artisan');
    expect(first.table('requirements').single['id'], id);
    first.dispose();
    final restored = await open();
    expect(restored.role, 'artisan');
    await restored.switchRole('buyer');
    expect(restored.table('requirements').single['id'], id);
    expect(restored.table('requirements').single['quantity'], 500);
    restored.dispose();
  });

  test('A signed-in buyer opens the inquiry on the shared backend', () async {
    SharedPreferences.setMockInitialValues({});
    final inquiries = FakeInquiries();
    final repo =
        await openRepository(inquiries: inquiries, orders: FakeOrders());
    await repo.applyAccount(testAccount(AccountRole.buyer));

    await repo.act('inquiry', {
      'product_id': 'basket',
      'product': 'Bamboo basket',
      'quantity': 60,
      'lead_days': 20,
      'location': 'Mumbai',
    });

    expect(inquiries.created.single['product_id'], 'basket');
    expect(inquiries.created.single['quantity'], 60);
    repo.dispose();
  });

  test('Shared inquiries and orders load for their artisan, and actions route',
      () async {
    SharedPreferences.setMockInitialValues({});
    final inquiries = FakeInquiries([
      {
        'id': 'rfq-1',
        'buyer_id': 'buyer-1',
        'artisan_id': 'artisan-1',
        'product_id': 'basket',
        'product_title': 'Bamboo Basket',
        'quantity': 60,
        'lead_days': 20,
        'location': 'Mumbai',
        'status': 'sent',
        'capacity_status': 'pending',
        'messages': [],
        'quotes': [],
      }
    ]);
    final orders = FakeOrders([
      {
        'id': 'order-1',
        'buyer_id': 'buyer-1',
        'artisan_id': 'artisan-1',
        'product_id': 'basket',
        'status': 'confirmed',
        'milestones': [],
      }
    ]);
    final repo = await openRepository(inquiries: inquiries, orders: orders);
    await repo.applyAccount(signedInArtisan());

    expect(repo.inquiries.single['id'], 'rfq-1');
    expect(repo.orders.single['id'], 'order-1');

    await repo.act('capacity', {
      'id': 'rfq-1',
      'status': 'confirmed',
      'quantity': 60,
      'lead_days': 20,
    });
    await repo.act('accept', {'id': 'rfq-1', 'quote_id': 'quote-1'});

    expect(inquiries.actions, ['rfq-1/capacity', 'rfq-1/accept']);
    repo.dispose();
  });

  test('A language change re-points the profile the offline bridge reads',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repo = await openRepository();
    await repo.applyAccount(testAccount(AccountRole.buyer));
    expect(repo.profile['language_pref'], 'en');

    await repo.applyAccount(withLanguage(testAccount(AccountRole.buyer), 'hi'));
    expect(repo.profile['language_pref'], 'hi');
    repo.dispose();
  });

  test('A signed-out workspace keeps inquiries on the local engine', () async {
    SharedPreferences.setMockInitialValues({});
    final inquiries = FakeInquiries();
    final repo =
        await openRepository(inquiries: inquiries, orders: FakeOrders());
    await repo.switchRole('buyer');

    await repo.act('inquiry', {
      'product_id': 'basket',
      'quantity': 60,
      'lead_days': 20,
      'location': 'Mumbai',
    });

    expect(inquiries.created, isEmpty);
    expect(repo.table('inquiries'), isNotEmpty);
    repo.dispose();
  });

  test('A message notification loads for its recipient and marks read',
      () async {
    SharedPreferences.setMockInitialValues({});
    final alerts = FakeNotifications([
      {
        'id': 'n1',
        'account_id': 'artisan-user',
        'actor_id': 'artisan-user',
        'role': 'artisan',
        'title': 'New message · Handmade Bamboo Basket',
        'link': 'inquiry/rfq-1?tab=chat',
        'category': 'Others',
        'read': false,
      }
    ]);
    final repo = await openRepository(
        inquiries: FakeInquiries(),
        orders: FakeOrders(),
        notifications: alerts);
    await repo.applyAccount(signedInArtisan());

    // The recipient sees it, unread, pointing at the conversation.
    expect(repo.notifications.single['id'], 'n1');
    expect(repo.notifications.single['read'], isFalse);
    expect(repo.notifications.single['link'], 'inquiry/rfq-1?tab=chat');

    await repo.act('read_notifications', {});

    expect(alerts.readCalls, 1);
    expect(repo.notifications.single['read'], isTrue);
    repo.dispose();
  });

  test('A device-local demo notification never counts for a signed-in account',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repo = await openRepository(
        inquiries: FakeInquiries(),
        orders: FakeOrders(),
        notifications: FakeNotifications());
    await repo.applyAccount(signedInArtisan());

    // A demo row left over from offline use carries the artisan's actor id, so
    // it would show unread and the backend could never mark it read.
    repo.state['notifications'] = [
      {
        'id': 'local-1',
        'actor_id': 'artisan-1',
        'role': 'artisan',
        'title': 'Demo quote',
        'link': 'inquiry/rfq-1',
        'read': false,
      }
    ];

    expect(repo.notifications, isEmpty);
    repo.dispose();
  });

  test('Artisan order steps go to the account order endpoints', () async {
    SharedPreferences.setMockInitialValues({});
    final orders = FakeOrders([
      {
        'id': 'order-1',
        'buyer_id': 'buyer-1',
        'artisan_id': 'artisan-1',
        'product_id': 'basket',
        'status': 'confirmed',
      }
    ]);
    final repo =
        await openRepository(inquiries: FakeInquiries(), orders: orders);
    await repo.applyAccount(signedInArtisan());

    await repo.act('order_accept', {'id': 'order-1'});
    await repo.act('production_plan', {
      'id': 'order-1',
      'prod_start_date': '2026-10-01',
      'prod_completion_date': '2026-10-20',
    });
    await repo
        .act('delivery_status', {'id': 'order-1', 'status': 'in_transit'});

    // The account client is used, not the demo workspace one: the segments are
    // the backend's, so a signed-in artisan reaches the shared order.
    expect(orders.actions, [
      'order-1/accept',
      'order-1/production-plan',
      'order-1/delivery-status',
    ]);
    repo.dispose();
  });
}

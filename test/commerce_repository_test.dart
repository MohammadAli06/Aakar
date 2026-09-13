import 'package:craft_connect/features/commerce/data/commerce_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}

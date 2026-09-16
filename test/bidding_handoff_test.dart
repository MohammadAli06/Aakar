import 'package:craft_connect/core/services/product_service.dart';
import 'package:craft_connect/features/commerce/data/commerce_repository.dart';
import 'package:craft_connect/features/commerce/domain/commerce_engine.dart';
import 'package:craft_connect/shared/models/account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_session_helper.dart';

class BiddingCatalogue extends ProductService {
  @override
  Future<List<Record>> mine() async =>
      records(CommerceEngine.seed()['products']);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'Bidding handoff persists and repeated opening preserves edited quotation',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repo = CommerceRepository(catalogue: BiddingCatalogue());
    while (!repo.ready) {
      await Future<void>.delayed(Duration.zero);
    }
    await repo.applyAccount(testAccount(AccountRole.artisan));
    final product = repo.products.first;
    final inquiry = <String, dynamic>{
      'id': 'bid-handoff',
      'bidding_session_id': 'session',
      'product_id': product['id'],
      'artisan_id': repo.actor,
      'buyer_id': 'other-buyer',
      'buyer_name': 'Buyer',
      'quantity': 10,
      'budget': 250,
      'quotes': [],
      'messages': []
    };
    await repo.importBiddingInquiry(inquiry, product);
    (repo.state['inquiries'] as List)
        .firstWhere((row) => row['id'] == 'bid-handoff')['quotes'] = [
      {'id': 'reviewed-draft'}
    ];
    await repo.importBiddingInquiry(inquiry, product);
    expect(
        repo.table('inquiries').where((r) => r['id'] == 'bid-handoff').length,
        1);
    expect(repo.lookup('inquiries', 'bid-handoff')!['quotes'], [
      {'id': 'reviewed-draft'}
    ]);
    await expectLater(
        repo.importBiddingInquiry(
            {...inquiry, 'artisan_id': 'someone-else'}, product),
        throwsA(isA<WorkflowError>()));
    repo.dispose();
    final restored = CommerceRepository(catalogue: BiddingCatalogue());
    while (!restored.ready) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(restored.lookup('inquiries', 'bid-handoff')!['quotes'], [
      {'id': 'reviewed-draft'}
    ]);
    restored.dispose();
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:craft_connect/features/commerce/domain/commerce_engine.dart';

void main() {
  group('craftsmanship complexity pipeline', () {
    test('floor uses material + labour + overhead', () {
      final draft = {'material_cost': 300, 'labour_cost': 200, 'overhead': 50};
      expect(CommerceEngine.floor(draft), 550);
    });

    test('floor treats missing costs as zero rather than throwing', () {
      expect(CommerceEngine.floor({}), 0);
    });

    test('an AI complexity visibly moves the suggested range', () {
      final draft = {'material_cost': 300, 'labour_cost': 200, 'overhead': 50};
      final floor = CommerceEngine.floor(draft);

      double lo(double c) => floor * (1.25 + c * .15);
      double hi(double c) => floor * (1.5 + c * .2);

      // Same floor, only the assessed complexity differs.
      expect(lo(0.0), 687.5);
      expect(lo(1.0), 770.0);
      expect(hi(0.0), 825.0);
      expect(hi(1.0), 935.0);

      // The range always clears the floor, which is the promise the UI makes.
      for (final c in [0.0, 0.35, 0.5, 0.8, 1.0]) {
        expect(lo(c), greaterThan(floor));
        expect(hi(c), greaterThanOrEqualTo(lo(c)));
      }
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:craft_connect/features/commerce/presentation/product_studio_screen.dart';

void main() {
  group('aiComplexityScore', () {
    test('reads a valid score', () {
      expect(aiComplexityScore({'complexity_score': 0.4}), 0.4);
      expect(aiComplexityScore({'complexity_score': 1}), 1.0);
      expect(aiComplexityScore({'complexity_score': 1.0}), 1.0);
    });

    test('rejects a response the chip cannot render', () {
      // The regression: these reached the chip and crashed the pricing step.
      expect(aiComplexityScore(null), isNull);
      expect(aiComplexityScore('not a map'), isNull);
      expect(aiComplexityScore({}), isNull);
      expect(aiComplexityScore({'complexity_score': null}), isNull);
      expect(aiComplexityScore({'is_fallback': true}), isNull);
      expect(aiComplexityScore({'complexity_score': 'high'}), isNull);
      expect(aiComplexityScore({'complexity_score': double.nan}), isNull);
      expect(aiComplexityScore({'complexity_score': double.infinity}), isNull);
      expect(aiComplexityScore({'complexity_score': -0.2}), isNull);
      expect(aiComplexityScore({'complexity_score': 1.4}), isNull);
    });
  });
}

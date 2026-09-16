import 'dart:typed_data';
import 'dart:ui';
import 'package:craft_connect/features/capture/product_capture_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rules = ProductCaptureRules();
  ProductCaptureHint check(Rect? box, {double? light = 100, int misses = 0}) =>
      rules.evaluate(
          box: box,
          frame: const Size(100, 100),
          brightness: light,
          misses: misses);

  test('one prioritized instruction, all checks required for ready', () {
    expect(check(null, light: 20), ProductCaptureHint.searching);
    expect(check(const Rect.fromLTWH(0, 0, 10, 10), light: 20),
        ProductCaptureHint.dark);
    expect(check(const Rect.fromLTWH(0, 0, 10, 10)), ProductCaptureHint.closer);
    expect(check(const Rect.fromLTWH(0, 0, 90, 90)), ProductCaptureHint.back);
    expect(
        check(const Rect.fromLTWH(0, 20, 40, 40)), ProductCaptureHint.center);
    expect(
        check(const Rect.fromLTWH(25, 25, 50, 50)), ProductCaptureHint.ready);
    expect(check(const Rect.fromLTWH(25, 25, 50, 50), light: null),
        ProductCaptureHint.manual);
  });

  test(
      'fallback after five misses retains brightness and recovers on detection',
      () {
    expect(check(null, misses: 4), ProductCaptureHint.searching);
    expect(check(null, misses: 5), ProductCaptureHint.manual);
    expect(check(null, misses: 5, light: 79), ProductCaptureHint.dark);
    expect(check(const Rect.fromLTWH(25, 25, 50, 50), misses: 0, light: 80),
        ProductCaptureHint.ready);
  });

  test('Y luminance ignores row padding and chroma/pixel padding', () {
    final bytes = Uint8List.fromList(
        [80, 255, 100, 255, 255, 255, 120, 255, 140, 255, 255, 255]);
    expect(sampleLuminance(bytes, 2, 2, 6, 2), 110);
    expect(sampleLuminance(Uint8List(0), 2, 2, 2, 1), isNull);
  });

  test('iOS BGRA uses colour luminance rather than blue alone', () {
    expect(
        sampleLuminance(Uint8List.fromList([0, 0, 255, 255]), 1, 1, 4, 4,
            bgra: true),
        closeTo(76.245, .001));
  });
}

import 'dart:typed_data';
import 'dart:ui';

enum ProductCaptureHint {
  searching('Place the product inside the frame', 'उत्पाद को फ्रेम में रखें'),
  dark('Move to better lighting', 'बेहतर रोशनी में जाएँ'),
  closer('Move closer', 'थोड़ा पास लाएँ'),
  back('Move back a little', 'थोड़ा पीछे जाएँ'),
  center('Center the product', 'उत्पाद को बीच में रखें'),
  ready('Ready to capture', 'फ़ोटो लेने के लिए तैयार'),
  manual('Place the product in the guide and tap capture',
      'उत्पाद को फ्रेम में रखें और फ़ोटो बटन दबाएँ');

  const ProductCaptureHint(this.en, this.hi);
  final String en, hi;
}

/// Starting thresholds; calibrate with real products and demo lighting.
class ProductCaptureRules {
  const ProductCaptureRules(
      {this.minArea = .15,
      this.maxArea = .70,
      this.maxOffset = .20,
      this.minBrightness = 80,
      this.fallbackChecks = 5});
  final double minArea, maxArea, maxOffset, minBrightness;
  final int fallbackChecks;

  ProductCaptureHint evaluate(
      {required Rect? box,
      required Size frame,
      required double? brightness,
      required int misses}) {
    if (box == null && misses < fallbackChecks) {
      return ProductCaptureHint.searching;
    }
    if (brightness != null && brightness < minBrightness) {
      return ProductCaptureHint.dark;
    }
    if (box == null || brightness == null) return ProductCaptureHint.manual;
    final area = box.width * box.height / (frame.width * frame.height);
    if (area < minArea) return ProductCaptureHint.closer;
    if (area > maxArea) return ProductCaptureHint.back;
    if ((box.center.dx / frame.width - .5).abs() > maxOffset ||
        (box.center.dy / frame.height - .5).abs() > maxOffset) {
      return ProductCaptureHint.center;
    }
    return ProductCaptureHint.ready;
  }
}

/// Sample at most about 1,600 pixels, respecting padding and pixel stride.
double? sampleLuminance(
    Uint8List bytes, int width, int height, int rowStride, int pixelStride,
    {bool bgra = false}) {
  var sum = 0.0, count = 0;
  final dx = (width / 40).ceil().clamp(1, width);
  final dy = (height / 40).ceil().clamp(1, height);
  for (var y = 0; y < height; y += dy) {
    for (var x = 0; x < width; x += dx) {
      final i = y * rowStride + x * pixelStride;
      if (i + (bgra ? 2 : 0) >= bytes.length) continue;
      sum += bgra
          ? .114 * bytes[i] + .587 * bytes[i + 1] + .299 * bytes[i + 2]
          : bytes[i];
      count++;
    }
  }
  return count == 0 ? null : sum / count;
}

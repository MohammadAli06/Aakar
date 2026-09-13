import 'package:craft_connect/features/commerce/domain/photo_enhancement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as imaging;

/// A plain light backdrop with a dark product block in the middle.
imaging.Image scene({required int width, required int height}) {
  final image = imaging.Image(width: width, height: height, numChannels: 3);
  imaging.fill(image, color: imaging.ColorRgb8(232, 230, 226));
  imaging.fillRect(image,
      x1: width ~/ 4,
      y1: height ~/ 4,
      x2: width * 3 ~/ 4,
      y2: height * 3 ~/ 4,
      color: imaging.ColorRgb8(96, 54, 30));
  return image;
}

void main() {
  test('textured border bands clear without crossing the protected centre', () {
    final source = imaging.Image(width: 240, height: 200, numChannels: 3);
    for (final pixel in source) {
      final shade = (pixel.x ~/ 18).isEven ? 65 : 185;
      pixel
        ..r = shade
        ..g = shade - 15
        ..b = shade - 30;
    }
    final original = source.getBytes().toList();
    final result = preparePhoto(source, PhotoPrep.plainBackground);
    for (var x = 5; x < 240; x += 18) {
      expect(result.getPixel(x, 5).r.toInt(), 255);
    }
    // Even backdrop-identical pixels in the entire centre are immutable.
    for (var y = 30; y < 170; y++) {
      for (var x = 36; x < 204; x++) {
        expect(result.getPixel(x, y).r, source.getPixel(x, y).r);
      }
    }
    expect(source.getBytes(), original);
  });

  test('cleanup removes a small enclosed island but retains large patches', () {
    final source = scene(width: 400, height: 400);
    imaging.fillRect(source,
        x1: 10, y1: 10, x2: 20, y2: 20, color: imaging.ColorRgb8(20, 20, 20));
    // >2% of the frame, wholly outside the protected centre.
    imaging.fillRect(source,
        x1: 5, y1: 80, x2: 45, y2: 300, color: imaging.ColorRgb8(20, 20, 20));
    final result = preparePhoto(source, PhotoPrep.plainBackground);
    expect(result.getPixel(15, 15).r.toInt(), 255);
    expect(result.getPixel(25, 150).r.toInt(), 20);
  });

  test('a small product extension connected to the centre is retained', () {
    final source = scene(width: 200, height: 200);
    imaging.fillRect(source,
        x1: 15, y1: 95, x2: 60, y2: 105, color: imaging.ColorRgb8(96, 54, 30));
    final result = preparePhoto(source, PhotoPrep.plainBackground);
    expect(result.getPixel(20, 100).r.toInt(), 96);
  });

  test('feather transitions over three backdrop pixels, never into the centre',
      () {
    final source = imaging.Image(width: 200, height: 200, numChannels: 3);
    imaging.fill(source, color: imaging.ColorRgb8(100, 100, 100));
    final result = preparePhoto(source, PhotoPrep.plainBackground);
    expect(result.getPixel(26, 100).r.toInt(), 255);
    expect(result.getPixel(27, 100).r.toInt(), inExclusiveRange(100, 255));
    expect(result.getPixel(28, 100).r, lessThan(result.getPixel(27, 100).r));
    expect(result.getPixel(29, 100).r, lessThan(result.getPixel(28, 100).r));
    expect(result.getPixel(30, 100).r.toInt(), 100);
  });

  test('natural setting never replaces textured background pixels', () {
    final source = imaging.Image(width: 200, height: 200, numChannels: 3);
    for (final pixel in source) {
      final shade = pixel.x.isEven ? 110 : 130;
      pixel
        ..r = shade
        ..g = shade
        ..b = shade;
    }
    final result = preparePhoto(source, PhotoPrep.naturalSetting);
    expect(result.getBytes(), source.getBytes());
  });

  test('B2B fits wide product ends and pads both backdrop choices', () {
    final source = scene(width: 300, height: 100);
    imaging.fillRect(source,
        x1: 20, y1: 40, x2: 280, y2: 60, color: imaging.ColorRgb8(96, 54, 30));
    imaging.fillRect(source,
        x1: 20, y1: 40, x2: 30, y2: 60, color: imaging.ColorRgb8(220, 20, 20));
    imaging.fillRect(source,
        x1: 270,
        y1: 40,
        x2: 280,
        y2: 60,
        color: imaging.ColorRgb8(20, 20, 220));
    for (final plain in [true, false]) {
      final result = preparePhoto(source, PhotoPrep.b2bCatalog,
          catalogPlainBackground: plain);
      expect(result.width, 1200);
      expect(result.getPixel(119, 600).r.toInt(), 255);
      expect(result.getPixel(1080, 600).r.toInt(), 255);
      expect(result.any((p) => p.r > 200 && p.g < 40 && p.b < 40), isTrue);
      expect(result.any((p) => p.b > 200 && p.g < 40 && p.r < 40), isTrue);
    }
    final plain = preparePhoto(source, PhotoPrep.b2bCatalog);
    final natural = preparePhoto(source, PhotoPrep.b2bCatalog,
        catalogPlainBackground: false);
    expect(plain.getBytes(), isNot(orderedEquals(natural.getBytes())));
  });

  test('every option is offered and carries a reason', () {
    expect(photoPrepOptions.map((option) => option.mode).toList(),
        PhotoPrep.values);
    for (final option in photoPrepOptions) {
      expect(option.labelEn, isNotEmpty);
      expect(option.reasonEn.length, greaterThan(40));
      expect(option.reasonHi, isNotEmpty);
    }
  });

  test('plain background whitens the backdrop and leaves the product alone',
      () {
    final result =
        preparePhoto(scene(width: 200, height: 160), PhotoPrep.plainBackground);

    final corner = result.getPixel(0, 0);
    expect(corner.r.toInt(), 255);
    expect(corner.g.toInt(), 255);
    expect(corner.b.toInt(), 255);

    final centre = result.getPixel(100, 80);
    expect(centre.r.toInt(), 96);
    expect(centre.g.toInt(), 54);
    expect(centre.b.toInt(), 30);
  });

  test('natural setting keeps the backdrop but lifts a dim exposure', () {
    final dim = imaging.Image(width: 200, height: 160, numChannels: 3);
    imaging.fill(dim, color: imaging.ColorRgb8(70, 68, 66));
    final lifted = preparePhoto(dim, PhotoPrep.naturalSetting);

    expect(lifted.getPixel(5, 5).r.toInt(), greaterThan(90));
    // Colour relationships survive: the correction is one gain, not a cast.
    final pixel = lifted.getPixel(5, 5);
    expect(pixel.r - pixel.g, closeTo(2, 3));
  });

  test('an evenly exposed photo is passed through unchanged', () {
    final even = imaging.Image(width: 120, height: 120, numChannels: 3);
    imaging.fill(even, color: imaging.ColorRgb8(150, 140, 130));
    imaging.fillRect(even,
        x1: 20, y1: 20, x2: 100, y2: 100, color: imaging.ColorRgb8(60, 55, 50));
    final result = preparePhoto(even, PhotoPrep.naturalSetting);

    expect(result.getPixel(4, 4).r.toInt(), 150);
  });

  test('B2B catalogue frame is always a 1200 square', () {
    for (final size in const [
      [240, 120],
      [120, 240],
      [1200, 1200],
      [40, 40],
    ]) {
      final result = preparePhoto(
          scene(width: size[0], height: size[1]), PhotoPrep.b2bCatalog);
      expect(result.width, 1200);
      expect(result.height, 1200);
    }
  });

  test('the catalogue frame keeps the whole product in view', () {
    // A wide photo of a centred product: the crop keeps the middle, so the
    // product colour survives at the centre of the square.
    final result =
        preparePhoto(scene(width: 300, height: 100), PhotoPrep.b2bCatalog);
    final centre = result.getPixel(600, 600);
    expect(centre.r.toInt(), 96);
  });
}

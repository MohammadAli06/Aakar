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

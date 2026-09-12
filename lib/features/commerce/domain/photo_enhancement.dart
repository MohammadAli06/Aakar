import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as imaging;
import 'package:path_provider/path_provider.dart';

/// How a product photo is prepared before it is attached to a listing.
///
/// Every option is a plain, deterministic image operation — a backdrop
/// replacement, an exposure correction, or a square frame. None of them invent,
/// redraw or restyle the product, and the original file is always kept so the
/// artisan can compare the two and change their mind.
enum PhotoPrep { plainBackground, naturalSetting, b2bCatalog }

class PhotoPrepOption {
  final PhotoPrep mode;
  final String labelEn;
  final String labelHi;
  final String reasonEn;
  final String reasonHi;
  const PhotoPrepOption(
      this.mode, this.labelEn, this.labelHi, this.reasonEn, this.reasonHi);
}

const photoPrepOptions = <PhotoPrepOption>[
  PhotoPrepOption(
    PhotoPrep.plainBackground,
    'Plain white background',
    'सादा सफ़ेद बैकग्राउंड',
    'Cleans a plain, evenly lit backdrop to studio white. Works best against a wall, cloth or paper; if your backdrop is busy, choose “keep my natural setting”.',
    'सादे और एक-रोशनी वाले बैकग्राउंड को सफ़ेद करता है। दीवार, कपड़े या कागज़ पर सबसे अच्छा; पीछे का दृश्य व्यस्त हो तो “अपनी प्राकृतिक सेटिंग” चुनें।',
  ),
  PhotoPrepOption(
    PhotoPrep.naturalSetting,
    'Keep my natural setting',
    'अपनी प्राकृतिक सेटिंग रखें',
    'Keeps your real workspace or backdrop and corrects exposure only, so a dim photo reads clearly. Colour, texture and shape stay as photographed.',
    'आपका असली वर्कशॉप/पृष्ठभूमि वैसा ही रहता है, सिर्फ़ रोशनी ठीक होती है। रंग, बनावट और आकार वैसे ही रहते हैं।',
  ),
  PhotoPrepOption(
    PhotoPrep.b2bCatalog,
    'B2B catalogue frame',
    'B2B कैटलॉग फ़्रेम',
    'Frames the product as a square 1200×1200 image, so every bulk listing shares one consistent shape and size.',
    'उत्पाद को 1200×1200 वर्ग में रखता है, ताकि हर थोक लिस्टिंग एक जैसी दिखे।',
  ),
];

PhotoPrepOption photoPrepOption(PhotoPrep mode) =>
    photoPrepOptions.firstWhere((option) => option.mode == mode);

/// A listing photo does not need the full camera file, and the pixel passes
/// stay quick at this size.
const _workingEdge = 1400;
const _catalogueSide = 1200;

/// Backdrop similarity in Lab space: low enough that the product's own colour
/// survives, high enough to absorb shading across a plain backdrop.
const _backdropTolerance = 14.0;

/// Neutral mid-tone the exposure correction aims for, and the range outside
/// which a photo counts as genuinely dim or bright.
const _targetMedian = 118.0;
const _dimBelow = 100;
const _brightAbove = 145;

/// Apply [mode] to [source]. Pure — no file or plugin access — so the
/// transforms are directly testable.
imaging.Image preparePhoto(imaging.Image source, PhotoPrep mode) {
  // Work in a known 8-bit, 3-channel space so pixel reads and writes mean the
  // same thing for every supported input format.
  final work = source.convert(format: imaging.Format.uint8, numChannels: 3);
  switch (mode) {
    case PhotoPrep.plainBackground:
      return _plainBackground(_downscale(work, _workingEdge));
    case PhotoPrep.naturalSetting:
      return _correctExposure(_downscale(work, _workingEdge));
    case PhotoPrep.b2bCatalog:
      return _catalogueFrame(work);
  }
}

/// Decode [sourcePath], apply [mode] and write the result into the app's
/// documents directory. The source file itself is never modified.
Future<String> preparePhotoFile(String sourcePath, PhotoPrep mode) async {
  final bytes = await File(sourcePath).readAsBytes();
  final decoded = imaging.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('This photo could not be read.');
  }
  final prepared = preparePhoto(decoded, mode);
  final directory = await getApplicationDocumentsDirectory();
  final path =
      '${directory.path}/prepared-${mode.name}-${DateTime.now().microsecondsSinceEpoch}.jpg';
  await File(path).writeAsBytes(imaging.encodeJpg(prepared, quality: 92));
  return path;
}

imaging.Image _downscale(imaging.Image source, int maxEdge) {
  final longest = math.max(source.width, source.height);
  if (longest <= maxEdge) return source;
  final scale = maxEdge / longest;
  return imaging.copyResize(source,
      width: math.max(1, (source.width * scale).round()),
      height: math.max(1, (source.height * scale).round()),
      interpolation: imaging.Interpolation.average);
}

/// Replace backdrop regions connected to the frame with white. Seeding only
/// from the border means a similarly coloured area inside the product is kept.
imaging.Image _plainBackground(imaging.Image image) {
  final seeds = <List<int>>[
    [0, 0],
    [image.width - 1, 0],
    [0, image.height - 1],
    [image.width - 1, image.height - 1],
    [image.width ~/ 2, 0],
    [image.width ~/ 2, image.height - 1],
    [0, image.height ~/ 2],
    [image.width - 1, image.height ~/ 2],
  ];
  for (final seed in seeds) {
    final x = seed[0], y = seed[1];
    final corner = image.getPixel(x, y);
    // An earlier seed may already have whitened this edge.
    if (corner.r >= 250 && corner.g >= 250 && corner.b >= 250) continue;
    imaging.fillFlood(image,
        x: x,
        y: y,
        color: imaging.ColorRgb8(255, 255, 255),
        threshold: _backdropTolerance);
  }
  return image;
}

/// Bring a genuinely dim or bright photo back to a neutral mid-tone. The same
/// gain is applied to every channel, so hue, texture and shape are untouched —
/// and a normally exposed photo is returned exactly as taken.
imaging.Image _correctExposure(imaging.Image image) {
  final histogram = List<int>.filled(256, 0);
  for (final pixel in image) {
    histogram[_luminance(pixel.r, pixel.g, pixel.b)]++;
  }
  final median = _percentile(histogram, image.width * image.height, 0.5);
  if (median >= _dimBelow && median <= _brightAbove) return image;

  final gain = (_targetMedian / median).clamp(0.85, 1.45);
  for (final pixel in image) {
    pixel
      ..r = (pixel.r * gain).clamp(0, 255)
      ..g = (pixel.g * gain).clamp(0, 255)
      ..b = (pixel.b * gain).clamp(0, 255);
  }
  return image;
}

/// Crop to the largest centred square and resize to the fixed catalogue size,
/// so bulk listings share one consistent shape.
imaging.Image _catalogueFrame(imaging.Image source) {
  final side = math.min(source.width, source.height);
  final square = imaging.copyCrop(source,
      x: (source.width - side) ~/ 2,
      y: (source.height - side) ~/ 2,
      width: side,
      height: side);
  if (square.width == _catalogueSide && square.height == _catalogueSide) {
    return square;
  }
  return imaging.copyResize(square,
      width: _catalogueSide,
      height: _catalogueSide,
      interpolation: imaging.Interpolation.average);
}

int _luminance(num r, num g, num b) =>
    (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);

int _percentile(List<int> histogram, int total, double fraction) {
  final target = (total * fraction).round();
  var seen = 0;
  for (var value = 0; value < histogram.length; value++) {
    seen += histogram[value];
    if (seen >= target) return value;
  }
  return histogram.length - 1;
}

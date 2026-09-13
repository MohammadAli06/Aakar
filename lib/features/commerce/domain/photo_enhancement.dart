import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as imaging;
import 'package:path_provider/path_provider.dart';

/// How a product photo is prepared before it is attached to a listing.
///
/// Product Studio uses StudioService for OpenAI white-background editing and
/// deterministic exposure/framing. The local transforms below remain legacy
/// utilities, not a silent fallback for a failed OpenAI request.
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
    'OpenAI replaces the surroundings with white, with instructions to preserve the whole object and its real details. Review the result against your original.',
    'OpenAI को पूरा उत्पाद और असली विवरण सुरक्षित रखकर आसपास सफ़ेद करने का निर्देश मिलता है। परिणाम मूल फ़ोटो से मिलाकर जाँचें।',
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
    'Fits the retained product area into a 1200×1200 square with at least 10% margins. Choose a white backdrop or keep the whole natural photo using the switch below.',
    'बचे हुए उत्पाद क्षेत्र को कम से कम 10% खाली किनारों के साथ 1200×1200 वर्ग में रखता है। नीचे के स्विच से सफ़ेद बैकग्राउंड या पूरी प्राकृतिक फ़ोटो चुनें।',
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
imaging.Image preparePhoto(imaging.Image source, PhotoPrep mode,
    {bool catalogPlainBackground = true}) {
  // Work in a known 8-bit, 3-channel space so pixel reads and writes mean the
  // same thing for every supported input format.
  final work = source.convert(format: imaging.Format.uint8, numChannels: 3);
  switch (mode) {
    case PhotoPrep.plainBackground:
      return _plainBackground(_downscale(work, _workingEdge));
    case PhotoPrep.naturalSetting:
      return _correctExposure(_downscale(work, _workingEdge));
    case PhotoPrep.b2bCatalog:
      final image = _downscale(work, _workingEdge);
      final mask = catalogPlainBackground ? _backgroundMask(image) : null;
      return _catalogueFrame(
          mask != null ? _applyBackground(image, mask) : image, mask);
  }
}

/// Decode [sourcePath], apply [mode] and write the result into the app's
/// documents directory. The source file itself is never modified.
Future<String> preparePhotoFile(String sourcePath, PhotoPrep mode,
    {bool catalogPlainBackground = true}) async {
  final bytes = await File(sourcePath).readAsBytes();
  final decoded = imaging.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('This photo could not be read.');
  }
  final prepared = preparePhoto(imaging.bakeOrientation(decoded), mode,
      catalogPlainBackground: catalogPlainBackground);
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

imaging.Image _plainBackground(imaging.Image image) =>
    _applyBackground(image, _backgroundMask(image));

/// Build a mask against immutable source colours. The middle 70% of each
/// dimension is a hard keep region, not a claim of subject segmentation.
Uint8List _backgroundMask(imaging.Image image) {
  final w = image.width, h = image.height, count = w * h;
  final mask = Uint8List(count);
  final protected = Uint8List(count);
  final lab = Float32List(count * 3);
  final insetX = (w * .15).floor(), insetY = (h * .15).floor();
  for (final pixel in image) {
    final i = pixel.y * w + pixel.x;
    if (pixel.x >= insetX &&
        pixel.x < w - insetX &&
        pixel.y >= insetY &&
        pixel.y < h - insetY) {
      protected[i] = 1;
    } else {
      final colour = imaging.rgbToLab(pixel.r, pixel.g, pixel.b);
      for (var channel = 0; channel < 3; channel++) {
        lab[i * 3 + channel] = colour[channel].toDouble();
      }
    }
  }
  final queue = Int32List(count);
  final visited = Int32List(count);
  var stamp = 0;
  void flood(int seed) {
    if (mask[seed] != 0 || protected[seed] != 0) return;
    stamp++;
    var head = 0, tail = 0;
    void visit(int i) {
      if (mask[i] != 0 || protected[i] != 0 || visited[i] == stamp) return;
      visited[i] = stamp;
      final l = lab[i * 3] - lab[seed * 3];
      final a = lab[i * 3 + 1] - lab[seed * 3 + 1];
      final b = lab[i * 3 + 2] - lab[seed * 3 + 2];
      if (l * l + a * a + b * b > _backdropTolerance * _backdropTolerance) {
        return;
      }
      mask[i] = 1;
      queue[tail++] = i;
    }

    visit(seed);
    while (head < tail) {
      final i = queue[head++], x = i % w;
      if (x > 0) visit(i - 1);
      if (x < w - 1) visit(i + 1);
      if (i >= w) visit(i - w);
      if (i < count - w) visit(i + w);
    }
  }

  // Include the last pixel even when the edge is not divisible by 18.
  for (var x = 0; x < w; x += 18) {
    flood(x);
    flood((h - 1) * w + x);
  }
  for (var y = 0; y < h; y += 18) {
    flood(y * w);
    flood(y * w + w - 1);
  }
  flood(w - 1);
  flood(count - 1);

  // Only sweep small retained components enclosed by the new mask. Eight-way
  // connectivity preserves even diagonal attachments to the protected product.
  visited.fillRange(0, count, 0);
  for (var seed = 0; seed < count; seed++) {
    if (mask[seed] != 0 || visited[seed] != 0) continue;
    var head = 0, tail = 1;
    var keep = false;
    queue[0] = seed;
    visited[seed] = 1;
    while (head < tail) {
      final i = queue[head++], x = i % w, y = i ~/ w;
      if (protected[i] != 0 || x == 0 || y == 0 || x == w - 1 || y == h - 1) {
        keep = true;
      }
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
          final next = ny * w + nx;
          if (mask[next] == 0 && visited[next] == 0) {
            visited[next] = 1;
            queue[tail++] = next;
          }
        }
      }
    }
    if (!keep && tail < count * .02) {
      for (var j = 0; j < tail; j++) {
        mask[queue[j]] = 1;
      }
    }
  }
  return mask;
}

/// Feather three pixels outward into the removed backdrop only. Retained
/// pixels (especially the protected centre) must never be blurred or whitened.
imaging.Image _applyBackground(imaging.Image image, Uint8List mask) {
  final w = image.width, h = image.height;
  for (final pixel in image) {
    if (mask[pixel.y * w + pixel.x] == 0) continue;
    var distance = 4;
    for (var dy = -3; dy <= 3; dy++) {
      for (var dx = -3; dx <= 3; dx++) {
        final x = pixel.x + dx, y = pixel.y + dy;
        if (x >= 0 && x < w && y >= 0 && y < h && mask[y * w + x] == 0) {
          distance = math.min(distance, math.max(dx.abs(), dy.abs()));
        }
      }
    }
    final alpha = distance / 4;
    pixel
      ..r = (pixel.r + (255 - pixel.r) * alpha).round()
      ..g = (pixel.g + (255 - pixel.g) * alpha).round()
      ..b = (pixel.b + (255 - pixel.b) * alpha).round();
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

/// Fit retained bounds with 10% minimum margins; never crop a centre square.
/// Keeping the natural backdrop fits the whole photograph instead.
imaging.Image _catalogueFrame(imaging.Image source, Uint8List? mask) {
  var left = 0, top = 0, right = source.width - 1, bottom = source.height - 1;
  if (mask != null) {
    left = source.width;
    top = source.height;
    right = bottom = 0;
    for (var i = 0; i < mask.length; i++) {
      if (mask[i] != 0) continue;
      left = math.min(left, i % source.width);
      right = math.max(right, i % source.width);
      top = math.min(top, i ~/ source.width);
      bottom = math.max(bottom, i ~/ source.width);
    }
    // Keep the outward feather in the crop too.
    left = math.max(0, left - 3);
    top = math.max(0, top - 3);
    right = math.min(source.width - 1, right + 3);
    bottom = math.min(source.height - 1, bottom + 3);
  }
  final crop = imaging.copyCrop(source,
      x: left, y: top, width: right - left + 1, height: bottom - top + 1);
  final scale = (_catalogueSide * .8) / math.max(crop.width, crop.height);
  final fitted = imaging.copyResize(crop,
      width: math.max(1, (crop.width * scale).round()),
      height: math.max(1, (crop.height * scale).round()),
      interpolation: imaging.Interpolation.linear);
  final canvas = imaging.Image(
      width: _catalogueSide, height: _catalogueSide, numChannels: 3);
  imaging.fill(canvas, color: imaging.ColorRgb8(255, 255, 255));
  return imaging.compositeImage(canvas, fitted,
      dstX: (_catalogueSide - fitted.width) ~/ 2,
      dstY: (_catalogueSide - fitted.height) ~/ 2);
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

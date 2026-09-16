import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'product_capture_guidance.dart';

/// Owns one detector and drops incoming frames while a check is running.
class ProductFrameAnalyzer {
  final _detector = ObjectDetector(
      options: ObjectDetectorOptions(
          mode: DetectionMode.stream,
          classifyObjects: false,
          multipleObjects: false));
  final _clock = Stopwatch()..start();
  final rules = const ProductCaptureRules();
  int _lastFrame = -300, _misses = 0;
  bool _busy = false, _closed = false;
  Future<ProductCaptureHint?>? _pending;

  Future<ProductCaptureHint?> analyze(
      CameraImage image, CameraController camera) {
    if (_closed || _busy || _clock.elapsedMilliseconds - _lastFrame < 300) {
      return Future.value();
    }
    _busy = true;
    _lastFrame = _clock.elapsedMilliseconds;
    return _pending = _process(image, camera);
  }

  Future<void> close() async {
    _closed = true;
    await _pending;
    try {
      await _detector.close();
    } catch (_) {
      // The native detector may never have initialized on this device.
    }
  }

  Future<ProductCaptureHint?> _process(
      CameraImage image, CameraController camera) async {
    double? brightness;
    Rect? box;
    var size = Size(image.width.toDouble(), image.height.toDouble());
    try {
      final plane = image.planes.first;
      final bgra = image.format.group == ImageFormatGroup.bgra8888;
      if (bgra ||
          image.format.group == ImageFormatGroup.yuv420 ||
          image.format.group == ImageFormatGroup.nv21) {
        brightness = sampleLuminance(plane.bytes, image.width, image.height,
            plane.bytesPerRow, bgra ? 4 : (plane.bytesPerPixel ?? 1),
            bgra: bgra);
      }
      final orientation = {
        DeviceOrientation.portraitUp: 0,
        DeviceOrientation.landscapeLeft: 90,
        DeviceOrientation.portraitDown: 180,
        DeviceOrientation.landscapeRight: 270
      }[camera.value.deviceOrientation]!;
      final sensor = camera.description.sensorOrientation;
      final degrees = Platform.isIOS
          ? sensor
          : (camera.description.lensDirection == CameraLensDirection.front
                  ? sensor + orientation
                  : sensor - orientation + 360) %
              360;
      final rotation = InputImageRotationValue.fromRawValue(degrees)!;
      if (degrees == 90 || degrees == 270) size = Size(size.height, size.width);
      Uint8List bytes;
      InputImageFormat format;
      if (bgra && Platform.isIOS) {
        bytes = plane.bytes;
        format = InputImageFormat.bgra8888;
      } else if (image.format.group == ImageFormatGroup.nv21 &&
          image.planes.length == 1) {
        bytes = plane.bytes;
        format = InputImageFormat.nv21;
      } else if (image.format.group == ImageFormatGroup.yuv420 &&
          image.planes.length == 3) {
        // ML Kit's byte API needs NV21. Respect CameraX row and pixel padding.
        bytes = Uint8List(image.width * image.height * 3 ~/ 2);
        var offset = 0;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            bytes[offset++] = plane
                .bytes[y * plane.bytesPerRow + x * (plane.bytesPerPixel ?? 1)];
          }
        }
        for (var y = 0; y < image.height ~/ 2; y++) {
          for (var x = 0; x < image.width ~/ 2; x++) {
            for (final index in [2, 1]) {
              final chroma = image.planes[index];
              bytes[offset++] = chroma.bytes[
                  y * chroma.bytesPerRow + x * (chroma.bytesPerPixel ?? 1)];
            }
          }
        }
        format = InputImageFormat.nv21;
      } else {
        throw StateError('Unsupported frame format');
      }
      final objects = await _detector.processImage(InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
              size: Size(image.width.toDouble(), image.height.toDouble()),
              rotation: rotation,
              format: format,
              bytesPerRow: bgra ? plane.bytesPerRow : image.width)));
      box = objects.firstOrNull?.boundingBox;
    } catch (_) {
      // An unavailable model or malformed frame must never disable capture.
    } finally {
      _busy = false;
    }
    if (_closed) return null;
    _misses = box == null ? _misses + 1 : 0;
    return rules.evaluate(
        box: box, frame: size, brightness: brightness, misses: _misses);
  }
}

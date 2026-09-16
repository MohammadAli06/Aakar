import 'dart:async';
import 'package:camera/camera.dart';
import 'package:craft_connect/features/capture/product_capture_guidance.dart';
import 'package:craft_connect/features/capture/product_frame_analyzer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('google_mlkit_object_detector');
  late CameraController camera;
  late ProductFrameAnalyzer analyzer;
  late List<MethodCall> calls;

  // Legacy constructor allows a platform frame fixture without a real camera.
  // ignore: deprecated_member_use
  CameraImage frame() => CameraImage.fromPlatformData({
        'width': 4,
        'height': 2,
        'format': 35,
        'planes': [
          {
            'bytes': Uint8List.fromList(
                [100, 100, 100, 100, 255, 255, 100, 100, 100, 100, 255, 255]),
            'bytesPerRow': 6,
            'bytesPerPixel': 1
          },
          {
            'bytes': Uint8List.fromList([10, 255, 20, 255]),
            'bytesPerRow': 4,
            'bytesPerPixel': 2
          },
          {
            'bytes': Uint8List.fromList([30, 255, 40, 255]),
            'bytesPerRow': 4,
            'bytesPerPixel': 2
          },
        ]
      });

  setUp(() {
    calls = [];
    camera = CameraController(
        const CameraDescription(
            name: 'test',
            lensDirection: CameraLensDirection.back,
            sensorOrientation: 90),
        ResolutionPreset.high);
    analyzer = ProductFrameAnalyzer();
  });
  tearDown(() async {
    await analyzer.close();
    await camera.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('packs padded YUV and throttles without queuing concurrent frames',
      () async {
    final pending = Completer<List<dynamic>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'vision#startObjectDetector') return pending.future;
      return null;
    });
    final first = analyzer.analyze(frame(), camera);
    await Future<void>.delayed(Duration.zero);
    expect(await analyzer.analyze(frame(), camera), isNull);
    expect(calls, hasLength(1));
    final args = calls.first.arguments as Map;
    expect(args['options'], containsPair('classify', false));
    expect(args['options'], containsPair('multiple', false));
    expect(args['options'], containsPair('mode', 0));
    expect(args['imageData']['bytes'],
        [100, 100, 100, 100, 100, 100, 100, 100, 30, 10, 40, 20]);
    expect(args['imageData']['metadata']['rotation'], 90);
    pending.complete([]);
    expect(await first, ProductCaptureHint.searching);
    expect(await analyzer.analyze(frame(), camera), isNull);
    await Future<void>.delayed(const Duration(milliseconds: 310));
    expect(
        await analyzer.analyze(frame(), camera), ProductCaptureHint.searching);
    expect(calls, hasLength(2));
  });

  test('native detector failure reaches manual guidance instead of throwing',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'vision#startObjectDetector') {
        throw PlatformException(code: 'model-unavailable');
      }
      return null;
    });
    for (var i = 0; i < 4; i++) {
      expect(await analyzer.analyze(frame(), camera),
          ProductCaptureHint.searching);
      await Future<void>.delayed(const Duration(milliseconds: 310));
    }
    expect(await analyzer.analyze(frame(), camera), ProductCaptureHint.manual);
  });
}

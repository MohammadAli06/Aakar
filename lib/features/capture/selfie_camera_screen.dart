import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../core/localization/app_strings.dart';

/// Full-screen in-app selfie camera with live face guidance.
///
/// A face is considered well framed when exactly one face is present, roughly
/// centred in the circle and a sensible size. The ring turns green and, once
/// that holds steady, the photo is captured automatically — the shutter button
/// stays available as a manual fallback.
///
/// Everything runs in-process (no device camera app), so returning from it can
/// never lose the image or restart the app.
class SelfieCameraScreen extends StatefulWidget {
  const SelfieCameraScreen({super.key});

  /// How long the face must stay well framed before the auto-capture fires.
  static const holdDuration = Duration(milliseconds: 700);

  @override
  State<SelfieCameraScreen> createState() => _SelfieCameraScreenState();
}

class _SelfieCameraScreenState extends State<SelfieCameraScreen>
    with WidgetsBindingObserver {
  static const _circleCenterY = 0.40;
  static const _circleRadiusFraction = 0.36;

  CameraController? _controller;
  FaceDetector? _detector;
  bool _initializing = true;
  bool _capturing = false;
  bool _aligned = false;
  bool _autoFired = false;
  bool _processing = false;
  bool _streaming = false;
  bool _detectionUnavailable = false;
  DateTime? _alignedSince;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableLandmarks: false,
        enableContours: false,
        enableClassification: false,
        enableTracking: false,
        minFaceSize: 0.2,
      ),
    );
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      if (_streaming) {
        controller.stopImageStream().catchError((_) {});
      }
      controller.dispose();
    }
    _detector?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller = null;
      if (_streaming) {
        _streaming = false;
        controller.stopImageStream().catchError((_) {});
      }
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _start();
    }
  }

  Future<CameraController?> _createController(
      CameraDescription camera, ImageFormatGroup? format) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: format ?? ImageFormatGroup.unknown,
    );
    try {
      await controller.initialize();
      return controller;
    } catch (_) {
      await controller.dispose();
      return null;
    }
  }

  Future<void> _start() async {
    if (mounted) setState(() => _initializing = true);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera is available on this device.');
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // nv21 feeds ML Kit directly. If this device rejects that format, fall
      // back to a plain preview so a selfie can still be taken manually.
      var controller = await _createController(front, ImageFormatGroup.nv21);
      var detection = true;
      if (controller == null) {
        controller = await _createController(front, null);
        detection = false;
      }
      if (controller == null) {
        throw StateError('Could not start the camera.');
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
        _error = null;
        _aligned = false;
        _autoFired = false;
        _alignedSince = null;
        _detectionUnavailable = !detection;
      });

      if (!detection) {
        _streaming = false;
        return;
      }
      try {
        await controller.startImageStream(_onFrame);
        _streaming = true;
      } catch (_) {
        _streaming = false;
        if (mounted) setState(() => _detectionUnavailable = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _initializing = false;
        });
      }
    }
  }

  InputImageRotation _rotationFor(int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    final detector = _detector;
    final controller = _controller;
    if (detector == null ||
        controller == null ||
        _processing ||
        _capturing ||
        !controller.value.isInitialized) {
      return;
    }
    _processing = true;
    try {
      final rotation = _rotationFor(controller.description.sensorOrientation);
      final input = InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
      final faces = await detector.processImage(input);
      if (!mounted) return;
      _evaluate(faces, image, rotation);
    } catch (_) {
      // Skip malformed frames rather than tearing down the preview.
    } finally {
      _processing = false;
    }
  }

  void _evaluate(List<Face> faces, CameraImage image, InputImageRotation rotation) {
    final rotated = rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    final width = (rotated ? image.height : image.width).toDouble();
    final height = (rotated ? image.width : image.height).toDouble();

    var aligned = false;
    if (faces.length == 1 && width > 0 && height > 0) {
      final box = faces.first.boundingBox;
      final cx = box.center.dx / width;
      final cy = box.center.dy / height;
      final faceWidth = box.width / width;
      aligned = (cx - 0.5).abs() <= 0.16 &&
          (cy - _circleCenterY).abs() <= 0.20 &&
          faceWidth >= 0.28 &&
          faceWidth <= 0.80;
    }

    if (aligned) {
      _alignedSince ??= DateTime.now();
    } else {
      _alignedSince = null;
      _autoFired = false;
    }

    final shouldAutoCapture = aligned &&
        !_autoFired &&
        _alignedSince != null &&
        DateTime.now().difference(_alignedSince!) >= SelfieCameraScreen.holdDuration;

    if (aligned != _aligned && mounted) {
      setState(() => _aligned = aligned);
    }

    if (shouldAutoCapture) {
      _autoFired = true;
      _capture();
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing || !controller.value.isInitialized) {
      return;
    }
    setState(() => _capturing = true);
    try {
      if (_streaming) {
        _streaming = false;
        await controller.stopImageStream();
      }
      final file = await controller.takePicture();
      if (mounted) Navigator.of(context).pop(file.path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _capturing = false;
          _error = e.toString();
        });
      }
    }
  }

  String get _hint {
    if (_capturing) return context.tr('Capturing…');
    if (_detectionUnavailable) return context.tr('Tap to take your photo');
    if (_aligned) return context.tr('Hold still…');
    return context.tr('Center your face in the circle');
  }

  Color get _ringColor {
    if (_capturing) return const Color(0xFF4A7C2E);
    if (_detectionUnavailable) return Colors.white70;
    return _aligned ? const Color(0xFF4CAF50) : Colors.white70;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _preview(),
            if (_error == null)
              IgnorePointer(
                child: CustomPaint(
                  painter: _CircleMaskPainter(
                    centerY: _circleCenterY,
                    radiusFraction: _circleRadiusFraction,
                    ringColor: _ringColor,
                    ringWidth: _aligned ? 7 : 4,
                  ),
                ),
              ),
            _topBar(),
            if (_error == null) _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_outlined,
                color: Colors.white54, size: 44),
            const SizedBox(height: 16),
            Text(
              context.tr(
                  'Camera unavailable. Check camera permission and try again.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: _start,
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38)),
              child: Text(context.tr('Try again')),
            ),
          ],
        ),
      );
    }

    final controller = _controller;
    if (_initializing ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    // CameraPreview already rotates itself for the sensor/device orientation and
    // keeps its own aspect ratio. Rotating it here would rotate it twice, and
    // laying it out under tight constraints would stretch it.
    Widget preview = CameraPreview(controller);
    final isFront =
        controller.description.lensDirection == CameraLensDirection.front;
    if (isFront) {
      preview = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
        child: preview,
      );
    }
    // Center loosens the constraints so the preview keeps its aspect ratio
    // instead of being stretched to fill the screen.
    return Center(child: preview);
  }

  Widget _topBar() {
    return Positioned(
      top: 8,
      left: 8,
      right: 8,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: _aligned ? const Color(0xFF8CE99A) : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            child: Text(_hint),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: (_initializing || _capturing || _error != null)
                ? null
                : _capture,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white24,
                border: Border.all(
                    color: _aligned ? const Color(0xFF4CAF50) : Colors.white,
                    width: 4),
              ),
              child: _capturing
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3),
                    )
                  : const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleMaskPainter extends CustomPainter {
  final double centerY;
  final double radiusFraction;
  final Color ringColor;
  final double ringWidth;

  const _CircleMaskPainter({
    required this.centerY,
    required this.radiusFraction,
    required this.ringColor,
    required this.ringWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * centerY);
    final radius = size.width * radiusFraction;

    final overlay = Path()..addRect(Offset.zero & size);
    final hole = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(
      Path.combine(PathOperation.difference, overlay, hole),
      Paint()..color = Colors.black.withOpacity(0.62),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..color = ringColor,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleMaskPainter old) =>
      old.ringColor != ringColor ||
      old.ringWidth != ringWidth ||
      old.centerY != centerY ||
      old.radiusFraction != radiusFraction;
}

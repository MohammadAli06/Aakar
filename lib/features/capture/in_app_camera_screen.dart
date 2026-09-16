import 'dart:async';
import 'dart:io';
import '../commerce/presentation/craft_forms.dart';
import '../commerce/presentation/craft_widgets.dart';
import 'product_capture_guidance.dart';
import 'product_frame_analyzer.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';

/// Full-screen in-app camera for product photos.
///
/// Everything happens inside the app process: no intent to the device camera
/// app, so the Flutter activity is never backgrounded and destroyed. Pops with
/// the captured file path, or null when cancelled.
class InAppCameraScreen extends StatefulWidget {
  const InAppCameraScreen({super.key});

  @override
  State<InAppCameraScreen> createState() => _InAppCameraScreenState();
}

class _InAppCameraScreenState extends State<InAppCameraScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  int _index = 0;
  bool _initializing = true;
  bool _capturing = false;
  bool _torch = false;
  String? _error;
  ProductFrameAnalyzer? _analyzer;
  int _generation = 0;
  Future<void> _releasing = Future.value();
  bool _active = true, _voice = true;
  Timer? _speechTimer;
  ProductCaptureHint _hint = ProductCaptureHint.searching;
  ProductCaptureHint? _spoken;

  void _setHint(ProductCaptureHint hint) {
    if (!mounted) return;
    if (_hint != hint) {
      setState(() => _hint = hint);
      _speechTimer?.cancel();
    }
    if (!_voice || _spoken == hint || _speechTimer?.isActive == true) return;
    _speechTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted || !_active || _capturing) return;
      _spoken = hint;
      speakCraft(context, bilingual(context, hint.en, hint.hi), silent: true);
    });
  }

  Future<void> _release(
      CameraController? controller, ProductFrameAnalyzer? analyzer) async {
    _speechTimer?.cancel();
    await stopCraftSpeech();
    if (controller != null) {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {}
      await controller.dispose();
    }
    await analyzer?.close();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _active = false;
    _generation++;
    _releasing = _release(_controller, _analyzer);
    _controller = null;
    _analyzer = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _active = true;
      _start();
    } else if (state == AppLifecycleState.inactive) {
      _active = false;
      _generation++;
      _releasing = _release(_controller, _analyzer);
      _controller = null;
      _analyzer = null;
    }
  }

  Future<void> _start() async {
    final generation = ++_generation;
    final previous = _controller;
    final previousAnalyzer = _analyzer;
    _controller = null;
    _analyzer = null;
    if (mounted) setState(() => _initializing = true);
    await _releasing;
    await _release(previous, previousAnalyzer);
    if (!mounted || !_active || generation != _generation) return;
    try {
      final cameras = _cameras.isNotEmpty ? _cameras : await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera is available on this device.');
      }
      _cameras = cameras;
      var controller = CameraController(
        cameras[_index % cameras.length],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup:
            Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
      );
      try {
        await controller.initialize();
      } catch (_) {
        await controller.dispose();
        // A device that rejects the analysis format can still take photos.
        controller = CameraController(
            cameras[_index % cameras.length], ResolutionPreset.high,
            enableAudio: false);
        try {
          await controller.initialize();
        } catch (_) {
          await controller.dispose();
          rethrow;
        }
      }
      if (_torch) {
        try {
          await controller.setFlashMode(FlashMode.torch);
        } catch (_) {
          _torch = false;
        }
      }
      if (!mounted || !_active || generation != _generation) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
        _error = null;
        _hint = ProductCaptureHint.searching;
        _spoken = null;
      });
      final analyzer = ProductFrameAnalyzer();
      _analyzer = analyzer;
      try {
        await controller.startImageStream((image) async {
          if (_capturing || !_active || generation != _generation) return;
          final hint = await analyzer.analyze(image, controller);
          if (mounted &&
              _active &&
              !_capturing &&
              generation == _generation &&
              hint != null) {
            _setHint(hint);
          }
        });
      } catch (_) {
        if (generation == _generation) _setHint(ProductCaptureHint.manual);
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = e.toString();
          _initializing = false;
        });
      }
    }
  }

  Future<void> _flip() async {
    if (_cameras.length < 2) return;
    _index = (_index + 1) % _cameras.length;
    await _start();
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.setFlashMode(_torch ? FlashMode.off : FlashMode.torch);
      setState(() => _torch = !_torch);
    } catch (_) {
      // Torch is not available on every camera; ignore.
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    setState(() => _capturing = true);
    _speechTimer?.cancel();
    await stopCraftSpeech();
    try {
      if (controller.value.isStreamingImages) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _preview(),
            if (!_initializing && _error == null) ...[
              IgnorePointer(
                  child: LayoutBuilder(builder: (context, constraints) {
                final side = (constraints.maxWidth * .75)
                    .clamp(0.0, constraints.maxHeight * .55);
                return Center(
                    child: CustomPaint(
                        painter: _FramePainter(_hint == ProductCaptureHint.ready
                            ? Colors.greenAccent
                            : Colors.white),
                        child: SizedBox.square(dimension: side)));
              })),
              Positioned(
                  bottom: 118,
                  left: 20,
                  right: 20,
                  child: IgnorePointer(
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(bilingual(context, _hint.en, _hint.hi),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14))))),
            ],
            _topBar(),
            _bottomBar(),
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
          const Spacer(),
          IconButton(
              tooltip:
                  bilingual(context, 'Voice guidance', 'आवाज़ से मार्गदर्शन'),
              onPressed: () {
                setState(() => _voice = !_voice);
                if (!_voice) {
                  _speechTimer?.cancel();
                  stopCraftSpeech();
                } else {
                  _spoken = null;
                  _setHint(_hint);
                }
              },
              icon: Icon(_voice ? Icons.volume_up : Icons.volume_off,
                  color: Colors.white)),
          if (_cameras.length > 1)
            IconButton(
              tooltip: context.tr('Switch camera'),
              onPressed: _initializing || _capturing ? null : _flip,
              icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
            ),
          IconButton(
            tooltip: context.tr('Flash'),
            onPressed: _initializing || _capturing ? null : _toggleTorch,
            icon: Icon(
              _torch ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Positioned(
      bottom: 28,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap:
              (_initializing || _capturing || _error != null) ? null : _capture,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white24,
              border: Border.all(color: Colors.white, width: 4),
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
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    const corner = 34.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(0, corner)
      ..lineTo(0, 0)
      ..lineTo(corner, 0)
      ..moveTo(size.width - corner, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, corner)
      ..moveTo(size.width, size.height - corner)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width - corner, size.height)
      ..moveTo(corner, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, size.height - corner);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FramePainter oldDelegate) =>
      oldDelegate.color != color;
}

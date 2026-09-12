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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller = null;
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _start();
    }
  }

  Future<void> _start() async {
    if (mounted) setState(() => _initializing = true);
    try {
      final cameras =
          _cameras.isNotEmpty ? _cameras : await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera is available on this device.');
      }
      _cameras = cameras;
      final controller = CameraController(
        cameras[_index % cameras.length],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (_torch) {
        await controller.setFlashMode(FlashMode.torch);
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
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
    final previous = _controller;
    _controller = null;
    setState(() => _initializing = true);
    await previous?.dispose();
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
    try {
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
            // Guide frame + hint
            IgnorePointer(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      painter: _FramePainter(),
                      child: const SizedBox(width: 300, height: 300),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        context.tr('Place the product inside the frame'),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
    if (_initializing || controller == null || !controller.value.isInitialized) {
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
          if (_cameras.length > 1)
            IconButton(
              tooltip: context.tr('Switch camera'),
              onPressed: _initializing ? null : _flip,
              icon: const Icon(Icons.cameraswitch_rounded,
                  color: Colors.white),
            ),
          IconButton(
            tooltip: context.tr('Flash'),
            onPressed: _initializing ? null : _toggleTorch,
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
          onTap: (_initializing || _capturing || _error != null)
              ? null
              : _capture,
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
                    child:
                        CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
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
  @override
  void paint(Canvas canvas, Size size) {
    const corner = 34.0;
    final paint = Paint()
      ..color = Colors.white
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

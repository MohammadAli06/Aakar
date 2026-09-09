import '../../core/localization/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/glass_card.dart';

class PhotoCaptureScreen extends StatefulWidget {
  const PhotoCaptureScreen({super.key});

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  bool _capturing = false;
  late AnimationController _scanController;

  // Live guidance tips
  static const _tips = [
    {
      'icon': '☀️',
      'hi': 'अच्छी रोशनी में फोटो लें',
      'en': 'Take in good lighting'
    },
    {'icon': '📐', 'hi': 'उत्पाद को बीच में रखें', 'en': 'Center the product'},
    {'icon': '🔍', 'hi': 'क्लियर फोकस रखें', 'en': 'Keep it in focus'},
    {'icon': '📏', 'hi': '30-50 cm दूरी से', 'en': '30-50 cm distance'},
  ];

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _captureImage(ImageSource source) async {
    setState(() => _capturing = true);
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (file != null && mounted) {
        context.push('/enhancement', extra: file.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText('${context.tr('Camera error')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
        title: const AppText('फोटो कैप्चर'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Camera frame mockup
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.glassBorder, width: 1.5),
                ),
                child: Stack(
                  children: [
                    // Grid overlay
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: CustomPaint(
                        painter: _GridPainter(),
                        size: const Size(double.infinity, 300),
                      ),
                    ),
                    // Corner brackets
                    ..._buildCornerBrackets(),
                    // Scan line animation
                    AnimatedBuilder(
                      animation: _scanController,
                      builder: (_, __) => Positioned(
                        top: 300 * _scanController.value - 2,
                        left: 24,
                        right: 24,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.primary,
                                Colors.transparent
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.primary.withOpacity(0.5),
                                  blurRadius: 6),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Center placeholder text
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined,
                              size: 48,
                              color: AppColors.primary.withOpacity(0.5)),
                          const SizedBox(height: 8),
                          const AppText(
                            'यहाँ उत्पाद दिखेगा',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Tips
              const AppText(
                '📋 बेहतर फोटो के लिए',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.8,
                children: _tips
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Row(
                            children: [
                              AppText(t['icon']!,
                                  style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AppText(t['hi']!,
                                        style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),
              // Action buttons
              GestureDetector(
                onTap:
                    _capturing ? null : () => _captureImage(ImageSource.camera),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary]),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: Center(
                    child: _capturing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_rounded,
                                  color: Colors.white, size: 22),
                              SizedBox(width: 10),
                              AppText('कैमरा खोलें  •  Open Camera',
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _capturing
                    ? null
                    : () => _captureImage(ImageSource.gallery),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                      color: AppColors.glassBorder, width: 1.5),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library_rounded,
                        color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    AppText('गैलरी से चुनें  •  Choose from Gallery',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCornerBrackets() {
    const size = 28.0;
    const thickness = 3.0;
    const color = AppColors.primary;
    return [
      // Top-left
      Positioned(
          top: 16,
          left: 16,
          child: _Corner(
              size: size,
              thickness: thickness,
              color: color,
              isTop: true,
              isLeft: true)),
      // Top-right
      Positioned(
          top: 16,
          right: 16,
          child: _Corner(
              size: size,
              thickness: thickness,
              color: color,
              isTop: true,
              isLeft: false)),
      // Bottom-left
      Positioned(
          bottom: 16,
          left: 16,
          child: _Corner(
              size: size,
              thickness: thickness,
              color: color,
              isTop: false,
              isLeft: true)),
      // Bottom-right
      Positioned(
          bottom: 16,
          right: 16,
          child: _Corner(
              size: size,
              thickness: thickness,
              color: color,
              isTop: false,
              isLeft: false)),
    ];
  }
}

class _Corner extends StatelessWidget {
  final double size;
  final double thickness;
  final Color color;
  final bool isTop;
  final bool isLeft;
  const _Corner(
      {required this.size,
      required this.thickness,
      required this.color,
      required this.isTop,
      required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
            color: color, thickness: thickness, isTop: isTop, isLeft: isLeft),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool isTop;
  final bool isLeft;

  const _CornerPainter(
      {required this.color,
      required this.thickness,
      required this.isTop,
      required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final double s = size.width;
    if (isTop && isLeft) {
      canvas.drawLine(const Offset(0, 0), Offset(s, 0), paint);
      canvas.drawLine(const Offset(0, 0), Offset(0, s), paint);
    } else if (isTop && !isLeft) {
      canvas.drawLine(Offset(0, 0), Offset(s, 0), paint);
      canvas.drawLine(Offset(s, 0), Offset(s, s), paint);
    } else if (!isTop && isLeft) {
      canvas.drawLine(Offset(0, 0), Offset(0, s), paint);
      canvas.drawLine(Offset(0, s), Offset(s, s), paint);
    } else {
      canvas.drawLine(Offset(s, 0), Offset(s, s), paint);
      canvas.drawLine(Offset(0, s), Offset(s, s), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.glassBorder.withOpacity(0.3)
      ..strokeWidth = 0.5;
    canvas.drawLine(
        Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0),
        Offset(size.width * 2 / 3, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3),
        Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

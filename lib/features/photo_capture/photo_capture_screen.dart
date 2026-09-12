import '../../core/localization/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../capture/capture_flow.dart';

class PhotoCaptureScreen extends StatefulWidget {
  const PhotoCaptureScreen({super.key});

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> {
  final _picker = ImagePicker();
  bool _capturing = false;

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

  Future<void> _captureImage(ImageSource source) async {
    setState(() => _capturing = true);
    try {
      // The camera opens inside the app — launching the device camera app can
      // destroy the Flutter activity and lose the photo.
      final String? path = source == ImageSource.camera
          ? await captureProductPhoto(context)
          : (await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 90,
                  maxWidth: 1920,
                  maxHeight: 1920))
              ?.path;
      if (path != null && mounted) {
        context.push('/enhancement', extra: path);
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
              // Capture itself happens in the full-screen in-app camera.
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.glassBorder, width: 1.5),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.camera_alt_outlined,
                        size: 48, color: AppColors.primary),
                    SizedBox(height: 12),
                    AppText(
                      'कैमरा इस ऐप के अंदर ही खुलेगा',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    AppText(
                      'The camera opens inside the app',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textHint,
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
}

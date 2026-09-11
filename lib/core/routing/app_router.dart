import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/onboarding/language_selection_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/profile/profile_setup_screen.dart';
import '../../features/photo_capture/photo_capture_screen.dart';
import '../../features/photo_capture/enhancement_screen.dart';
import '../../features/cataloging/voice_catalog_screen.dart';
import '../../features/cataloging/listing_preview_screen.dart';
import '../../features/pricing/pricing_screen.dart';
import '../../features/b2b/b2b_screen.dart';
import '../../features/commerce/presentation/commerce_screen.dart';
import '../../features/commerce/presentation/product_studio_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/language',
        name: 'language',
        builder: (context, state) => const LanguageSelectionScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
        routes: [
          GoRoute(
            path: 'otp',
            name: 'otp',
            builder: (context, state) {
              final phone = state.extra as String? ?? '';
              return OtpScreen(phoneNumber: phone);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/profile-setup',
        name: 'profileSetup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const CommerceScreen(),
      ),
      GoRoute(
          path: '/workspace/create',
          builder: (context, state) => const ProductStudioScreen()),
      GoRoute(
          path: '/workspace/create/:id',
          builder: (context, state) =>
              ProductStudioScreen(productId: state.pathParameters['id'])),
      GoRoute(
          path: '/workspace/:page',
          builder: (context, state) =>
              CommerceScreen(page: state.pathParameters['page']!)),
      GoRoute(
          path: '/workspace/:page/:id',
          builder: (context, state) => CommerceScreen(
              page: state.pathParameters['page']!,
              id: state.pathParameters['id'])),
      GoRoute(
        path: '/photo-capture',
        name: 'photoCapture',
        builder: (context, state) => const PhotoCaptureScreen(),
      ),
      GoRoute(
        path: '/enhancement',
        name: 'enhancement',
        builder: (context, state) {
          final imagePath = state.extra as String? ?? '';
          return EnhancementScreen(imagePath: imagePath);
        },
      ),
      GoRoute(
        path: '/cataloging',
        name: 'cataloging',
        builder: (context, state) {
          final productId = state.extra as String? ?? '';
          return VoiceCatalogScreen(productId: productId);
        },
      ),
      GoRoute(
        path: '/listing-preview',
        name: 'listingPreview',
        builder: (context, state) {
          final productId = state.extra as String? ?? '';
          return ListingPreviewScreen(productId: productId);
        },
      ),
      GoRoute(
        path: '/pricing',
        name: 'pricing',
        builder: (context, state) {
          final productId = state.extra as String? ?? '';
          return PricingScreen(productId: productId);
        },
      ),
      GoRoute(
        path: '/b2b',
        name: 'b2b',
        builder: (context, state) {
          final productId = state.extra as String? ?? '';
          return B2BScreen(productId: productId);
        },
      ),
    ],
  );
});

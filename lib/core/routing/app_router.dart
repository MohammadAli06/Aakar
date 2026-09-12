import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/artisan_auth_screen.dart';
import '../../features/auth/buyer_auth_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/role_select_screen.dart';
import '../../features/auth/phone_sign_in_screen.dart';
import '../../features/profile/account_home_screen.dart';
import '../../features/profile/account_verification_screen.dart';
import '../../features/b2b/b2b_screen.dart';
import '../../features/cataloging/listing_preview_screen.dart';
import '../../features/cataloging/voice_catalog_screen.dart';
import '../../features/commerce/presentation/commerce_screen.dart';
import '../../features/commerce/presentation/product_studio_screen.dart';
import '../../features/onboarding/language_selection_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/photo_capture/enhancement_screen.dart';
import '../../features/photo_capture/photo_capture_screen.dart';
import '../../features/pricing/pricing_screen.dart';
import '../../features/profile/profile_setup_screen.dart';
import '../services/app_providers.dart';
import '../services/session_controller.dart';

/// Reachable without a completed signup.
const _publicRoutes = {
  '/auth',
  '/splash',
  '/language',
  '/onboarding',
  '/role',
  '/auth/artisan',
  '/auth/otp',
  '/auth/buyer',
};

/// The signup/entry flow. A signed-in account is sent away from these, but
/// `/language` stays reachable because it is also an in-app setting.
const _signupFlowRoutes = {
  '/auth',
  '/splash',
  '/onboarding',
  '/role',
  '/auth/artisan',
  '/auth/otp',
  '/auth/buyer',
};

const _homeRoute = '/dashboard';

final appRouterProvider = Provider<GoRouter>((ref) {
  // The session instance is stable for the app's lifetime and drives the guard
  // through `refreshListenable`.
  final session = ref.read(sessionProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    refreshListenable: session,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final status = session.status;

      // Session still resolving — hold at the splash screen.
      if (status == SessionStatus.loading) {
        return location == '/splash' ? null : '/splash';
      }

      // No usable session: only the public entry routes are reachable.
      // `unavailable` means the backend could not be reached, so the account
      // cannot be trusted yet — it must not be treated as signed in.
      if (status == SessionStatus.signedOut) {
        if (location == '/role' ||
            location == '/auth/artisan' ||
            location == '/auth/buyer') {
          return '/auth';
        }
        if (location == '/auth/otp' &&
            (state.extra is! String || (state.extra as String).isEmpty))
          return '/auth';
        return _publicRoutes.contains(location) ? null : '/auth';
      }
      if (status == SessionStatus.unavailable) {
        return location == '/account-error' ? null : '/account-error';
      }

      // Signed in with Firebase but signup was never completed on the backend.
      if (status == SessionStatus.unregistered) {
        return location == '/role' ? null : '/role';
      }

      // Signed in: leave the signup flow, and finish the profile first.
      if (_signupFlowRoutes.contains(location)) {
        return session.profileComplete ? _homeRoute : '/profile-setup';
      }
      if (!session.profileComplete && location != '/profile-setup') {
        return '/profile-setup';
      }
      if (session.profileComplete && location == '/profile-setup') {
        return '/verification';
      }
      if (location == '/account-error') return _homeRoute;
      // Legacy API screens are not part of the supported commerce workspace.
      if ({
        '/photo-capture',
        '/enhancement',
        '/cataloging',
        '/listing-preview',
        '/pricing',
        '/b2b'
      }.contains(location)) {
        return '/account';
      }
      return null;
    },
    routes: [
      GoRoute(
          path: '/auth',
          builder: (context, state) => const PhoneSignInScreen()),
      GoRoute(
          path: '/account-error',
          builder: (context, state) => const AccountHomeScreen()),
      GoRoute(
          path: '/account',
          builder: (context, state) => const AccountHomeScreen()),
      GoRoute(
          path: '/verification',
          builder: (context, state) => const AccountVerificationScreen()),
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
        path: '/role',
        name: 'role',
        builder: (context, state) => const RoleSelectScreen(),
      ),
      GoRoute(
        path: '/auth/artisan',
        name: 'artisanAuth',
        builder: (context, state) => const ArtisanAuthScreen(),
      ),
      GoRoute(
        path: '/auth/buyer',
        name: 'buyerAuth',
        builder: (context, state) => const BuyerAuthScreen(),
      ),
      GoRoute(
        path: '/auth/otp',
        name: 'otp',
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          return OtpScreen(phoneNumber: phone);
        },
      ),
      GoRoute(
        path: '/profile-setup',
        name: 'profileSetup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        name: 'profileEdit',
        builder: (context, state) => const ProfileSetupScreen(editing: true),
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

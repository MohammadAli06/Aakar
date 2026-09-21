import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Set by Profile → "App guide" to replay the tour on the next Home build.
/// Consumed once, and it never touches the stored "seen" flag, so first-run
/// behaviour for a new account is unchanged.
final appTourReplayProvider = StateProvider<bool>((ref) => false);

/// The caption shown for one tour target.
class TourCopy {
  final String titleEn, titleHi, bodyEn, bodyHi;
  const TourCopy(this.titleEn, this.titleHi, this.bodyEn, this.bodyHi);
}

/// The first-run coach-mark tour.
///
/// Device-local on purpose: a tour is a UI affordance rather than an account
/// fact, so it needs no backend route and no schema.
class AppTour {
  static const _artisanKey = 'onboarding_seen_artisan';
  static const _buyerKey = 'onboarding_seen_buyer';

  /// Captions for every target, for both roles. Keeping one table (rather than
  /// one per role) means a wrapper always has text even when the step is not
  /// part of this role's tour, which `Showcase` asserts on.
  static const Map<String, TourCopy> copy = {
    'home': TourCopy(
        'Home',
        'होम',
        'Search, shortcuts and your activity all start here.',
        'यहाँ से खोजें, शॉर्टकट और अपनी गतिविधि देखें।'),
    'add_product': TourCopy(
        'Add a product',
        'उत्पाद जोड़ें',
        'Add a product with just a photo and your voice — the AI fills the rest.',
        'सिर्फ़ फ़ोटो और आवाज़ से उत्पाद जोड़ें — बाकी AI भरेगा।'),
    'products': TourCopy(
        'Products',
        'उत्पाद',
        'Manage, edit and publish your listings.',
        'अपने उत्पाद संभालें, बदलें और प्रकाशित करें।'),
    'discover': TourCopy(
        'Discover',
        'खोजें',
        'Browse and compare verified artisan products.',
        'सत्यापित कारीगरों के उत्पाद देखें और तुलना करें।'),
    'inquiries': TourCopy(
        'Inquiries',
        'पूछताछ',
        'Your conversations and price quotations with artisans live here.',
        'कारीगरों से बातचीत और भाव यहाँ मिलेंगे।'),
    'bidding': TourCopy(
        'Bidding',
        'बोली',
        'Join a sealed-bid session to get bulk prices.',
        'थोक भाव के लिए बोली सत्र में शामिल हों।'),
    'orders': TourCopy(
        'Orders',
        'ऑर्डर',
        'Track every order from confirmation to delivery.',
        'पुष्टि से डिलीवरी तक हर ऑर्डर देखें।'),
  };

  /// The stops for each role, in visit order. Both tours are five taps long and
  /// follow the role's own bottom bar. The buyer has no Requirements
  /// destination, so requirement posting is introduced on the Home stop.
  static const Map<bool, List<String>> _targets = {
    true: ['home', 'discover', 'inquiries', 'bidding', 'orders'],
    false: ['home', 'add_product', 'products', 'bidding', 'orders'],
  };

  static List<String> targets({required bool buyer}) =>
      _targets[buyer] ?? const [];

  static String storageKey({required bool buyer}) =>
      buyer ? _buyerKey : _artisanKey;

  /// Whether the tour has already been shown for this role.
  ///
  /// A storage failure counts as "shown" so a broken preference store can never
  /// block a working screen with a tour that cannot be recorded.
  static Future<bool> seen({required bool buyer}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(storageKey(buyer: buyer)) ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> markSeen({required bool buyer}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(storageKey(buyer: buyer), true);
    } catch (_) {
      // Unrecordable, so the tour is simply offered again next time.
    }
  }
}

/// Core data models for Aakar

enum VerificationStatus { aiGenerated, artisanReviewed, approved, rejected }

enum CraftCategory {
  pottery,
  weaving,
  embroidery,
  woodcraft,
  metalcraft,
  painting,
  leathercraft,
  jewelry,
  other
}

class ArtisanProfile {
  final String id;
  final String name;
  final String phone;
  final String languagePref;
  final String state;
  final String district;
  final CraftCategory craftCategory;
  final String? profileImageUrl;

  const ArtisanProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.languagePref,
    required this.state,
    required this.district,
    required this.craftCategory,
    this.profileImageUrl,
  });

  factory ArtisanProfile.fromJson(Map<String, dynamic> json) => ArtisanProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        languagePref: json['language_pref'] as String? ?? 'hi',
        state: json['state'] as String? ?? '',
        district: json['district'] as String? ?? '',
        craftCategory: CraftCategory.values.firstWhere(
          (e) => e.name == json['craft_category'],
          orElse: () => CraftCategory.other,
        ),
        profileImageUrl: json['profile_image_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'language_pref': languagePref,
        'state': state,
        'district': district,
        'craft_category': craftCategory.name,
        'profile_image_url': profileImageUrl,
      };
}

class Product {
  final String id;
  final String artisanId;
  final CraftCategory category;
  final ProductStatus status;
  final DateTime createdAt;
  final ProductImage? image;
  final ProductListing? listing;
  final PriceRecommendation? priceRecommendation;
  final B2BReadiness? b2bReadiness;

  const Product({
    required this.id,
    required this.artisanId,
    required this.category,
    required this.status,
    required this.createdAt,
    this.image,
    this.listing,
    this.priceRecommendation,
    this.b2bReadiness,
  });
}

enum ProductStatus { draft, aiGenerated, verified, published }

class ProductImage {
  final String id;
  final String productId;
  final String originalUrl;
  final String? enhancedUrl;
  final VerificationStatus verificationStatus;

  const ProductImage({
    required this.id,
    required this.productId,
    required this.originalUrl,
    this.enhancedUrl,
    required this.verificationStatus,
  });
}

class AttributeField {
  final String key;
  final String labelEn;
  final String labelHi;
  final String? value;
  final double confidence; // 0.0 to 1.0
  final bool isRequired;

  const AttributeField({
    required this.key,
    required this.labelEn,
    required this.labelHi,
    this.value,
    required this.confidence,
    required this.isRequired,
  });

  AttributeField copyWith({String? value, double? confidence}) => AttributeField(
        key: key,
        labelEn: labelEn,
        labelHi: labelHi,
        value: value ?? this.value,
        confidence: confidence ?? this.confidence,
        isRequired: isRequired,
      );
}

class ProductListing {
  final String id;
  final String productId;
  final String titleEn;
  final String titleHi;
  final String descEn;
  final String descHi;
  final List<AttributeField> attributes;
  final List<String> tags;
  final VerificationStatus verificationStatus;

  const ProductListing({
    required this.id,
    required this.productId,
    required this.titleEn,
    required this.titleHi,
    required this.descEn,
    required this.descHi,
    required this.attributes,
    required this.tags,
    required this.verificationStatus,
  });
}

class MarketComparable {
  final String name;
  final double price;
  final String source;
  final String? imageUrl;

  const MarketComparable({
    required this.name,
    required this.price,
    required this.source,
    this.imageUrl,
  });
}

class PriceRecommendation {
  final String id;
  final String productId;
  final double materialCost;
  final double labourCost;
  final double overhead;
  final double craftsmanshipScore;
  final double recommendedMin;
  final double recommendedMax;
  final double? finalPrice;
  final String explanationText;
  final String explanationTextHi;
  final List<MarketComparable> comparables;
  final VerificationStatus verificationStatus;

  const PriceRecommendation({
    required this.id,
    required this.productId,
    required this.materialCost,
    required this.labourCost,
    required this.overhead,
    required this.craftsmanshipScore,
    required this.recommendedMin,
    required this.recommendedMax,
    this.finalPrice,
    required this.explanationText,
    required this.explanationTextHi,
    required this.comparables,
    required this.verificationStatus,
  });

  double get costFloor => materialCost + labourCost + overhead;
}

class B2BChannel {
  final String id;
  final String name;
  final String description;
  final String logoUrl;
  final List<String> requiredFields;

  const B2BChannel({
    required this.id,
    required this.name,
    required this.description,
    required this.logoUrl,
    required this.requiredFields,
  });
}

class B2BReadiness {
  final String id;
  final String productId;
  final String channelId;
  final List<String> missingFields;
  final double readinessScore; // 0.0 to 1.0
  final B2BStatus status;

  const B2BReadiness({
    required this.id,
    required this.productId,
    required this.channelId,
    required this.missingFields,
    required this.readinessScore,
    required this.status,
  });
}

enum B2BStatus { notStarted, inProgress, ready }

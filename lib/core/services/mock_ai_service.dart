import 'dart:math';
import '../../shared/models/models.dart';

/// Mock AI Service — simulates realistic AI backend responses.
/// Drop-in: replace each method with real Dio API calls against FastAPI.
class MockAIService {
  static final _random = Random();

  // Simulate network delay
  static Future<T> _delay<T>(T value, [int ms = 1500]) async {
    await Future.delayed(Duration(milliseconds: ms + _random.nextInt(500)));
    return value;
  }

  /// Simulate image enhancement: returns mock before/after URLs.
  static Future<Map<String, String>> enhanceImage(String localImagePath) async {
    await Future.delayed(const Duration(seconds: 3));
    return {
      'original': localImagePath,
      'enhanced': localImagePath, // In production: returned from backend
      'background_removed': localImagePath,
    };
  }

  /// Simulate ASR: transcribe spoken description to text.
  static Future<String> transcribeVoice(String audioPath, String language) async {
    const sampleTranscripts = {
      'hi': 'यह एक हाथ से बना मिट्टी का मटका है। इसे राजस्थान की पारंपरिक कुम्हार कला से बनाया गया है। '
          'इसकी ऊंचाई लगभग 30 सेंटीमीटर है और इसे पानी रखने के लिए उपयोग किया जाता है।',
      'en': 'This is a handmade clay pot made using traditional Rajasthani pottery art. '
          'It is about 30 centimetres tall and is used for storing water.',
    };
    return _delay(sampleTranscripts[language] ?? sampleTranscripts['hi']!, 2000);
  }

  /// Simulate attribute extraction with confidence scores.
  static Future<List<AttributeField>> extractAttributes(
      String transcript, CraftCategory category) async {
    await Future.delayed(const Duration(seconds: 2));
    return [
      const AttributeField(
        key: 'product_type',
        labelEn: 'Product Type',
        labelHi: 'उत्पाद प्रकार',
        value: 'Clay Water Pot (Matka)',
        confidence: 0.97,
        isRequired: true,
      ),
      const AttributeField(
        key: 'material',
        labelEn: 'Material',
        labelHi: 'सामग्री',
        value: 'Terracotta Clay',
        confidence: 0.92,
        isRequired: true,
      ),
      const AttributeField(
        key: 'craft_technique',
        labelEn: 'Craft Technique',
        labelHi: 'शिल्प तकनीक',
        value: 'Wheel-thrown, hand-finished',
        confidence: 0.88,
        isRequired: true,
      ),
      const AttributeField(
        key: 'dimensions',
        labelEn: 'Dimensions',
        labelHi: 'आयाम',
        value: '30 cm height, 25 cm diameter',
        confidence: 0.82,
        isRequired: false,
      ),
      const AttributeField(
        key: 'color',
        labelEn: 'Colour',
        labelHi: 'रंग',
        value: 'Earthy terracotta brown',
        confidence: 0.90,
        isRequired: true,
      ),
      const AttributeField(
        key: 'use_case',
        labelEn: 'Use Case',
        labelHi: 'उपयोग',
        value: 'Water storage, home decor',
        confidence: 0.85,
        isRequired: false,
      ),
      const AttributeField(
        key: 'origin',
        labelEn: 'Origin / Region',
        labelHi: 'उत्पत्ति / क्षेत्र',
        value: null,
        confidence: 0.10, // Missing — will trigger follow-up
        isRequired: true,
      ),
      const AttributeField(
        key: 'weight',
        labelEn: 'Weight',
        labelHi: 'वज़न',
        value: null,
        confidence: 0.05, // Missing
        isRequired: false,
      ),
    ];
  }

  /// Simulate bilingual listing generation.
  static Future<ProductListing> generateListing(
    String productId,
    List<AttributeField> attributes,
    String artisanName,
  ) async {
    await Future.delayed(const Duration(seconds: 2));
    return ProductListing(
      id: 'listing_${DateTime.now().millisecondsSinceEpoch}',
      productId: productId,
      titleEn: 'Handcrafted Rajasthani Terracotta Matka — Traditional Clay Water Pot',
      titleHi: 'हस्तनिर्मित राजस्थानी टेराकोटा मटका — पारंपरिक मिट्टी का घड़ा',
      descEn:
          'A beautifully handcrafted terracotta matka made using the centuries-old wheel-throwing technique '
          'by skilled Rajasthani artisans. This traditional clay water pot naturally cools water and is '
          'an eco-friendly alternative to plastic. Each piece is unique, bearing the artisan\'s individual touch. '
          'Perfect for home décor and functional use. Supports local craft heritage.',
      descHi:
          'राजस्थान के कुशल कारीगरों द्वारा सदियों पुरानी चाक-निर्माण तकनीक से बनाया गया यह सुंदर '
          'टेराकोटा मटका पानी को प्राकृतिक रूप से ठंडा रखता है। यह प्लास्टिक का पर्यावरण-हितैषी विकल्प है। '
          'प्रत्येक टुकड़ा अनूठा है और कारीगर की व्यक्तिगत कलाकारी को दर्शाता है।',
      attributes: attributes,
      tags: [
        'handmade', 'terracotta', 'matka', 'rajasthani', 'pottery',
        'clay pot', 'eco-friendly', 'traditional craft', 'water pot', 'home decor'
      ],
      verificationStatus: VerificationStatus.aiGenerated,
    );
  }

  /// Simulate pricing engine.
  static Future<PriceRecommendation> generatePricing(
    String productId, {
    required double materialCost,
    required double labourHours,
    required double wagePerHour,
    required double overhead,
    required CraftCategory category,
  }) async {
    await Future.delayed(const Duration(seconds: 2));
    final labourCost = labourHours * wagePerHour;
    final costFloor = materialCost + labourCost + overhead;
    const craftsmanshipScore = 0.82;
    const marketMin = 2200.0;
    const marketMax = 2800.0;
    final recommendedMin = (costFloor * 1.3).clamp(marketMin * 0.9, marketMax);
    final recommendedMax = (costFloor * 1.6).clamp(recommendedMin, marketMax * 1.1);

    return PriceRecommendation(
      id: 'price_${DateTime.now().millisecondsSinceEpoch}',
      productId: productId,
      materialCost: materialCost,
      labourCost: labourCost,
      overhead: overhead,
      craftsmanshipScore: craftsmanshipScore,
      recommendedMin: recommendedMin,
      recommendedMax: recommendedMax,
      explanationText:
          '₹${recommendedMin.toStringAsFixed(0)}–₹${recommendedMax.toStringAsFixed(0)} recommended '
          'because your cost is ₹${costFloor.toStringAsFixed(0)} and similar handmade pottery '
          'sells for ₹${marketMin.toStringAsFixed(0)}–₹${marketMax.toStringAsFixed(0)}. '
          'Your craftsmanship score of ${(craftsmanshipScore * 100).toInt()}% earns a premium. '
          'This gives you ₹${(recommendedMin - costFloor).toStringAsFixed(0)}–'
          '₹${(recommendedMax - costFloor).toStringAsFixed(0)} margin while staying competitive.',
      explanationTextHi:
          '₹${recommendedMin.toStringAsFixed(0)}–₹${recommendedMax.toStringAsFixed(0)} की '
          'सिफारिश की जाती है क्योंकि आपकी लागत ₹${costFloor.toStringAsFixed(0)} है और इसी '
          'तरह के हस्तनिर्मित बर्तन ₹${marketMin.toStringAsFixed(0)}–₹${marketMax.toStringAsFixed(0)} में बिकते हैं। '
          'यह आपको ₹${(recommendedMin - costFloor).toStringAsFixed(0)}–'
          '₹${(recommendedMax - costFloor).toStringAsFixed(0)} का मुनाफा देता है।',
      comparables: const [
        MarketComparable(name: 'Handmade Clay Pot — Jaipur Crafts', price: 2350, source: 'Jaipur Crafts'),
        MarketComparable(name: 'Traditional Matka — IndiaCraft', price: 2500, source: 'IndiaCraft'),
        MarketComparable(name: 'Terracotta Water Pot — Craftsvilla', price: 2700, source: 'Craftsvilla'),
      ],
      verificationStatus: VerificationStatus.aiGenerated,
    );
  }

  /// Simulate B2B readiness check.
  static Future<B2BReadiness> checkB2BReadiness(
    String productId,
    String channelId,
    ProductListing listing,
    PriceRecommendation? pricing,
  ) async {
    await Future.delayed(const Duration(seconds: 1));
    final missingFields = <String>[];
    if (pricing?.finalPrice == null) missingFields.add('Minimum Order Quantity (MOQ)');
    missingFields.add('GST Registration Number');
    missingFields.add('Production Capacity (units/month)');

    final readiness = 1.0 - (missingFields.length / 6.0);
    return B2BReadiness(
      id: 'b2b_${DateTime.now().millisecondsSinceEpoch}',
      productId: productId,
      channelId: channelId,
      missingFields: missingFields,
      readinessScore: readiness.clamp(0.0, 1.0),
      status: readiness >= 0.8 ? B2BStatus.ready : B2BStatus.inProgress,
    );
  }
}

import 'package:flutter/material.dart';

/// UI copy is translated at render time so mounted routes react to locale changes.
/// Unknown strings (including artisan-entered content) are preserved.
extension AppLanguage on BuildContext {
  bool get isHindi => Localizations.localeOf(this).languageCode == 'hi';
  String tr(String source) {
    final pair = appTranslations[source];
    return pair == null ? source : pair[isHindi ? 0 : 1];
  }
}

class AppText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  const AppText(this.data,
      {super.key,
      this.style,
      this.textAlign,
      this.maxLines,
      this.overflow,
      this.softWrap});

  @override
  Widget build(BuildContext context) => Text(context.tr(data),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap);
}

final Map<String, List<String>> appTranslations = {
  for (final pair in _copy)
    for (final text in pair) text: [pair[0], pair[1]],
};

const _copy = <List<String>>[
  [
    "OTP आपके नंबर पर भेजा जाएगा",
    "OTP will be sent to this number",
    "OTP आपके नंबर पर भेजा जाएगा  •  OTP will be sent to this number"
  ],
  ["बाज़ार चुनें", "Choose Marketplace", "बाज़ार चुनें  •  Choose Marketplace"],
  ["तैयारी स्कोर", "Readiness Score", "तैयारी स्कोर  •  Readiness Score"],
  ["क्या चाहिए", "What's Missing", "क्या चाहिए  •  What's Missing"],
  [
    "सब कुछ तैयार है!",
    "All requirements met!",
    "सब कुछ तैयार है!  •  All requirements met!"
  ],
  [
    "B2B Channel से जोड़ें",
    "Connect Now",
    "B2B Channel से जोड़ें  •  Connect Now"
  ],
  ["टेराकोटा मटका", "Terracotta Matka"],
  ["बाँधनी दुपट्टा", "Bandhani Dupatta"],
  ["लकड़ी का हाथी", "Wooden Elephant"],
  ["फोटो खींचें, हम संवारेंगे", "Snap. We enhance."],
  ["बोलें, हम लिखेंगे", "Speak. We catalog."],
  ["सही कीमत, सही मुनाफा", "Fair price. Real margin."],
  [
    "बस अपने उत्पाद की फोटो लें। हमारी AI उसे e-commerce के लिए तैयार कर देगी — बैकग्राउंड, रोशनी, सब कुछ।",
    "Just click a photo. Our AI makes it e-commerce ready — background, lighting, everything."
  ],
  [
    "अपनी भाषा में बताएं अपना उत्पाद। AI सुनेगा, समझेगा, और Hindi-English में listing तैयार करेगा।",
    "Describe in your language. AI listens, understands, and builds your bilingual listing."
  ],
  [
    "AI आपकी मेहनत की लागत देखकर कीमत सुझाएगा — मशीन-निर्मित सामान से तुलना नहीं, बस हस्तशिल्प से।",
    "AI suggests prices respecting your labour — compared only to handmade, never to machine-made."
  ],
  ["अच्छी रोशनी में फोटो लें", "Take in good lighting"],
  ["उत्पाद को बीच में रखें", "Center the product"],
  ["क्लियर फोकस रखें", "Keep it in focus"],
  ["30-50 cm दूरी से", "30-50 cm distance"],
  ["कैमरा खोलें", "Open Camera", "कैमरा खोलें  •  Open Camera"],
  [
    "गैलरी से चुनें",
    "Choose from Gallery",
    "गैलरी से चुनें  •  Choose from Gallery"
  ],
  ["सामग्री लागत", "Material Cost"],
  ["काम के घंटे", "Labour Hours"],
  ["प्रति घंटा दर", "Wage per Hour"],
  ["अन्य खर्च", "Overhead"],
  ["लागत विवरण", "Cost Breakdown", "लागत विवरण  •  Cost Breakdown"],
  ["सुझाव पाएं", "Get AI Price", "सुझाव पाएं  •  Get AI Price Recommendation"],
  ["AI सुझाव", "AI Recommendation", "AI सुझाव  •  AI Recommendation"],
  ["क्यों?", "Why?", "क्यों?  •  Why?"],
  [
    "हस्तनिर्मित तुलनाएं",
    "Handmade Comparables",
    "हस्तनिर्मित तुलनाएं  •  Handmade Comparables"
  ],
  ["अपनी कीमत चुनें", "Set Your Price", "अपनी कीमत चुनें  •  Set Your Price"],
  ["कुम्हारी", "Pottery"],
  ["बुनाई", "Weaving"],
  ["कढ़ाई", "Embroidery"],
  ["लकड़ी", "Woodcraft"],
  ["धातु", "Metalcraft"],
  ["चित्रकारी", "Painting"],
  ["चर्म", "Leather"],
  ["आभूषण", "Jewelry"],
  ["भाषा चुनें", "Choose your language"],
  ["आप बाद में इसे बदल सकते हैं", "You can change this later"],
  ["जल्द उपलब्ध", "Coming soon"],
  ["आगे बढ़ें  →", "Continue  →"],
  ["अगला →", "Next →"],
  ["शुरू करें 🎨", "Get started 🎨"],
  ["छोड़ें", "Skip"],
  [
    "हस्तकला की पहचान, डिजिटल दुनिया में",
    "Bringing your craft to the digital world"
  ],
  [
    "कारीगर की समझ। आपकी कला, आपका नियंत्रण।",
    "Artisan intelligence. Your craft, your control."
  ],
  ["नमस्ते! 👋", "Hello! 👋"],
  ["अपना मोबाइल नंबर दर्ज करें", "Enter your mobile number"],
  ["OTP भेजें  →", "Send OTP  →"],
  ["या", "or", "या / or"],
  ["🎭  डेमो मोड (निर्णायकों के लिए)", "🎭  Demo Mode (Judges)"],
  [
    "आगे बढ़कर, आप हमारी शर्तों और गोपनीयता नीति से सहमत होते हैं",
    "By continuing, you agree to our Terms & Privacy Policy"
  ],
  ["OTP दर्ज करें", "Enter OTP"],
  ["OTP भेजा गया: ", "OTP sent to "],
  ["सत्यापित करें और आगे बढ़ें", "Verify & Continue"],
  ["OTP दोबारा भेजें", "Resend OTP"],
  ["💡 डेमो: कोई भी 6 अंक दर्ज करें", "💡 Demo: Enter any 6 digits"],
  ["आपका नाम क्या है?", "What is your name?"],
  ["राज्य", "State", "राज्य / State"],
  ["आपकी कला?", "What is your craft?"],
  ["सुप्रभात", "Good morning"],
  ["नमस्ते", "Hello"],
  ["शुभ संध्या", "Good evening"],
  ["उत्पाद", "Products"],
  ["सत्यापित", "Verified"],
  ["B2B तैयार", "B2B Ready"],
  ["मेरे उत्पाद", "My Products"],
  ["सभी देखें", "View all"],
  ["B2B / सरकारी बाज़ार", "B2B / Government Marketplace"],
  [
    "GeM · ONDC · राज्य बोर्ड तक पहुँचें",
    "Reach GeM · ONDC · State Boards",
    "GeM · ONDC · State Boards तक पहुँचें"
  ],
  ["नया उत्पाद जोड़ें", "Add new product"],
  ["कलाकार", "Kalakar"],
  ["फोटो कैप्चर", "Photo Capture"],
  ["यहाँ उत्पाद दिखेगा", "Your product will appear here"],
  ["📋 बेहतर फोटो के लिए", "📋 Tips for better photos"],
  [
    "बैकग्राउंड हटाया जा रहा है",
    "Removing background",
    "Background हटाया जा रहा है"
  ],
  ["रोशनी सुधारी जा रही है", "Adjusting lighting", "Lighting adjust हो रही है"],
  ["रंग निखारे जा रहे हैं", "Enhancing colors", "Colors enhance हो रहे हैं"],
  ["पहले / बाद", "Before / After"],
  ["AI आपकी फोटो सुधार रहा है...", "AI is enhancing your photo..."],
  [
    "फोटो सुधार पूरा! मूल फोटो भी सुरक्षित है।",
    "Enhancement complete! Original photo saved too.",
    "Enhancement complete! मूल फोटो भी सेव है।"
  ],
  ["पहले", "Before", "पहले / Before"],
  ["✨ बाद", "✨ After", "✨ बाद / After"],
  [
    "← तुलना के लिए स्लाइड करें →",
    "← Slide to compare →",
    "← स्लाइड करें तुलना के लिए  ",
    "  Slide to compare →"
  ],
  ["🔄 फिर से", "🔄 Retry"],
  ["सही है! आगे बढ़ें", "Looks good! Continue"],
  ["स्मार्ट कैटालॉग", "Smart Catalog"],
  ["🎤 अपने उत्पाद के बारे में बताएं", "🎤 Tell us about your product"],
  [
    "जैसे: \"यह मेरे हाथ से बना मिट्टी का मटका है, राजस्थान से, ऊँचाई 30 cm...\"",
    "For example: \"This is my handmade clay pot from Rajasthan, 30 cm tall...\""
  ],
  [
    "अपने उत्पाद के बारे में अपनी भाषा में बोलें।",
    "Speak freely about your product in any language."
  ],
  ["सुन रहा हूँ... बोलते रहें", "Listening... keep speaking"],
  ["बोलने के लिए दबाएं", "Tap to speak"],
  ["AI समझ रहा है...", "AI is understanding..."],
  ["आपके विवरण का विश्लेषण हो रहा है...", "Analyzing your description..."],
  ["प्रश्न", "Question"],
  ["🧠 AI ने समझा", "🧠 What AI understood"],
  ["लिस्टिंग बनाएं →", "Create Listing →", "Listing बनाएं →"],
  ["पूरा हुआ", "Done"],
  ["रद्द करें", "Cancel"],
  ["सहेजें", "Save"],
  ["डेमो: अपने आप भरें", "Demo: Auto-fill"],
  ["लिस्टिंग का पूर्वावलोकन", "Listing Preview"],
  [
    "लिस्टिंग तैयार हो रही है...",
    "Preparing your listing...",
    "Listing तैयार हो रही है..."
  ],
  [
    "दो भाषाओं में लिस्टिंग तैयार हो रही है...",
    "Generating bilingual listing..."
  ],
  ["पढ़ा जा रहा है...", "Reading aloud..."],
  ["🔊 सुनें", "🔊 Read Back", "🔊 सुनें — Read Back"],
  ["✏️ संपादित", "✏️ Edit"],
  [
    "✓ स्वीकृत! कीमत तय करें →",
    "✓ Approved! Set Price →",
    "✓ Approved! Price Set करें →"
  ],
  [
    "✅ हाँ, सही है! स्वीकृत करें",
    "✅ Looks correct! Approve",
    "✅ हाँ, सही है! Approve"
  ],
  [
    "AI द्वारा तैयार — कृपया जाँचें",
    "AI-generated — please verify",
    "AI द्वारा तैयार — कृपया जाँचें  ",
    "  AI-generated — please verify"
  ],
  ["शीर्षक", "Title", "शीर्षक / Title"],
  ["विवरण", "Description", "विवरण / Description"],
  ["टैग / मुख्य शब्द", "Tags / Keywords"],
  ["संपादन जल्द उपलब्ध होगा!", "Edit mode coming soon!"],
  ["💰 मूल्य निर्धारण", "💰 Pricing"],
  ["कुल लागत", "Total Cost", "कुल लागत (Cost Floor)"],
  ["मेहनत-आधारित", "Labour-based"],
  ["✓ कीमत तय! B2B देखें →", "✓ Price set! View B2B →"],
  ["✅ यह कीमत सही है", "✅ Confirm this price"],
  ["मशीन-निर्मित वस्तुएँ शामिल नहीं", "Machine-made excluded"],
  ["सरकारी ई-मार्केट", "Government e-Marketplace"],
  ["राष्ट्रीय डिजिटल व्यापार", "Open Network for Digital Commerce"],
  ["राज्य हस्तशिल्प बोर्ड", "State Handicraft Board"],
  ["B2B बाज़ार तक पहुँचें", "Reach B2B marketplaces"],
  ["जाँच रहे हैं...", "Checking..."],
  ["भरें", "Fill in"],
  ["🎉 आवेदन भेजा गया!", "🎉 Application submitted!"],
  ["डैशबोर्ड पर जाएं", "Go to Dashboard", "Dashboard पर जाएं"],
  ["उच्च", "High"],
  ["मध्यम", "Medium"],
  ["निम्न", "Low"],
  [
    "ℹ️  जानकारी चाहिए",
    "ℹ️  Information needed",
    "ℹ️  जानकारी चाहिए · Missing"
  ],
  ["AI द्वारा तैयार", "AI Generated"],
  ["समीक्षा में", "In Review"],
  ["समीक्षा", "Review"],
  ["✓ स्वीकृत", "✓ Approved"],
  ["अस्वीकृत", "Rejected"],
  ["अस्वीकृत", "Rej"],
  ["उत्पाद प्रकार", "Product Type"],
  ["सामग्री", "Material"],
  ["शिल्प तकनीक", "Craft Technique"],
  ["आयाम", "Dimensions"],
  ["रंग", "Color"],
  ["उपयोग", "Usage"],
  ["उत्पत्ति / क्षेत्र", "Origin / Region"],
  ["वज़न", "Weight"],
  ["राजस्थान", "Rajasthan"],
  ["उत्तर प्रदेश", "Uttar Pradesh"],
  ["गुजरात", "Gujarat"],
  ["पश्चिम बंगाल", "West Bengal"],
  ["मध्य प्रदेश", "Madhya Pradesh"],
  ["ओडिशा", "Odisha"],
  ["तमिलनाडु", "Tamil Nadu"],
  ["कर्नाटक", "Karnataka"],
  ["महाराष्ट्र", "Maharashtra"],
  ["असम", "Assam"],
  ["अन्य", "Other"],
  [
    "← तुलना के लिए स्लाइड करें →",
    "← Slide to compare →",
    "← स्लाइड करें तुलना के लिए  |  Slide to compare →"
  ],
  [
    "AI द्वारा तैयार — कृपया जाँचें",
    "AI-generated — please verify",
    "AI द्वारा तैयार — कृपया जाँचें  |  AI-generated — please verify"
  ],
  [
    "\"Matka\" और \"Terracotta\" जैसे शिल्प-शब्द संरक्षित हैं",
    "Craft terms like \"Matka\" & \"Terracotta\" preserved verbatim",
    "\"Matka\" और \"Terracotta\" जैसे शिल्प-शब्द संरक्षित हैं\nCraft terms like \"Matka\" & \"Terracotta\" preserved verbatim"
  ],
  [
    "आपकी लिस्टिंग भेज दी गई है। खरीदार जल्द संपर्क करेंगे।",
    "Your listing has been submitted. Buyers will contact you soon.",
    "आपका listing B2B channel पर भेज दिया गया है। खरीदार जल्द संपर्क करेंगे।\n\nYour listing has been submitted. Buyers will contact you soon."
  ],
  ["कृपया सही मोबाइल नंबर दर्ज करें", "Valid phone number required"],
  ["अपनी शिल्प श्रेणी चुनें", "Select your craft category"],
  [
    "सरकारी और B2B बाज़ारों के लिए ज़रूरी जानकारी जाँचें। हम बताएंगे कि क्या भरना बाकी है।",
    "Check what you need to list on govt. & B2B platforms. We'll tell you exactly what's missing."
  ],
  ["न्यूनतम ऑर्डर मात्रा (MOQ)", "Minimum Order Quantity (MOQ)"],
  ["GST पंजीकरण संख्या", "GST Registration Number"],
  ["उत्पादन क्षमता (इकाइयाँ/माह)", "Production Capacity (units/month)"],
  ["न्यूनतम", "Min"],
  ["सुझाई गई कीमत", "Recommended"],
  ["शेष", "remaining"],
  ["कैमरा त्रुटि", "Camera error"],
  ["AI फोटो सुधार", "AI Enhancement"],
  ["राजस्थान / महाराष्ट्र / आदि", "Rajasthan / Maharashtra / etc."],
];

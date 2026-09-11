import 'package:flutter/material.dart';

class AppColors {
  // Core palette — earthy green craft theme
  static const Color primary = Color(0xFF285448);          // Deep forest from buyer reference
  static const Color primaryDark = Color(0xFF1C3D33);
  static const Color primaryLight = Color(0xFF527C63);
  static const Color secondary = Color(0xFF8B9D6B);        // Sage green
  static const Color secondaryDark = Color(0xFF6B7D4B);
  static const Color accent = Color(0xFFD4A574);           // Warm earth/terracotta
  static const Color accentGreen = Color(0xFF4A7C2E);      // Success / approved
  static const Color accentRed = Color(0xFFC0392B);        // Error / reject

  // Background layers — warm earthy tones
  static const Color background = Color(0xFFF8F7F2);       // Warm cream
  static const Color surface = Color(0xFFFFFFFF);          // White card
  static const Color surfaceLight = Color(0xFFF8F5F0);     // Light cream
  static const Color surfaceHighlight = Color(0xFFEDE8DF); // Hover/active

  // Glass effect colours (subtle for light theme)
  static const Color glassFill = Color(0x0A000000);
  static const Color glassBorder = Color(0x10000000);

  // Text — dark for light theme
  static const Color textPrimary = Color(0xFF1A2E05);      // Dark forest
  static const Color textSecondary = Color(0xFF4A5D3A);    // Muted green
  static const Color textHint = Color(0xFF8B9D6B);         // Light sage
  static const Color textOnPrimary = Color(0xFFFFFFFF);    // White on green

  // Semantic
  static const Color error = Color(0xFFC0392B);
  static const Color warning = Color(0xFFD4A574);
  static const Color success = Color(0xFF4A7C2E);
  static const Color info = Color(0xFF5D8AA8);
  static const Color divider = Color(0xFFD4C9B8);

  // Verification status colours
  static const Color statusGenerated = Color(0xFF5D8AA8);   // AI Generated — blue
  static const Color statusReviewed = Color(0xFFD4A574);    // Reviewed — amber
  static const Color statusApproved = Color(0xFF4A7C2E);    // Approved — green

  // Confidence level colours
  static const Color confidenceHigh = Color(0xFF4A7C2E);
  static const Color confidenceMedium = Color(0xFFD4A574);
  static const Color confidenceLow = Color(0xFFC0392B);

  // Gradient definitions
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
    stops: [0.0, 1.0],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF5F0E8), Color(0xFFE8E0D0)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF8F5F0)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFD4A574), Color(0xFF8B6F47)],
  );
}

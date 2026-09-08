import 'package:flutter/material.dart';

class AppColors {
  // Core palette — saffron-to-indigo craft gradient
  static const Color primary = Color(0xFFFF6B35);       // Saffron
  static const Color primaryDark = Color(0xFFE05A25);
  static const Color primaryLight = Color(0xFFFF8A5B);
  static const Color secondary = Color(0xFF6C63FF);      // Indigo
  static const Color secondaryDark = Color(0xFF5A52E0);
  static const Color accent = Color(0xFFF59E0B);         // Gold — verified/approved
  static const Color accentGreen = Color(0xFF10B981);    // Success / approved
  static const Color accentRed = Color(0xFFEF4444);      // Error / reject

  // Background layers
  static const Color background = Color(0xFF0A0A14);     // Deep dark
  static const Color surface = Color(0xFF13131F);        // Card surface
  static const Color surfaceLight = Color(0xFF1C1C2E);   // Elevated surface
  static const Color surfaceHighlight = Color(0xFF242438); // Hover/active

  // Glass effect colours
  static const Color glassFill = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x26FFFFFF);

  // Text
  static const Color textPrimary = Color(0xFFF0F0F8);
  static const Color textSecondary = Color(0xFFB0B0C8);
  static const Color textHint = Color(0xFF6B6B88);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Semantic
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);
  static const Color info = Color(0xFF3B82F6);
  static const Color divider = Color(0xFF1E1E30);

  // Verification status colours
  static const Color statusGenerated = Color(0xFF3B82F6);   // AI Generated — blue
  static const Color statusReviewed = Color(0xFFF59E0B);    // Reviewed — amber
  static const Color statusApproved = Color(0xFF10B981);    // Approved — green

  // Confidence level colours
  static const Color confidenceHigh = Color(0xFF10B981);
  static const Color confidenceMedium = Color(0xFFF59E0B);
  static const Color confidenceLow = Color(0xFFEF4444);

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
    colors: [Color(0xFF0F0F1A), Color(0xFF0A0A14)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A2E), Color(0xFF13131F)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFFF6B35)],
  );
}

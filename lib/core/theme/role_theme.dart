import 'package:flutter/material.dart';
import '../../shared/models/account.dart';

/// Reference palettes: warm artisan studio and quiet, cool buyer workspace.
abstract final class RoleTheme {
  static ThemeData forRole(AccountRole? role) {
    final buyer = role == AccountRole.buyer;
    final primary = buyer ? const Color(0xFF28564F) : const Color(0xFF176344);
    final background =
        buyer ? const Color(0xFFF5F7F6) : const Color(0xFFFBF6EC);
    final scheme = ColorScheme.fromSeed(seedColor: primary).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      surface: background,
      onSurface: const Color(0xFF20342F),
      outline: buyer ? const Color(0xFFD8E2DE) : const Color(0xFFE1DACB),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(buyer ? 10 : 14),
      borderSide: BorderSide(color: scheme.outline),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
          backgroundColor: background,
          scrolledUnderElevation: 0,
          centerTitle: false),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: border,
        enabledBorder: border,
        focusedBorder:
            border.copyWith(borderSide: BorderSide(color: primary, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buyer ? 10 : 14)),
        textStyle: const TextStyle(
            fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 15),
      )),
      cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: scheme.outline))),
    );
  }
}

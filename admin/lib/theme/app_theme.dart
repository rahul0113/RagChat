import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// RagChat Theme — Based on Stitch "Lumina Interface" design system
/// Glassmorphism + dark-mode-first + Inter/Geist typography
class AppTheme {
  // === Stitch Named Colors ===
  static const Color background = Color(0xFF14121F);
  static const Color surface = Color(0xFF14121F);
  static const Color surfaceContainerLowest = Color(0xFF0E0C19);
  static const Color surfaceContainerLow = Color(0xFF1C1A27);
  static const Color card = Color(0xFF201E2C);
  static const Color surfaceContainerHigh = Color(0xFF2B2836);
  static const Color surfaceContainerHighest = Color(0xFF363342);
  static const Color surfaceBright = Color(0xFF3A3746);

  // === Primary (Indigo) ===
  static const Color primary = Color(0xFFC0C1FF);
  static const Color primaryContainer = Color(0xFF8083FF);
  static const Color onPrimary = Color(0xFF1000A9);
  static const Color onPrimaryContainer = Color(0xFF0D0096);

  // === Secondary (Purple) ===
  static const Color secondary = Color(0xFFDDB7FF);
  static const Color secondaryContainer = Color(0xFF6F00BE);
  static const Color onSecondaryContainer = Color(0xFFD6A9FF);

  // === Tertiary (Green) ===
  static const Color tertiary = Color(0xFF4AE176);
  static const Color tertiaryContainer = Color(0xFF00A74B);

  // === Neutral ===
  static const Color textPrimary = Color(0xFFE5E0F3);
  static const Color textSecondary = Color(0xFFC7C4D7);
  static const Color outline = Color(0xFF908FA0);
  static const Color border = Color(0xFF464554);

  // === Functional ===
  static const Color success = Color(0xFF4AE176);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFFFB4AB);
  static const Color info = Color(0xFF8083FF);

  // === Glass Effects ===
  static const double glassBlur = 10.0;
  static const double modalGlassBlur = 20.0;
  static Color get glassSurface => const Color(0xB31E1B2E); // rgba(30, 27, 46, 0.7)
  static Color get glassModal => const Color(0xD92D2942); // rgba(45, 41, 66, 0.85)

  // Light theme colors
  static const Color lightBackground = Color(0xFFF8F7FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerHigh = Color(0xFFF0EFF5);
  static const Color lightTextPrimary = Color(0xFF1A1528);
  static const Color lightTextSecondary = Color(0xFF6B6880);
  static const Color lightOutline = Color(0xFF908FA0);
  static const Color lightBorder = Color(0xFFD8D6E3);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        surface: surface,
        error: error,
        onPrimary: onPrimary,
        onSecondary: Color(0xFF490080),
        onTertiary: Color(0xFF003915),
        onError: Color(0xFF690005),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      cardTheme: CardTheme(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: outline),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 0,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        surface: lightSurface,
        error: Color(0xFFBA1A1A),
        onPrimary: Color(0xFF1000A9),
        onSecondary: Color(0xFF490080),
        onTertiary: Color(0xFF003915),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: lightTextPrimary,
        displayColor: lightTextPrimary,
      ),
      cardTheme: CardTheme(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0EFF5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: lightOutline),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 0,
      ),
    );
  }

  // === Glass Decoration Helper ===
  static BoxDecoration glassDecoration({
    double borderRadius = 8,
    double opacity = 0.7,
    double blur = 10,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: Color.fromRGBO(30, 27, 46, opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? Colors.white.withOpacity(0.1),
        width: 1,
      ),
    );
  }

  static BoxDecoration glassCardDecoration() {
    return BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: border, width: 1),
    );
  }
}

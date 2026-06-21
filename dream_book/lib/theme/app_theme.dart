import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The "Twilight Storybook" palette — a dreamy, magical aesthetic inspired by
/// cinematic fantasy art: deep night-sky indigos and violets, warm candle-gold
/// accents, and soft moonlit lavender text.
class MagicColors {
  MagicColors._();

  // Night-sky background gradient (top → bottom).
  static const Color nightTop = Color(0xFF0B1026); // deep midnight blue
  static const Color nightMid = Color(0xFF1A1340); // royal indigo
  static const Color nightBottom = Color(0xFF2C1B4D); // dusk violet

  // Surfaces (glassy cards floating over the night sky).
  static const Color surface = Color(0xFF221A44);
  static const Color surfaceGlass = Color(0x33FFFFFF); // 20% white veil

  // Warm magical accents — candlelight / enchanted gold.
  static const Color gold = Color(0xFFF4C766);
  static const Color amber = Color(0xFFE8A94B);

  // Secondary enchantment — a soft starlit lilac / aurora.
  static const Color lilac = Color(0xFFB79CED);
  static const Color aurora = Color(0xFF7FE0D4);

  // Text.
  static const Color textPrimary = Color(0xFFF3ECFF); // moonlit white-lilac
  static const Color textMuted = Color(0xFFB6ABD8); // hazy lavender
  static const Color danger = Color(0xFFFF8A9B);

  /// Full-screen twilight gradient used as the app backdrop.
  static const LinearGradient nightSky = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [nightTop, nightMid, nightBottom],
  );
}

/// Builds the app-wide [ThemeData]. A single source of truth so every screen
/// inherits the magical look (fonts, colors, buttons, cards, inputs).
class AppTheme {
  AppTheme._();

  /// Elegant fantasy serif for brand titles & big headings — think the engraved
  /// caps on a storybook cover.
  static TextStyle displayFont({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w600,
    Color color = MagicColors.textPrimary,
    double? letterSpacing,
    double? height,
  }) => GoogleFonts.cinzel(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  /// Flowing serif for section headings & story prose.
  static TextStyle serifFont({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w500,
    Color color = MagicColors.textPrimary,
    FontStyle? fontStyle,
    double? height,
  }) => GoogleFonts.cormorantGaramond(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    fontStyle: fontStyle,
    height: height,
  );

  /// Rounded, friendly body font for UI chrome & controls.
  static TextStyle bodyFont({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w500,
    Color color = MagicColors.textPrimary,
    double? letterSpacing,
  }) => GoogleFonts.quicksand(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
  );

  static ThemeData build() {
    const scheme = ColorScheme.dark(
      primary: MagicColors.gold,
      onPrimary: Color(0xFF2A1B05),
      primaryContainer: MagicColors.surface,
      onPrimaryContainer: MagicColors.textPrimary,
      secondary: MagicColors.lilac,
      onSecondary: Color(0xFF1A1340),
      surface: MagicColors.surface,
      onSurface: MagicColors.textPrimary,
      error: MagicColors.danger,
      onError: Color(0xFF3A0A12),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      splashColor: MagicColors.gold.withValues(alpha: 0.12),
      highlightColor: MagicColors.gold.withValues(alpha: 0.06),
    );

    final textTheme = base.textTheme;

    return base.copyWith(
      textTheme: textTheme.copyWith(
        displayLarge: displayFont(fontSize: 44, letterSpacing: 1.5),
        displayMedium: displayFont(fontSize: 34, letterSpacing: 1.2),
        headlineMedium: displayFont(fontSize: 26, letterSpacing: 0.8),
        headlineSmall: displayFont(fontSize: 22, letterSpacing: 0.6),
        titleLarge: serifFont(fontSize: 24, fontWeight: FontWeight.w600),
        titleMedium: bodyFont(fontSize: 17, fontWeight: FontWeight.w600),
        titleSmall: bodyFont(fontSize: 14, fontWeight: FontWeight.w600),
        bodyLarge: bodyFont(fontSize: 16),
        bodyMedium: bodyFont(fontSize: 14, color: MagicColors.textMuted),
        bodySmall: bodyFont(fontSize: 12, color: MagicColors.textMuted),
        labelLarge: bodyFont(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: MagicColors.gold),
        titleTextStyle: displayFont(
          fontSize: 22,
          letterSpacing: 1.0,
          color: MagicColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: MagicColors.surface.withValues(alpha: 0.55),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: MagicColors.lilac.withValues(alpha: 0.18)),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MagicColors.gold,
          foregroundColor: const Color(0xFF2A1B05),
          textStyle: bodyFont(fontSize: 15, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MagicColors.lilac,
          side: BorderSide(color: MagicColors.lilac.withValues(alpha: 0.5)),
          textStyle: bodyFont(fontSize: 14, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MagicColors.gold,
          textStyle: bodyFont(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: MagicColors.gold,
        foregroundColor: const Color(0xFF2A1B05),
        elevation: 6,
        extendedTextStyle: bodyFont(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        labelStyle: bodyFont(color: MagicColors.textMuted),
        hintStyle: bodyFont(color: MagicColors.textMuted.withValues(alpha: 0.7)),
        prefixIconColor: MagicColors.lilac,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: MagicColors.lilac.withValues(alpha: 0.25),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: MagicColors.gold, width: 1.6),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: MagicColors.lilac.withValues(alpha: 0.25),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: MagicColors.nightMid,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: MagicColors.lilac.withValues(alpha: 0.25)),
        ),
        titleTextStyle: displayFont(fontSize: 20),
        contentTextStyle: bodyFont(color: MagicColors.textMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MagicColors.nightTop,
        contentTextStyle: bodyFont(color: MagicColors.textPrimary),
        actionTextColor: MagicColors.gold,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: MagicColors.lilac,
        textColor: MagicColors.textPrimary,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: MagicColors.gold,
      ),
      iconTheme: const IconThemeData(color: MagicColors.lilac),
      dividerColor: MagicColors.lilac.withValues(alpha: 0.15),
    );
  }
}

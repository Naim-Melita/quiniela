import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Estilos de texto del design system.
///
/// Inter para toda la UI; JetBrains Mono para cualquier cosa que sea un numero
/// de quiniela, para que los digitos alineen verticalmente al escanear una
/// columna de resultados.
abstract final class AppText {
  static TextStyle get displayLg => GoogleFonts.inter(
        fontSize: 48,
        height: 56 / 48,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.02 * 48,
      );

  static TextStyle get headlineLg => GoogleFonts.inter(
        fontSize: 32,
        height: 40 / 32,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get headlineLgMobile => GoogleFonts.inter(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get headlineMd => GoogleFonts.inter(
        fontSize: 20,
        height: 28 / 20,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get bodyLg => GoogleFonts.inter(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get bodySm => GoogleFonts.inter(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get labelCaps => GoogleFonts.inter(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w700,
      );

  /// Numeros de sorteo, bolillas y cualquier dato tabular.
  static TextStyle get dataDisplay => GoogleFonts.jetBrainsMono(
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.05 * 18,
      );

  /// Variante de [dataDisplay] a un tamano arbitrario, para las bolillas
  /// grandes del dashboard y del generador.
  static TextStyle data(double size, {FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        height: 1.1,
        fontWeight: weight,
        letterSpacing: 0.02 * size,
      );
}

abstract final class AppTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onTertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      surfaceContainerLowest: AppColors.surfaceContainerLowest,
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      textTheme: TextTheme(
        displayLarge: AppText.displayLg,
        headlineLarge: AppText.headlineLg,
        headlineMedium: AppText.headlineLgMobile,
        titleLarge: AppText.headlineMd,
        bodyLarge: AppText.bodyLg,
        bodyMedium: AppText.bodyLg,
        bodySmall: AppText.bodySm,
        labelSmall: AppText.labelCaps,
      ).apply(
        bodyColor: AppColors.onSurface,
        displayColor: AppColors.onSurface,
      ),
    );
  }
}

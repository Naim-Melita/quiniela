import 'package:flutter/material.dart';

/// Paleta del design system "High-Stakes Precision" definido en Stitch.
///
/// Los nombres siguen los tokens del design system (surface / on-surface /
/// container...) para que el codigo se pueda contrastar contra el diseno sin
/// tener que traducir nada.
abstract final class AppColors {
  // Superficies
  static const background = Color(0xFF051424);
  static const surface = Color(0xFF051424);
  static const surfaceDim = Color(0xFF051424);
  static const surfaceBright = Color(0xFF2C3A4C);
  static const surfaceContainerLowest = Color(0xFF010F1F);
  static const surfaceContainerLow = Color(0xFF0D1C2D);
  static const surfaceContainer = Color(0xFF122131);
  static const surfaceContainerHigh = Color(0xFF1C2B3C);
  static const surfaceContainerHighest = Color(0xFF273647);
  static const surfaceVariant = Color(0xFF273647);

  // Contenido
  static const onBackground = Color(0xFFD4E4FA);
  static const onSurface = Color(0xFFD4E4FA);
  static const onSurfaceVariant = Color(0xFFC6C6CD);
  static const outline = Color(0xFF909097);
  static const outlineVariant = Color(0xFF45464D);

  // Primary (azul acero): estructura y titulos
  static const primary = Color(0xFFBEC6E0);
  static const onPrimary = Color(0xFF283044);
  static const primaryContainer = Color(0xFF0F172A);
  static const onPrimaryContainer = Color(0xFF798098);
  static const primaryFixedDim = Color(0xFFBEC6E0);

  // Secondary (verde "suerte"): acciones principales, estados en vivo y aciertos
  static const secondary = Color(0xFF4EDEA3);
  static const onSecondary = Color(0xFF003824);
  static const secondaryContainer = Color(0xFF00A572);
  static const onSecondaryContainer = Color(0xFF00311F);
  static const secondaryFixed = Color(0xFF6FFBBE);

  // Tertiary (dorado "jackpot"): numeros ganadores y destacados
  static const tertiary = Color(0xFFFFB95F);
  static const onTertiary = Color(0xFF472A00);
  static const tertiaryContainer = Color(0xFF251400);
  static const onTertiaryContainer = Color(0xFFB47300);

  // Error
  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);
  static const errorContainer = Color(0xFF93000A);
  static const onErrorContainer = Color(0xFFFFDAD6);
}

/// Escala de espaciado del design system (base 4px).
abstract final class AppSpacing {
  static const double base = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 40;

  /// Margen lateral de las pantallas.
  static const double containerMargin = 16;

  /// Separacion entre columnas/tarjetas.
  static const double gutter = 12;

  /// Lado minimo de cualquier cosa que se toque.
  ///
  /// 48dp es el minimo de Material y de WCAG 2.5.5. No se mide sobre el texto
  /// sino sobre el area sensible: un chip de 20px de texto necesita llegar a 48
  /// aunque se vea mas chico.
  static const double blancoDeToque = 48;
}

/// Radios del design system.
abstract final class AppRadius {
  static const Radius sm = Radius.circular(4);
  static const Radius lg = Radius.circular(8);
  static const Radius xl = Radius.circular(12);

  static const BorderRadius allSm = BorderRadius.all(sm);
  static const BorderRadius allLg = BorderRadius.all(lg);
  static const BorderRadius allXl = BorderRadius.all(xl);
  static const BorderRadius full = BorderRadius.all(Radius.circular(9999));
}

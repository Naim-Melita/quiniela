import 'package:flutter/material.dart';

import '../models/sorteo.dart';
import 'app_colors.dart';

/// Color con el que se identifica cada loteria.
///
/// Nacional y Provincia mantienen el dorado y el verde del diseno original de
/// Stitch. Las otras cuatro se eligieron para que se distingan entre si de un
/// vistazo sobre el fondo navy y sin competir con el verde, que en esta app
/// significa "accion" y "en vivo".
Color acentoDe(Loteria loteria) => switch (loteria) {
      Loteria.nacional => AppColors.tertiary, // dorado
      Loteria.provincia => AppColors.secondary, // verde
      Loteria.santaFe => const Color(0xFF7FB3FF), // celeste
      Loteria.cordoba => const Color(0xFFC79BFF), // violeta
      Loteria.entreRios => const Color(0xFFFF8FA3), // coral
      Loteria.montevideo => const Color(0xFF5AD1E8), // cian
    };

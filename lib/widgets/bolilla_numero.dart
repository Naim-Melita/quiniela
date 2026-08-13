import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Bolilla: el circulo con glow que muestra un numero ganador.
///
/// Es el unico elemento del design system con forma de circulo perfecto, para
/// que se distinga de cualquier componente funcional de la UI.
class BolillaNumero extends StatelessWidget {
  const BolillaNumero({
    super.key,
    required this.numero,
    required this.color,
    this.diametro = 96,
    this.glow = true,
  });

  final String numero;
  final Color color;
  final double diametro;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diametro,
      height: diametro,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 4),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        numero,
        style: AppText.data(diametro * 0.42, weight: FontWeight.w800).copyWith(
          color: AppColors.onSurface,
          shadows: glow
              ? [
                  Shadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

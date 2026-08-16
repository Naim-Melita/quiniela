import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'glass_panel.dart';

/// Franja de "ultimo minuto" del dashboard.
///
/// Antes el texto corria de derecha a izquierda como una marquesina. Se saco
/// por tres motivos: la mitad del ciclo el mensaje estaba fuera de la pantalla y
/// no se podia leer, obligaba a esperar a que volviera a pasar para engancharlo
/// desde el principio, y el movimiento automatico sin forma de pausarlo va en
/// contra de WCAG 2.2.2. El dato es corto y entra entero: se muestra quieto.
///
/// Queda el punto que late, que es el que dice "esto es de ahora". Respeta
/// "reducir movimiento" del sistema.
class TickerUltimoMinuto extends StatefulWidget {
  const TickerUltimoMinuto({super.key, required this.mensaje});

  final String mensaje;

  @override
  State<TickerUltimoMinuto> createState() => _TickerUltimoMinutoState();
}

class _TickerUltimoMinutoState extends State<TickerUltimoMinuto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulso.stop();
      _pulso.value = 0;
    } else if (!_pulso.isAnimating) {
      _pulso.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Ultimo minuto',
      value: widget.mensaje,
      excludeSemantics: true,
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FadeTransition(
                  opacity: Tween<double>(begin: 1, end: 0.25).animate(_pulso),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                // Flexible: con el texto del sistema al 200% la etiqueta no
                // entra en el ancho de un telefono y desbordaba la fila.
                Flexible(
                  child: Text(
                    'ULTIMO MINUTO',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.labelCaps.copyWith(
                      color: AppColors.secondary,
                      letterSpacing: 0.08 * 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.base),
            // El mensaje se lleva el ancho completo en su propia linea: en un
            // telefono angosto, compartir fila con la etiqueta lo dejaba en una
            // columna de cuatro palabras.
            Text(
              widget.mensaje,
              style: AppText.bodySm.copyWith(color: AppColors.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

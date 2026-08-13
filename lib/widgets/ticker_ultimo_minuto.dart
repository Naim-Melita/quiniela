import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'glass_panel.dart';

/// Franja de "ultimo minuto" del dashboard: icono pulsante + texto que corre.
class TickerUltimoMinuto extends StatefulWidget {
  const TickerUltimoMinuto({super.key, required this.mensaje});

  final String mensaje;

  @override
  State<TickerUltimoMinuto> createState() => _TickerUltimoMinutoState();
}

class _TickerUltimoMinutoState extends State<TickerUltimoMinuto>
    with TickerProviderStateMixin {
  late final AnimationController _desplazamiento;
  late final AnimationController _pulso;

  @override
  void initState() {
    super.initState();
    _desplazamiento = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
    _pulso = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _desplazamiento.dispose();
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Row(
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0.35).animate(_pulso),
            child: const Icon(
              Icons.timer_outlined,
              size: 20,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'ULTIMO MINUTO:',
            style: AppText.bodySm.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, restricciones) {
                  return AnimatedBuilder(
                    animation: _desplazamiento,
                    builder: (context, hijo) {
                      // Va de borde derecho a borde izquierdo y vuelve a empezar.
                      final dx = restricciones.maxWidth -
                          _desplazamiento.value * (restricciones.maxWidth * 2);
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: hijo,
                      );
                    },
                    child: Text(
                      widget.mensaje,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: AppText.bodySm.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

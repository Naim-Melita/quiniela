import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Placeholders con la forma del contenido que esta por llegar.
///
/// Se prefieren al spinner en todo lo que sea contenido: el spinner no dice
/// cuanto viene ni con que forma, y en esta app la espera es larga de verdad
/// (estadisticas de 30 dias son cientos de sorteos). Con la silueta puesta, la
/// pantalla no salta cuando entran los datos.
///
/// La animacion respeta "reducir movimiento" del sistema: con eso activado el
/// bloque se queda quieto en un tono intermedio.

/// Un bloque gris que late.
class Esqueleto extends StatefulWidget {
  const Esqueleto({
    super.key,
    this.alto = 16,
    this.ancho,
    this.radio = AppRadius.allSm,
  });

  final double alto;
  final double? ancho;
  final BorderRadius radio;

  @override
  State<Esqueleto> createState() => _EsqueletoState();
}

class _EsqueletoState extends State<Esqueleto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulso.stop();
      _pulso.value = 0.5;
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
    return AnimatedBuilder(
      animation: _pulso,
      builder: (context, _) => Container(
        width: widget.ancho,
        height: widget.alto,
        decoration: BoxDecoration(
          color: Color.lerp(
            AppColors.surfaceContainerLow,
            AppColors.surfaceContainerHighest,
            _pulso.value,
          ),
          borderRadius: widget.radio,
        ),
      ),
    );
  }
}

/// Envuelve una silueta y la anuncia como "cargando" una sola vez.
///
/// Sin esto el lector de pantalla recorre veinte rectangulos vacios.
class EsqueletoDeLista extends StatelessWidget {
  const EsqueletoDeLista({
    super.key,
    required this.child,
    required this.etiqueta,
  });

  final Widget child;

  /// Que se esta cargando: "Cargando resultados".
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: etiqueta,
      liveRegion: true,
      excludeSemantics: true,
      child: child,
    );
  }
}

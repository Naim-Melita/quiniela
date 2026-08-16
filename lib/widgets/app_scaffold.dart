import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Barra superior comun a todas las pantallas.
///
/// Tenia un avatar y una campana de notificaciones que no hacian nada. Un
/// control que no responde es peor que no tenerlo: ocupa la unica fila fija de
/// la pantalla, invita a tocarlo y no pasa nada. Quedan la marca y la lupa, que
/// son las dos cosas que si llevan a algun lado.
class QuinielaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const QuinielaAppBar({super.key, this.titulo = 'Quiniela24', this.onBuscar});

  final String titulo;

  /// Abre la busqueda de un numero. Si es null no se muestra la lupa.
  final VoidCallback? onBuscar;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDim,
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.containerMargin,
            right: AppSpacing.base,
          ),
          child: Row(
            children: [
              // Expanded en vez de Spacer: con pantallas angostas el titulo se
              // corta con puntos suspensivos en lugar de desbordar la Row.
              Expanded(
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // El titulo de la barra es el encabezado de la pantalla.
                  semanticsLabel: titulo,
                  style: AppText.headlineMd.copyWith(
                    color: AppColors.primaryFixedDim,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onBuscar case final buscar?)
                IconButton(
                  onPressed: buscar,
                  icon: const Icon(Icons.search),
                  color: AppColors.primaryFixedDim,
                  tooltip: 'Buscar un numero',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Titulo de seccion (el "headline-lg-mobile" del diseno).
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key, this.accion});

  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          // header: true deja que el lector de pantalla salte de seccion en
          // seccion en vez de leer la pagina entera de corrido.
          child: Semantics(
            header: true,
            // El titulo ya arranca en 24px. Al 200% del sistema, una palabra
            // sola como "Estadisticas" mide mas que la pantalla de un telefono
            // chico y no hay donde cortarla, asi que desbordaba la fila. Se le
            // pone techo al escalado solo aca: el cuerpo del texto, que es lo
            // que de verdad cuesta leer, sigue escalando entero.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.6,
              child: Text(
                texto,
                style: AppText.headlineLgMobile.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
        // Flexible y no a secas: la accion es contenido de ancho propio y con
        // el texto del sistema al 200% llega a medir mas que la pantalla, con
        // lo que desbordaba la fila entera.
        if (accion case final control?) Flexible(child: control),
      ],
    );
  }
}

/// Tarjeta base: fondo `surface-container`, radio 12 y borde tenue.
///
/// Con [onTap] se vuelve tocable. Es importante usar eso y no envolverla en un
/// InkWell desde afuera: el splash se pinta sobre el Material que la tarjeta
/// tiene debajo, asi que un fondo opaco encima lo tapa entero y el toque queda
/// sin ninguna respuesta visual. Aca la decoracion la pinta un [Ink], que es el
/// mismo Material, y la tinta queda arriba.
class TarjetaSuperficie extends StatelessWidget {
  const TarjetaSuperficie({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color = AppColors.surfaceContainer,
    this.onTap,
    this.semantica,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  /// Si viene, la tarjeta entera es un boton.
  final VoidCallback? onTap;

  /// Que anuncia el lector de pantalla en lugar de leer la tarjeta entera.
  final String? semantica;

  @override
  Widget build(BuildContext context) {
    final decoracion = BoxDecoration(
      color: color,
      borderRadius: AppRadius.allXl,
      border: Border.all(
        color: AppColors.outlineVariant.withValues(alpha: 0.5),
      ),
    );

    final alTocar = onTap;
    if (alTocar == null) {
      return Container(padding: padding, decoration: decoracion, child: child);
    }

    return Semantics(
      button: true,
      label: semantica,
      // Con etiqueta propia no tiene sentido que ademas lea las diez lineas de
      // adentro; sin etiqueta se deja pasar el contenido tal cual.
      excludeSemantics: semantica != null,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.allXl,
        child: Ink(
          decoration: decoracion,
          child: InkWell(
            onTap: alTocar,
            borderRadius: AppRadius.allXl,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

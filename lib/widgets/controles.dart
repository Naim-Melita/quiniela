import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Controles de seleccion de la app.
///
/// Estaban repetidos cuatro veces (ventana de dias en dos pantallas, cifras del
/// generador, filtros de resultados) y las cuatro copias eran un
/// [GestureDetector] sobre un Container: sin foco de teclado, sin anuncio de
/// "seleccionado" para el lector de pantalla, sin feedback al tocar y con el
/// area sensible del alto del texto.

/// Selector de una opcion entre pocas, en forma de pildora segmentada.
///
/// Las opciones van en un Map porque conserva el orden de escritura y deja el
/// call site legible: `{7: '7 dias', 14: '14 dias'}`.
class SelectorSegmentado<T> extends StatelessWidget {
  const SelectorSegmentado({
    super.key,
    required this.etiqueta,
    required this.opciones,
    required this.seleccionada,
    required this.onSeleccion,
  });

  /// Que agrupa el selector. No se dibuja: es lo que anuncia el lector de
  /// pantalla antes de las opciones, para que "7 dias" tenga contexto.
  final String etiqueta;

  final Map<T, String> opciones;
  final T seleccionada;
  final ValueChanged<T> onSeleccion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: etiqueta,
      child: Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.full,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Row(
            children: [
              for (final opcion in opciones.entries)
                Expanded(
                  child: _Segmento(
                    etiqueta: opcion.value,
                    activo: opcion.key == seleccionada,
                    onTap: () => onSeleccion(opcion.key),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segmento extends StatelessWidget {
  const _Segmento({
    required this.etiqueta,
    required this.activo,
    required this.onTap,
  });

  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activo,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.full,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(
            minHeight: AppSpacing.blancoDeToque,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            color: activo ? AppColors.secondaryContainer : Colors.transparent,
            borderRadius: AppRadius.full,
          ),
          child: Text(
            etiqueta,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodySm.copyWith(
              fontWeight: FontWeight.bold,
              color: activo
                  ? AppColors.onSecondaryContainer
                  : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip de filtro de una fila horizontal (turnos, loterias).
///
/// A diferencia del segmentado, aca las opciones son muchas y scrollean.
class ChipFiltro extends StatelessWidget {
  const ChipFiltro({
    super.key,
    required this.etiqueta,
    required this.activo,
    required this.onTap,
    this.color,
  });

  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;

  /// Acento del chip. Por defecto el verde de accion.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final acento = color ?? AppColors.secondary;

    return Semantics(
      button: true,
      selected: activo,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.full,
        // Ink y no Container: el splash del InkWell se pinta sobre el Material
        // que tiene debajo, asi que un fondo opaco encima lo tapa por completo.
        child: Ink(
          decoration: BoxDecoration(
            color: activo
                ? acento.withValues(alpha: 0.2)
                : AppColors.surfaceContainer,
            borderRadius: AppRadius.full,
            border: Border.all(
              color: activo
                  ? acento
                  : AppColors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.full,
            child: Container(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.blancoDeToque,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              alignment: Alignment.center,
              child: Text(
                etiqueta,
                style: AppText.bodySm.copyWith(
                  fontWeight: FontWeight.bold,
                  color: activo ? acento : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

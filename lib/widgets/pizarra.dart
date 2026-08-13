import 'package:flutter/material.dart';

import '../models/sorteo.dart';
import '../theme/acentos.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Las 20 posiciones de un sorteo, en dos columnas de 10.
///
/// [jugadaDestacada] pinta las posiciones donde acerto esa jugada, que es como
/// la busqueda de un numero muestra donde salio.
class PizarraSorteo extends StatelessWidget {
  const PizarraSorteo({
    super.key,
    required this.resultado,
    this.jugadaDestacada,
  });

  final ResultadoSorteo resultado;
  final String? jugadaDestacada;

  @override
  Widget build(BuildContext context) {
    final acento = acentoDe(resultado.loteria);
    final destacadas = jugadaDestacada == null
        ? const <int>{}
        : resultado.posicionesDe(jugadaDestacada!).toSet();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Columna(
            resultado: resultado,
            desde: 1,
            hasta: 10,
            acento: acento,
            destacadas: destacadas,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _Columna(
            resultado: resultado,
            desde: 11,
            hasta: 20,
            acento: acento,
            destacadas: destacadas,
          ),
        ),
      ],
    );
  }
}

class _Columna extends StatelessWidget {
  const _Columna({
    required this.resultado,
    required this.desde,
    required this.hasta,
    required this.acento,
    required this.destacadas,
  });

  final ResultadoSorteo resultado;
  final int desde;
  final int hasta;
  final Color acento;
  final Set<int> destacadas;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var p = desde; p <= hasta; p++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.base),
            child: _Fila(
              posicion: p,
              numero: resultado.posicion(p),
              acento: acento,
              esCabeza: p == 1,
              destacada: destacadas.contains(p),
              jugada: null,
            ),
          ),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.posicion,
    required this.numero,
    required this.acento,
    required this.esCabeza,
    required this.destacada,
    required this.jugada,
  });

  final int posicion;
  final String numero;
  final Color acento;
  final bool esCabeza;
  final bool destacada;
  final String? jugada;

  @override
  Widget build(BuildContext context) {
    // Una posicion destacada por busqueda gana sobre el resalte de cabeza: es
    // lo que el usuario vino a ver.
    final Color fondo;
    final Color texto;
    if (destacada) {
      fondo = AppColors.secondary.withValues(alpha: 0.22);
      texto = AppColors.secondaryFixed;
    } else if (esCabeza) {
      fondo = acento.withValues(alpha: 0.12);
      texto = acento;
    } else {
      fondo = AppColors.surfaceContainerLow;
      texto = AppColors.onSurface;
    }

    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Text(
            '$posicion',
            style: AppText.labelCaps.copyWith(
              color: esCabeza ? acento : AppColors.outline,
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.base,
            ),
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: AppRadius.allSm,
              border: destacada
                  ? Border.all(color: AppColors.secondary, width: 1.5)
                  : null,
            ),
            child: Text(
              numero,
              textAlign: TextAlign.center,
              style: AppText.dataDisplay.copyWith(fontSize: 16, color: texto),
            ),
          ),
        ),
      ],
    );
  }
}

/// Encabezado con la loteria, el turno y la hora, como lo usan las tarjetas de
/// resultados y el detalle.
class EncabezadoSorteo extends StatelessWidget {
  const EncabezadoSorteo({super.key, required this.resultado, this.compacto = false});

  final ResultadoSorteo resultado;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final acento = acentoDe(resultado.loteria);
    return Row(
      children: [
        Icon(resultado.loteria.icono, color: acento, size: 20),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            compacto
                ? resultado.loteria.nombre
                : '${resultado.loteria.nombre} - ${resultado.turno.nombre}',
            style: AppText.headlineMd.copyWith(color: AppColors.onSurface),
          ),
        ),
        Text(
          resultado.turno.horarioFormateado,
          style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

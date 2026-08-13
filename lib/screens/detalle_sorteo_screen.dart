import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/sorteo.dart';
import '../theme/acentos.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/bolilla_numero.dart';
import '../widgets/pizarra.dart';

/// Pizarra completa de un sorteo, con la cabeza destacada y el extracto.
class DetalleSorteoScreen extends StatelessWidget {
  const DetalleSorteoScreen({
    super.key,
    required this.resultado,
    this.jugadaDestacada,
  });

  final ResultadoSorteo resultado;

  /// Si se llego desde la busqueda, se resaltan las posiciones que acertaron.
  final String? jugadaDestacada;

  String get _textoParaCompartir {
    final fecha = DateFormat('dd/MM/yyyy').format(resultado.fecha);
    final lineas = [
      '${resultado.loteria.nombre} - ${resultado.turno.nombre}',
      '$fecha ${resultado.turno.horarioFormateado}'
          '${resultado.sorteo != null ? ' - Sorteo ${resultado.sorteo}' : ''}',
      '',
      for (var p = 1; p <= 20; p++)
        '${p.toString().padLeft(2, '0')}  ${resultado.posicion(p)}',
      if (resultado.letras case final letras?) ...['', 'Letras: $letras'],
    ];
    return lineas.join('\n');
  }

  void _copiar(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _textoParaCompartir));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Pizarra copiada'),
        backgroundColor: AppColors.surfaceContainerHighest,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final acento = acentoDe(resultado.loteria);
    final fecha = DateFormat("EEEE d 'de' MMMM", 'es').format(resultado.fecha);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDim,
        foregroundColor: AppColors.onSurface,
        title: Text(
          resultado.loteria.nombre,
          style: AppText.headlineMd.copyWith(color: AppColors.onSurface),
        ),
        actions: [
          IconButton(
            onPressed: () => _copiar(context),
            icon: const Icon(Icons.copy),
            tooltip: 'Copiar pizarra',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.containerMargin),
        children: [
          TarjetaSuperficie(
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(resultado.loteria.icono, color: acento),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resultado.turno.nombre,
                            style: AppText.headlineMd.copyWith(
                              color: AppColors.onSurface,
                            ),
                          ),
                          Text(
                            // Capitaliza el dia, que el formateo devuelve en
                            // minuscula.
                            '${fecha[0].toUpperCase()}${fecha.substring(1)} - '
                            '${resultado.turno.horarioFormateado}',
                            style: AppText.bodySm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                BolillaNumero(
                  numero: resultado.cabezaDosCifras,
                  color: acento,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'A la cabeza: ${resultado.cabeza}',
                  style: AppText.dataDisplay.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TarjetaSuperficie(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Las 20 posiciones',
                        style: AppText.headlineMd.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    if (resultado.sorteo case final sorteo?)
                      Text(
                        'Sorteo $sorteo',
                        style: AppText.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                PizarraSorteo(
                  resultado: resultado,
                  jugadaDestacada: jugadaDestacada,
                ),
                if (resultado.letras case final letras?) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Text(
                        'LETRAS',
                        style: AppText.labelCaps.copyWith(
                          color: AppColors.outline,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        letras,
                        style: AppText.dataDisplay.copyWith(color: acento),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => _copiar(context),
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copiar pizarra'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.secondary,
              side: const BorderSide(color: AppColors.outlineVariant),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            ),
          ),
        ],
      ),
    );
  }
}

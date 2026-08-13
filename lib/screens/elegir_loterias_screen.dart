import 'package:flutter/material.dart';

import '../data/preferencias.dart';
import '../models/sorteo.dart';
import '../theme/acentos.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

/// Elegir que loterias seguir y en que orden aparecen en el inicio.
class ElegirLoteriasScreen extends StatefulWidget {
  const ElegirLoteriasScreen({super.key, required this.preferencias});

  final PreferenciasLoterias preferencias;

  @override
  State<ElegirLoteriasScreen> createState() => _ElegirLoteriasScreenState();
}

class _ElegirLoteriasScreenState extends State<ElegirLoteriasScreen> {
  /// Todas las loterias en el orden en que se van a mostrar: primero las
  /// seguidas (en su orden), despues el resto.
  late List<Loteria> _orden;
  late Set<Loteria> _seguidas;

  @override
  void initState() {
    super.initState();
    final favoritas = widget.preferencias.favoritas;
    _seguidas = favoritas.toSet();
    _orden = [
      ...favoritas,
      ...Loteria.values.where((l) => !favoritas.contains(l)),
    ];
  }

  void _alternar(Loteria loteria) {
    setState(() {
      if (_seguidas.contains(loteria)) {
        _seguidas.remove(loteria);
      } else {
        _seguidas.add(loteria);
      }
    });
  }

  void _reordenar(int desde, int hasta) {
    setState(() {
      // onReorderItem ya entrega el indice destino compensado por la fila que
      // se saca, asi que va directo.
      final item = _orden.removeAt(desde);
      _orden.insert(hasta, item);
    });
  }

  Future<void> _guardar() async {
    final favoritas = _orden.where(_seguidas.contains).toList();
    await widget.preferencias.guardar(favoritas);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ninguna = _seguidas.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDim,
        foregroundColor: AppColors.onSurface,
        title: Text(
          'Mis loterias',
          style: AppText.headlineMd.copyWith(color: AppColors.onSurface),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.containerMargin,
              AppSpacing.sm,
              AppSpacing.containerMargin,
              0,
            ),
            child: Text(
              'Marca las que seguis y arrastra para ordenarlas. El inicio las '
              'muestra en este orden.',
              style: AppText.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(AppSpacing.containerMargin),
              itemCount: _orden.length,
              onReorderItem: _reordenar,
              proxyDecorator: (child, _, _) => Material(
                color: Colors.transparent,
                child: child,
              ),
              itemBuilder: (context, i) {
                final loteria = _orden[i];
                return Padding(
                  key: ValueKey(loteria),
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: _FilaLoteria(
                    loteria: loteria,
                    seguida: _seguidas.contains(loteria),
                    indice: i,
                    onAlternar: () => _alternar(loteria),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.containerMargin),
              child: Column(
                children: [
                  if (ninguna)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(
                        'Sin ninguna marcada se vuelve a Nacional y Provincia.',
                        textAlign: TextAlign.center,
                        style: AppText.bodySm.copyWith(
                          color: AppColors.tertiary,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _guardar,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondaryContainer,
                        foregroundColor: AppColors.onSecondaryContainer,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.allXl,
                        ),
                      ),
                      child: Text(
                        'Guardar',
                        style: AppText.bodyLg.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaLoteria extends StatelessWidget {
  const _FilaLoteria({
    required this.loteria,
    required this.seguida,
    required this.indice,
    required this.onAlternar,
  });

  final Loteria loteria;
  final bool seguida;
  final int indice;
  final VoidCallback onAlternar;

  @override
  Widget build(BuildContext context) {
    final acento = acentoDe(loteria);
    final turnos = loteria.turnosQueJuega;

    return TarjetaSuperficie(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      color: seguida
          ? AppColors.surfaceContainerHigh
          : AppColors.surfaceContainerLow,
      child: Row(
        children: [
          Checkbox(
            value: seguida,
            onChanged: (_) => onAlternar(),
            activeColor: AppColors.secondaryContainer,
            checkColor: AppColors.onSecondaryContainer,
            side: const BorderSide(color: AppColors.outline),
          ),
          Icon(loteria.icono, color: acento, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loteria.nombre,
                  style: AppText.bodyLg.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  // Aclarar los turnos importa: Montevideo solo juega dos, y
                  // sin decirlo parece que faltan datos.
                  turnos.length == TurnoSorteo.values.length
                      ? 'Los 5 turnos'
                      : turnos.map((t) => t.nombre).join(' y '),
                  style: AppText.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ReorderableDragStartListener(
            index: indice,
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.xs),
              child: Icon(Icons.drag_handle, color: AppColors.outline),
            ),
          ),
        ],
      ),
    );
  }
}

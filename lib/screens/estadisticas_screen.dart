import 'package:flutter/material.dart';

import '../data/preferencias.dart';
import '../data/quiniela_repository.dart';
import '../models/sorteo.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

/// Numeros calientes y frios sobre una ventana de dias.
class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({
    super.key,
    required this.repositorio,
    required this.preferencias,
  });

  final QuinielaRepository repositorio;
  final PreferenciasLoterias preferencias;

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  // 90 dias contra la fuente real serian ~900 sorteos: se probo y el spinner no
  // termina nunca. La ventana arranca en 7, que carga en segundos, y el techo
  // queda en 30.
  static const _ventanas = [7, 14, 30];

  int _dias = 7;
  late Future<List<FrecuenciaNumero>> _frecuencias;

  @override
  void initState() {
    super.initState();
    _frecuencias = _cargar();
    widget.preferencias.addListener(_recargar);
  }

  @override
  void dispose() {
    widget.preferencias.removeListener(_recargar);
    super.dispose();
  }

  Future<List<FrecuenciaNumero>> _cargar() => widget.repositorio.frecuencias(
        dias: _dias,
        loterias: widget.preferencias.favoritas,
      );

  void _recargar() {
    final futuro = _cargar();
    setState(() {
      _frecuencias = futuro;
    });
  }

  void _cambiarVentana(int dias) {
    if (dias == _dias) return;
    _dias = dias;
    _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const QuinielaAppBar(),
      body: FutureBuilder<List<FrecuenciaNumero>>(
        future: _frecuencias,
        builder: (context, snapshot) {
          final cargando = snapshot.connectionState != ConnectionState.done;
          final frecuencias = snapshot.data ?? const <FrecuenciaNumero>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.containerMargin,
              AppSpacing.md,
              AppSpacing.containerMargin,
              120,
            ),
            children: [
              const TituloSeccion('Estadisticas'),
              const SizedBox(height: AppSpacing.base),
              Text(
                'Cuantas veces salio cada numero a 2 cifras, contando las 20 '
                'posiciones de '
                '${widget.preferencias.favoritas.map((l) => l.nombre).join(", ")}.',
                style: AppText.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _SelectorVentana(
                dias: _dias,
                opciones: _ventanas,
                onCambio: _cambiarVentana,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (cargando)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.secondary,
                    ),
                  ),
                )
              else ...[
                _TarjetaNumeros(
                  titulo: 'Numeros calientes',
                  subtitulo: 'Los que mas salieron en $_dias dias',
                  icono: Icons.local_fire_department,
                  acento: AppColors.tertiary,
                  numeros: frecuencias.take(6).toList(),
                ),
                const SizedBox(height: AppSpacing.md),
                _TarjetaNumeros(
                  titulo: 'Numeros frios',
                  subtitulo: 'Los que menos aparecieron',
                  icono: Icons.ac_unit,
                  acento: AppColors.primary,
                  numeros: frecuencias.reversed.take(6).toList(),
                ),
                const SizedBox(height: AppSpacing.md),
                _TarjetaRanking(
                  titulo: 'Ranking de apariciones',
                  frecuencias: frecuencias.take(10).toList(),
                ),
                const SizedBox(height: AppSpacing.md),
                _AvisoAzar(sorteos: frecuencias.firstOrNull?.sorteosAnalizados),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SelectorVentana extends StatelessWidget {
  const _SelectorVentana({
    required this.dias,
    required this.opciones,
    required this.onCambio,
  });

  final int dias;
  final List<int> opciones;
  final ValueChanged<int> onCambio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.full,
      ),
      child: Row(
        children: [
          for (final opcion in opciones)
            Expanded(
              child: GestureDetector(
                onTap: () => onCambio(opcion),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: opcion == dias
                        ? AppColors.secondaryContainer
                        : Colors.transparent,
                    borderRadius: AppRadius.full,
                  ),
                  child: Text(
                    '$opcion dias',
                    textAlign: TextAlign.center,
                    style: AppText.bodySm.copyWith(
                      fontWeight: FontWeight.bold,
                      color: opcion == dias
                          ? AppColors.onSecondaryContainer
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TarjetaNumeros extends StatelessWidget {
  const _TarjetaNumeros({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.acento,
    required this.numeros,
  });

  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color acento;
  final List<FrecuenciaNumero> numeros;

  @override
  Widget build(BuildContext context) {
    return TarjetaSuperficie(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: acento),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: AppText.headlineMd.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      subtitulo,
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
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final f in numeros)
                Container(
                  width: 72,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: acento.withValues(alpha: 0.12),
                    borderRadius: AppRadius.allLg,
                    border: Border.all(
                      color: acento.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        f.numero,
                        style: AppText.data(24).copyWith(color: acento),
                      ),
                      const SizedBox(height: AppSpacing.base),
                      Text(
                        '${f.apariciones}x',
                        style: AppText.labelCaps.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ranking con barras proporcionales al numero mas frecuente.
class _TarjetaRanking extends StatelessWidget {
  const _TarjetaRanking({required this.titulo, required this.frecuencias});

  final String titulo;
  final List<FrecuenciaNumero> frecuencias;

  @override
  Widget build(BuildContext context) {
    final maximo = frecuencias.isEmpty
        ? 1
        : frecuencias.map((f) => f.apariciones).reduce((a, b) => a > b ? a : b);

    return TarjetaSuperficie(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: AppText.headlineMd.copyWith(color: AppColors.onSurface),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final f in frecuencias)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      f.numero,
                      style: AppText.dataDisplay.copyWith(
                        color: AppColors.tertiary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: AppRadius.full,
                      child: LinearProgressIndicator(
                        value: maximo == 0 ? 0 : f.apariciones / maximo,
                        minHeight: 10,
                        backgroundColor: AppColors.surfaceContainerLowest,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.secondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${f.apariciones}',
                      textAlign: TextAlign.right,
                      style: AppText.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AvisoAzar extends StatelessWidget {
  const _AvisoAzar({required this.sorteos});

  final int? sorteos;

  @override
  Widget build(BuildContext context) {
    return TarjetaSuperficie(
      color: AppColors.surfaceContainerLow,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.outline, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Sobre ${sorteos ?? 0} sorteos analizados. Cada sorteo es '
              'independiente: que un numero venga caliente o frio no cambia '
              'su probabilidad de salir.',
              style: AppText.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../data/preferencias.dart';
import '../data/quiniela_repository.dart';
import '../models/sorteo.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/banner_anuncio.dart';
import '../widgets/controles.dart';
import '../widgets/esqueleto.dart';

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
  // 90 dias contra la fuente real serian ~900 sorteos: se probo y no termina
  // nunca. La ventana arranca en 7, que carga en segundos, y el techo queda
  // en 30.
  static const _ventanas = {7: '7 dias', 14: '14 dias', 30: '30 dias'};

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
              // Arriba de todo: es la unica posicion que se ve sin scrollear.
              // Va antes del titulo y separado del selector de dias, que es el
              // unico control de la pantalla.
              const BannerAnuncio(),
              const SizedBox(height: AppSpacing.xs),
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
              SelectorSegmentado<int>(
                etiqueta: 'Ventana de analisis',
                opciones: _ventanas,
                seleccionada: _dias,
                onSeleccion: _cambiarVentana,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (cargando)
                const _EsqueletoEstadisticas()
              // Sin esta rama un fallo de red pinta las tarjetas vacias y
              // "Sobre 0 sorteos analizados", sin manera de reintentar.
              else if (snapshot.hasError)
                _FalloDeCarga(onReintentar: _recargar)
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

/// Silueta de las tres tarjetas mientras se juntan los sorteos.
///
/// Aca la espera es de las largas de la app (30 dias son cientos de sorteos),
/// asi que importa que se vea que viene y con que forma.
class _EsqueletoEstadisticas extends StatelessWidget {
  const _EsqueletoEstadisticas();

  @override
  Widget build(BuildContext context) {
    return EsqueletoDeLista(
      etiqueta: 'Calculando las estadisticas',
      child: Column(
        children: [
          for (var tarjeta = 0; tarjeta < 2; tarjeta++) ...[
            TarjetaSuperficie(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Esqueleto(alto: 24, ancho: 24, radio: AppRadius.full),
                      SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Esqueleto(alto: 20, ancho: 160),
                            SizedBox(height: AppSpacing.base),
                            Esqueleto(alto: 14, ancho: 200),
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
                      for (var i = 0; i < 6; i++)
                        const Esqueleto(
                          alto: 72,
                          ancho: 72,
                          radio: AppRadius.allLg,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          TarjetaSuperficie(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Esqueleto(alto: 20, ancho: 200),
                const SizedBox(height: AppSpacing.md),
                for (var i = 0; i < 6; i++)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: [
                        Esqueleto(alto: 16, ancho: 28),
                        SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Esqueleto(alto: 10, radio: AppRadius.full),
                        ),
                        SizedBox(width: AppSpacing.xs),
                        Esqueleto(alto: 14, ancho: 32),
                      ],
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

/// No se pudo armar la estadistica. Distinto de una ventana sin sorteos.
class _FalloDeCarga extends StatelessWidget {
  const _FalloDeCarga({required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return TarjetaSuperficie(
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 32, color: AppColors.error),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'No pudimos armar las estadisticas',
            textAlign: TextAlign.center,
            style: AppText.bodyLg.copyWith(color: AppColors.onSurface),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            'Hacen falta los resultados del sitio oficial. Revisa la conexion '
            'y volve a probar.',
            textAlign: TextAlign.center,
            style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: onReintentar,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reintentar'),
            style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
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
                Semantics(
                  label: 'Numero ${f.numero}, salio ${f.apariciones} veces',
                  excludeSemantics: true,
                  child: Container(
                    // minWidth y no width: con el texto al 200% el numero de
                    // dos cifras ya no entra en 72px fijos.
                    constraints: const BoxConstraints(minWidth: 72),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
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
                      mainAxisSize: MainAxisSize.min,
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
              child: Semantics(
                label: 'Numero ${f.numero}, ${f.apariciones} apariciones',
                excludeSemantics: true,
                child: Row(
                  children: [
                    Text(
                      f.numero,
                      style: AppText.dataDisplay.copyWith(
                        color: AppColors.tertiary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
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
                    Text(
                      '${f.apariciones}',
                      textAlign: TextAlign.right,
                      style: AppText.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
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

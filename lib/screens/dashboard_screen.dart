import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/preferencias.dart';
import '../data/quiniela_repository.dart';
import '../models/sorteo.dart';
import '../theme/acentos.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/banner_anuncio.dart';
import '../widgets/bolilla_numero.dart';
import '../widgets/esqueleto.dart';
import '../widgets/ticker_ultimo_minuto.dart';
import 'buscar_numero_screen.dart';
import 'detalle_sorteo_screen.dart';
import 'elegir_loterias_screen.dart';

/// Pantalla de inicio: aviso de ultimo minuto, acceso al generador, ultimo
/// resultado de cada loteria que sigue el usuario, y la agenda del dia.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.repositorio,
    required this.preferencias,
    required this.onGenerarJugada,
    required this.onVerResultados,
  });

  final QuinielaRepository repositorio;
  final PreferenciasLoterias preferencias;
  final VoidCallback onGenerarJugada;
  final VoidCallback onVerResultados;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DatosDashboard> _datos;

  /// Con que favoritas se cargo lo que esta en pantalla, para saber si cambiaron.
  List<Loteria> _favoritasCargadas = const [];

  @override
  void initState() {
    super.initState();
    _datos = _cargar();
    widget.preferencias.addListener(_alCambiarFavoritas);
  }

  @override
  void dispose() {
    widget.preferencias.removeListener(_alCambiarFavoritas);
    super.dispose();
  }

  /// Si el usuario cambio las loterias que sigue, hay que volver a pedir.
  void _alCambiarFavoritas() {
    final favoritas = widget.preferencias.favoritas;
    final iguales = favoritas.length == _favoritasCargadas.length &&
        List.generate(
          favoritas.length,
          (i) => favoritas[i] == _favoritasCargadas[i],
        ).every((x) => x);
    if (iguales) return;

    final futuro = _cargar();
    setState(() {
      _datos = futuro;
    });
  }

  Future<_DatosDashboard> _cargar() async {
    final favoritas = widget.preferencias.favoritas;
    _favoritasCargadas = favoritas;

    final (aviso, ultimos, agenda) = await (
      widget.repositorio.avisoUltimoMinuto(),
      widget.repositorio.ultimosResultados(favoritas),
      widget.repositorio.sorteosDeHoy(),
    ).wait;
    return _DatosDashboard(aviso: aviso, ultimos: ultimos, agenda: agenda);
  }

  Future<void> _refrescar() async {
    final futuro = _cargar();
    setState(() {
      _datos = futuro;
    });
    await futuro;
  }

  void _abrirBusqueda() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BuscarNumeroScreen(
          repositorio: widget.repositorio,
          loterias: widget.preferencias.favoritas,
        ),
      ),
    );
  }

  void _abrirDetalle(ResultadoSorteo resultado) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetalleSorteoScreen(resultado: resultado),
      ),
    );
  }

  void _elegirLoterias() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ElegirLoteriasScreen(preferencias: widget.preferencias),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: QuinielaAppBar(onBuscar: _abrirBusqueda),
      body: FutureBuilder<_DatosDashboard>(
        future: _datos,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _EsqueletoDashboard();
          }
          if (snapshot.hasError) {
            return _ErrorCarga(onReintentar: _refrescar);
          }

          final datos = snapshot.requireData;
          return RefreshIndicator(
            onRefresh: _refrescar,
            color: AppColors.secondary,
            backgroundColor: AppColors.surfaceContainer,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.containerMargin,
                AppSpacing.md,
                AppSpacing.containerMargin,
                120,
              ),
              children: [
                TickerUltimoMinuto(mensaje: datos.aviso),
                const SizedBox(height: AppSpacing.md),
                _BotonGenerar(onPressed: widget.onGenerarJugada),
                // Debajo del boton: es la unica posicion del inicio que se ve
                // sin scrollear. Se deja la separacion grande y el rotulo
                // "PUBLICIDAD" arriba -- unos 49px entre el boton y el anuncio
                // -- porque este es el boton que mas se toca de la app y un
                // anuncio pegado ahi es de donde salen los clics por accidente.
                const SizedBox(height: AppSpacing.lg),
                const BannerAnuncio(),
                const SizedBox(height: AppSpacing.md),
                TituloSeccion(
                  'Ultimos Resultados',
                  accion: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _elegirLoterias,
                        icon: const Icon(Icons.tune, size: 20),
                        color: AppColors.secondary,
                        tooltip: 'Elegir loterias',
                      ),
                      Flexible(
                        child: TextButton(
                          onPressed: widget.onVerResultados,
                          child: Text(
                            'Ver todos',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodySm.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Con la fuente real, una lista vacia casi siempre significa
                // que no hubo forma de llegar al sitio oficial. Quedarse mudo
                // haria parecer que no hay sorteos.
                if (datos.ultimos.isEmpty)
                  _SinDatos(onReintentar: _refrescar)
                else
                  for (final resultado in datos.ultimos) ...[
                    _TarjetaResultado(
                      resultado: resultado,
                      onTap: () => _abrirDetalle(resultado),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                const SizedBox(height: AppSpacing.xs),
                const TituloSeccion('Sorteos de Hoy'),
                const SizedBox(height: AppSpacing.md),
                _AgendaDelDia(sorteos: datos.agenda),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DatosDashboard {
  const _DatosDashboard({
    required this.aviso,
    required this.ultimos,
    required this.agenda,
  });

  final String aviso;
  final List<ResultadoSorteo> ultimos;
  final List<SorteoDelDia> agenda;
}

class _BotonGenerar extends StatelessWidget {
  const _BotonGenerar({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.allXl,
        boxShadow: [
          BoxShadow(
            color: AppColors.secondaryContainer.withValues(alpha: 0.3),
            blurRadius: 24,
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.secondaryContainer,
          foregroundColor: AppColors.onSecondaryContainer,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.allXl),
        ),
        icon: const Icon(Icons.casino, size: 26),
        label: Text(
          'Generar Numero de la Suerte',
          textAlign: TextAlign.center,
          style: AppText.headlineMd.copyWith(
            color: AppColors.onSecondaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta con la cabeza del ultimo sorteo de una loteria.
class _TarjetaResultado extends StatelessWidget {
  const _TarjetaResultado({required this.resultado, required this.onTap});

  final ResultadoSorteo resultado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final acento = acentoDe(resultado.loteria);
    final fecha = DateFormat('d MMM', 'es').format(resultado.fecha);

    return TarjetaSuperficie(
      onTap: onTap,
      semantica: '${resultado.loteria.nombre}, ${resultado.turno.nombre} '
          'del $fecha. A la cabeza: ${resultado.cabeza}. '
          'Abre las 20 posiciones.',
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resultado.loteria.nombre,
                      style: AppText.headlineMd.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      '${resultado.turno.nombre} - $fecha, '
                      '${resultado.turno.horarioFormateado}',
                      style: AppText.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(resultado.loteria.icono, color: acento),
              // La tarjeta entera abre el detalle; el chevron es el unico
              // cartel que hace falta. Antes convivia con un "Ver las 20" que
              // ademas desbordaba la fila en pantallas de 320px.
              const Icon(
                Icons.chevron_right,
                color: AppColors.outline,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          BolillaNumero(
            numero: resultado.cabezaDosCifras,
            color: acento,
            semantica: 'A la cabeza: ${resultado.cabezaDosCifras}',
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            resultado.cabeza,
            style: AppText.dataDisplay.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaDelDia extends StatelessWidget {
  const _AgendaDelDia({required this.sorteos});

  final List<SorteoDelDia> sorteos;

  @override
  Widget build(BuildContext context) {
    return TarjetaSuperficie(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < sorteos.length; i++)
            _FilaSorteo(
              sorteo: sorteos[i],
              conSeparador: i < sorteos.length - 1,
            ),
        ],
      ),
    );
  }
}

class _FilaSorteo extends StatelessWidget {
  const _FilaSorteo({required this.sorteo, required this.conSeparador});

  final SorteoDelDia sorteo;
  final bool conSeparador;

  @override
  Widget build(BuildContext context) {
    final enVivo = sorteo.estado == EstadoSorteo.enVivo;
    final finalizado = sorteo.estado == EstadoSorteo.finalizado;

    // Un turno que ya paso se apaga con color, no con Opacity: el 0.6 que habia
    // antes dejaba el texto secundario en 4.28:1 sobre el fondo, por debajo del
    // 4.5:1 que pide AA. El outline es un token del sistema y da 5.1:1.
    final colorTitulo = switch (sorteo.estado) {
      EstadoSorteo.enVivo => AppColors.secondary,
      EstadoSorteo.finalizado => AppColors.onSurfaceVariant,
      EstadoSorteo.proximo => AppColors.onSurface,
    };

    return Semantics(
      label: '${sorteo.turno.nombre}, '
          '${sorteo.turno.horarioFormateado}, ${sorteo.etiquetaEstado}',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: enVivo ? AppColors.surfaceContainerHigh : null,
          border: Border(
            left: BorderSide(
              color: enVivo ? AppColors.secondary : Colors.transparent,
              width: 4,
            ),
            bottom: conSeparador
                ? BorderSide(
                    color: AppColors.outlineVariant.withValues(alpha: 0.3),
                  )
                : BorderSide.none,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sorteo.turno.nombre,
                    style: AppText.bodyLg.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorTitulo,
                    ),
                  ),
                  Text(
                    sorteo.turno.horarioFormateado,
                    style: AppText.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            // Flexible: con el texto del sistema al 200%, "Finalizado" mide mas
            // que la fila entera. El icono y la etiqueta de accesibilidad
            // siguen diciendo el estado aunque el texto se recorte.
            if (enVivo)
              const Flexible(child: _IndicadorEnVivo())
            else
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono ademas del texto: el estado no puede depender solo
                    // del color para quien no lo distingue.
                    Icon(
                      finalizado ? Icons.check_circle_outline : Icons.schedule,
                      size: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.base),
                    Flexible(
                      child: Text(
                        sorteo.etiquetaEstado,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}

class _IndicadorEnVivo extends StatefulWidget {
  const _IndicadorEnVivo();

  @override
  State<_IndicadorEnVivo> createState() => _IndicadorEnVivoState();
}

class _IndicadorEnVivoState extends State<_IndicadorEnVivo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0.2).animate(_pulso),
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.base),
        Flexible(
          child: Text(
            'En vivo',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodySm.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

/// Silueta del inicio mientras cargan los datos.
///
/// Reproduce la estructura real (franja, boton, dos tarjetas, agenda) para que
/// la pagina no salte cuando entran los resultados.
class _EsqueletoDashboard extends StatelessWidget {
  const _EsqueletoDashboard();

  @override
  Widget build(BuildContext context) {
    return EsqueletoDeLista(
      etiqueta: 'Cargando los ultimos resultados',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.containerMargin,
          AppSpacing.md,
          AppSpacing.containerMargin,
          120,
        ),
        children: [
          const Esqueleto(alto: 56, radio: AppRadius.allLg),
          const SizedBox(height: AppSpacing.md),
          const Esqueleto(alto: 56, radio: AppRadius.allXl),
          const SizedBox(height: AppSpacing.lg),
          const Esqueleto(alto: 24, ancho: 200),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < 2; i++) ...[
            TarjetaSuperficie(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Esqueleto(alto: 20, ancho: 120),
                            SizedBox(height: AppSpacing.base),
                            Esqueleto(alto: 14, ancho: 180),
                          ],
                        ),
                      ),
                      const Esqueleto(alto: 24, ancho: 24, radio: AppRadius.full),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Esqueleto(alto: 96, ancho: 96, radio: AppRadius.full),
                  const SizedBox(height: AppSpacing.sm),
                  const Esqueleto(alto: 14, ancho: 64),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.xs),
          const Esqueleto(alto: 24, ancho: 160),
          const SizedBox(height: AppSpacing.md),
          TarjetaSuperficie(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < TurnoSorteo.values.length; i++)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Esqueleto(alto: 16, ancho: 96),
                              SizedBox(height: AppSpacing.base),
                              Esqueleto(alto: 14, ancho: 48),
                            ],
                          ),
                        ),
                        Esqueleto(alto: 14, ancho: 72),
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

/// No llegaron resultados. Se muestra en el lugar de las tarjetas para que la
/// pantalla no quede con un hueco silencioso.
class _SinDatos extends StatelessWidget {
  const _SinDatos({required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return TarjetaSuperficie(
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off,
            size: 32,
            color: AppColors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'No pudimos traer los ultimos resultados',
            textAlign: TextAlign.center,
            style: AppText.bodyLg.copyWith(color: AppColors.onSurface),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            'Revisa la conexion y volve a probar.',
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

class _ErrorCarga extends StatelessWidget {
  const _ErrorCarga({required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: AppColors.error),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No pudimos traer los resultados',
            style: AppText.bodyLg.copyWith(color: AppColors.onSurface),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

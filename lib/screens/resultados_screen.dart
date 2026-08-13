import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/preferencias.dart';
import '../data/quiniela_repository.dart';
import '../data/reloj_argentina.dart';
import '../models/sorteo.dart';
import '../theme/acentos.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/pizarra.dart';
import 'buscar_numero_screen.dart';
import 'detalle_sorteo_screen.dart';

/// Pizarra historica: las 20 posiciones de cada sorteo, con filtros por dia,
/// turno y loteria.
class ResultadosScreen extends StatefulWidget {
  const ResultadosScreen({
    super.key,
    required this.repositorio,
    required this.preferencias,
  });

  final QuinielaRepository repositorio;
  final PreferenciasLoterias preferencias;

  @override
  State<ResultadosScreen> createState() => _ResultadosScreenState();
}

class _ResultadosScreenState extends State<ResultadosScreen> {
  DateTime _fecha = ahoraEnArgentina();
  TurnoSorteo? _turno;

  /// Null = todas las que sigue el usuario.
  Loteria? _loteria;

  late Future<List<ResultadoSorteo>> _resultados;

  @override
  void initState() {
    super.initState();
    _resultados = _cargar();
    widget.preferencias.addListener(_recargar);
  }

  @override
  void dispose() {
    widget.preferencias.removeListener(_recargar);
    super.dispose();
  }

  List<Loteria> get _loteriasAConsultar {
    final loteria = _loteria;
    if (loteria != null) return [loteria];
    return widget.preferencias.favoritas;
  }

  Future<List<ResultadoSorteo>> _cargar() => widget.repositorio.resultadosDe(
        fecha: _fecha,
        turno: _turno,
        loterias: _loteriasAConsultar,
      );

  void _recargar() {
    final futuro = _cargar();
    setState(() {
      _resultados = futuro;
    });
  }

  bool get _esHoy {
    final hoy = ahoraEnArgentina();
    return _fecha.year == hoy.year &&
        _fecha.month == hoy.month &&
        _fecha.day == hoy.day;
  }

  /// Mueve la fecha [dias] dias. No deja pasar de hoy: no hay resultados en el
  /// futuro.
  void _mover(int dias) {
    final nueva = _fecha.add(Duration(days: dias));
    final hoy = ahoraEnArgentina();
    if (nueva.isAfter(DateTime(hoy.year, hoy.month, hoy.day))) return;
    _fecha = nueva;
    _recargar();
  }

  Future<void> _elegirFecha() async {
    final hoy = ahoraEnArgentina();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: hoy.subtract(const Duration(days: 365)),
      lastDate: hoy,
      locale: const Locale('es'),
    );
    if (elegida != null) {
      _fecha = elegida;
      _recargar();
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: QuinielaAppBar(onBuscar: _abrirBusqueda),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.containerMargin,
              AppSpacing.sm,
              AppSpacing.containerMargin,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NavegadorDias(
                  fecha: _fecha,
                  esHoy: _esHoy,
                  onAnterior: () => _mover(-1),
                  onSiguiente: () => _mover(1),
                  onElegir: _elegirFecha,
                ),
                const SizedBox(height: AppSpacing.xs),
                _FiltroTurnos(
                  seleccionado: _turno,
                  onSeleccion: (turno) {
                    _turno = turno;
                    _recargar();
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                _FiltroLoterias(
                  seleccionada: _loteria,
                  disponibles: widget.preferencias.favoritas,
                  onSeleccion: (loteria) {
                    _loteria = loteria;
                    _recargar();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: GestureDetector(
              // Deslizar a los costados cambia de dia. Arrastrar a la izquierda
              // avanza, como pasar la hoja de un almanaque.
              onHorizontalDragEnd: (detalle) {
                final velocidad = detalle.primaryVelocity ?? 0;
                if (velocidad > 250) {
                  _mover(-1);
                } else if (velocidad < -250) {
                  _mover(1);
                }
              },
              child: FutureBuilder<List<ResultadoSorteo>>(
                future: _resultados,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.secondary,
                      ),
                    );
                  }
                  final resultados = snapshot.data ?? const [];
                  if (resultados.isEmpty) {
                    return const _SinResultados();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.containerMargin,
                      0,
                      AppSpacing.containerMargin,
                      120,
                    ),
                    itemCount: resultados.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, i) =>
                        _TarjetaPizarra(resultado: resultados[i]),
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

/// Flechas y fecha, con atajo a hoy.
class _NavegadorDias extends StatelessWidget {
  const _NavegadorDias({
    required this.fecha,
    required this.esHoy,
    required this.onAnterior,
    required this.onSiguiente,
    required this.onElegir,
  });

  final DateTime fecha;
  final bool esHoy;
  final VoidCallback onAnterior;
  final VoidCallback onSiguiente;
  final VoidCallback onElegir;

  @override
  Widget build(BuildContext context) {
    final etiqueta = esHoy
        ? 'Hoy'
        : DateFormat("EEEE d 'de' MMM", 'es').format(fecha);

    return Row(
      children: [
        IconButton(
          onPressed: onAnterior,
          icon: const Icon(Icons.chevron_left),
          color: AppColors.secondary,
          tooltip: 'Dia anterior',
        ),
        Expanded(
          child: GestureDetector(
            onTap: onElegir,
            child: Column(
              children: [
                Text(
                  '${etiqueta[0].toUpperCase()}${etiqueta.substring(1)}',
                  textAlign: TextAlign.center,
                  style: AppText.headlineLgMobile.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy').format(fecha),
                  style: AppText.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          // Sin resultados en el futuro: en hoy la flecha queda apagada.
          onPressed: esHoy ? null : onSiguiente,
          icon: const Icon(Icons.chevron_right),
          color: AppColors.secondary,
          disabledColor: AppColors.outlineVariant,
          tooltip: 'Dia siguiente',
        ),
      ],
    );
  }
}

class _FiltroTurnos extends StatelessWidget {
  const _FiltroTurnos({required this.seleccionado, required this.onSeleccion});

  final TurnoSorteo? seleccionado;
  final ValueChanged<TurnoSorteo?> onSeleccion;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            etiqueta: 'Todos',
            activo: seleccionado == null,
            onTap: () => onSeleccion(null),
          ),
          for (final turno in TurnoSorteo.values) ...[
            const SizedBox(width: AppSpacing.xs),
            _Chip(
              etiqueta: turno.nombre,
              activo: seleccionado == turno,
              onTap: () => onSeleccion(turno),
            ),
          ],
        ],
      ),
    );
  }
}

class _FiltroLoterias extends StatelessWidget {
  const _FiltroLoterias({
    required this.seleccionada,
    required this.disponibles,
    required this.onSeleccion,
  });

  final Loteria? seleccionada;
  final List<Loteria> disponibles;
  final ValueChanged<Loteria?> onSeleccion;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            etiqueta: 'Mis loterias',
            activo: seleccionada == null,
            onTap: () => onSeleccion(null),
          ),
          // Se ofrecen todas, no solo las seguidas: sirve para espiar una
          // loteria puntual sin tener que agregarla a favoritas.
          for (final loteria in Loteria.values) ...[
            const SizedBox(width: AppSpacing.xs),
            _Chip(
              etiqueta: loteria.nombre,
              activo: seleccionada == loteria,
              color: acentoDe(loteria),
              onTap: () => onSeleccion(loteria),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.etiqueta,
    required this.activo,
    required this.onTap,
    this.color,
  });

  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final acento = color ?? AppColors.secondary;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.full,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
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
        child: Text(
          etiqueta,
          style: AppText.bodySm.copyWith(
            fontWeight: FontWeight.bold,
            color: activo ? acento : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Pizarra completa de un sorteo, que ademas abre el detalle al tocarla.
class _TarjetaPizarra extends StatelessWidget {
  const _TarjetaPizarra({required this.resultado});

  final ResultadoSorteo resultado;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetalleSorteoScreen(resultado: resultado),
        ),
      ),
      borderRadius: AppRadius.allXl,
      child: TarjetaSuperficie(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EncabezadoSorteo(resultado: resultado),
            const SizedBox(height: AppSpacing.md),
            PizarraSorteo(resultado: resultado),
          ],
        ),
      ),
    );
  }
}

class _SinResultados extends StatelessWidget {
  const _SinResultados();

  @override
  Widget build(BuildContext context) {
    // ListView y no Column: hace falta que sea desplazable para que el gesto
    // horizontal de cambiar de dia siga funcionando con la pantalla vacia.
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.xl),
        const Icon(
          Icons.event_busy,
          size: 48,
          color: AppColors.onSurfaceVariant,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'No hay resultados para este dia',
          textAlign: TextAlign.center,
          style: AppText.bodyLg.copyWith(color: AppColors.onSurface),
        ),
        const SizedBox(height: AppSpacing.base),
        Text(
          'Los domingos no hay sorteo. Desliza a los costados o usa las flechas '
          'para cambiar de dia.',
          textAlign: TextAlign.center,
          style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

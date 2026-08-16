import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/quiniela_repository.dart';
import '../models/sorteo.dart';
import '../theme/acentos.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/controles.dart';
import '../widgets/esqueleto.dart';
import 'detalle_sorteo_screen.dart';

/// "Fijate si salio el 47": busca una jugada en los sorteos recientes.
class BuscarNumeroScreen extends StatefulWidget {
  const BuscarNumeroScreen({
    super.key,
    required this.repositorio,
    required this.loterias,
  });

  final QuinielaRepository repositorio;

  /// Loterias en las que buscar: las que sigue el usuario.
  final List<Loteria> loterias;

  @override
  State<BuscarNumeroScreen> createState() => _BuscarNumeroScreenState();
}

class _BuscarNumeroScreenState extends State<BuscarNumeroScreen> {
  static const _ventanas = {1: 'Hoy', 3: 'Ultimos 3', 7: 'Ultimos 7'};

  final _controlador = TextEditingController();

  int _dias = 3;
  String _jugadaBuscada = '';
  Future<List<AparicionNumero>>? _resultados;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _buscar() {
    final jugada = _controlador.text.trim();
    if (jugada.isEmpty) return;

    final futuro = widget.repositorio.buscarNumero(
      jugada: jugada,
      loterias: widget.loterias,
      dias: _dias,
    );
    setState(() {
      _jugadaBuscada = jugada;
      _resultados = futuro;
    });
  }

  void _cambiarVentana(int dias) {
    if (dias == _dias) return;
    setState(() => _dias = dias);
    if (_jugadaBuscada.isNotEmpty) _buscar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDim,
        foregroundColor: AppColors.onSurface,
        title: Text(
          'Buscar un numero',
          style: AppText.headlineMd.copyWith(color: AppColors.onSurface),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.containerMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controlador,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _buscar(),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  style: AppText.data(28).copyWith(color: AppColors.onSurface),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '00',
                    hintStyle: AppText.data(28).copyWith(
                      color: AppColors.outline,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceContainer,
                    suffixIcon: IconButton(
                      onPressed: _buscar,
                      icon: const Icon(Icons.search),
                      color: AppColors.secondary,
                      tooltip: 'Buscar',
                    ),
                    border: const OutlineInputBorder(
                      borderRadius: AppRadius.allXl,
                      borderSide: BorderSide(color: AppColors.outlineVariant),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: AppRadius.allXl,
                      borderSide: BorderSide(color: AppColors.outlineVariant),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: AppRadius.allXl,
                      borderSide: BorderSide(
                        color: AppColors.secondary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'De 1 a 4 cifras. Una jugada acierta cuando coincide con las '
                  'ultimas cifras del numero sorteado: al 4221 le acierta el 21.',
                  style: AppText.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SelectorSegmentado<int>(
                  etiqueta: 'Cuantos dias mirar',
                  opciones: _ventanas,
                  seleccionada: _dias,
                  onSeleccion: _cambiarVentana,
                ),
              ],
            ),
          ),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    final futuro = _resultados;
    if (futuro == null) {
      return _Mensaje(
        icono: Icons.search,
        titulo: 'Escribi un numero',
        detalle: 'Se busca en ${widget.loterias.length} loterias: '
            '${widget.loterias.map((l) => l.nombre).join(', ')}.',
      );
    }

    return FutureBuilder<List<AparicionNumero>>(
      future: futuro,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return EsqueletoDeLista(
            etiqueta: 'Buscando el $_jugadaBuscada',
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.containerMargin,
                0,
                AppSpacing.containerMargin,
                AppSpacing.lg,
              ),
              itemCount: 5,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (_, _) => const TarjetaSuperficie(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Esqueleto(alto: 20, ancho: 20, radio: AppRadius.full),
                    SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Esqueleto(alto: 16, ancho: 180),
                          SizedBox(height: AppSpacing.base),
                          Esqueleto(alto: 14, ancho: 120),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Sin este chequeo, un fallo de red se muestra como "el numero no
        // salio", que es afirmar algo falso sobre el sorteo.
        if (snapshot.hasError) {
          return _Mensaje(
            icono: Icons.cloud_off,
            titulo: 'No pudimos buscar el $_jugadaBuscada',
            detalle: 'No se pudo llegar a los resultados oficiales. Revisa la '
                'conexion y volve a probar.',
            onReintentar: _buscar,
          );
        }

        final apariciones = snapshot.data ?? const [];
        if (apariciones.isEmpty) {
          return _Mensaje(
            icono: Icons.sentiment_dissatisfied,
            titulo: 'El $_jugadaBuscada no salio',
            detalle: 'No aparecio en ninguna posicion en '
                '${_dias == 1 ? "el dia de hoy" : "los ultimos $_dias dias"}.',
          );
        }

        final aLaCabeza = apariciones.where((a) => a.aLaCabeza).length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.containerMargin,
            0,
            AppSpacing.containerMargin,
            AppSpacing.lg,
          ),
          children: [
            _Resumen(
              jugada: _jugadaBuscada,
              sorteos: apariciones.length,
              aLaCabeza: aLaCabeza,
              dias: _dias,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final aparicion in apariciones)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _FilaAparicion(
                  aparicion: aparicion,
                  jugada: _jugadaBuscada,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({
    required this.jugada,
    required this.sorteos,
    required this.aLaCabeza,
    required this.dias,
  });

  final String jugada;
  final int sorteos;
  final int aLaCabeza;
  final int dias;

  @override
  Widget build(BuildContext context) {
    return TarjetaSuperficie(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.15),
              borderRadius: AppRadius.allLg,
              border: Border.all(color: AppColors.secondary),
            ),
            alignment: Alignment.center,
            child: Text(
              jugada,
              style: AppText.data(24).copyWith(color: AppColors.secondaryFixed),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Salio en $sorteos ${sorteos == 1 ? "sorteo" : "sorteos"}',
                  style: AppText.headlineMd.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  aLaCabeza > 0
                      ? '$aLaCabeza ${aLaCabeza == 1 ? "vez" : "veces"} a la '
                          'cabeza - ultimos $dias dias'
                      : 'Ninguna a la cabeza - ultimos $dias dias',
                  style: AppText.bodySm.copyWith(
                    color: aLaCabeza > 0
                        ? AppColors.tertiary
                        : AppColors.onSurfaceVariant,
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

class _FilaAparicion extends StatelessWidget {
  const _FilaAparicion({required this.aparicion, required this.jugada});

  final AparicionNumero aparicion;
  final String jugada;

  @override
  Widget build(BuildContext context) {
    final resultado = aparicion.resultado;
    final acento = acentoDe(resultado.loteria);
    final fecha = DateFormat('d MMM', 'es').format(resultado.fecha);

    final posiciones = aparicion.posiciones.join(', ');

    return TarjetaSuperficie(
      padding: const EdgeInsets.all(AppSpacing.sm),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetalleSorteoScreen(
            resultado: resultado,
            jugadaDestacada: jugada,
          ),
        ),
      ),
      semantica: '${resultado.loteria.nombre}, ${resultado.turno.nombre} '
          'del $fecha. El $jugada salio en '
          '${aparicion.posiciones.length == 1 ? "la posicion" : "las posiciones"} '
          '$posiciones'
          '${aparicion.aLaCabeza ? ", a la cabeza" : ""}. Abre la pizarra.',
      child: Row(
        children: [
          Icon(resultado.loteria.icono, color: acento, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${resultado.loteria.nombre} - ${resultado.turno.nombre}',
                  style: AppText.bodyLg.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$fecha - posicion $posiciones',
                  style: AppText.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (aparicion.aLaCabeza) ...[
            const SizedBox(width: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.base,
              ),
              decoration: BoxDecoration(
                color: AppColors.tertiary.withValues(alpha: 0.15),
                borderRadius: AppRadius.full,
                border: Border.all(color: AppColors.tertiary),
              ),
              child: Text(
                'CABEZA',
                style: AppText.labelCaps.copyWith(
                  color: AppColors.tertiary,
                ),
              ),
            ),
          ],
          const Icon(Icons.chevron_right, color: AppColors.outline),
        ],
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({
    required this.icono,
    required this.titulo,
    required this.detalle,
    this.onReintentar,
  });

  final IconData icono;
  final String titulo;
  final String detalle;

  /// Si viene, se muestra un boton para volver a intentar.
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 44,
              color: onReintentar == null
                  ? AppColors.onSurfaceVariant
                  : AppColors.error,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: AppText.headlineMd.copyWith(color: AppColors.onSurface),
            ),
            const SizedBox(height: AppSpacing.base),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: AppText.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            if (onReintentar case final reintentar?) ...[
              const SizedBox(height: AppSpacing.xs),
              TextButton.icon(
                onPressed: reintentar,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/quiniela_repository.dart';
import '../data/reloj_argentina.dart';
import '../models/sorteo.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/banner_anuncio.dart';
import '../widgets/controles.dart';

/// Generador de jugadas + diccionario de suenos.
class GeneradorScreen extends StatefulWidget {
  const GeneradorScreen({super.key, required this.repositorio});

  final QuinielaRepository repositorio;

  @override
  State<GeneradorScreen> createState() => _GeneradorScreenState();
}

class _GeneradorScreenState extends State<GeneradorScreen> {
  static const _duracionSorteo = Duration(milliseconds: 700);
  static const _intervaloScramble = Duration(milliseconds: 60);

  final _random = Random();
  final _buscador = TextEditingController();

  int _cifras = 2;
  Jugada? _jugada;

  /// Digitos que se muestran; durante el "sorteo" van cambiando al azar.
  ///
  /// Va en un notifier y no en el State: la ruleta los cambia cada 60 ms, y con
  /// setState cada uno de esos frames reconstruia el ListView entero, incluidas
  /// las ~100 filas del diccionario de suenos. Asi solo se rearma la fila de
  /// casilleros.
  final _digitos = ValueNotifier<List<String>>(List.filled(2, '-'));
  bool _sorteando = false;
  Timer? _scramble;
  Timer? _fin;

  /// Suenos que se estan mostrando y si todavia no llego la primera tanda.
  ///
  /// Se guarda la lista y no un Future: cada tecla creaba un Future nuevo y el
  /// FutureBuilder volvia al estado "waiting", asi que la lista parpadeaba a
  /// spinner en cada pulsacion sobre un filtro que es de memoria.
  List<Sueno> _suenos = const [];
  bool _cargandoSuenos = true;

  @override
  void initState() {
    super.initState();
    _buscar('');
  }

  @override
  void dispose() {
    _scramble?.cancel();
    _fin?.cancel();
    _buscador.dispose();
    _digitos.dispose();
    super.dispose();
  }

  void _cambiarCifras(int cifras) {
    if (cifras == _cifras) return;
    _scramble?.cancel();
    _fin?.cancel();
    _digitos.value = List.filled(cifras, '-');
    setState(() {
      _cifras = cifras;
      _jugada = null;
      _sorteando = false;
    });
  }

  void _generar() {
    if (_sorteando) return;
    HapticFeedback.mediumImpact();
    final jugada = widget.repositorio.generarJugada(_cifras);

    setState(() {
      _sorteando = true;
      _jugada = null;
    });

    // Fase de "ruleta": los digitos rotan al azar y despues caen en el valor
    // real. Es puro efecto visual; el numero ya salio del repositorio.
    _scramble = Timer.periodic(_intervaloScramble, (_) {
      _digitos.value = List.generate(
        _cifras,
        (_) => _random.nextInt(10).toString(),
      );
    });

    _fin = Timer(_duracionSorteo, () {
      _scramble?.cancel();
      HapticFeedback.heavyImpact();
      _digitos.value = jugada.numero.split('');
      setState(() {
        _sorteando = false;
        _jugada = jugada;
      });
    });
  }

  void _copiar() {
    final jugada = _jugada;
    if (jugada == null) return;
    Clipboard.setData(ClipboardData(text: jugada.numero));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Jugada ${jugada.numero} copiada'),
        backgroundColor: AppColors.surfaceContainerHighest,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _buscar(String consulta) async {
    final resultados = await widget.repositorio.buscarSuenos(consulta);
    if (!mounted) return;
    // Una respuesta vieja puede llegar despues de una mas nueva; se descarta
    // para que la lista no quede mostrando el filtro anterior.
    if (consulta != _buscador.text) return;
    setState(() {
      _suenos = resultados;
      _cargandoSuenos = false;
    });
  }

  /// Un sueno del diccionario se puede jugar directo: pasa a ser la jugada.
  void _jugarSueno(Sueno sueno) {
    _scramble?.cancel();
    _fin?.cancel();
    HapticFeedback.selectionClick();
    _digitos.value = sueno.numero.split('');
    setState(() {
      _cifras = 2;
      _sorteando = false;
      _jugada = Jugada(numero: sueno.numero, generadaEn: ahoraEnArgentina());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const QuinielaAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.containerMargin,
          AppSpacing.md,
          AppSpacing.containerMargin,
          120,
        ),
        children: [
          const TituloSeccion('Generador de Jugadas'),
          const SizedBox(height: AppSpacing.base),
          Text(
            'Elegi cuantas cifras jugas y dale al bombo.',
            style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          _TarjetaGenerador(
            cifras: _cifras,
            digitos: _digitos,
            sorteando: _sorteando,
            hayJugada: _jugada != null,
            onCambiarCifras: _cambiarCifras,
            onGenerar: _generar,
            onCopiar: _copiar,
          ),
          const SizedBox(height: AppSpacing.lg),
          // Entre el generador y el diccionario. Es el corte de seccion mas
          // limpio de la pantalla y deja el anuncio lejos del boton "Generar":
          // un banner pegado al boton que la gente toca a repeticion es la
          // receta del clic accidental.
          const BannerAnuncio(),
          const SizedBox(height: AppSpacing.xs),
          const TituloSeccion('Diccionario de Suenos'),
          const SizedBox(height: AppSpacing.sm),
          _Buscador(controlador: _buscador, onCambio: _buscar),
          const SizedBox(height: AppSpacing.md),
          if (_cargandoSuenos)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.secondary),
              ),
            )
          else if (_suenos.isEmpty)
            _SinCoincidencias(consulta: _buscador.text)
          else ...[
            if (_buscador.text.trim().isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'POPULARES',
                    style: AppText.labelCaps.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                ),
              ),
            for (final sueno in _suenos)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _FilaSueno(
                  sueno: sueno,
                  onJugar: () => _jugarSueno(sueno),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TarjetaGenerador extends StatelessWidget {
  const _TarjetaGenerador({
    required this.cifras,
    required this.digitos,
    required this.sorteando,
    required this.hayJugada,
    required this.onCambiarCifras,
    required this.onGenerar,
    required this.onCopiar,
  });

  final int cifras;

  /// Los digitos cambian ~12 veces por segundo durante la ruleta, asi que se
  /// escuchan aparte: solo se rearma esta fila, no la pantalla entera.
  final ValueListenable<List<String>> digitos;

  final bool sorteando;
  final bool hayJugada;
  final ValueChanged<int> onCambiarCifras;
  final VoidCallback onGenerar;
  final VoidCallback onCopiar;

  @override
  Widget build(BuildContext context) {
    return TarjetaSuperficie(
      child: Column(
        children: [
          SelectorSegmentado<int>(
            etiqueta: 'Cuantas cifras jugar',
            opciones: const {
              1: '1 cifra',
              2: '2 cifras',
              3: '3 cifras',
              4: '4 cifras',
            },
            seleccionada: cifras,
            onSeleccion: onCambiarCifras,
          ),
          const SizedBox(height: AppSpacing.lg),
          // El ancho del casillero sale del espacio disponible: con cuatro
          // cifras fijas en 64px, la fila desbordaba 26px en un telefono de
          // 320px. Se reparte lo que hay y se le pone un techo para que con una
          // sola cifra no quede un cuadrado gigante.
          ValueListenableBuilder<List<String>>(
            valueListenable: digitos,
            builder: (context, valores, _) => LayoutBuilder(
              builder: (context, restricciones) {
                final separaciones = AppSpacing.xs * (valores.length - 1);
                final lado = ((restricciones.maxWidth - separaciones) /
                        valores.length)
                    .clamp(44.0, 64.0);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < valores.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.xs),
                      _SlotDigito(
                        digito: valores[i],
                        activo: sorteando,
                        lado: lado,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: sorteando ? null : onGenerar,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondaryContainer,
                    foregroundColor: AppColors.onSecondaryContainer,
                    disabledBackgroundColor:
                        AppColors.secondaryContainer.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.allXl,
                    ),
                  ),
                  icon: const Icon(Icons.casino),
                  label: Text(
                    sorteando ? 'Sorteando...' : 'Generar',
                    style: AppText.bodyLg.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton.filledTonal(
                onPressed: hayJugada ? onCopiar : null,
                icon: const Icon(Icons.copy),
                tooltip: 'Copiar jugada',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainerHighest,
                  foregroundColor: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Casillero de un digito. Se pinta en dorado cuando el numero ya quedo fijo.
class _SlotDigito extends StatelessWidget {
  const _SlotDigito({
    required this.digito,
    required this.activo,
    required this.lado,
  });

  final String digito;
  final bool activo;

  /// Ancho del casillero, que lo decide la fila segun lo que haya disponible.
  final double lado;

  @override
  Widget build(BuildContext context) {
    final definido = digito != '-';
    final color = activo
        ? AppColors.onSurfaceVariant
        : (definido ? AppColors.tertiary : AppColors.outline);

    return Container(
      width: lado,
      height: lado * 1.3,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.allXl,
        border: Border.all(
          color: definido && !activo
              ? AppColors.tertiary
              : AppColors.outlineVariant,
          width: 2,
        ),
        boxShadow: definido && !activo
            ? [
                BoxShadow(
                  color: AppColors.tertiary.withValues(alpha: 0.35),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      // El casillero tiene alto fijo: el digito no puede escalar sin limite.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Text(
          digito,
          style: AppText.data(lado * 0.62).copyWith(color: color),
        ),
      ),
    );
  }
}

class _Buscador extends StatelessWidget {
  const _Buscador({required this.controlador, required this.onCambio});

  final TextEditingController controlador;
  final ValueChanged<String> onCambio;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      onChanged: onCambio,
      style: AppText.bodyLg.copyWith(color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: 'Sone con... (perro, agua, plata)',
        hintStyle: AppText.bodyLg.copyWith(color: AppColors.outline),
        prefixIcon: const Icon(Icons.search, color: AppColors.outline),
        suffixIcon: controlador.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, color: AppColors.outline),
                onPressed: () {
                  controlador.clear();
                  onCambio('');
                },
              ),
        filled: true,
        fillColor: AppColors.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: AppRadius.allXl,
          borderSide: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.allXl,
          borderSide: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.allXl,
          borderSide: BorderSide(color: AppColors.secondary, width: 2),
        ),
      ),
    );
  }
}

class _FilaSueno extends StatelessWidget {
  const _FilaSueno({required this.sueno, required this.onJugar});

  final Sueno sueno;
  final VoidCallback onJugar;

  @override
  Widget build(BuildContext context) {
    return TarjetaSuperficie(
      onTap: onJugar,
      padding: const EdgeInsets.all(AppSpacing.sm),
      semantica: '${sueno.nombre}, numero ${sueno.numero}. '
          'Lo pone como jugada.',
      child: Row(
        children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.tertiaryContainer,
                borderRadius: AppRadius.allLg,
                border: Border.all(
                  color: AppColors.tertiary.withValues(alpha: 0.4),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                sueno.numero,
                style: AppText.dataDisplay.copyWith(
                  color: AppColors.tertiary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sueno.nombre,
                    style: AppText.bodyLg.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (sueno.sinonimos.isNotEmpty)
                    Text(
                      sueno.sinonimos.join(' - '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.outline,
          ),
        ],
      ),
    );
  }
}

class _SinCoincidencias extends StatelessWidget {
  const _SinCoincidencias({required this.consulta});

  final String consulta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          const Icon(
            Icons.bedtime_off_outlined,
            size: 40,
            color: AppColors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Nada para "$consulta"',
            style: AppText.bodyLg.copyWith(color: AppColors.onSurface),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            'Proba con otra palabra o con el numero.',
            style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

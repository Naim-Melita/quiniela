import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/quiniela_repository.dart';
import '../data/reloj_argentina.dart';
import '../models/sorteo.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

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
  List<String> _digitos = List.filled(2, '-');
  bool _sorteando = false;
  Timer? _scramble;
  Timer? _fin;

  late Future<List<Sueno>> _suenos;

  @override
  void initState() {
    super.initState();
    _suenos = widget.repositorio.buscarSuenos('');
  }

  @override
  void dispose() {
    _scramble?.cancel();
    _fin?.cancel();
    _buscador.dispose();
    super.dispose();
  }

  void _cambiarCifras(int cifras) {
    if (cifras == _cifras) return;
    _scramble?.cancel();
    _fin?.cancel();
    setState(() {
      _cifras = cifras;
      _jugada = null;
      _sorteando = false;
      _digitos = List.filled(cifras, '-');
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
      setState(() {
        _digitos = List.generate(
          _cifras,
          (_) => _random.nextInt(10).toString(),
        );
      });
    });

    _fin = Timer(_duracionSorteo, () {
      _scramble?.cancel();
      HapticFeedback.heavyImpact();
      setState(() {
        _sorteando = false;
        _jugada = jugada;
        _digitos = jugada.numero.split('');
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

  void _buscar(String consulta) {
    // Ojo: el cuerpo de setState no puede devolver un Future, y una asignacion
    // evalua al valor asignado. Con cuerpo de bloque devuelve void.
    final resultados = widget.repositorio.buscarSuenos(consulta);
    setState(() {
      _suenos = resultados;
    });
  }

  /// Un sueno del diccionario se puede jugar directo: pasa a ser la jugada.
  void _jugarSueno(Sueno sueno) {
    _scramble?.cancel();
    _fin?.cancel();
    HapticFeedback.selectionClick();
    setState(() {
      _cifras = 2;
      _sorteando = false;
      _jugada = Jugada(numero: sueno.numero, generadaEn: ahoraEnArgentina());
      _digitos = sueno.numero.split('');
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
          const TituloSeccion('Diccionario de Suenos'),
          const SizedBox(height: AppSpacing.sm),
          _Buscador(controlador: _buscador, onCambio: _buscar),
          const SizedBox(height: AppSpacing.md),
          FutureBuilder<List<Sueno>>(
            future: _suenos,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.secondary,
                    ),
                  ),
                );
              }
              final suenos = snapshot.data ?? const [];
              if (suenos.isEmpty) {
                return _SinCoincidencias(consulta: _buscador.text);
              }
              return Column(
                children: [
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
                  for (final sueno in suenos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: _FilaSueno(
                        sueno: sueno,
                        onJugar: () => _jugarSueno(sueno),
                      ),
                    ),
                ],
              );
            },
          ),
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
  final List<String> digitos;
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
          _SelectorCifras(cifras: cifras, onCambio: onCambiarCifras),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < digitos.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xs),
                _SlotDigito(digito: digitos[i], activo: sorteando),
              ],
            ],
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

class _SelectorCifras extends StatelessWidget {
  const _SelectorCifras({required this.cifras, required this.onCambio});

  final int cifras;
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
          for (var n = 1; n <= 4; n++)
            Expanded(
              child: GestureDetector(
                onTap: () => onCambio(n),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: n == cifras
                        ? AppColors.secondaryContainer
                        : Colors.transparent,
                    borderRadius: AppRadius.full,
                  ),
                  child: Text(
                    '$n ${n == 1 ? 'cifra' : 'cifras'}',
                    textAlign: TextAlign.center,
                    style: AppText.bodySm.copyWith(
                      fontWeight: FontWeight.bold,
                      color: n == cifras
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

/// Casillero de un digito. Se pinta en dorado cuando el numero ya quedo fijo.
class _SlotDigito extends StatelessWidget {
  const _SlotDigito({required this.digito, required this.activo});

  final String digito;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final definido = digito != '-';
    final color = activo
        ? AppColors.onSurfaceVariant
        : (definido ? AppColors.tertiary : AppColors.outline);

    return Container(
      width: 64,
      height: 84,
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
      child: Text(digito, style: AppText.data(40).copyWith(color: color)),
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
    return InkWell(
      onTap: onJugar,
      borderRadius: AppRadius.allXl,
      child: TarjetaSuperficie(
        padding: const EdgeInsets.all(AppSpacing.sm),
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

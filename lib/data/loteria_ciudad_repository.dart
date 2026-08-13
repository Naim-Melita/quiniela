import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/sorteo.dart';
import 'api/loteria_ciudad_api.dart';
import 'cache_resultados.dart';
import 'diccionario_suenos.dart';
import 'quiniela_repository.dart';
import 'reloj_argentina.dart';

/// Repositorio contra la fuente oficial (Loteria de la Ciudad).
///
/// Reparte el trabajo en dos vias segun la loteria: la Ciudad se resuelve con el
/// extracto XML, direccionable por fecha y turno; el resto necesita el numero de
/// sorteo del indice y sale del fragmento HTML. Ver [LoteriaCiudadApi].
///
/// Todo lo que se descarga pasa por [CacheResultados], porque un sorteo
/// publicado es inmutable.
class LoteriaCiudadRepository implements QuinielaRepository {
  LoteriaCiudadRepository({
    LoteriaCiudadApi? api,
    CacheResultados? cache,
    DateTime Function()? reloj,
  })  : _api = api ?? LoteriaCiudadApi(),
        _cache = cache ?? CacheResultados(),
        // Hora argentina, no la del telefono: ver reloj_argentina.dart.
        _ahora = reloj ?? ahoraEnArgentina;

  /// Cuantas peticiones en paralelo contra el sitio oficial.
  ///
  /// Es un servidor publico que no pedimos permiso para usar: seis en vuelo
  /// alcanza para que las estadisticas carguen en tiempo razonable sin
  /// convertir la app en una molestia.
  static const _concurrencia = 6;

  /// El indice de sorteos cambia solo cuando se publica un turno nuevo.
  static const _vigenciaIndice = Duration(minutes: 10);

  final LoteriaCiudadApi _api;
  final CacheResultados _cache;
  final DateTime Function() _ahora;

  final _randomJugadas = Random();

  List<EntradaIndice>? _indice;
  DateTime? _indiceActualizado;

  /// Turnos que ya deberian estar publicados a esta altura del dia.
  @override
  Future<List<SorteoDelDia>> sorteosDeHoy() async {
    final ahora = _ahora();
    final minutosAhora = ahora.hour * 60 + ahora.minute;

    return TurnoSorteo.values.map((turno) {
      final delta = minutosAhora - turno.minutosDelDia;
      final estado = switch (delta) {
        >= 15 => EstadoSorteo.finalizado,
        >= -5 => EstadoSorteo.enVivo,
        _ => EstadoSorteo.proximo,
      };
      return SorteoDelDia(turno: turno, estado: estado);
    }).toList();
  }

  @override
  Future<List<ResultadoSorteo>> ultimosResultados(
    List<Loteria> loterias,
  ) async {
    await _cache.cargar();

    // Se camina hacia atras turno por turno hasta encontrar el ultimo publicado
    // de cada loteria. No alcanza con mirar solo el ultimo turno del reloj: una
    // loteria puede demorar la carga, y los domingos no hay sorteo.
    final resultados = <Loteria, ResultadoSorteo>{};
    for (final (fecha, turno) in _turnosHaciaAtras(desde: _ahora()).take(12)) {
      final faltantes = loterias
          .where((l) => !resultados.containsKey(l))
          .toList();
      if (faltantes.isEmpty) break;

      final lote = await _traerLote([
        for (final loteria in faltantes)
          if (loteria.juega(turno)) (loteria, fecha, turno),
      ]);
      for (final r in lote) {
        resultados.putIfAbsent(r.loteria, () => r);
      }
    }

    await _cache.persistir();
    return [for (final loteria in loterias) ?resultados[loteria]];
  }

  @override
  Future<List<ResultadoSorteo>> resultadosDe({
    required DateTime fecha,
    TurnoSorteo? turno,
    List<Loteria> loterias = const [Loteria.nacional, Loteria.provincia],
  }) async {
    await _cache.cargar();

    final hoy = _soloFecha(_ahora());
    final dia = _soloFecha(fecha);
    if (dia.isAfter(hoy)) return const [];

    final turnos = turno == null ? TurnoSorteo.values : [turno];
    final pedidos = [
      for (final t in turnos)
        if (!(dia == hoy && !_yaSePublico(t)))
          for (final l in loterias)
            // Montevideo solo juega matutina y nocturna: pedir los otros
            // turnos seria gastar peticiones en respuestas vacias.
            if (l.juega(t)) (l, dia, t),
    ];

    final resultados = await _traerLote(pedidos);
    await _cache.persistir();

    resultados.sort((a, b) {
      final porTurno = a.turno.index.compareTo(b.turno.index);
      return porTurno != 0
          ? porTurno
          : a.loteria.index.compareTo(b.loteria.index);
    });
    return resultados;
  }

  @override
  Future<List<AparicionNumero>> buscarNumero({
    required String jugada,
    required List<Loteria> loterias,
    int dias = 3,
  }) async {
    if (jugada.isEmpty || jugada.length > 4) return const [];

    final resultados = await _traerLote(
      _pedidosDeVentana(dias: dias, loterias: loterias),
    );
    await _cache.persistir();

    final apariciones = <AparicionNumero>[];
    for (final resultado in resultados) {
      final posiciones = resultado.posicionesDe(jugada);
      if (posiciones.isNotEmpty) {
        apariciones.add(
          AparicionNumero(resultado: resultado, posiciones: posiciones),
        );
      }
    }

    // Del mas reciente al mas viejo: primero por fecha, despues por turno.
    apariciones.sort((a, b) {
      final porFecha = b.resultado.fecha.compareTo(a.resultado.fecha);
      if (porFecha != 0) return porFecha;
      return b.resultado.turno.index.compareTo(a.resultado.turno.index);
    });
    return apariciones;
  }

  @override
  Future<List<FrecuenciaNumero>> frecuencias({
    int dias = 30,
    List<Loteria> loterias = Loteria.predeterminadas,
  }) async {
    final resultados = await _traerLote(
      _pedidosDeVentana(dias: dias, loterias: loterias),
    );
    await _cache.persistir();

    final conteo = <String, int>{
      for (var n = 0; n < 100; n++) n.toString().padLeft(2, '0'): 0,
    };
    for (final resultado in resultados) {
      for (final numero in resultado.numeros) {
        final dosCifras = numero.substring(numero.length - 2);
        conteo[dosCifras] = (conteo[dosCifras] ?? 0) + 1;
      }
    }

    return [
      for (final e in conteo.entries)
        FrecuenciaNumero(
          numero: e.key,
          apariciones: e.value,
          sorteosAnalizados: resultados.length,
        ),
    ]..sort((a, b) {
        final porApariciones = b.apariciones.compareTo(a.apariciones);
        return porApariciones != 0
            ? porApariciones
            : a.numero.compareTo(b.numero);
      });
  }

  @override
  Future<String> avisoUltimoMinuto() async {
    final sorteos = await sorteosDeHoy();
    final proximo = sorteos
        .where((s) => s.estado != EstadoSorteo.finalizado)
        .firstOrNull;

    if (proximo == null) {
      return 'Cerro la jornada. Manana arranca La Previa a las '
          '${TurnoSorteo.laPrevia.horarioFormateado}.';
    }

    final ahora = _ahora();
    final faltan =
        proximo.turno.minutosDelDia - (ahora.hour * 60 + ahora.minute);
    if (faltan <= 0) {
      return 'Sorteando ${proximo.turno.nombre}. Resultados en instantes...';
    }
    return 'Cierre de apuestas ${proximo.turno.nombre} en $faltan min.';
  }

  @override
  Future<List<Sueno>> buscarSuenos(String consulta) async {
    if (consulta.trim().isEmpty) {
      return [
        for (final numero in suenosPopulares)
          diccionarioSuenos.firstWhere((s) => s.numero == numero),
      ];
    }
    return diccionarioSuenos.where((s) => s.coincideCon(consulta)).toList();
  }

  @override
  Jugada generarJugada(int cifras) {
    assert(cifras >= 1 && cifras <= 4, 'La quiniela va de 1 a 4 cifras');
    final maximo = pow(10, cifras).toInt();
    final numero =
        _randomJugadas.nextInt(maximo).toString().padLeft(cifras, '0');
    return Jugada(numero: numero, generadaEn: _ahora());
  }

  // --- Internos -----------------------------------------------------------

  /// Todos los (loteria, fecha, turno) publicados de los ultimos [dias] dias.
  List<(Loteria, DateTime, TurnoSorteo)> _pedidosDeVentana({
    required int dias,
    required List<Loteria> loterias,
  }) {
    final hoy = _soloFecha(_ahora());
    final pedidos = <(Loteria, DateTime, TurnoSorteo)>[];
    for (var d = 0; d < dias; d++) {
      final fecha = hoy.subtract(Duration(days: d));
      for (final turno in TurnoSorteo.values) {
        if (fecha == hoy && !_yaSePublico(turno)) continue;
        for (final loteria in loterias) {
          if (loteria.juega(turno)) pedidos.add((loteria, fecha, turno));
        }
      }
    }
    return pedidos;
  }

  /// Trae un lote de sorteos: lo que este en cache sale de ahi y el resto se
  /// pide por red de a [_concurrencia].
  ///
  /// Los que fallan se descartan en silencio: un sorteo que no esta (o una
  /// loteria que ese dia no jugo) es normal, y no tiene que voltear al resto del
  /// lote. Los errores de parseo si se loguean, porque significan que el sitio
  /// cambio y hay que mirarlo.
  Future<List<ResultadoSorteo>> _traerLote(
    List<(Loteria, DateTime, TurnoSorteo)> pedidos,
  ) async {
    // Idempotente: asegura el cache aca para que ningun metodo publico se
    // olvide de cargarlo y termine pidiendo por red algo que ya estaba.
    await _cache.cargar();

    final resultados = <ResultadoSorteo>[];
    final porRed = <(Loteria, DateTime, TurnoSorteo)>[];

    for (final pedido in pedidos) {
      final clave = _clave(pedido);
      final enCache = _cache.obtener(clave);
      if (enCache != null) {
        resultados.add(enCache);
      } else {
        porRed.add(pedido);
      }
    }

    for (var i = 0; i < porRed.length; i += _concurrencia) {
      final grupo = porRed.skip(i).take(_concurrencia);
      final tanda = await Future.wait(grupo.map(_traerUno));
      for (final r in tanda) {
        if (r != null) {
          _cache.guardar(r);
          resultados.add(r);
        }
      }
    }

    return resultados;
  }

  Future<ResultadoSorteo?> _traerUno(
    (Loteria, DateTime, TurnoSorteo) pedido,
  ) async {
    final (loteria, fecha, turno) = pedido;
    try {
      if (loteria.tieneExtractoXml) {
        return await _api.extractoXml(
          loteria: loteria,
          fecha: fecha,
          turno: turno,
        );
      }

      final sorteo = await _sorteoDe(fecha: fecha, turno: turno);
      if (sorteo == null) return null;
      return await _api.resultadoHtml(
        loteria: loteria,
        fecha: fecha,
        turno: turno,
        sorteo: sorteo,
      );
    } on QuinielaApiException catch (e) {
      debugPrint('${loteria.nombre} ${turno.nombre} ${_iso(fecha)}: $e');
      return null;
    }
  }

  /// Numero de sorteo de una fecha y turno, segun el indice de la home.
  Future<String?> _sorteoDe({
    required DateTime fecha,
    required TurnoSorteo turno,
  }) async {
    final indice = await _obtenerIndice();
    return indice
        .where((e) => e.turno == turno && _soloFecha(e.fecha) == _soloFecha(fecha))
        .firstOrNull
        ?.sorteo;
  }

  Future<List<EntradaIndice>> _obtenerIndice() async {
    final cacheado = _indice;
    final actualizado = _indiceActualizado;
    if (cacheado != null &&
        actualizado != null &&
        _ahora().difference(actualizado) < _vigenciaIndice) {
      return cacheado;
    }

    final fresco = await _api.indiceSorteos();
    _indice = fresco;
    _indiceActualizado = _ahora();
    return fresco;
  }

  /// Turnos desde [desde] hacia el pasado, del mas reciente al mas viejo.
  Iterable<(DateTime, TurnoSorteo)> _turnosHaciaAtras({
    required DateTime desde,
  }) sync* {
    var fecha = _soloFecha(desde);
    var indice = TurnoSorteo.values.length - 1;

    // Arranca en el ultimo turno de hoy que ya se publico.
    while (indice >= 0 && !_yaSePublico(TurnoSorteo.values[indice])) {
      indice--;
    }

    // 40 turnos hacia atras son unos 8 dias: de sobra para saltear un fin de
    // semana largo sin quedarse iterando para siempre.
    for (var pasos = 0; pasos < 40; pasos++) {
      if (indice < 0) {
        fecha = fecha.subtract(const Duration(days: 1));
        indice = TurnoSorteo.values.length - 1;
      }
      yield (fecha, TurnoSorteo.values[indice]);
      indice--;
    }
  }

  bool _yaSePublico(TurnoSorteo turno) {
    final ahora = _ahora();
    return (ahora.hour * 60 + ahora.minute) - turno.minutosDelDia >= 15;
  }

  String _clave((Loteria, DateTime, TurnoSorteo) pedido) {
    final (loteria, fecha, turno) = pedido;
    return '${loteria.name}|${_iso(fecha)}|${turno.name}';
  }

  String _iso(DateTime d) => _soloFecha(d).toIso8601String().substring(0, 10);

  DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);
}

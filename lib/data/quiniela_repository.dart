import 'dart:math';

import '../models/sorteo.dart';
import 'diccionario_suenos.dart';
import 'reloj_argentina.dart';

/// Fuente de datos de la app.
///
/// Toda la UI habla contra esta interfaz, nunca contra la implementacion. El dia
/// que haya API o scraping real, se escribe otra implementacion y se cambia el
/// repositorio que se inyecta en `main.dart`; ninguna pantalla se toca.
abstract interface class QuinielaRepository {
  /// Agenda de sorteos de hoy con su estado respecto de la hora actual.
  Future<List<SorteoDelDia>> sorteosDeHoy();

  /// Ultimo resultado publicado de cada loteria de [loterias].
  Future<List<ResultadoSorteo>> ultimosResultados(List<Loteria> loterias);

  /// Resultados de una fecha, opcionalmente filtrados por turno.
  Future<List<ResultadoSorteo>> resultadosDe({
    required DateTime fecha,
    TurnoSorteo? turno,
    List<Loteria> loterias,
  });

  /// Frecuencia con la que salio cada numero de 2 cifras en los ultimos
  /// [dias] dias, ordenada de mas a menos frecuente.
  Future<List<FrecuenciaNumero>> frecuencias({
    int dias,
    List<Loteria> loterias,
  });

  /// Donde acerto [jugada] (1 a 4 cifras) en los ultimos [dias] dias.
  ///
  /// Devuelve un item por sorteo con acierto, ordenado del mas reciente al mas
  /// viejo.
  Future<List<AparicionNumero>> buscarNumero({
    required String jugada,
    required List<Loteria> loterias,
    int dias,
  });

  /// Aviso rotativo del encabezado del dashboard.
  Future<String> avisoUltimoMinuto();

  /// Busca en el diccionario de suenos. Con [consulta] vacia devuelve los
  /// populares.
  Future<List<Sueno>> buscarSuenos(String consulta);

  /// Genera una jugada al azar de [cifras] digitos (1 a 4).
  Jugada generarJugada(int cifras);
}

/// Implementacion con datos simulados.
///
/// Los resultados son deterministas: la semilla sale de la fecha, la loteria y
/// el turno, asi que el mismo sorteo devuelve siempre los mismos numeros entre
/// ejecuciones. Sin eso, cada rebuild mostraria una pizarra distinta y no se
/// podria revisar la UI ni escribir tests.
class MockQuinielaRepository implements QuinielaRepository {
  MockQuinielaRepository({DateTime Function()? reloj})
      : _ahora = reloj ?? ahoraEnArgentina;

  final DateTime Function() _ahora;

  /// Latencia simulada, para que la UI ejercite sus estados de carga.
  static const _latencia = Duration(milliseconds: 250);

  final _randomJugadas = Random();

  @override
  Future<List<SorteoDelDia>> sorteosDeHoy() async {
    await Future<void>.delayed(_latencia);
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
    await Future<void>.delayed(_latencia);
    final (fecha, turno) = _ultimoTurnoPublicado();
    return [
      for (final loteria in loterias)
        _generarResultado(loteria: loteria, turno: turno, fecha: fecha),
    ];
  }

  @override
  Future<List<ResultadoSorteo>> resultadosDe({
    required DateTime fecha,
    TurnoSorteo? turno,
    List<Loteria> loterias = const [Loteria.nacional, Loteria.provincia],
  }) async {
    await Future<void>.delayed(_latencia);
    final turnos = turno == null ? TurnoSorteo.values : [turno];
    final publicados = _turnosPublicadosEn(fecha);

    return [
      for (final t in turnos)
        if (publicados.contains(t))
          for (final loteria in loterias)
            // Montevideo, por ejemplo, no juega los cinco turnos.
            if (loteria.juega(t))
              _generarResultado(loteria: loteria, turno: t, fecha: fecha),
    ];
  }

  @override
  Future<List<AparicionNumero>> buscarNumero({
    required String jugada,
    required List<Loteria> loterias,
    int dias = 3,
  }) async {
    await Future<void>.delayed(_latencia);
    if (jugada.isEmpty || jugada.length > 4) return const [];

    final hoy = _fechaSola(_ahora());
    final apariciones = <AparicionNumero>[];

    for (var d = 0; d < dias; d++) {
      final fecha = hoy.subtract(Duration(days: d));
      for (final turno in _turnosPublicadosEn(fecha).reversed) {
        for (final loteria in loterias) {
          if (!loteria.juega(turno)) continue;
          final resultado = _generarResultado(
            loteria: loteria,
            turno: turno,
            fecha: fecha,
          );
          final posiciones = resultado.posicionesDe(jugada);
          if (posiciones.isNotEmpty) {
            apariciones.add(
              AparicionNumero(resultado: resultado, posiciones: posiciones),
            );
          }
        }
      }
    }
    return apariciones;
  }

  @override
  Future<List<FrecuenciaNumero>> frecuencias({
    int dias = 30,
    List<Loteria> loterias = Loteria.predeterminadas,
  }) async {
    await Future<void>.delayed(_latencia);
    final hoy = _fechaSola(_ahora());
    final conteo = <String, int>{
      for (var n = 0; n < 100; n++) n.toString().padLeft(2, '0'): 0,
    };
    var sorteosAnalizados = 0;

    for (var d = 0; d < dias; d++) {
      final fecha = hoy.subtract(Duration(days: d));
      for (final turno in _turnosPublicadosEn(fecha)) {
        for (final loteria in loterias) {
          if (!loteria.juega(turno)) continue;
          final resultado = _generarResultado(
            loteria: loteria,
            turno: turno,
            fecha: fecha,
          );
          sorteosAnalizados++;
          for (final numero in resultado.numeros) {
            final dosCifras = numero.substring(numero.length - 2);
            conteo[dosCifras] = conteo[dosCifras]! + 1;
          }
        }
      }
    }

    final lista = [
      for (final entrada in conteo.entries)
        FrecuenciaNumero(
          numero: entrada.key,
          apariciones: entrada.value,
          sorteosAnalizados: sorteosAnalizados,
        ),
    ]..sort((a, b) {
        final porApariciones = b.apariciones.compareTo(a.apariciones);
        // Desempate estable por numero, para que el orden no baile entre
        // llamadas cuando dos numeros salieron la misma cantidad de veces.
        return porApariciones != 0
            ? porApariciones
            : a.numero.compareTo(b.numero);
      });
    return lista;
  }

  @override
  Future<String> avisoUltimoMinuto() async {
    await Future<void>.delayed(_latencia);
    final sorteos = await sorteosDeHoy();
    final proximo = sorteos
        .where((s) => s.estado != EstadoSorteo.finalizado)
        .firstOrNull;

    if (proximo == null) {
      return 'Cerro la jornada. Manana arranca La Previa a las '
          '${TurnoSorteo.laPrevia.horarioFormateado}.';
    }

    final ahora = _ahora();
    final faltan = proximo.turno.minutosDelDia - (ahora.hour * 60 + ahora.minute);
    if (faltan <= 0) {
      return 'Sorteando ${proximo.turno.nombre}. Resultados en instantes...';
    }
    return 'Cierre de apuestas ${proximo.turno.nombre} en $faltan min. '
        'Pozo estimado \$15.000.000';
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
    final numero = _randomJugadas.nextInt(maximo).toString().padLeft(cifras, '0');
    return Jugada(numero: numero, generadaEn: _ahora());
  }

  // --- Internos -----------------------------------------------------------

  /// Fecha y turno del ultimo sorteo con resultados publicados.
  (DateTime, TurnoSorteo) _ultimoTurnoPublicado() {
    final ahora = _ahora();
    final publicadosHoy = _turnosPublicadosEn(ahora);
    if (publicadosHoy.isNotEmpty) {
      return (_fechaSola(ahora), publicadosHoy.last);
    }
    // Antes de La Previa el ultimo dato del dia es la Nocturna de ayer.
    return (
      _fechaSola(ahora).subtract(const Duration(days: 1)),
      TurnoSorteo.nocturna,
    );
  }

  /// Turnos de [fecha] que ya tienen resultados. Para dias pasados son todos.
  List<TurnoSorteo> _turnosPublicadosEn(DateTime fecha) {
    final ahora = _ahora();
    final esHoy = _fechaSola(fecha) == _fechaSola(ahora);
    if (_fechaSola(fecha).isAfter(_fechaSola(ahora))) return const [];
    if (!esHoy) return TurnoSorteo.values;

    final minutosAhora = ahora.hour * 60 + ahora.minute;
    return TurnoSorteo.values
        .where((t) => minutosAhora - t.minutosDelDia >= 15)
        .toList();
  }

  ResultadoSorteo _generarResultado({
    required Loteria loteria,
    required TurnoSorteo turno,
    required DateTime fecha,
  }) {
    final semilla = _semilla(loteria: loteria, turno: turno, fecha: fecha);
    final random = Random(semilla);
    final numeros = List.generate(
      20,
      (_) => random.nextInt(10000).toString().padLeft(4, '0'),
    );
    return ResultadoSorteo(
      loteria: loteria,
      turno: turno,
      fecha: _fechaSola(fecha),
      numeros: numeros,
    );
  }

  int _semilla({
    required Loteria loteria,
    required TurnoSorteo turno,
    required DateTime fecha,
  }) {
    final dia = fecha.year * 10000 + fecha.month * 100 + fecha.day;
    return dia * 100 + loteria.index * 10 + turno.index;
  }

  DateTime _fechaSola(DateTime d) => DateTime(d.year, d.month, d.day);
}

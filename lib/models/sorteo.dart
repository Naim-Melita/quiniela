import 'package:flutter/material.dart';

/// Loteria que emite el sorteo.
///
/// [jurisdiccion] es el codigo que usa el sitio de Loteria de la Ciudad, que es
/// la fuente oficial de la que sale todo. Ojo con el primero: lo que la calle
/// llama "Quiniela Nacional" es, oficialmente, la Quiniela de la Ciudad —
/// Loteria Nacional la opera Loteria de la Ciudad. Es el mismo sorteo con dos
/// nombres. "Provincia" si es un sorteo distinto, el de Buenos Aires.
/// Los codigos y los turnos de cada una salieron de probar el endpoint una por
/// una, no de la documentacion (no hay). Dos advertencias que costaron:
///
/// - El JS del sitio llama `resultadosRios` a la jurisdiccion 64 y
///   `resultadosMend` a la 59, pero el servidor responde al reves: 59 devuelve
///   `ENRTRE RIOS` (el typo es de ellos) y 64 dice "No hay Sorteo de MENDOZA".
///   Vale el label del servidor, que es el que trae el dato.
/// - Mendoza (64) no aparece: 0 sorteos en 15 muestreados. Esta fuente no la
///   publica, asi que no esta en la lista. Ponerla seria mostrar una loteria
///   siempre vacia.
enum Loteria {
  nacional('Nacional', Icons.military_tech, '51'),
  provincia('Provincia', Icons.map, '53'),
  santaFe('Santa Fe', Icons.location_city, '72'),
  cordoba('Cordoba', Icons.place, '55'),
  entreRios('Entre Rios', Icons.water, '59'),
  // Montevideo solo juega dos turnos, no los cinco.
  montevideo('Montevideo', Icons.public, '00', [
    TurnoSorteo.matutina,
    TurnoSorteo.nocturna,
  ]);

  const Loteria(this.nombre, this.icono, this.jurisdiccion, [this.turnos]);

  final String nombre;
  final IconData icono;

  /// Codigo de jurisdiccion en el sitio de Loteria de la Ciudad.
  final String jurisdiccion;

  /// Turnos que juega. Null = los cinco.
  final List<TurnoSorteo>? turnos;

  /// Turnos que esta loteria realmente sortea.
  List<TurnoSorteo> get turnosQueJuega => turnos ?? TurnoSorteo.values;

  bool juega(TurnoSorteo turno) => turnosQueJuega.contains(turno);

  /// Solo la Ciudad publica el extracto en XML; el resto sale del HTML.
  bool get tieneExtractoXml => this == Loteria.nacional;

  /// Las que arranca siguiendo un usuario nuevo.
  static const predeterminadas = [Loteria.nacional, Loteria.provincia];

  static Loteria? porNombreInterno(String? nombre) =>
      Loteria.values.where((l) => l.name == nombre).firstOrNull;
}

/// Turnos de la quiniela. El horario es el de cierre/pizarra habitual.
enum TurnoSorteo {
  laPrevia('La Previa', TimeOfDay(hour: 10, minute: 15), 'R'),
  primera('Primera', TimeOfDay(hour: 12, minute: 0), 'P'),
  matutina('Matutina', TimeOfDay(hour: 15, minute: 0), 'M'),
  vespertina('Vespertina', TimeOfDay(hour: 18, minute: 0), 'V'),
  nocturna('Nocturna', TimeOfDay(hour: 21, minute: 0), 'N');

  const TurnoSorteo(this.nombre, this.horario, this.letraExtracto);

  final String nombre;
  final TimeOfDay horario;

  /// Letra del turno en el nombre del archivo de extracto oficial
  /// (`QNL51M20260813.xml` = jurisdiccion 51, Matutina, 13/08/2026).
  final String letraExtracto;

  /// Minutos desde la medianoche, para ordenar y comparar contra la hora actual.
  int get minutosDelDia => horario.hour * 60 + horario.minute;

  String get horarioFormateado =>
      '${horario.hour.toString().padLeft(2, '0')}:'
      '${horario.minute.toString().padLeft(2, '0')}';
}

/// En que punto del dia esta un turno respecto de [ahora].
enum EstadoSorteo { finalizado, enVivo, proximo }

/// Un turno de sorteo situado en el dia de hoy, con su estado.
@immutable
class SorteoDelDia {
  const SorteoDelDia({required this.turno, required this.estado});

  final TurnoSorteo turno;
  final EstadoSorteo estado;

  String get etiquetaEstado => switch (estado) {
        EstadoSorteo.finalizado => 'Finalizado',
        EstadoSorteo.enVivo => 'En vivo',
        EstadoSorteo.proximo => 'Proximo',
      };
}

/// Resultado completo de un sorteo: las 20 posiciones de la pizarra.
///
/// [numeros] siempre tiene 20 entradas de 4 digitos. La posicion 1 (indice 0)
/// es la "cabeza"; sus dos ultimos digitos son el numero que se muestra grande
/// en el dashboard.
@immutable
class ResultadoSorteo {
  const ResultadoSorteo({
    required this.loteria,
    required this.turno,
    required this.fecha,
    required this.numeros,
    this.letras,
    this.sorteo,
  }) : assert(numeros.length == 20, 'Un sorteo tiene 20 posiciones');

  final Loteria loteria;
  final TurnoSorteo turno;
  final DateTime fecha;
  final List<String> numeros;

  /// Las cuatro letras del extracto. Solo viene en el XML de la Ciudad.
  final String? letras;

  /// Numero de sorteo oficial, cuando la fuente lo informa.
  final String? sorteo;

  /// Clave estable para cachear: un sorteo ya publicado no cambia nunca.
  String get clave =>
      '${loteria.name}|${fecha.toIso8601String().substring(0, 10)}|${turno.name}';

  Map<String, Object?> aJson() => {
        'loteria': loteria.name,
        'turno': turno.name,
        'fecha': fecha.toIso8601String().substring(0, 10),
        'numeros': numeros,
        'letras': letras,
        'sorteo': sorteo,
      };

  /// Devuelve null si el registro esta corrupto o quedo de una version vieja,
  /// para que un cache invalido se descarte en vez de romper la app.
  static ResultadoSorteo? desdeJson(Map<String, Object?> json) {
    final loteria = Loteria.values
        .where((l) => l.name == json['loteria'])
        .firstOrNull;
    final turno = TurnoSorteo.values
        .where((t) => t.name == json['turno'])
        .firstOrNull;
    final fecha = DateTime.tryParse((json['fecha'] as String?) ?? '');
    final numeros = (json['numeros'] as List?)?.cast<String>();

    if (loteria == null || turno == null || fecha == null) return null;
    if (numeros == null || numeros.length != 20) return null;

    return ResultadoSorteo(
      loteria: loteria,
      turno: turno,
      fecha: fecha,
      numeros: numeros,
      letras: json['letras'] as String?,
      sorteo: json['sorteo'] as String?,
    );
  }

  /// Numero de la posicion 1, completo (4 digitos).
  String get cabeza => numeros.first;

  /// Los dos ultimos digitos de la cabeza: el numero "a la cabeza" que se
  /// canta en la calle y el que muestra grande el dashboard.
  String get cabezaDosCifras => cabeza.substring(cabeza.length - 2);

  /// El numero en una posicion dada (1..20).
  String posicion(int p) => numeros[p - 1];

  /// Posiciones (1..20) en las que acerto [jugada].
  ///
  /// Una jugada de N cifras acierta cuando coincide con las **ultimas** N
  /// cifras del numero sorteado: al 4221 le acierta el 21 a dos cifras y el
  /// 221 a tres, no el 42. Asi se paga en la quiniela.
  List<int> posicionesDe(String jugada) {
    if (jugada.isEmpty || jugada.length > 4) return const [];
    return [
      for (var p = 1; p <= 20; p++)
        if (posicion(p).endsWith(jugada)) p,
    ];
  }
}

/// Un acierto de una jugada en un sorteo concreto.
@immutable
class AparicionNumero {
  const AparicionNumero({required this.resultado, required this.posiciones});

  final ResultadoSorteo resultado;

  /// Posiciones donde salio, de la 1 a la 20.
  final List<int> posiciones;

  /// Salio a la cabeza, que es el acierto que mas se paga.
  bool get aLaCabeza => posiciones.contains(1);
}

/// Entrada del diccionario de suenos ("la cabala").
@immutable
class Sueno {
  const Sueno({
    required this.numero,
    required this.nombre,
    this.sinonimos = const [],
  });

  /// Numero asociado, de 2 digitos ('00'..'99').
  final String numero;
  final String nombre;
  final List<String> sinonimos;

  /// Si el texto buscado matchea el nombre, algun sinonimo o el numero.
  bool coincideCon(String consulta) {
    final q = consulta.trim().toLowerCase();
    if (q.isEmpty) return false;
    if (numero.contains(q)) return true;
    if (nombre.toLowerCase().contains(q)) return true;
    return sinonimos.any((s) => s.toLowerCase().contains(q));
  }
}

/// Frecuencia de aparicion de un numero en una ventana de sorteos.
@immutable
class FrecuenciaNumero {
  const FrecuenciaNumero({
    required this.numero,
    required this.apariciones,
    required this.sorteosAnalizados,
  });

  /// Numero de 2 digitos.
  final String numero;
  final int apariciones;
  final int sorteosAnalizados;

  double get porcentaje =>
      sorteosAnalizados == 0 ? 0 : apariciones / sorteosAnalizados * 100;
}

/// Una jugada generada por el usuario.
@immutable
class Jugada {
  const Jugada({required this.numero, required this.generadaEn});

  /// Numero jugado, de 1 a 4 digitos.
  final String numero;
  final DateTime generadaEn;

  int get cifras => numero.length;
}

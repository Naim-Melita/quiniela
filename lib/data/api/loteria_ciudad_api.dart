import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../../models/sorteo.dart';

/// Algo salio mal hablando con el sitio oficial.
class QuinielaApiException implements Exception {
  const QuinielaApiException(this.mensaje, {this.causa});

  final String mensaje;
  final Object? causa;

  @override
  String toString() => 'QuinielaApiException: $mensaje';
}

/// Una fila del indice de sorteos que publica la home del sitio.
class EntradaIndice {
  const EntradaIndice({
    required this.sorteo,
    required this.fecha,
    required this.turno,
  });

  final String sorteo;
  final DateTime fecha;
  final TurnoSorteo turno;
}

/// Cliente de la fuente oficial actual: la home publica fecha, turno y numero
/// de sorteo; `includes/resultados-data.php` devuelve JSON dentro de una
/// asignacion JavaScript con las 20 posiciones de todas las jurisdicciones.
/// Los parsers XML/HTML anteriores se conservan para fixtures historicos.
class LoteriaCiudadApi {
  LoteriaCiudadApi({
    http.Client? cliente,
    String? base,
    String? baseAlternativa,
    this.timeout = const Duration(seconds: 15),
  }) : _cliente = cliente ?? http.Client(),
       _base = base ?? baseProxy,
       _baseAlternativa =
           baseAlternativa ?? (base == null ? baseOficial : null);

  static const baseOficial = 'https://quiniela.loteriadelaciudad.gob.ar';
  static const baseProxy = 'https://quiniela24.armelix.dev/fuente-loteria';

  /// Codigo de juego de la quiniela en `consultaResultados.php`.

  final http.Client _cliente;
  final String _base;
  final String? _baseAlternativa;
  final Duration timeout;

  void cerrar() => _cliente.close();

  // --- Indice de sorteos --------------------------------------------------

  /// Indice sorteo -> (fecha, turno) de los ultimos dias.
  ///
  /// La home lista los sorteos en `<option value=52769>Fecha: 13/08/2026 -
  /// Sorteo: 52769</option>`, de mas nuevo a mas viejo. El turno no viene en esa
  /// linea, pero los sorteos de un mismo dia son correlativos y en orden de
  /// turno, asi que se asigna ordenando por numero dentro de cada fecha.
  ///
  /// No se puede calcular el numero de sorteo por aritmetica sobre la fecha: los
  /// domingos no hay sorteo y la numeracion salta.
  Future<List<EntradaIndice>>? _indiceEnVuelo;
  DateTime? _indiceHasta;
  final Map<String, Future<String>> _datosEnVuelo = {};

  Future<List<EntradaIndice>> indiceSorteos() {
    if (_indiceEnVuelo != null && DateTime.now().isBefore(_indiceHasta!)) {
      return _indiceEnVuelo!;
    }
    _datosEnVuelo.clear();
    _indiceHasta = DateTime.now().add(const Duration(minutes: 10));
    return _indiceEnVuelo = _descargarIndice().catchError((Object error) {
      _indiceEnVuelo = null;
      throw error;
    });
  }

  Future<List<EntradaIndice>> _descargarIndice() async {
    // Sin aceptar404: si la home no responde, no hay nada que hacer.
    final html = await _get(Uri.parse('$_base/'));
    return parsearIndice(html!);
  }

  static final _reOpcion = RegExp(
    r'<option\s+value=(\d+)>\s*Fecha:\s*(\d{2})/(\d{2})/(\d{4})\s*-\s*Sorteo:\s*\d+\s*</option>',
  );

  /// Visible para tests: parsea el indice a partir del HTML de la home.
  static List<EntradaIndice> parsearIndice(String html) {
    final actuales = RegExp(
      r'''<li\b[^>]*data-value=["'](\d+)["'][^>]*>\s*(\d{2})/(\d{2})/(\d{4})\s*-\s*\d{2}:\d{2}\s*-\s*Sorteo N[º°]\s*\d+\s*-\s*([A-Z ]+)\s*</li>''',
    );
    final entradasActuales = <EntradaIndice>[];
    for (final m in actuales.allMatches(html)) {
      final turno = _turnoDesdeModalidad(m.group(5));
      if (turno == null) throw const QuinielaApiException('Turno desconocido');
      entradasActuales.add(
        EntradaIndice(
          sorteo: m.group(1)!,
          fecha: DateTime(
            int.parse(m.group(4)!),
            int.parse(m.group(3)!),
            int.parse(m.group(2)!),
          ),
          turno: turno,
        ),
      );
    }
    if (entradasActuales.isNotEmpty) return entradasActuales;
    final porFecha = <DateTime, List<int>>{};

    for (final m in _reOpcion.allMatches(html)) {
      final sorteo = int.parse(m.group(1)!);
      final fecha = DateTime(
        int.parse(m.group(4)!),
        int.parse(m.group(3)!),
        int.parse(m.group(2)!),
      );
      porFecha.putIfAbsent(fecha, () => []).add(sorteo);
    }

    if (porFecha.isEmpty) {
      throw const QuinielaApiException(
        'No se encontro el indice de sorteos en la home. Puede que el sitio '
        'haya cambiado el marcado.',
      );
    }

    final entradas = <EntradaIndice>[];
    for (final entrada in porFecha.entries) {
      final sorteos = entrada.value..sort();
      for (
        var i = 0;
        i < sorteos.length && i < TurnoSorteo.values.length;
        i++
      ) {
        entradas.add(
          EntradaIndice(
            sorteo: '${sorteos[i]}',
            fecha: entrada.key,
            turno: TurnoSorteo.values[i],
          ),
        );
      }
    }
    return entradas;
  }

  // --- Resultados ---------------------------------------------------------

  /// Resultado de Ciudad por fecha y turno. Conserva el nombre publico anterior
  /// para compatibilidad; consulta el endpoint actual, no la ruta XML retirada.
  Future<ResultadoSorteo?> extractoXml({
    required Loteria loteria,
    required DateTime fecha,
    required TurnoSorteo turno,
  }) async {
    final indice = await indiceSorteos();
    final entrada = indice
        .where(
          (e) =>
              e.fecha.year == fecha.year &&
              e.fecha.month == fecha.month &&
              e.fecha.day == fecha.day &&
              e.turno == turno,
        )
        .firstOrNull;
    if (entrada == null) return null;
    return resultadoHtml(
      loteria: loteria,
      fecha: fecha,
      turno: turno,
      sorteo: entrada.sorteo,
    );
  }

  /// Visible para tests: parsea el XML del extracto oficial.
  static ResultadoSorteo parsearExtractoXml(
    String xml, {
    required Loteria loteria,
    required DateTime fechaEsperada,
    required TurnoSorteo turnoEsperado,
  }) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(xml);
    } on XmlException catch (e) {
      throw QuinielaApiException('El extracto no es XML valido', causa: e);
    }

    final suerte = doc.findAllElements('Suerte').firstOrNull;
    if (suerte == null) {
      throw const QuinielaApiException('El extracto no trae el nodo <Suerte>');
    }

    final numeros = <String>[];
    for (var p = 1; p <= 20; p++) {
      final tag = 'N${p.toString().padLeft(2, '0')}';
      final valor = suerte.findElements(tag).firstOrNull?.innerText.trim();
      if (valor == null || !RegExp(r'^\d{1,4}$').hasMatch(valor)) {
        throw QuinielaApiException(
          'El extracto no trae la posicion $p (<$tag>)',
        );
      }
      numeros.add(valor.padLeft(4, '0'));
    }

    final modalidad = doc
        .findAllElements('Modalidad')
        .firstOrNull
        ?.innerText
        .trim();

    return ResultadoSorteo(
      loteria: loteria,
      // El turno se toma del propio extracto cuando se puede reconocer; si el
      // XML trae una modalidad que no mapea, se cae a [turnoEsperado], que es el
      // que se pidio. El fallback importa mas de lo que parece: el archivo se
      // direcciona por turno, y devolver otro haria que el repositorio guarde en
      // cache con una clave distinta de la que consulta (nunca acertaria) y que
      // la pizarra quede rotulada con un turno que no es.
      turno:
          _turnoDesdeModalidad(modalidad) ??
          _turnoDesdeHora(
            doc.findAllElements('HoraSorteo').firstOrNull?.innerText.trim(),
          ) ??
          turnoEsperado,
      fecha: DateTime(
        fechaEsperada.year,
        fechaEsperada.month,
        fechaEsperada.day,
      ),
      numeros: numeros,
      letras: doc.findAllElements('Letras').firstOrNull?.innerText.trim(),
      sorteo: doc.findAllElements('Sorteo').firstOrNull?.innerText.trim(),
    );
  }

  /// Resultado de una jurisdiccion desde los datos actuales del sorteo.
  /// Conserva el nombre publico anterior para compatibilidad.
  Future<ResultadoSorteo?> resultadoHtml({
    required Loteria loteria,
    required DateTime fecha,
    required TurnoSorteo turno,
    required String sorteo,
  }) async {
    final cuerpo = await (_datosEnVuelo[sorteo] ??=
        _get(
          Uri.parse('$_base/includes/resultados-data.php?sorteo=$sorteo'),
        ).then((value) => value!).catchError((Object error) {
          _datosEnVuelo.remove(sorteo);
          throw error;
        }));
    try {
      final match = RegExp(
        r'window\.RESULTADOS_DATA\s*=\s*(\[.*\])\s*;',
        dotAll: true,
      ).firstMatch(cuerpo);
      if (match == null) throw const FormatException('Faltan los datos');
      final datos = jsonDecode(match.group(1)!) as List;
      final fila = datos
          .cast<Map<String, dynamic>>()
          .where((r) => '${r['sorteo']}' == sorteo)
          .firstOrNull;
      if (fila == null) throw const FormatException('Sorteo incorrecto');
      final fechaTexto =
          '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
      const modalidades = ['PREV', 'PRIM', 'MATU', 'VESP', 'NOCT'];
      if (fila['fecha'] != fechaTexto ||
          fila['modalidad'] != modalidades[turno.index]) {
        throw const FormatException('Fecha o turno incorrectos');
      }
      final jurisdiccion =
          (fila['jurisdicciones'] as Map)[loteria.jurisdiccion] as Map?;
      if (jurisdiccion == null) {
        _datosEnVuelo.remove(sorteo);
        return null;
      }
      final posiciones = <int, String>{};
      for (final n in jurisdiccion['numeros'] as List) {
        final pos = int.parse('${n['pos']}');
        final valor = '${n['val']}';
        if (pos < 1 ||
            pos > 20 ||
            posiciones.containsKey(pos) ||
            !RegExp(r'^\d{1,4}$').hasMatch(valor)) {
          throw const FormatException('Posicion invalida');
        }
        posiciones[pos] = valor.padLeft(4, '0');
      }
      if (posiciones.length != 20) {
        throw const FormatException('Faltan posiciones');
      }
      return ResultadoSorteo(
        loteria: loteria,
        fecha: DateTime(fecha.year, fecha.month, fecha.day),
        turno: turno,
        sorteo: sorteo,
        letras: jurisdiccion['letras'] as String?,
        numeros: [for (var p = 1; p <= 20; p++) posiciones[p]!],
      );
    } catch (e) {
      _datosEnVuelo.remove(sorteo);
      throw QuinielaApiException(
        'Respuesta invalida para el sorteo $sorteo',
        causa: e,
      );
    }
  }

  static final _rePosicion = RegExp(
    r'<div class="pos">(\d{2})</div>\s*<div>(\d{1,4})</div>',
  );
  static final _reSinSorteo = RegExp('No hay Sorteo', caseSensitive: false);

  /// Visible para tests: parsea el fragmento HTML de `consultaResultados.php`.
  static ResultadoSorteo? parsearFragmentoHtml(
    String html, {
    required Loteria loteria,
    required DateTime fecha,
    required TurnoSorteo turno,
    String? sorteo,
  }) {
    if (_reSinSorteo.hasMatch(html)) return null;

    // El fragmento repite la grilla dos veces (layout web y mobile), asi que se
    // indexa por posicion en vez de acumular en una lista.
    final porPosicion = <int, String>{};
    for (final m in _rePosicion.allMatches(html)) {
      final posicion = int.parse(m.group(1)!);
      if (posicion >= 1 && posicion <= 20) {
        porPosicion[posicion] = m.group(2)!.padLeft(4, '0');
      }
    }

    if (porPosicion.isEmpty) return null;
    if (porPosicion.length != 20) {
      throw QuinielaApiException(
        'El fragmento de ${loteria.nombre} trae ${porPosicion.length} de 20 '
        'posiciones. Puede que el sitio haya cambiado el marcado.',
      );
    }

    return ResultadoSorteo(
      loteria: loteria,
      turno: turno,
      fecha: DateTime(fecha.year, fecha.month, fecha.day),
      numeros: [for (var p = 1; p <= 20; p++) porPosicion[p]!],
      sorteo: sorteo,
    );
  }

  // --- Internos -----------------------------------------------------------

  static TurnoSorteo? _turnoDesdeModalidad(String? modalidad) {
    if (modalidad == null) return null;
    final m = modalidad.toUpperCase();
    // El XML usa "LA PREVIA" / "LA PRIMERA"; el resto va sin articulo.
    if (m.contains('PREVIA')) return TurnoSorteo.laPrevia;
    if (m.contains('PRIMERA')) return TurnoSorteo.primera;
    if (m.contains('MATUTINA')) return TurnoSorteo.matutina;
    if (m.contains('VESPERTINA')) return TurnoSorteo.vespertina;
    if (m.contains('NOCTURNA')) return TurnoSorteo.nocturna;
    return null;
  }

  static TurnoSorteo? _turnoDesdeHora(String? hora) {
    if (hora == null) return null;
    return TurnoSorteo.values
        .where((t) => t.horarioFormateado == hora.trim())
        .firstOrNull;
  }

  Future<String?> _get(Uri uri, {bool aceptar404 = false}) async {
    Object? ultimoError;
    var hubo404 = false;
    for (final candidata in _candidatas(uri)) {
      try {
        final respuesta = await _cliente.get(candidata).timeout(timeout);
        if (respuesta.statusCode == 200) return _decodificar(respuesta);
        if (respuesta.statusCode == 404) hubo404 = true;
        ultimoError = QuinielaApiException(
          '$candidata respondio ${respuesta.statusCode}',
        );
      } catch (e) {
        ultimoError = e;
      }
    }

    if (aceptar404 && hubo404) return null;
    throw QuinielaApiException(
      'No se pudo conectar con $uri',
      causa: ultimoError,
    );
  }

  Iterable<Uri> _candidatas(Uri original) sync* {
    yield original;
    final alternativa = _baseAlternativa;
    if (alternativa == null || !original.toString().startsWith(_base)) return;
    yield Uri.parse(
      '$alternativa${original.toString().substring(_base.length)}',
    );
  }

  /// El sitio no declara charset en todas las respuestas y http.dart cae a
  /// latin-1 cuando falta. Se intenta UTF-8 primero, que es lo que manda.
  String _decodificar(http.Response respuesta) {
    try {
      return utf8.decode(respuesta.bodyBytes);
    } on FormatException {
      return respuesta.body;
    }
  }
}

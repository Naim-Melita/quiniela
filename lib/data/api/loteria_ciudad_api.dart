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

/// Cliente del sitio oficial de Loteria de la Ciudad.
///
/// El sitio no tiene API documentada; esto se apoya en tres cosas que si son
/// publicas y estables:
///
/// 1. `descarga.php?sorteo=YYYY/MM/QNL{jur}{turno}{YYYYMMDD}.xml` devuelve el
///    **extracto oficial en XML**. Solo existe para la Ciudad (jurisdiccion 51),
///    pero es la via mas robusta: no depende del HTML ni del numero de sorteo,
///    se direcciona por fecha y turno.
/// 2. `consultaResultados.php` (POST) devuelve un fragmento HTML con las 20
///    posiciones. Es la unica via para Provincia y las demas jurisdicciones, y
///    necesita el numero de sorteo.
/// 3. La home trae el indice sorteo -> fecha de los ultimos ~26 dias, que es de
///    donde sale ese numero de sorteo.
///
/// Al ser HTML sin contrato, el punto 2 se puede romper si el sitio cambia el
/// marcado. Por eso los parsers validan lo que extraen y tiran
/// [QuinielaApiException] en vez de devolver datos a medias.
class LoteriaCiudadApi {
  LoteriaCiudadApi({
    http.Client? cliente,
    String? base,
    this.timeout = const Duration(seconds: 15),
  })  : _cliente = cliente ?? http.Client(),
        _base = base ?? baseOficial;

  static const baseOficial = 'https://quiniela.loteriadelaciudad.gob.ar';

  /// Codigo de juego de la quiniela en `consultaResultados.php`.
  static const _codigoJuego = '0080';

  final http.Client _cliente;
  final String _base;
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
  Future<List<EntradaIndice>> indiceSorteos() async {
    // Sin aceptar404: si la home no responde, no hay nada que hacer.
    final html = await _get(Uri.parse('$_base/'));
    return parsearIndice(html!);
  }

  static final _reOpcion = RegExp(
    r'<option\s+value=(\d+)>\s*Fecha:\s*(\d{2})/(\d{2})/(\d{4})\s*-\s*Sorteo:\s*\d+\s*</option>',
  );

  /// Visible para tests: parsea el indice a partir del HTML de la home.
  static List<EntradaIndice> parsearIndice(String html) {
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
      for (var i = 0; i < sorteos.length && i < TurnoSorteo.values.length; i++) {
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

  /// Extracto oficial en XML. Solo para la Ciudad.
  ///
  /// Devuelve null si el sorteo no existe (404), que es lo que pasa con una
  /// fecha sin sorteo o un turno que todavia no se jugo.
  Future<ResultadoSorteo?> extractoXml({
    required Loteria loteria,
    required DateTime fecha,
    required TurnoSorteo turno,
  }) async {
    final aa = fecha.year.toString().padLeft(4, '0');
    final mm = fecha.month.toString().padLeft(2, '0');
    final dd = fecha.day.toString().padLeft(2, '0');
    final archivo = 'QNL${loteria.jurisdiccion}${turno.letraExtracto}$aa$mm$dd';
    final uri = Uri.parse(
      '$_base/resultadosQuiniela/descarga.php?sorteo=$aa/$mm/$archivo.xml',
    );

    final xml = await _get(uri, aceptar404: true);
    if (xml == null || xml.trim().isEmpty) return null;
    return parsearExtractoXml(
      xml,
      loteria: loteria,
      fechaEsperada: fecha,
      turnoEsperado: turno,
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
      turno: _turnoDesdeModalidad(modalidad) ??
          _turnoDesdeHora(
            doc.findAllElements('HoraSorteo').firstOrNull?.innerText.trim(),
          ) ??
          turnoEsperado,
      fecha: DateTime(fechaEsperada.year, fechaEsperada.month, fechaEsperada.day),
      numeros: numeros,
      letras: doc.findAllElements('Letras').firstOrNull?.innerText.trim(),
      sorteo: doc.findAllElements('Sorteo').firstOrNull?.innerText.trim(),
    );
  }

  /// Fragmento HTML con las 20 posiciones, para las jurisdicciones sin XML.
  ///
  /// Devuelve null cuando el sitio responde "No hay Sorteo ... para la fecha
  /// ingresada", que es un caso normal (esa loteria no sorteo ese turno).
  Future<ResultadoSorteo?> resultadoHtml({
    required Loteria loteria,
    required DateTime fecha,
    required TurnoSorteo turno,
    required String sorteo,
  }) async {
    final cuerpo = await _post(
      Uri.parse('$_base/resultadosQuiniela/consultaResultados.php'),
      {
        'codigo': _codigoJuego,
        'juridiccion': loteria.jurisdiccion,
        'sorteo': sorteo,
      },
    );

    return parsearFragmentoHtml(
      cuerpo,
      loteria: loteria,
      fecha: fecha,
      turno: turno,
      sorteo: sorteo,
    );
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
    final http.Response respuesta;
    try {
      respuesta = await _cliente.get(uri).timeout(timeout);
    } catch (e) {
      throw QuinielaApiException('No se pudo conectar con $uri', causa: e);
    }

    if (aceptar404 && respuesta.statusCode == 404) return null;
    if (respuesta.statusCode != 200) {
      throw QuinielaApiException(
        '$uri respondio ${respuesta.statusCode}',
      );
    }
    return _decodificar(respuesta);
  }

  Future<String> _post(Uri uri, Map<String, String> campos) async {
    final http.Response respuesta;
    try {
      respuesta = await _cliente.post(uri, body: campos).timeout(timeout);
    } catch (e) {
      throw QuinielaApiException('No se pudo conectar con $uri', causa: e);
    }

    if (respuesta.statusCode != 200) {
      throw QuinielaApiException('$uri respondio ${respuesta.statusCode}');
    }
    return _decodificar(respuesta);
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

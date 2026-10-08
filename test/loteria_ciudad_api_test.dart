import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quiniela/data/api/loteria_ciudad_api.dart';
import 'package:quiniela/models/sorteo.dart';

/// Los fixtures son respuestas reales del sitio oficial, capturadas el
/// 13/08/2026. Si el sitio cambia el marcado, estos tests siguen pasando pero la
/// app deja de andar: hay que volver a capturarlos para detectarlo.
String _fixture(String nombre) =>
    File('test/fixtures/$nombre').readAsStringSync();

void main() {
  test('lee el indice actual con fecha y turno explicitos', () {
    final indice = LoteriaCiudadApi.parsearIndice(
      _fixture('indice_actual.html'),
    );
    final primera = indice.firstWhere((e) => e.sorteo == '53008');
    expect(primera.fecha, DateTime(2026, 10, 8));
    expect(primera.turno, TurnoSorteo.primera);
  });

  test('consulta resultados actuales de Ciudad y Provincia', () async {
    final api = LoteriaCiudadApi(
      base: 'https://oficial.test',
      cliente: MockClient((pedido) async {
        if (pedido.url.path == '/') {
          return http.Response.bytes(
            utf8.encode(_fixture('indice_actual.html')),
            200,
          );
        }
        if (pedido.url.path == '/includes/resultados-data.php') {
          return http.Response(_fixture('resultados_actuales.js'), 200);
        }
        return http.Response('ruta retirada', 404);
      }),
    );
    final ciudad = await api.extractoXml(
      loteria: Loteria.nacional,
      fecha: DateTime(2026, 10, 8),
      turno: TurnoSorteo.primera,
    );
    final provincia = await api.resultadoHtml(
      loteria: Loteria.provincia,
      fecha: DateTime(2026, 10, 8),
      turno: TurnoSorteo.primera,
      sorteo: '53008',
    );
    expect(ciudad!.cabeza, '4599');
    expect(provincia!.cabeza, '1006');
    expect(ciudad.numeros, hasLength(20));
    expect(provincia.numeros, hasLength(20));
  });

  for (final caso in [
    'fecha incorrecta',
    'posicion duplicada',
    'datos incompletos',
  ]) {
    test('rechaza resultados actuales con $caso', () async {
      var cuerpo = _fixture('resultados_actuales.js');
      if (caso == 'fecha incorrecta') {
        cuerpo = cuerpo.replaceFirst('08\\/10\\/2026', '07\\/10\\/2026');
      } else if (caso == 'posicion duplicada') {
        cuerpo = cuerpo.replaceFirst('"pos":"02"', '"pos":"01"');
      } else {
        cuerpo = cuerpo.replaceFirst('{"pos":"20","val":"7675"}', '');
      }
      final api = LoteriaCiudadApi(
        base: 'https://oficial.test',
        cliente: MockClient((_) async => http.Response(cuerpo, 200)),
      );
      await expectLater(
        api.resultadoHtml(
          loteria: Loteria.nacional,
          fecha: DateTime(2026, 10, 8),
          turno: TurnoSorteo.primera,
          sorteo: '53008',
        ),
        throwsA(isA<QuinielaApiException>()),
      );
      api.cerrar();
    });
  }

  group('fuentes de red', () {
    test(
      'si el proxy falla reintenta la misma ruta contra la fuente oficial',
      () async {
        final hosts = <String>[];
        final cliente = MockClient((pedido) async {
          hosts.add(pedido.url.host);
          if (pedido.url.host == 'proxy.test') {
            return http.Response('proxy no disponible', 502);
          }
          return http.Response.bytes(
            utf8.encode(_fixture('home_indice.html')),
            200,
          );
        });
        final api = LoteriaCiudadApi(
          cliente: cliente,
          base: 'https://proxy.test/fuente-loteria',
          baseAlternativa: 'https://oficial.test',
        );

        final indice = await api.indiceSorteos();

        expect(indice, isNotEmpty);
        expect(hosts, ['proxy.test', 'oficial.test']);
      },
    );
  });

  group('extracto XML de la Ciudad', () {
    late ResultadoSorteo resultado;

    setUp(() {
      resultado = LoteriaCiudadApi.parsearExtractoXml(
        _fixture('ciudad_matutina.xml'),
        loteria: Loteria.nacional,
        fechaEsperada: DateTime(2026, 8, 12),
        turnoEsperado: TurnoSorteo.matutina,
      );
    });

    test('lee las 20 posiciones en orden', () {
      expect(resultado.numeros, hasLength(20));
      expect(resultado.posicion(1), '2141');
      expect(resultado.posicion(2), '7401');
      expect(resultado.posicion(20), '2244');
    });

    test('la cabeza a dos cifras sale de la posicion 1', () {
      expect(resultado.cabeza, '2141');
      expect(resultado.cabezaDosCifras, '41');
    });

    test('toma el turno de la modalidad del propio extracto', () {
      expect(resultado.turno, TurnoSorteo.matutina);
    });

    test('lee letras y numero de sorteo', () {
      expect(resultado.letras, 'U F G X');
      expect(resultado.sorteo, '52764');
    });

    test('si no puede reconocer el turno se queda con el que se pidio', () {
      // El archivo se direcciona por turno, asi que el que se pidio es mejor
      // dato que cualquier default: devolver otro haria que el repositorio
      // guarde en cache con una clave distinta de la que consulta.
      final sinModalidad = _fixture('ciudad_matutina.xml')
          .replaceAll(RegExp(r'<Modalidad>.*?</Modalidad>'), '')
          .replaceAll(RegExp(r'<HoraSorteo>.*?</HoraSorteo>'), '');

      final resultado = LoteriaCiudadApi.parsearExtractoXml(
        sinModalidad,
        loteria: Loteria.nacional,
        fechaEsperada: DateTime(2026, 8, 12),
        turnoEsperado: TurnoSorteo.nocturna,
      );

      expect(resultado.turno, TurnoSorteo.nocturna);
    });

    test('un XML sin el nodo Suerte falla explicitamente', () {
      expect(
        () => LoteriaCiudadApi.parsearExtractoXml(
          '<DatosSorteo><Entidad>x</Entidad></DatosSorteo>',
          loteria: Loteria.nacional,
          fechaEsperada: DateTime(2026, 8, 12),
          turnoEsperado: TurnoSorteo.matutina,
        ),
        throwsA(isA<QuinielaApiException>()),
      );
    });

    test('un XML al que le falta una posicion falla explicitamente', () {
      final truncado = _fixture(
        'ciudad_matutina.xml',
      ).replaceAll(RegExp(r'<N20>\d+</N20>'), '');
      expect(
        () => LoteriaCiudadApi.parsearExtractoXml(
          truncado,
          loteria: Loteria.nacional,
          fechaEsperada: DateTime(2026, 8, 12),
          turnoEsperado: TurnoSorteo.matutina,
        ),
        throwsA(isA<QuinielaApiException>()),
      );
    });

    test('algo que no es XML falla explicitamente', () {
      expect(
        () => LoteriaCiudadApi.parsearExtractoXml(
          '<html><body>404</body>',
          loteria: Loteria.nacional,
          fechaEsperada: DateTime(2026, 8, 12),
          turnoEsperado: TurnoSorteo.matutina,
        ),
        throwsA(isA<QuinielaApiException>()),
      );
    });
  });

  group('fragmento HTML de Provincia', () {
    test('lee las 20 posiciones pese a que la grilla viene duplicada', () {
      final resultado = LoteriaCiudadApi.parsearFragmentoHtml(
        _fixture('buenos_aires_fragmento.html'),
        loteria: Loteria.provincia,
        fecha: DateTime(2026, 8, 12),
        turno: TurnoSorteo.matutina,
      );

      expect(resultado, isNotNull);
      expect(resultado!.numeros, hasLength(20));
      expect(resultado.posicion(1), '6111');
      expect(resultado.posicion(11), '4017');
      expect(resultado.posicion(20), '4899');
      expect(resultado.cabezaDosCifras, '11');
    });

    test('"No hay Sorteo" devuelve null, no una excepcion', () {
      final resultado = LoteriaCiudadApi.parsearFragmentoHtml(
        "<div class='leyenda'>No hay Sorteo de BUENOS AIRES para la fecha "
        'ingresada</div>',
        loteria: Loteria.provincia,
        fecha: DateTime(2026, 8, 12),
        turno: TurnoSorteo.matutina,
      );

      expect(resultado, isNull);
    });

    test('un fragmento vacio devuelve null', () {
      final resultado = LoteriaCiudadApi.parsearFragmentoHtml(
        '<div></div>',
        loteria: Loteria.provincia,
        fecha: DateTime(2026, 8, 12),
        turno: TurnoSorteo.matutina,
      );

      expect(resultado, isNull);
    });

    test('una grilla incompleta falla en vez de devolver datos a medias', () {
      // Se le saca la posicion 20 a las dos copias de la grilla.
      final mutilado = _fixture(
        'buenos_aires_fragmento.html',
      ).replaceAll(RegExp(r'<div class="pos">20</div><div>\d+</div>'), '');

      expect(
        () => LoteriaCiudadApi.parsearFragmentoHtml(
          mutilado,
          loteria: Loteria.provincia,
          fecha: DateTime(2026, 8, 12),
          turno: TurnoSorteo.matutina,
        ),
        throwsA(isA<QuinielaApiException>()),
      );
    });

    test('rellena con ceros a la izquierda si el sitio manda menos digitos', () {
      final resultado = LoteriaCiudadApi.parsearFragmentoHtml(
        [
          for (var p = 1; p <= 20; p++)
            '<div class="pos">${p.toString().padLeft(2, '0')}</div><div>7</div>',
        ].join(),
        loteria: Loteria.provincia,
        fecha: DateTime(2026, 8, 12),
        turno: TurnoSorteo.nocturna,
      );

      expect(resultado!.posicion(1), '0007');
    });
  });

  group('indice de sorteos de la home', () {
    late List<EntradaIndice> indice;

    setUp(() {
      indice = LoteriaCiudadApi.parsearIndice(_fixture('home_indice.html'));
    });

    test('encuentra sorteos', () {
      expect(indice, isNotEmpty);
    });

    test('asigna los turnos en orden dentro de cada fecha', () {
      final delDia =
          indice.where((e) => e.fecha == DateTime(2026, 8, 10)).toList()
            ..sort((a, b) => a.turno.index.compareTo(b.turno.index));

      // 52752..52756 son, segun la tabla de la propia home, PREVIA a NOCTURNA.
      expect(delDia.map((e) => e.sorteo), [
        '52752',
        '52753',
        '52754',
        '52755',
        '52756',
      ]);
    });

    test('el sorteo 52764 cae en la matutina del 12/08, como dice su XML', () {
      final entrada = indice.firstWhere((e) => e.sorteo == '52764');

      expect(entrada.fecha, DateTime(2026, 8, 12));
      expect(entrada.turno, TurnoSorteo.matutina);
    });

    test('no inventa sorteos los domingos', () {
      // El 09/08/2026 fue domingo: la numeracion salta del 08 al 10.
      final domingo = indice.where((e) => e.fecha == DateTime(2026, 8, 9));

      expect(domingo, isEmpty);
    });

    test('un HTML sin el indice falla explicitamente', () {
      expect(
        () => LoteriaCiudadApi.parsearIndice('<html><body>nada</body></html>'),
        throwsA(isA<QuinielaApiException>()),
      );
    });
  });
}

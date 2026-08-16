import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiniela/data/api/loteria_ciudad_api.dart';
import 'package:quiniela/models/sorteo.dart';

/// Los fixtures son respuestas reales del sitio oficial, capturadas el
/// 13/08/2026. Si el sitio cambia el marcado, estos tests siguen pasando pero la
/// app deja de andar: hay que volver a capturarlos para detectarlo.
String _fixture(String nombre) =>
    File('test/fixtures/$nombre').readAsStringSync();

void main() {
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
      final truncado = _fixture('ciudad_matutina.xml')
          .replaceAll(RegExp(r'<N20>\d+</N20>'), '');
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
      final mutilado = _fixture('buenos_aires_fragmento.html').replaceAll(
        RegExp(r'<div class="pos">20</div><div>\d+</div>'),
        '',
      );

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
      final delDia = indice
          .where((e) => e.fecha == DateTime(2026, 8, 10))
          .toList()
        ..sort((a, b) => a.turno.index.compareTo(b.turno.index));

      // 52752..52756 son, segun la tabla de la propia home, PREVIA a NOCTURNA.
      expect(
        delDia.map((e) => e.sorteo),
        ['52752', '52753', '52754', '52755', '52756'],
      );
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

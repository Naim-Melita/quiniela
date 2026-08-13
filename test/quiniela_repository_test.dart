import 'package:flutter_test/flutter_test.dart';
import 'package:quiniela/data/quiniela_repository.dart';
import 'package:quiniela/models/sorteo.dart';

void main() {
  // Un martes cualquiera a las 16:00: ya pasaron La Previa, Primera y Matutina.
  DateTime reloj() => DateTime(2026, 8, 11, 16, 0);
  MockQuinielaRepository crear() => MockQuinielaRepository(reloj: reloj);

  group('sorteosDeHoy', () {
    test('marca finalizados los turnos que ya pasaron', () async {
      final sorteos = await crear().sorteosDeHoy();
      final porTurno = {for (final s in sorteos) s.turno: s.estado};

      expect(porTurno[TurnoSorteo.laPrevia], EstadoSorteo.finalizado);
      expect(porTurno[TurnoSorteo.primera], EstadoSorteo.finalizado);
      expect(porTurno[TurnoSorteo.matutina], EstadoSorteo.finalizado);
      expect(porTurno[TurnoSorteo.vespertina], EstadoSorteo.proximo);
      expect(porTurno[TurnoSorteo.nocturna], EstadoSorteo.proximo);
    });

    test('marca en vivo el turno que esta sorteando', () async {
      // 15:02: la Matutina (15:00) todavia esta dentro de la ventana en vivo.
      final repo = MockQuinielaRepository(
        reloj: () => DateTime(2026, 8, 11, 15, 2),
      );
      final sorteos = await repo.sorteosDeHoy();
      final matutina =
          sorteos.firstWhere((s) => s.turno == TurnoSorteo.matutina);

      expect(matutina.estado, EstadoSorteo.enVivo);
    });
  });

  group('resultados', () {
    test('cada sorteo trae 20 posiciones de 4 digitos', () async {
      final resultados = await crear().resultadosDe(
        fecha: DateTime(2026, 8, 10),
        turno: TurnoSorteo.nocturna,
      );

      expect(resultados, isNotEmpty);
      for (final r in resultados) {
        expect(r.numeros, hasLength(20));
        expect(r.numeros.every((n) => n.length == 4), isTrue);
      }
    });

    test('son deterministas entre llamadas', () async {
      final primera = await crear().resultadosDe(
        fecha: DateTime(2026, 8, 10),
        turno: TurnoSorteo.primera,
      );
      final segunda = await crear().resultadosDe(
        fecha: DateTime(2026, 8, 10),
        turno: TurnoSorteo.primera,
      );

      expect(primera.first.numeros, segunda.first.numeros);
    });

    test('loterias distintas dan pizarras distintas', () async {
      final resultados = await crear().resultadosDe(
        fecha: DateTime(2026, 8, 10),
        turno: TurnoSorteo.primera,
      );
      final nacional =
          resultados.firstWhere((r) => r.loteria == Loteria.nacional);
      final provincia =
          resultados.firstWhere((r) => r.loteria == Loteria.provincia);

      expect(nacional.numeros, isNot(provincia.numeros));
    });

    test('no devuelve turnos de hoy que todavia no se sortearon', () async {
      final resultados = await crear().resultadosDe(fecha: reloj());
      final turnos = resultados.map((r) => r.turno).toSet();

      expect(turnos, isNot(contains(TurnoSorteo.vespertina)));
      expect(turnos, isNot(contains(TurnoSorteo.nocturna)));
      expect(turnos, contains(TurnoSorteo.matutina));
    });

    test('una fecha futura no tiene resultados', () async {
      final resultados = await crear().resultadosDe(
        fecha: DateTime(2026, 8, 20),
      );

      expect(resultados, isEmpty);
    });

    test('cabezaDosCifras son los ultimos dos digitos de la posicion 1', () {
      final resultado = ResultadoSorteo(
        loteria: Loteria.nacional,
        turno: TurnoSorteo.matutina,
        fecha: DateTime(2026, 8, 11),
        numeros: List.filled(20, '0000')..[0] = '1947',
      );

      expect(resultado.cabeza, '1947');
      expect(resultado.cabezaDosCifras, '47');
      expect(resultado.posicion(1), '1947');
    });
  });

  group('ultimosResultados', () {
    test('devuelve el ultimo turno ya publicado', () async {
      final ultimos = await crear().ultimosResultados(
        const [Loteria.nacional, Loteria.provincia],
      );

      expect(ultimos, hasLength(2));
      // A las 16:00 el ultimo publicado es la Matutina de hoy.
      expect(ultimos.every((r) => r.turno == TurnoSorteo.matutina), isTrue);
      expect(ultimos.first.fecha, DateTime(2026, 8, 11));
    });

    test('antes del primer sorteo cae en la Nocturna de ayer', () async {
      final repo = MockQuinielaRepository(
        reloj: () => DateTime(2026, 8, 11, 8, 0),
      );
      final ultimos = await repo.ultimosResultados(const [Loteria.nacional]);

      expect(ultimos.single.turno, TurnoSorteo.nocturna);
      expect(ultimos.single.fecha, DateTime(2026, 8, 10));
    });
  });

  group('frecuencias', () {
    test('cubre los 100 numeros y viene ordenada de mayor a menor', () async {
      final frecuencias = await crear().frecuencias(dias: 7);

      expect(frecuencias, hasLength(100));
      for (var i = 1; i < frecuencias.length; i++) {
        expect(
          frecuencias[i - 1].apariciones,
          greaterThanOrEqualTo(frecuencias[i].apariciones),
        );
      }
    });

    test('el total de apariciones cierra con los sorteos analizados', () async {
      final frecuencias = await crear().frecuencias(dias: 7);
      final total =
          frecuencias.fold<int>(0, (suma, f) => suma + f.apariciones);
      final sorteos = frecuencias.first.sorteosAnalizados;

      // 20 posiciones por sorteo.
      expect(total, sorteos * 20);
    });
  });

  group('generarJugada', () {
    test('respeta la cantidad de cifras pedida', () {
      final repo = crear();
      for (var cifras = 1; cifras <= 4; cifras++) {
        for (var i = 0; i < 50; i++) {
          expect(repo.generarJugada(cifras).numero, hasLength(cifras));
        }
      }
    });

    test('rellena con ceros a la izquierda', () {
      final repo = crear();
      // Con 4 cifras, cualquier numero chico tiene que venir tipo '0042'.
      final jugadas = List.generate(200, (_) => repo.generarJugada(4).numero);
      expect(jugadas.every((n) => n.length == 4), isTrue);
      expect(jugadas.every((n) => int.tryParse(n) != null), isTrue);
    });
  });

  group('diccionario de suenos', () {
    test('sin consulta devuelve los populares', () async {
      final suenos = await crear().buscarSuenos('');
      expect(suenos, isNotEmpty);
    });

    test('busca por nombre y por sinonimo', () async {
      final repo = crear();
      final porNombre = await repo.buscarSuenos('perro');
      final porSinonimo = await repo.buscarSuenos('cachorro');

      expect(porNombre.map((s) => s.numero), contains('06'));
      expect(porSinonimo.map((s) => s.numero), contains('06'));
    });

    test('busca por numero', () async {
      final suenos = await crear().buscarSuenos('32');
      expect(suenos.map((s) => s.numero), contains('32'));
    });

    test('una consulta sin coincidencias devuelve vacio', () async {
      final suenos = await crear().buscarSuenos('xyzzy');
      expect(suenos, isEmpty);
    });
  });
}

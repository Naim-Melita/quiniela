import 'package:flutter_test/flutter_test.dart';
import 'package:quiniela/data/quiniela_repository.dart';
import 'package:quiniela/data/reloj_argentina.dart';
import 'package:quiniela/models/sorteo.dart';

ResultadoSorteo _conCabeza(String cabeza, {List<String>? resto}) {
  return ResultadoSorteo(
    loteria: Loteria.nacional,
    turno: TurnoSorteo.matutina,
    fecha: DateTime(2026, 8, 11),
    numeros: [cabeza, ...?resto, ...List.filled(19 - (resto?.length ?? 0), '0000')],
  );
}

void main() {
  group('reloj argentino', () {
    test('devuelve la hora de Argentina, no la del dispositivo', () {
      final ahora = ahoraEnArgentina();
      final utc = DateTime.now().toUtc();
      final esperado = utc.add(desplazamientoArgentina);

      // Se compara al minuto para no depender del instante exacto.
      expect(ahora.hour, esperado.hour);
      expect(ahora.day, esperado.day);
    });

    test('esta tres horas detras de UTC', () {
      final ahora = ahoraEnArgentina();
      final utc = DateTime.now().toUtc();
      final diferencia = DateTime(
        utc.year,
        utc.month,
        utc.day,
        utc.hour,
        utc.minute,
      ).difference(DateTime(
        ahora.year,
        ahora.month,
        ahora.day,
        ahora.hour,
        ahora.minute,
      ));

      expect(diferencia, const Duration(hours: 3));
    });
  });

  group('acierto de una jugada', () {
    test('acierta contra las ultimas cifras, no contra las primeras', () {
      final resultado = _conCabeza('4221');

      // A dos cifras el 4221 paga el 21, no el 42.
      expect(resultado.posicionesDe('21'), contains(1));
      expect(resultado.posicionesDe('42'), isNot(contains(1)));
    });

    test('funciona de 1 a 4 cifras', () {
      final resultado = _conCabeza('4221');

      expect(resultado.posicionesDe('1'), contains(1));
      expect(resultado.posicionesDe('21'), contains(1));
      expect(resultado.posicionesDe('221'), contains(1));
      expect(resultado.posicionesDe('4221'), contains(1));
    });

    test('encuentra el mismo numero en varias posiciones', () {
      final resultado = _conCabeza('4221', resto: ['1121', '9999']);

      // Posicion 1 (4221) y 2 (1121) terminan en 21; la 3 no.
      expect(resultado.posicionesDe('21'), [1, 2]);
    });

    test('una jugada vacia o de mas de 4 cifras no acierta nada', () {
      final resultado = _conCabeza('4221');

      expect(resultado.posicionesDe(''), isEmpty);
      expect(resultado.posicionesDe('42210'), isEmpty);
    });

    test('el 00 acierta a los numeros terminados en 00', () {
      final resultado = _conCabeza('3500');

      expect(resultado.posicionesDe('00'), contains(1));
    });
  });

  group('turnos por loteria', () {
    test('la mayoria juega los cinco turnos', () {
      for (final loteria in [
        Loteria.nacional,
        Loteria.provincia,
        Loteria.santaFe,
        Loteria.cordoba,
        Loteria.entreRios,
      ]) {
        expect(
          loteria.turnosQueJuega,
          TurnoSorteo.values,
          reason: '${loteria.nombre} deberia jugar los 5',
        );
      }
    });

    test('Montevideo solo juega matutina y nocturna', () {
      expect(Loteria.montevideo.turnosQueJuega, [
        TurnoSorteo.matutina,
        TurnoSorteo.nocturna,
      ]);
      expect(Loteria.montevideo.juega(TurnoSorteo.laPrevia), isFalse);
      expect(Loteria.montevideo.juega(TurnoSorteo.nocturna), isTrue);
    });

    test('cada loteria tiene un codigo de jurisdiccion distinto', () {
      final codigos = Loteria.values.map((l) => l.jurisdiccion).toSet();
      expect(codigos, hasLength(Loteria.values.length));
    });

    test('solo Nacional tiene extracto XML', () {
      final conXml = Loteria.values.where((l) => l.tieneExtractoXml);
      expect(conXml, [Loteria.nacional]);
    });
  });

  group('resultadosDe respeta los turnos de cada loteria', () {
    test('no devuelve turnos que Montevideo no juega', () async {
      final repo = MockQuinielaRepository(
        reloj: () => DateTime(2026, 8, 11, 23, 0),
      );
      final resultados = await repo.resultadosDe(
        fecha: DateTime(2026, 8, 10),
        loterias: const [Loteria.montevideo],
      );

      expect(resultados, hasLength(2));
      expect(
        resultados.map((r) => r.turno).toSet(),
        {TurnoSorteo.matutina, TurnoSorteo.nocturna},
      );
    });
  });

  group('buscarNumero', () {
    late MockQuinielaRepository repo;

    setUp(() {
      repo = MockQuinielaRepository(reloj: () => DateTime(2026, 8, 11, 23, 0));
    });

    test('cada aparicion informa en que posiciones salio', () async {
      final apariciones = await repo.buscarNumero(
        jugada: '21',
        loterias: Loteria.values,
        dias: 5,
      );

      expect(apariciones, isNotEmpty);
      for (final aparicion in apariciones) {
        expect(aparicion.posiciones, isNotEmpty);
        for (final p in aparicion.posiciones) {
          expect(aparicion.resultado.posicion(p).endsWith('21'), isTrue);
        }
      }
    });

    test('viene ordenado del mas reciente al mas viejo', () async {
      final apariciones = await repo.buscarNumero(
        jugada: '7',
        loterias: Loteria.predeterminadas,
        dias: 4,
      );

      expect(apariciones.length, greaterThan(1));
      for (var i = 1; i < apariciones.length; i++) {
        final anterior = apariciones[i - 1].resultado;
        final actual = apariciones[i].resultado;
        expect(
          anterior.fecha.isAfter(actual.fecha) ||
              anterior.fecha.isAtSameMomentAs(actual.fecha),
          isTrue,
        );
      }
    });

    test('aLaCabeza es cierto solo si salio en la posicion 1', () async {
      final apariciones = await repo.buscarNumero(
        jugada: '5',
        loterias: Loteria.predeterminadas,
        dias: 5,
      );

      for (final a in apariciones) {
        expect(a.aLaCabeza, a.posiciones.contains(1));
      }
    });

    test('una jugada invalida devuelve vacio', () async {
      expect(
        await repo.buscarNumero(jugada: '', loterias: Loteria.values),
        isEmpty,
      );
      expect(
        await repo.buscarNumero(jugada: '12345', loterias: Loteria.values),
        isEmpty,
      );
    });
  });
}

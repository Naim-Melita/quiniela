import 'package:flutter_test/flutter_test.dart';
import 'package:quiniela/data/loteria_ciudad_repository.dart';
import 'package:quiniela/models/sorteo.dart';
import 'package:quiniela/data/reloj_argentina.dart';

/// Verificacion contra el sitio oficial EN VIVO.
///
/// No termina en `_test.dart` a proposito: `flutter test` no lo levanta solo,
/// porque depende de la red y del estado del sitio. Se corre a mano cuando hace
/// falta confirmar que la fuente sigue respondiendo como esperamos:
///
///     flutter test test/manual/verificar_fuente_real.dart
///
/// Si esto falla y los tests de `loteria_ciudad_api_test.dart` pasan, el sitio
/// cambio: hay que recapturar los fixtures de `test/fixtures/`.
void main() {
  late LoteriaCiudadRepository repo;

  setUp(() => repo = LoteriaCiudadRepository());

  test('trae el ultimo resultado de Nacional y Provincia', () async {
    final reloj = Stopwatch()..start();
    final ultimos = await repo.ultimosResultados(const [
      Loteria.nacional,
      Loteria.provincia,
    ]);
    reloj.stop();

    printOnFailure('tardo ${reloj.elapsedMilliseconds} ms');
    for (final r in ultimos) {
      // ignore: avoid_print
      print(
        '${r.loteria.nombre.padRight(10)} ${r.turno.nombre.padRight(11)} '
        '${r.fecha.toIso8601String().substring(0, 10)}  '
        'cabeza=${r.cabeza} (${r.cabezaDosCifras})  '
        'sorteo=${r.sorteo ?? "-"}  letras=${r.letras ?? "-"}',
      );
    }

    expect(ultimos, hasLength(2), reason: 'faltan loterias');
    for (final r in ultimos) {
      expect(r.numeros, hasLength(20));
      expect(
        r.numeros.every((n) => RegExp(r'^\d{4}$').hasMatch(n)),
        isTrue,
        reason: 'hay numeros que no son de 4 digitos: ${r.numeros}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('trae la jornada completa de un dia habil pasado', () async {
    // Una jornada completa reciente, dentro del indice disponible.
    var fecha = ahoraEnArgentina().subtract(const Duration(days: 1));
    while (fecha.weekday == DateTime.sunday) {
      fecha = fecha.subtract(const Duration(days: 1));
    }
    final resultados = await repo.resultadosDe(fecha: fecha);

    for (final r in resultados) {
      // ignore: avoid_print
      print(
        '${r.turno.nombre.padRight(11)} ${r.loteria.nombre.padRight(10)} '
        'cabeza=${r.cabeza}',
      );
    }

    expect(
      resultados.map((r) => r.turno).toSet(),
      TurnoSorteo.values.toSet(),
      reason: 'faltan turnos de la jornada',
    );
    expect(resultados.map((r) => r.loteria).toSet(), {
      Loteria.nacional,
      Loteria.provincia,
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('un dia sin sorteo (domingo) devuelve vacio, sin explotar', () async {
    final hoy = ahoraEnArgentina();
    final domingo = hoy.subtract(Duration(days: hoy.weekday % 7));
    final resultados = await repo.resultadosDe(fecha: domingo);

    // ignore: avoid_print
    print('domingo: ${resultados.length} resultados');
    expect(resultados, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('las frecuencias se calculan sobre sorteos reales', () async {
    final frecuencias = await repo.frecuencias(dias: 3);

    expect(frecuencias, hasLength(100));
    final analizados = frecuencias.first.sorteosAnalizados;
    final total = frecuencias.fold<int>(0, (s, f) => s + f.apariciones);

    // ignore: avoid_print
    print(
      'sorteos analizados=$analizados  '
      'top: ${frecuencias.take(5).map((f) => "${f.numero}(${f.apariciones})").join(" ")}',
    );

    expect(analizados, greaterThan(0), reason: 'no se bajo ningun sorteo');
    expect(total, analizados * 20);
  }, timeout: const Timeout(Duration(minutes: 5)));
}

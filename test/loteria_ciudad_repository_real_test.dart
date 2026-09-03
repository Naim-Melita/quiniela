import 'package:flutter_test/flutter_test.dart';
import 'package:quiniela/data/api/loteria_ciudad_api.dart';
import 'package:quiniela/data/cache_resultados.dart';
import 'package:quiniela/data/loteria_ciudad_repository.dart';
import 'package:quiniela/models/sorteo.dart';

class _ApiSinConexion extends LoteriaCiudadApi {
  @override
  Future<ResultadoSorteo?> extractoXml({
    required Loteria loteria,
    required DateTime fecha,
    required TurnoSorteo turno,
  }) {
    throw const QuinielaApiException('sin conexion');
  }
}

void main() {
  test(
    'un fallo total de red no se presenta como una jornada sin sorteos',
    () async {
      final repo = LoteriaCiudadRepository(
        api: _ApiSinConexion(),
        cache: CacheResultados(nombreArchivo: 'test_fallo_total.json'),
        reloj: () => DateTime(2026, 8, 20, 16),
      );

      expect(
        () => repo.resultadosDe(
          fecha: DateTime(2026, 8, 20),
          turno: TurnoSorteo.primera,
          loterias: const [Loteria.nacional],
        ),
        throwsA(isA<QuinielaApiException>()),
      );
    },
  );
}

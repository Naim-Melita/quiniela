import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiniela/data/anuncios.dart';
import 'package:quiniela/widgets/banner_anuncio.dart';

/// Cuando corresponde el anuncio de apertura.
///
/// Es la unica parte de la publicidad que decide si al usuario le tapa la
/// pantalla, asi que se prueba sola, sin SDK ni disco de por medio.
bool _corresponde({
  required int aperturas,
  DateTime? ultimaApertura,
  DateTime? ahora,
  int antesDelPrimero = 3,
  Duration espera = const Duration(hours: 4),
}) {
  return Anuncios.corresponde(
    aperturas: aperturas,
    ultimaApertura: ultimaApertura,
    ahora: ahora ?? DateTime(2026, 8, 15, 12),
    aperturasAntesDelPrimero: antesDelPrimero,
    esperaEntreAperturas: espera,
  );
}

void main() {
  group('anuncio de apertura', () {
    test('no aparece en las primeras tres aperturas', () {
      for (var apertura = 1; apertura <= 3; apertura++) {
        expect(
          _corresponde(aperturas: apertura),
          isFalse,
          reason: 'la apertura $apertura no deberia tener anuncio',
        );
      }
    });

    test('aparece recien en la cuarta', () {
      expect(_corresponde(aperturas: 4), isTrue);
    });

    test('sigue apareciendo despues de la cuarta', () {
      expect(_corresponde(aperturas: 12), isTrue);
    });

    test('no se repite antes de que pase la espera', () {
      final ahora = DateTime(2026, 8, 15, 12);
      expect(
        _corresponde(
          aperturas: 10,
          ultimaApertura: ahora.subtract(const Duration(hours: 1)),
          ahora: ahora,
        ),
        isFalse,
      );
    });

    test('vuelve a aparecer cuando paso la espera', () {
      final ahora = DateTime(2026, 8, 15, 12);
      expect(
        _corresponde(
          aperturas: 10,
          ultimaApertura: ahora.subtract(const Duration(hours: 5)),
          ahora: ahora,
        ),
        isTrue,
      );
    });

    test('el umbral se puede mover sin tocar la regla', () {
      expect(_corresponde(aperturas: 4, antesDelPrimero: 9), isFalse);
      expect(_corresponde(aperturas: 10, antesDelPrimero: 9), isTrue);
    });
  });

  group('banner', () {
    testWidgets('sin publicidad provista no ocupa lugar', (tester) async {
      // Es lo que mantiene la app entera testeable y lo que hace que la build
      // web, donde el SDK de AdMob no existe, no intente pedir nada.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Column(children: [BannerAnuncio()])),
        ),
      );
      await tester.pump();

      expect(tester.getSize(find.byType(BannerAnuncio)).height, 0);
      expect(tester.takeException(), isNull);
    });
  });
}

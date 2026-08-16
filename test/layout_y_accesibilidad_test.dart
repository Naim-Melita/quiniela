import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiniela/data/preferencias.dart';
import 'package:quiniela/data/quiniela_repository.dart';
import 'package:quiniela/screens/home_shell.dart';
import 'package:quiniela/theme/app_theme.dart';

/// Que la app entre y se pueda usar en los extremos razonables.
///
/// Los dos ejes que rompian cosas de verdad son el ancho y la escala de texto
/// del sistema, y se combinan: los desbordes aparecian solo en 320px con el
/// texto al 200%, que es un telefono chico con accesibilidad activada. Se prueba
/// la matriz completa porque cada arreglo puntual movia el problema a otra fila.

Widget _app({TextScaler escala = TextScaler.noScaling}) => MediaQuery(
      data: MediaQueryData(textScaler: escala),
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: HomeShell(
          // Reloj fijo: la agenda del dia no puede depender de la hora a la que
          // corran los tests.
          repositorio: MockQuinielaRepository(
            reloj: () => DateTime(2026, 8, 11, 16, 0),
          ),
          preferencias: PreferenciasLoterias(),
        ),
      ),
    );

/// Monta la app en un tamano dado y abre una pestana.
///
/// El IndexedStack construye las cuatro pantallas siempre, asi que un desborde
/// en cualquiera de ellas salta aunque no sea la que se esta mirando.
Future<void> _abrir(
  WidgetTester tester,
  String pestana, {
  required double ancho,
  TextScaler escala = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = Size(ancho, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_app(escala: escala));
  await tester.pump(const Duration(milliseconds: 500));
  if (pestana != 'Inicio') {
    await tester.tap(find.text(pestana));
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  group('no desborda', () {
    // 320 es el piso real de telefonos en uso (iPhone SE 1a gen y similares).
    const anchos = {'320px': 320.0, '390px': 390.0, '430px': 430.0};
    const escalas = {'1.0x': 1.0, '1.5x': 1.5, '2.0x': 2.0};

    for (final pestana in ['Inicio', 'Resultados', 'Generador', 'Stats']) {
      for (final ancho in anchos.entries) {
        for (final escala in escalas.entries) {
          testWidgets('$pestana en ${ancho.key} con texto ${escala.key}',
              (tester) async {
            await _abrir(
              tester,
              pestana,
              ancho: ancho.value,
              escala: TextScaler.linear(escala.value),
            );

            // Cuatro cifras es el caso mas ancho del generador.
            if (pestana == 'Generador') {
              await tester.tap(find.text('4 cifras'));
              await tester.pump(const Duration(milliseconds: 300));
            }

            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  // Falta aca el tercer matcher que trae Flutter, textContrastGuideline. No se
  // puede usar mientras las tipografias vengan de google_fonts: necesita
  // rasterizar el texto y google_fonts las descarga por red, que en los tests
  // esta cortada. El contraste de la paleta se verifico a mano con la formula
  // de WCAG; si algun dia las fuentes se empaquetan como asset, este grupo
  // deberia sumar `meetsGuideline(textContrastGuideline)`.
  group('accesibilidad', () {
    for (final pestana in ['Inicio', 'Resultados', 'Generador', 'Stats']) {
      testWidgets('$pestana respeta el minimo de 48dp al tocar', (tester) async {
        await _abrir(tester, pestana, ancho: 390);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      });

      testWidgets('$pestana no deja controles sin nombre', (tester) async {
        await _abrir(tester, pestana, ancho: 390);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      });
    }
  });
}

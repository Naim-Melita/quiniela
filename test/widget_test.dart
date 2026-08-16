import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiniela/data/preferencias.dart';
import 'package:quiniela/data/quiniela_repository.dart';
import 'package:quiniela/screens/home_shell.dart';
import 'package:quiniela/theme/app_theme.dart';

/// Monta el shell con un reloj fijo, para que la agenda del dia no dependa de
/// la hora a la que corran los tests.
Widget _app() {
  return MaterialApp(
    theme: AppTheme.dark,
    locale: const Locale('es'),
    supportedLocales: const [Locale('es'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: HomeShell(
      repositorio: MockQuinielaRepository(
        reloj: () => DateTime(2026, 8, 11, 16, 0),
      ),
      // Sin path_provider en los tests, cargar() falla y quedan las
      // predeterminadas: Nacional y Provincia. Es justo lo que queremos.
      preferencias: PreferenciasLoterias(),
    ),
  );
}

/// Monta la app y avanza el reloj hasta que resuelvan los FutureBuilder.
///
/// No se puede usar pumpAndSettle: el ticker de ultimo minuto y el punto de
/// "en vivo" son animaciones que se repiten para siempre, asi que el arbol
/// nunca queda quieto.
///
/// El viewport por defecto de los tests es 800x600, mas corto que cualquier
/// telefono: con esa altura las listas no llegan a construir el contenido de
/// abajo y los finders no lo encuentran. Se usa una pantalla alta para que la
/// pagina entre completa.
Future<void> _cargar(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_app());
  await tester.pump(const Duration(milliseconds: 500));
}

/// Pestana visible del shell.
int? _pestanaActiva(WidgetTester tester) =>
    tester.widget<IndexedStack>(find.byType(IndexedStack)).index;

void main() {
  testWidgets('el dashboard muestra los ultimos resultados', (tester) async {
    await _cargar(tester);

    expect(find.text('Ultimos Resultados'), findsOneWidget);
    expect(find.text('Sorteos de Hoy'), findsOneWidget);
    expect(find.text('Nacional'), findsOneWidget);
    expect(find.text('Provincia'), findsOneWidget);
  });

  testWidgets('la agenda marca la Vespertina como proxima', (tester) async {
    await _cargar(tester);

    expect(find.text('Vespertina'), findsOneWidget);
    expect(find.text('Proximo'), findsWidgets);
    expect(find.text('Finalizado'), findsWidgets);
  });

  testWidgets('la barra inferior cambia de pestana', (tester) async {
    await _cargar(tester);
    expect(_pestanaActiva(tester), 0);

    await tester.tap(find.text('Generador'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(_pestanaActiva(tester), 2);
  });

  testWidgets('el boton del dashboard lleva al generador', (tester) async {
    await _cargar(tester);

    await tester.tap(find.text('Generar Numero de la Suerte'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(_pestanaActiva(tester), 2);
  });

  testWidgets('generar una jugada llena los dos slots', (tester) async {
    await _cargar(tester);
    await tester.tap(find.text('Generador'));
    await tester.pump(const Duration(milliseconds: 500));

    // Arranca en 2 cifras, con los dos casilleros vacios.
    expect(find.text('-'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(FilledButton, 'Generar'));
    // La animacion de ruleta dura 700 ms antes de fijar el numero.
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('-'), findsNothing);
  });

  testWidgets('cambiar a 4 cifras resetea a cuatro slots', (tester) async {
    await _cargar(tester);
    await tester.tap(find.text('Generador'));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('4 cifras'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('-'), findsNWidgets(4));
  });

  testWidgets('la flecha de dia siguiente vuelve a hoy', (tester) async {
    // Regresion: con la fecha guardada con hora, volver de ayer a hoy daba
    // "hoy a las 15:30", que es despues de hoy a la medianoche, y el guard de
    // "no hay resultados en el futuro" bloqueaba la flecha para siempre.
    await _cargar(tester);
    await tester.tap(find.text('Resultados'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Hoy'), findsOneWidget);

    await tester.tap(find.byTooltip('Dia anterior'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Hoy'), findsNothing);

    await tester.tap(find.byTooltip('Dia siguiente'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Hoy'), findsOneWidget);
  });

  testWidgets('buscar en el diccionario filtra los suenos', (tester) async {
    await _cargar(tester);
    await tester.tap(find.text('Generador'));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextField), 'perro');
    // Un frame para el setState y otro para cuando resuelve el FutureBuilder.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('El perro'), findsOneWidget);
    expect(find.text('POPULARES'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiniela/data/preferencias.dart';
import 'package:quiniela/data/quiniela_repository.dart';
import 'package:quiniela/screens/resultados_screen.dart';
import 'package:quiniela/theme/app_theme.dart';

/// Fecha deliberadamente distinta de "hoy" en el mundo real: si la pantalla
/// alguna vez vuelve a mirar el reloj del dispositivo en lugar del reloj
/// inyectado, este test deja de pasar.
final _fechaFija = DateTime(2026, 8, 5, 10, 0);
DateTime _relojFijo() => _fechaFija;

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
    home: ResultadosScreen(
      repositorio: MockQuinielaRepository(reloj: _relojFijo),
      preferencias: PreferenciasLoterias(),
      reloj: _relojFijo,
    ),
  );
}

Future<void> _cargar(WidgetTester tester) async {
  // Mismo viewport que test/widget_test.dart: el default 800x600 corta
  // contenido antes de llegar a lo que buscan los finders.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_app());
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets(
    'la fecha inicial sale del reloj inyectado, no del reloj real',
    (tester) async {
      await _cargar(tester);

      // esHoy compara _fecha contra el reloj, y ambos salen del mismo reloj
      // fijo: si el encabezado dice "Hoy", _fecha se inicializo con el reloj
      // inyectado. La fecha en chico confirma que es la fecha correcta y no
      // cualquier otra que tambien coincidiera con "hoy".
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('05/08/2026'), findsOneWidget);
    },
  );

  testWidgets(
    'el boton de dia siguiente esta deshabilitado en la fecha del reloj',
    (tester) async {
      await _cargar(tester);

      // No hay resultados en el futuro: en "hoy" (segun el reloj inyectado)
      // la flecha de avanzar debe quedar apagada.
      final boton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      expect(boton.onPressed, isNull);
    },
  );
}

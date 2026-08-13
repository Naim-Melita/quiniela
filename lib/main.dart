import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/api/loteria_ciudad_api.dart';
import 'data/loteria_ciudad_repository.dart';
import 'data/preferencias.dart';
import 'screens/home_shell.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');

  // Se cargan antes de arrancar para que el inicio no parpadee mostrando las
  // predeterminadas y despues las del usuario.
  final preferencias = PreferenciasLoterias();
  await preferencias.cargar();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surfaceContainerHighest,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(QuinielaApp(preferencias: preferencias));
}

/// A donde le pega la app.
///
/// En Android va directo al sitio oficial. En web el navegador bloquea esa
/// llamada por CORS (el sitio no manda las cabeceras), asi que en debug se pasa
/// por el proxy local de `tool/proxy_cors.dart`, que existe solo para poder
/// mirar la app real en el navegador sin emulador.
String get _baseApi => kIsWeb && kDebugMode
    ? 'http://localhost:8090'
    : LoteriaCiudadApi.baseOficial;

class QuinielaApp extends StatelessWidget {
  const QuinielaApp({super.key, required this.preferencias});

  final PreferenciasLoterias preferencias;

  @override
  Widget build(BuildContext context) {
    // Punto unico de inyeccion. Con MockQuinielaRepository() la app corre
    // entera contra datos simulados, sin red, que es lo que usan los tests.
    final repositorio = LoteriaCiudadRepository(
      api: LoteriaCiudadApi(base: _baseApi),
    );

    return MaterialApp(
      title: 'Quiniela',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: HomeShell(
        repositorio: repositorio,
        preferencias: preferencias,
      ),
    );
  }
}

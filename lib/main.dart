import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/anuncios.dart';
import 'data/api/loteria_ciudad_api.dart';
import 'data/loteria_ciudad_repository.dart';
import 'data/preferencias.dart';
import 'screens/home_shell.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/banner_anuncio.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');

  // Se cargan antes de arrancar para que el inicio no parpadee mostrando las
  // predeterminadas y despues las del usuario.
  final preferencias = PreferenciasLoterias();
  await preferencias.cargar();

  // Cuenta esta apertura y arranca el SDK. No se hace con await bloqueante mas
  // alla de esto: si AdMob tarda, la app tiene que abrir igual.
  final anuncios = Anuncios();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surfaceContainerHighest,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  mostrarAplicacionAntesDeIniciarPublicidad(
    mostrarAplicacion: () =>
        runApp(QuinielaApp(preferencias: preferencias, anuncios: anuncios)),
    iniciarPublicidad: anuncios.iniciar,
  );
}

/// Dibuja la primera pantalla antes de iniciar cualquier SDK publicitario.
///
/// AdMob es accesorio: una inicializacion lenta nunca puede dejar a Android en
/// el splash nativo. La funcion separada mantiene esa garantia bajo prueba.
@visibleForTesting
void mostrarAplicacionAntesDeIniciarPublicidad({
  required VoidCallback mostrarAplicacion,
  required Future<void> Function() iniciarPublicidad,
}) {
  mostrarAplicacion();
  unawaited(iniciarPublicidad());
}

/// A donde le pega la app.
///
/// En Android va directo al sitio oficial. En web el navegador bloquea esa
/// llamada por CORS (el sitio no manda las cabeceras), asi que en debug se pasa
/// por el proxy local de `tool/proxy_cors.dart`, que existe solo para poder
/// mirar la app real en el navegador sin emulador.
class QuinielaApp extends StatefulWidget {
  const QuinielaApp({
    super.key,
    required this.preferencias,
    required this.anuncios,
  });

  final PreferenciasLoterias preferencias;
  final Anuncios anuncios;

  @override
  State<QuinielaApp> createState() => _QuinielaAppState();
}

class _QuinielaAppState extends State<QuinielaApp> {
  // Punto unico de inyeccion. Con MockQuinielaRepository() la app corre
  // entera contra datos simulados, sin red, que es lo que usan los tests.
  //
  // Se arma aca y no en build(): cada build seria otro http.Client abierto,
  // otro cache en memoria vacio y volver a bajar el indice de sorteos.
  late final LoteriaCiudadApi _api = kIsWeb && kDebugMode
      ? LoteriaCiudadApi(base: 'http://localhost:8090')
      : LoteriaCiudadApi();
  late final LoteriaCiudadRepository _repositorio = LoteriaCiudadRepository(
    api: _api,
  );

  @override
  void initState() {
    super.initState();
    // Despues del primer frame: mostrarlo antes taparia una pantalla que
    // todavia se esta armando, que es de las cosas que AdMob no permite.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.anuncios.mostrarApertura(),
    );
  }

  @override
  void dispose() {
    _api.cerrar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Lo que se ve en el conmutador de apps de Android. Va la marca sola: el
      // titulo largo ("Quiniela24: Resultados de Hoy") es el de la ficha de
      // Play, y ahi lo configura la consola, no el codigo.
      title: 'Quiniela24',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: PublicidadDeLaApp(
        anuncios: widget.anuncios,
        child: HomeShell(
          repositorio: _repositorio,
          preferencias: widget.preferencias,
        ),
      ),
    );
  }
}

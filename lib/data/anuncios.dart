import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path_provider/path_provider.dart';

/// Identificadores de AdMob.
///
/// Cuenta `ca-app-pub-1932510392030959`. El App ID va aparte, en el meta-data
/// `com.google.android.gms.ads.APPLICATION_ID` de
/// `android/app/src/main/AndroidManifest.xml`: es otro identificador y lleva `~`
/// en vez de `/`.
///
/// **En debug siempre se piden anuncios de prueba.** No es comodidad: pedir un
/// anuncio real desde una build de desarrollo cuenta como trafico invalido y es
/// la causa mas comun de que AdMob suspenda una cuenta.
///
/// Ojo con `flutter run --release` en el telefono propio: eso ya pide anuncios
/// reales, y tocarlos cuenta como clic invalido. Para probar en release hay que
/// anotar el dispositivo en [Anuncios.dispositivosDePrueba].
abstract final class IdsAnuncios {
  static const _bannerReal = 'ca-app-pub-1932510392030959/9355076371';
  static const _aperturaReal = 'ca-app-pub-1932510392030959/3791758506';

  /// Unidades de prueba oficiales de Google para Android.
  static const _bannerPrueba = 'ca-app-pub-3940256099942544/6300978111';
  static const _aperturaPrueba = 'ca-app-pub-3940256099942544/9257395921';

  /// Solo en release se piden anuncios reales. En debug, siempre los de prueba.
  static bool get _reales => kReleaseMode;

  static String get banner => _reales ? _bannerReal : _bannerPrueba;
  static String get apertura => _reales ? _aperturaReal : _aperturaPrueba;
}

/// Publicidad de la app: banners en pantalla y anuncio de apertura.
///
/// Lleva la cuenta de cuantas veces se abrio la app en disco, porque el anuncio
/// de apertura no se muestra las primeras veces: alguien que instala y lo
/// primero que ve es una pantalla completa de publicidad desinstala. Recien
/// aparece cuando ya hubo tiempo de entender para que sirve la app.
class Anuncios {
  Anuncios({
    this.nombreArchivo = 'uso.json',
    this.aperturasAntesDelPrimero = 3,
    this.esperaEntreAperturas = const Duration(hours: 4),
  });

  final String nombreArchivo;

  /// Cuantas aperturas pasan sin anuncio. Con 3, el primero cae en la cuarta vez
  /// que se abre la app.
  final int aperturasAntesDelPrimero;

  /// Minimo entre dos anuncios de apertura. Sin esto, quien mira los resultados
  /// cinco veces por dia se come cinco pantallas completas.
  final Duration esperaEntreAperturas;

  /// IDs de dispositivos para los que AdMob manda anuncios de prueba aun en
  /// release. El ID sale del logcat al pedir el primer anuncio.
  static const dispositivosDePrueba = <String>[];

  bool _iniciado = false;
  int _aperturas = 0;
  DateTime? _ultimaApertura;
  File? _archivo;
  Future<void>? _inicializacion;

  /// Si se pueden pedir anuncios. Falso en web (el SDK no existe ahi) y en los
  /// tests, donde no hay canal de plataforma.
  bool get disponibles => _iniciado;

  /// Arranca el SDK y cuenta esta apertura.
  ///
  /// Nunca tira: que falle la publicidad no puede impedir que abra la app.
  Future<void> iniciar() => _inicializacion ??= _iniciar();

  Future<void> _iniciar() async {
    if (kIsWeb) return;
    try {
      await _leerUso();
      _aperturas++;
      await _guardarUso();

      await (() async {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: dispositivosDePrueba),
        );
        await MobileAds.instance.initialize();
      })().timeout(const Duration(seconds: 20));
      _iniciado = true;
    } catch (e) {
      debugPrint('No se pudo iniciar la publicidad: $e');
    }
  }

  /// Si en esta apertura corresponde mostrar el anuncio de pantalla completa.
  bool get toca =>
      _iniciado &&
      corresponde(
        aperturas: _aperturas,
        ultimaApertura: _ultimaApertura,
        ahora: DateTime.now(),
        aperturasAntesDelPrimero: aperturasAntesDelPrimero,
        esperaEntreAperturas: esperaEntreAperturas,
      );

  /// La regla de cuando toca anuncio de apertura, sin nada de AdMob alrededor.
  ///
  /// Esta suelta y es estatica para poder probarla: el resto de la clase
  /// necesita el SDK y el disco, y esto es justamente lo unico que decide si el
  /// usuario se come una pantalla completa o no.
  @visibleForTesting
  static bool corresponde({
    required int aperturas,
    required DateTime? ultimaApertura,
    required DateTime ahora,
    required int aperturasAntesDelPrimero,
    required Duration esperaEntreAperturas,
  }) {
    // Las primeras veces no: quien instala y lo primero que ve es una pantalla
    // de publicidad desinstala.
    if (aperturas <= aperturasAntesDelPrimero) return false;

    // Y despues, con separacion: sin esto, quien mira los resultados cinco
    // veces por dia se come cinco pantallas completas.
    if (ultimaApertura != null &&
        ahora.difference(ultimaApertura) < esperaEntreAperturas) {
      return false;
    }
    return true;
  }

  /// Carga y muestra el anuncio de apertura, si corresponde.
  ///
  /// Se llama despues del primer frame: mostrarlo antes taparia la pantalla
  /// mientras todavia se esta armando, que es justo lo que AdMob no permite.
  Future<void> mostrarApertura() async {
    // El primer frame puede llegar antes que AdMob. Se espera aca, fuera del
    // arranque visual, y se comparte el mismo Future para no inicializar dos
    // veces ni contar dos aperturas.
    await iniciar();
    if (!toca) return;

    await AppOpenAd.load(
      adUnitId: IdsAnuncios.apertura,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (anuncio) {
          anuncio.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (a) => a.dispose(),
            onAdFailedToShowFullScreenContent: (a, e) {
              debugPrint('No se pudo mostrar el anuncio de apertura: $e');
              a.dispose();
            },
          );
          // La marca de tiempo se pone al mostrarlo, no al pedirlo: si no
          // carga, la proxima apertura tiene que poder intentarlo de nuevo.
          _ultimaApertura = DateTime.now();
          unawaited(_guardarUso());
          anuncio.show();
        },
        onAdFailedToLoad: (e) =>
            debugPrint('No cargo el anuncio de apertura: $e'),
      ),
    );
  }

  // --- Uso en disco --------------------------------------------------------

  Future<void> _leerUso() async {
    try {
      final archivo = await _obtenerArchivo();
      if (!await archivo.exists()) return;

      final crudo = jsonDecode(await archivo.readAsString());
      if (crudo is! Map) return;

      _aperturas = (crudo['aperturas'] as num?)?.toInt() ?? 0;
      final ultima = crudo['ultimaApertura'];
      if (ultima is String) _ultimaApertura = DateTime.tryParse(ultima);
    } catch (e) {
      debugPrint('No se pudo leer el uso: $e');
    }
  }

  Future<void> _guardarUso() async {
    try {
      final archivo = await _obtenerArchivo();
      await archivo.writeAsString(
        jsonEncode({
          'aperturas': _aperturas,
          'ultimaApertura': _ultimaApertura?.toIso8601String(),
        }),
        flush: true,
      );
    } catch (e) {
      debugPrint('No se pudo guardar el uso: $e');
    }
  }

  Future<File> _obtenerArchivo() async {
    final existente = _archivo;
    if (existente != null) return existente;
    final dir = await getApplicationSupportDirectory();
    return _archivo = File('${dir.path}/$nombreArchivo');
  }
}

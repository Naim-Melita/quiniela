import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../data/anuncios.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Deja la publicidad disponible para toda la app.
///
/// Va por InheritedWidget y no por constructor porque es transversal: pasarlo
/// por parametro obligaria a que cada pantalla lo reciba y lo reenvie sin
/// usarlo. Donde no esta provisto -- los tests y la build web -- [BannerAnuncio]
/// no dibuja nada, que es justo lo que queremos.
class PublicidadDeLaApp extends InheritedWidget {
  const PublicidadDeLaApp({
    super.key,
    required this.anuncios,
    required super.child,
  });

  final Anuncios anuncios;

  static Anuncios? de(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PublicidadDeLaApp>()
      ?.anuncios;

  @override
  bool updateShouldNotify(PublicidadDeLaApp anterior) =>
      anterior.anuncios != anuncios;
}

/// Banner adaptativo, pensado para ir intercalado entre secciones.
///
/// Tres decisiones para que no moleste:
///
/// - Reserva su alto desde el principio, asi el contenido no salta hacia abajo
///   cuando el anuncio termina de cargar.
/// - Si no llega a cargar, se colapsa a cero en vez de dejar un hueco gris.
/// - Va rotulado y con separacion propia. Ademas de ser lo que pide AdMob, es lo
///   que evita el toque por accidente, que es lo que mas enoja y lo que hace que
///   te bajen la cuenta por clics invalidos.
class BannerAnuncio extends StatefulWidget {
  const BannerAnuncio({super.key});

  @override
  State<BannerAnuncio> createState() => _BannerAnuncioState();
}

class _BannerAnuncioState extends State<BannerAnuncio> {
  /// Cuantas veces se reintenta antes de rendirse.
  ///
  /// Un "sin relleno" es de lo mas comun y casi siempre pasajero. Sin reintento,
  /// el primer fallo dejaba el hueco vacio para toda la sesion: era el motivo de
  /// que el banner del inicio no apareciera nunca mientras que el de resultados
  /// si, porque ese se recrea solo al cambiar de dia y con eso reintentaba.
  static const _maxIntentos = 3;

  /// Alto que se ocupa mientras todavia no se sabe la medida real.
  ///
  /// El banner adaptativo de AdMob queda entre 50 y 62dp en telefonos, asi que
  /// reservar 60 deja el reajuste posterior en pocos pixeles. Sin esto el bloque
  /// arranca en cero y empuja todo hacia abajo cuando llega la medida, que se
  /// nota sobre todo cuando el anuncio va primero en la pantalla.
  static const _altoDeReserva = 60.0;

  BannerAd? _anuncio;
  AnchoredAdaptiveBannerAdSize? _medida;
  double? _ancho;
  int _intentos = 0;
  bool _pidiendo = false;
  bool _agotado = false;
  Timer? _reintento;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TickerMode viene en false para las pestanas que el IndexedStack tiene
    // ocultas, asi que sirve de senal de visibilidad. Sin esto las cuatro piden
    // su banner en el mismo instante contra el mismo bloque -- que es lo que
    // AdMob no llena -- y ademas se gastarian impresiones en anuncios que nadie
    // llego a ver, lo que baja la unica metrica que importa.
    if (TickerMode.valuesOf(context).enabled) _pedirCuandoSePueda();
  }

  @override
  void dispose() {
    _reintento?.cancel();
    _anuncio?.dispose();
    super.dispose();
  }

  void _pedirCuandoSePueda() {
    if (_ancho == null) return; // todavia no hubo layout
    unawaited(_pedir());
  }

  Future<void> _pedir() async {
    if (_pidiendo || _agotado || _anuncio != null) return;
    if (!mounted || !TickerMode.valuesOf(context).enabled) return;

    final ancho = _ancho;
    if (ancho == null) return;

    final anuncios = PublicidadDeLaApp.de(context);
    if (anuncios == null || !anuncios.disponibles) {
      setState(() => _agotado = true);
      return;
    }

    _pidiendo = true;

    final medida =
        _medida ?? await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
          ancho.truncate(),
        );
    if (!mounted) return;
    if (medida == null) {
      setState(() => _agotado = true);
      return;
    }
    if (_medida == null) setState(() => _medida = medida);

    final banner = BannerAd(
      adUnitId: IdsAnuncios.banner,
      size: medida,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (cargado) {
          _pidiendo = false;
          if (!mounted) {
            cargado.dispose();
            return;
          }
          setState(() => _anuncio = cargado as BannerAd);
        },
        onAdFailedToLoad: (fallido, error) {
          _pidiendo = false;
          fallido.dispose();
          debugPrint('No cargo el banner (intento $_intentos): $error');
          if (mounted) _programarReintento();
        },
      ),
    );
    await banner.load();
  }

  void _programarReintento() {
    _intentos++;
    if (_intentos >= _maxIntentos) {
      setState(() => _agotado = true);
      return;
    }
    // Espera creciente: si el problema es que hay varios pedidos encimados,
    // separarlos en el tiempo suele alcanzar.
    _reintento?.cancel();
    _reintento = Timer(
      Duration(seconds: 4 * _intentos),
      () => unawaited(_pedir()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_agotado) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, restricciones) {
        // El ancho recien se conoce en layout, asi que el primer pedido sale de
        // aca. Los siguientes los dispara didChangeDependencies al hacerse
        // visible la pestana.
        if (_ancho != restricciones.maxWidth) {
          _ancho = restricciones.maxWidth;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _pedirCuandoSePueda(),
          );
        }

        final medida = _medida;
        final anuncio = _anuncio;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PUBLICIDAD',
                style: AppText.labelCaps.copyWith(
                  color: AppColors.outline,
                  fontSize: 10,
                  letterSpacing: 0.08 * 10,
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              // El alto se ocupa desde el primer frame, aunque todavia no se
              // sepa la medida ni haya anuncio, para que lo que sigue no se
              // corra hacia abajo cuando aparezca.
              SizedBox(
                width: medida?.width.toDouble() ?? double.infinity,
                height: medida?.height.toDouble() ?? _altoDeReserva,
                child: anuncio == null
                    ? const ColoredBox(color: AppColors.surfaceContainerLow)
                    : AdWidget(ad: anuncio),
              ),
            ],
          ),
        );
      },
    );
  }
}

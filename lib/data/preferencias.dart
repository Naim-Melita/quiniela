import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/sorteo.dart';

/// Que loterias sigue el usuario y en que orden.
///
/// Es un [ChangeNotifier] para que el inicio se actualice apenas se cambia la
/// seleccion, sin tener que volver a entrar a la pantalla.
class PreferenciasLoterias extends ChangeNotifier {
  PreferenciasLoterias({this.nombreArchivo = 'preferencias.json'});

  final String nombreArchivo;

  List<Loteria> _favoritas = List.of(Loteria.predeterminadas);
  File? _archivo;
  bool _cargado = false;

  /// Loterias que sigue, en el orden elegido. Nunca vacia: sin favoritas el
  /// inicio no tendria nada que mostrar, asi que se cae a las predeterminadas.
  List<Loteria> get favoritas => List.unmodifiable(_favoritas);

  bool esFavorita(Loteria loteria) => _favoritas.contains(loteria);

  Future<void> cargar() async {
    if (_cargado) return;
    _cargado = true;

    try {
      final archivo = await _obtenerArchivo();
      if (!await archivo.exists()) return;

      final crudo = jsonDecode(await archivo.readAsString());
      if (crudo is! Map) return;

      final nombres = (crudo['favoritas'] as List?)?.cast<String>() ?? const [];
      final leidas = [
        for (final nombre in nombres) ?Loteria.porNombreInterno(nombre),
      ];
      if (leidas.isNotEmpty) {
        _favoritas = leidas;
        notifyListeners();
      }
    } catch (e) {
      // Preferencias ilegibles no son motivo para no arrancar: se usan las
      // predeterminadas y se sobrescriben en el proximo guardado.
      debugPrint('No se pudieron leer las preferencias: $e');
    }
  }

  Future<void> guardar(List<Loteria> favoritas) async {
    _favoritas = favoritas.isEmpty
        ? List.of(Loteria.predeterminadas)
        : List.of(favoritas);
    notifyListeners();

    try {
      final archivo = await _obtenerArchivo();
      await archivo.writeAsString(
        jsonEncode({'favoritas': [for (final l in _favoritas) l.name]}),
        flush: true,
      );
    } catch (e) {
      debugPrint('No se pudieron guardar las preferencias: $e');
    }
  }

  Future<File> _obtenerArchivo() async {
    final existente = _archivo;
    if (existente != null) return existente;
    final dir = await getApplicationSupportDirectory();
    return _archivo = File('${dir.path}/$nombreArchivo');
  }
}

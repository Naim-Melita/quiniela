import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/sorteo.dart';

/// Cache de resultados ya publicados.
///
/// Un sorteo publicado no cambia nunca, asi que se guarda sin vencimiento. Esto
/// no es una optimizacion opcional: la pantalla de estadisticas necesita cientos
/// de sorteos, y sin cache habria que volver a pedirlos por red en cada arranque.
///
/// El formato es un unico JSON `{clave: resultado}`. Con ~30 dias de dos
/// loterias son unos 300 registros; no justifica una base de datos.
class CacheResultados {
  CacheResultados({this.nombreArchivo = 'resultados_cache.json'});

  final String nombreArchivo;

  final Map<String, ResultadoSorteo> _memoria = {};
  File? _archivo;
  bool _cargado = false;

  /// Evita que dos guardados simultaneos se pisen el archivo.
  Future<void> _escrituraEnCurso = Future.value();
  bool _hayCambiosSinGuardar = false;

  Future<void> cargar() async {
    if (_cargado) return;
    _cargado = true;

    try {
      final archivo = await _obtenerArchivo();
      if (!await archivo.exists()) return;

      final crudo = jsonDecode(await archivo.readAsString());
      if (crudo is! Map) return;

      for (final entrada in crudo.entries) {
        final valor = entrada.value;
        if (valor is! Map) continue;
        final resultado = ResultadoSorteo.desdeJson(
          valor.cast<String, Object?>(),
        );
        if (resultado != null) _memoria[entrada.key as String] = resultado;
      }
    } catch (e) {
      // Un cache ilegible no es motivo para que no arranque la app: se ignora
      // y se vuelve a construir contra la red.
      debugPrint('No se pudo leer el cache de resultados: $e');
    }
  }

  ResultadoSorteo? obtener(String clave) => _memoria[clave];

  bool contiene(String clave) => _memoria.containsKey(clave);

  void guardar(ResultadoSorteo resultado) {
    _memoria[resultado.clave] = resultado;
    _hayCambiosSinGuardar = true;
  }

  /// Baja a disco lo acumulado. Se llama despues de un lote de fetches, no en
  /// cada resultado, para no escribir el archivo entero 300 veces seguidas.
  Future<void> persistir() async {
    if (!_hayCambiosSinGuardar) return;
    _hayCambiosSinGuardar = false;

    _escrituraEnCurso = _escrituraEnCurso.then((_) async {
      try {
        final archivo = await _obtenerArchivo();
        final json = {
          for (final e in _memoria.entries) e.key: e.value.aJson(),
        };
        await archivo.writeAsString(jsonEncode(json), flush: true);
      } catch (e) {
        debugPrint('No se pudo escribir el cache de resultados: $e');
      }
    });
    await _escrituraEnCurso;
  }

  Future<void> limpiar() async {
    _memoria.clear();
    _hayCambiosSinGuardar = false;
    try {
      final archivo = await _obtenerArchivo();
      if (await archivo.exists()) await archivo.delete();
    } catch (e) {
      debugPrint('No se pudo borrar el cache de resultados: $e');
    }
  }

  Future<File> _obtenerArchivo() async {
    final existente = _archivo;
    if (existente != null) return existente;
    final dir = await getApplicationSupportDirectory();
    return _archivo = File('${dir.path}/$nombreArchivo');
  }
}

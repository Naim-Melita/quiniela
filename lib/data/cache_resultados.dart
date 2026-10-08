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
/// Tambien se recuerda lo que **no existe**: un domingo, o una loteria que ese
/// turno no jugo. Sin eso cada carga vuelve a preguntar por decenas de sorteos
/// que ya se sabe que no estan, y esas respuestas negativas nunca se dejan de
/// pedir. Solo entran claves de fechas pasadas, que son inmutables; lo de hoy
/// todavia se puede publicar mas tarde. Quien decide eso es el repositorio, que
/// es el que sabe la fecha: aca solo se guarda lo que se le pide.
///
/// El formato es un unico JSON con los resultados y las claves sin datos. Con
/// ~30 dias de dos loterias son unos 300 registros; no justifica una base de
/// datos.
class CacheResultados {
  CacheResultados({this.nombreArchivo = 'resultados_cache.json'});

  final String nombreArchivo;

  final Map<String, ResultadoSorteo> _memoria = {};
  final Set<String> _sinDatos = {};
  File? _archivo;

  /// La carga en curso, o la ya terminada.
  ///
  /// Se memoiza el Future y no un bool: las cuatro pantallas del shell arrancan
  /// en el mismo frame y piden el cache a la vez. Con un flag, la primera lo
  /// marca como cargado y se queda esperando el disco, y las demas siguen de
  /// largo con la memoria todavia vacia y piden por red todo lo que ya estaba
  /// guardado.
  Future<void>? _carga;

  /// Evita que dos guardados simultaneos se pisen el archivo.
  Future<void> _escrituraEnCurso = Future.value();
  bool _hayCambiosSinGuardar = false;

  /// Idempotente y seguro de llamar en paralelo.
  Future<void> cargar() => _carga ??= _cargarDeDisco();

  ResultadoSorteo? obtener(String clave) => _memoria[clave];

  /// Si ya se comprobo que ese sorteo no existe en la fuente.
  bool sabeQueNoHay(String clave) => _sinDatos.contains(clave);

  void guardar(String clave, ResultadoSorteo resultado) {
    _memoria[clave] = resultado;
    _sinDatos.remove(clave);
    _hayCambiosSinGuardar = true;
  }

  /// Anota que en [clave] no hay sorteo. Solo para fechas pasadas.
  void marcarSinDatos(String clave) {
    if (_memoria.containsKey(clave)) return;
    if (!_sinDatos.add(clave)) return;
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
          'version': _version,
          'resultados': {
            for (final e in _memoria.entries) e.key: e.value.aJson(),
          },
          'sinDatos': _sinDatos.toList(),
        };
        await archivo.writeAsString(jsonEncode(json), flush: true);
      } catch (e) {
        // Que falle el disco no puede dejar el cache marcado como guardado: si
        // no, ningun persistir() posterior vuelve a intentarlo y se pierde todo
        // lo que se baje en lo que queda de sesion.
        _hayCambiosSinGuardar = true;
        debugPrint('No se pudo escribir el cache de resultados: $e');
      }
    });
    await _escrituraEnCurso;
  }

  /// Version del formato en disco. La 1 era `{clave: resultado}` pelado.
  static const _version = 3;

  Future<void> _cargarDeDisco() async {
    try {
      final archivo = await _obtenerArchivo();
      if (!await archivo.exists()) return;

      final crudo = jsonDecode(await archivo.readAsString());
      if (crudo is! Map) return;

      // Un archivo de la version 1 es el mapa de resultados directamente; se
      // aprovecha igual en vez de tirarlo y volver a bajar todo por red.
      final guardados = crudo['resultados'];
      final resultados = guardados is Map ? guardados : crudo;
      for (final entrada in resultados.entries) {
        final clave = entrada.key;
        final valor = entrada.value;
        if (clave is! String || valor is! Map) continue;
        final resultado = ResultadoSorteo.desdeJson(
          valor.cast<String, Object?>(),
        );
        if (resultado != null) _memoria[clave] = resultado;
      }

      final sinDatos = crudo['sinDatos'];
      // La fuente anterior devolvia 404 para rutas retiradas: sus negativos
      // no prueban ausencia de sorteos en la fuente actual.
      if (crudo['version'] == _version && sinDatos is List) {
        _sinDatos.addAll(sinDatos.whereType<String>());
      }
    } catch (e) {
      // Un cache ilegible no es motivo para que no arranque la app: se ignora
      // y se vuelve a construir contra la red.
      debugPrint('No se pudo leer el cache de resultados: $e');
    }
  }

  Future<File> _obtenerArchivo() async {
    final existente = _archivo;
    if (existente != null) return existente;
    final dir = await getApplicationSupportDirectory();
    return _archivo = File('${dir.path}/$nombreArchivo');
  }
}

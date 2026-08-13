// Proxy CORS de DESARROLLO. No forma parte de la app.
//
// El sitio de Loteria de la Ciudad no manda cabeceras CORS, asi que la build web
// no puede pedirle nada desde el navegador. En Android el problema no existe.
// Este proxy solo sirve para poder mirar la app real (con datos reales) en el
// navegador, sin emulador.
//
//     dart tool/proxy_cors.dart
//
// Despues, la app en web apunta sola a http://localhost:8090 (ver main.dart).
import 'dart:io';

const _destino = 'quiniela.loteriadelaciudad.gob.ar';
const _puerto = 8090;

Future<void> main() async {
  final servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, _puerto);
  final cliente = HttpClient();
  stdout.writeln('Proxy CORS escuchando en http://localhost:$_puerto');
  stdout.writeln('  -> https://$_destino');

  await for (final pedido in servidor) {
    try {
      await _atender(pedido, cliente);
    } catch (e) {
      stderr.writeln('error atendiendo ${pedido.uri}: $e');
      try {
        pedido.response.statusCode = HttpStatus.badGateway;
        await pedido.response.close();
      } catch (_) {
        // La respuesta ya se cerro; no hay nada que hacer.
      }
    }
  }
}

Future<void> _atender(HttpRequest pedido, HttpClient cliente) async {
  final respuesta = pedido.response;
  respuesta.headers.set('Access-Control-Allow-Origin', '*');
  respuesta.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  respuesta.headers.set('Access-Control-Allow-Headers', '*');

  if (pedido.method == 'OPTIONS') {
    respuesta.statusCode = HttpStatus.ok;
    await respuesta.close();
    return;
  }

  final destino = Uri.https(_destino, pedido.uri.path, pedido.uri.queryParameters);
  final cuerpo = await _leerCuerpo(pedido);

  final saliente = await cliente.openUrl(pedido.method, destino);
  final contentType = pedido.headers.contentType;
  if (contentType != null) saliente.headers.contentType = contentType;
  if (cuerpo.isNotEmpty) saliente.add(cuerpo);

  final entrante = await saliente.close();
  stdout.writeln('${pedido.method} ${pedido.uri.path} -> ${entrante.statusCode}');

  respuesta.statusCode = entrante.statusCode;
  final tipo = entrante.headers.contentType;
  if (tipo != null) respuesta.headers.contentType = tipo;

  await for (final trozo in entrante) {
    respuesta.add(trozo);
  }
  await respuesta.close();
}

Future<List<int>> _leerCuerpo(HttpRequest pedido) async {
  final bytes = <int>[];
  await for (final trozo in pedido) {
    bytes.addAll(trozo);
  }
  return bytes;
}

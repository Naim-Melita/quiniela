import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quiniela/main.dart';

void main() {
  test('muestra Flutter antes de esperar la inicializacion de publicidad', () {
    final publicidadPendiente = Completer<void>();
    var aplicacionMostrada = false;

    mostrarAplicacionAntesDeIniciarPublicidad(
      mostrarAplicacion: () => aplicacionMostrada = true,
      iniciarPublicidad: () => publicidadPendiente.future,
    );

    expect(aplicacionMostrada, isTrue);
    expect(publicidadPendiente.isCompleted, isFalse);
  });
}

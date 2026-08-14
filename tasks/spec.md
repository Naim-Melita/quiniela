# Spec: Reloj inyectable en `ResultadosScreen`

## Objetivo

`ResultadosScreen` calcula "ahora" llamando directo a la función global `ahoraEnArgentina()` en
vez de recibirla inyectada, a diferencia de `LoteriaCiudadRepository` y `MockQuinielaRepository`,
que sí aceptan un `DateTime Function()? reloj` en su constructor. Efecto práctico: el estado
inicial de la pantalla (`_fecha`, y por lo tanto `_esHoy`, los límites de `_mover` y de
`_elegirFecha`) no se puede fijar desde un test — queda atado al reloj real del dispositivo que
corre el test.

Objetivo de este cambio: alinear `ResultadosScreen` con el patrón ya establecido en el repo,
haciéndola determinista y testeable, y agregar un test de widget que efectivamente lo pruebe (si
el reloj queda inyectable pero nada lo verifica, el gap solo se movió, no se cerró).

Usuario: nadie externo lo nota — es un cambio interno de testabilidad, sin cambio de
comportamiento visible en producción (el default sigue siendo `ahoraEnArgentina`).

## Alcance

**Adentro:**
- `lib/screens/resultados_screen.dart`: agregar el parámetro `reloj`, reemplazar las 4 llamadas
  directas a `ahoraEnArgentina()` (línea 33, `_esHoy`, `_mover`, `_elegirFecha`).
- Un test de widget nuevo (o agregado a uno existente) que monte `ResultadosScreen` sola (no via
  `HomeShell`) con un reloj fijo y compruebe que la fecha inicial y el comportamiento de "hoy"
  reflejan ese reloj, no el reloj real.

**Afuera:** `HomeShell`, `main.dart`, `GeneradorScreen` (también usa `ahoraEnArgentina()` directo,
pero no fue elegido para este fix).

## Comandos

```
Test (archivo puntual): flutter test test/resultados_screen_test.dart
Test (suite completa):  flutter test
Analyze:                flutter analyze
```
(Requiere las env vars de `JAVA_HOME`/`ANDROID_HOME`/`PATH` de CLAUDE.md exportadas antes.)

## Estructura tocada

```
lib/screens/resultados_screen.dart   → agrega parámetro reloj, reemplaza 4 usos
test/resultados_screen_test.dart     → nuevo: widget test dedicado
```

## Estilo de código (patrón a replicar, de `quiniela_repository.dart`)

```dart
class ResultadosScreen extends StatefulWidget {
  const ResultadosScreen({
    super.key,
    required this.repositorio,
    required this.preferencias,
    DateTime Function()? reloj,
  }) : reloj = reloj ?? ahoraEnArgentina;

  final QuinielaRepository repositorio;
  final PreferenciasLoterias preferencias;
  final DateTime Function() reloj;
  ...
}
```
Dentro del State, todo `ahoraEnArgentina()` pasa a ser `widget.reloj()`.

## Estrategia de testing

- Nivel: widget test (`flutter_test`), no unitario — el comportamiento a probar es de estado del
  `StatefulWidget`, no de una función pura.
- Ubicación: `test/resultados_screen_test.dart`, siguiendo la convención de nombre de
  `test/widget_test.dart` y `test/quiniela_repository_test.dart`.
- Caso mínimo: montar `ResultadosScreen` con `MockQuinielaRepository(reloj: fijo)` y
  `reloj: fijo` (mismo valor), y verificar que el encabezado muestra "Hoy" para esa fecha fija —
  hoy eso es no determinista porque el widget usa su propio reloj real en vez de uno inyectado.
- No se toca `test/widget_test.dart` (sigue montando por `HomeShell`, fuera de alcance).

## Boundaries

- **Siempre:** correr `flutter test test/resultados_screen_test.dart` y `flutter analyze` antes de
  dar el cambio por terminado.
- **Preguntar antes:** si aparece la tentación de también inyectar el reloj en `HomeShell`/
  `main.dart` para uso real (no solo tests) — eso ampliaría el alcance más allá de lo pedido.
- **Nunca:** cambiar el comportamiento por defecto en producción (el default debe seguir siendo
  `ahoraEnArgentina`, sin excepciones).

## Criterios de éxito

- [ ] `ResultadosScreen` ya no llama a `ahoraEnArgentina()` directo en ningún punto de su código.
- [ ] Con un reloj inyectado fijo, el estado inicial (`_fecha`, `_esHoy`) es determinista y
      verificable por test, sin depender del reloj real de la máquina que corre el test.
- [ ] El comportamiento en producción no cambia (mismo default).
- [ ] `flutter test` y `flutter analyze` pasan limpios.

## Preguntas abiertas

Ninguna — alcance acotado y sin ambigüedad de requerimiento.

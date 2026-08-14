# Plan: Reloj inyectable en `ResultadosScreen`

Ver `tasks/spec.md` para objetivo, alcance y criterios de éxito completos.

## Componentes

1. **`ResultadosScreen` (widget)** — agregar el parámetro `reloj` y reemplazar los 4 usos internos
   de `ahoraEnArgentina()`. Sin dependencias externas: es un cambio autocontenido en un solo
   archivo, mismo patrón ya usado en `quiniela_repository.dart` y `loteria_ciudad_repository.dart`.
2. **`test/resultados_screen_test.dart` (test nuevo)** — depende de (1) estar hecho, porque hasta
   que el reloj no sea inyectable no hay nada determinista que verificar.

No hay trabajo paralelizable real (son 2 pasos secuenciales de un cambio chico), así que no
aplica dividir en agentes/ramas paralelas.

## Orden de implementación

1. Modificar `ResultadosScreen` (constructor + 4 call-sites).
2. Escribir el widget test que prueba el reloj inyectado.
3. Verificar: `flutter analyze` + `flutter test test/resultados_screen_test.dart` + `flutter test`
   completo (para confirmar que no se rompió nada en `widget_test.dart`, que sigue montando
   `ResultadosScreen` indirectamente via `HomeShell` con su reloj real).

## Riesgos y mitigación

- **Riesgo:** `HomeShell` no pasa `reloj` a `ResultadosScreen`, así que en el árbol real la pantalla
  sigue usando el default `ahoraEnArgentina` — correcto y esperado (está fuera de alcance por
  decisión explícita), pero hay que confirmar que `test/widget_test.dart` (que monta todo el shell
  con un reloj fijo en el repositorio, no en la pantalla) sigue pasando sin tocarlo, ya que
  `ResultadosScreen` ahí seguirá con su reloj real por default. Mitigación: revisar si algún test
  existente en `widget_test.dart` depende de la fecha mostrada en la pestaña de Resultados — por
  lectura previa, ninguno lo hace (solo prueba Dashboard/Generador/navegación), así que no hay
  regresión esperada.
- **Riesgo:** el widget test nuevo podría necesitar `tester.view.physicalSize` grande, como ya
  documenta `test/widget_test.dart` (viewport default 800x600 corta contenido). Mitigación: copiar
  ese mismo setup.

## Checkpoint de verificación

Después del paso 3, si `flutter analyze` y ambas corridas de `flutter test` pasan limpias, el
cambio está terminado — no hay una fase adicional de integración manual necesaria (no toca red ni
UI visual nueva).

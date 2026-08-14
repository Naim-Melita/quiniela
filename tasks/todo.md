# Tasks: Reloj inyectable en `ResultadosScreen`

- [x] Task: Agregar parámetro `reloj` a `ResultadosScreen` y reemplazar los 4 usos de `ahoraEnArgentina()`
  - Acceptance: el constructor acepta `DateTime Function()? reloj` con default `ahoraEnArgentina`
    (mismo patrón que `MockQuinielaRepository`/`LoteriaCiudadRepository`); ningún método de
    `_ResultadosScreenState` llama a `ahoraEnArgentina()` directo — todos usan `widget.reloj()`.
  - Verify: `flutter analyze` sin warnings nuevos en el archivo.
  - Files: `lib/screens/resultados_screen.dart`

- [x] Task: Escribir `test/resultados_screen_test.dart`
  - Acceptance: monta `ResultadosScreen` sola (con `MaterialApp` + localizations, como en
    `test/widget_test.dart`) usando `MockQuinielaRepository(reloj: fijo)` y `reloj: fijo` (mismo
    valor) pasado al widget; verifica que la fecha mostrada corresponde al reloj fijo (ej. label
    "Hoy" quand el fijo es la fecha "actual" simulada, o la fecha formateada correcta si no).
  - Verify: `flutter test test/resultados_screen_test.dart` pasa.
  - Files: `test/resultados_screen_test.dart` (nuevo)

- [x] Task: Verificación final de la suite completa
  - Acceptance: no hay regresiones en el resto de los tests existentes.
  - Verify: `flutter test` (suite completa) y `flutter analyze` sobre todo el repo, ambos limpios.
  - Files: ninguno (solo verificación)

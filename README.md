> Actualizacion 08/10/2026: la fuente oficial cambio. La app lee ahora el
> selector `custom-option` de la home y consulta
> `includes/resultados-data.php?sorteo=NUMERO`, que publica los resultados de
> todas las jurisdicciones. Las rutas XML y POST descritas mas abajo son
> historicas y ya no se usan. La ventana disponible depende del indice actual
> (tambien para Ciudad). El cache v3 conserva resultados positivos y descarta
> negativos antiguos causados por las rutas retiradas. El proxy nginx necesita
> la ruta nueva de `deploy/nginx/fuente-loteria.conf`; mientras tanto Android
> reintenta contra el sitio oficial.

# Quiniela

App Android de quiniela: resultados, generador de jugadas con diccionario de
suenos, y estadisticas de frecuencia.

El diseno sale del proyecto **"Diseno de App Quiniela"** de Google Stitch. Los
HTML originales quedaron versionados en `design/stitch/` como referencia: cuando
haya que ajustar algo visual, ese es el contrato contra el que comparar.

## Estado

Las 4 pantallas andan contra la **fuente oficial**: el sitio de Loteria de la
Ciudad. No hay backend propio.

| Pantalla | Que hace |
|---|---|
| Inicio | Aviso de ultimo minuto, acceso al generador, ultimo resultado de cada loteria que sigue el usuario, agenda de los 5 turnos con estado en vivo |
| Detalle | Al tocar un resultado: las 20 posiciones, las letras del extracto, el numero de sorteo y copiar la pizarra |
| Buscar | "Fijate si salio el 47": en que loterias, turnos y posiciones acerto una jugada en los ultimos 1 / 3 / 7 dias |
| Resultados | Pizarra completa por fecha, turno y loteria, con flechas y deslizamiento para cambiar de dia |
| Mis loterias | Elegir cuales seguir y arrastrarlas para ordenar el inicio. Se guarda en el telefono |
| Generador | Jugadas de 1 a 4 cifras con animacion de ruleta, y diccionario de suenos buscable |
| Stats | Numeros calientes y frios sobre 7 / 14 / 30 dias, de las loterias que seguis |

## Loterias

Todas salen de la misma fuente. Que codigo tiene cada una y que turnos juega se
averiguo probando el endpoint una por una, no hay documentacion:

| Loteria | Jurisdiccion | Turnos |
|---|---|---|
| Nacional (Ciudad) | 51 | los 5 - **unica con extracto XML** |
| Provincia (Buenos Aires) | 53 | los 5 |
| Santa Fe | 72 | los 5 |
| Cordoba | 55 | los 5 |
| Entre Rios | 59 | los 5 |
| Montevideo | 00 | **solo Matutina y Nocturna** |

Dos trampas que cuestan tiempo si se toma el sitio al pie de la letra:

- El JS del sitio llama `resultadosRios` a la jurisdiccion **64** y
  `resultadosMend` a la **59**, pero el servidor responde al reves: la 59
  devuelve `ENRTRE RIOS` y la 64 dice "No hay Sorteo de MENDOZA". Vale el label
  del servidor.
- **Mendoza no esta**: 0 sorteos en 15 muestreados. Esta fuente no la publica.
  Incluirla seria mostrar una loteria siempre vacia.

## Hora

Los sorteos son a hora argentina, asi que la app **no usa el reloj del
telefono**: `lib/data/reloj_argentina.dart` ancla todo a UTC-3 (Argentina no
aplica horario de verano). No es cosmetico — con esa hora se decide que turnos
ya se publicaron, o sea que sorteos se piden. Probado en el emulador, que corre
en GMT: sin el ancla, con las 18:05 de Argentina la app daba la Vespertina por
finalizada y la Nocturna en vivo.

## Como correrlo

Esta maquina no tiene Android Studio; el toolchain son las command-line tools.
Hay que exportar las variables a mano antes de cualquier comando:

```bash
export JAVA_HOME="C:\Program Files\Eclipse Adoptium\jdk-17.0.20.8-hotspot"
export ANDROID_HOME="D:\Android\sdk"
export PATH="C:\Users\naimm\Documentos\flutter\bin:$PATH"
```

Despues:

```bash
flutter test
```

```bash
flutter build apk --debug
```

Verificacion contra el sitio oficial en vivo (no la levanta `flutter test`
porque depende de la red):

```bash
flutter test test/manual/verificar_fuente_real.dart
```

### Verla en el navegador (sin emulador)

Tiene soporte web solo para eso. El navegador bloquea por CORS las peticiones al
sitio oficial, que no manda esas cabeceras (en Android no pasa: no hay CORS).
Para saltearlo en desarrollo hay un proxy local. En una terminal:

```bash
dart tool/proxy_cors.dart
```

Y en otra:

```bash
flutter run -d web-server --web-port 8080
```

La app detecta sola que corre en web+debug y le pega al proxy en vez de al sitio
(ver `_baseApi` en `lib/main.dart`). En Android, release o los tests, siempre va
directo al sitio oficial.

## Arquitectura

```
lib/
  theme/       tokens del design system (colores, spacing, radios, tipografia)
  models/      dominio: Loteria, TurnoSorteo, ResultadoSorteo, Sueno...
  data/        QuinielaRepository (interfaz) + MockQuinielaRepository
  widgets/     piezas compartidas: GlassPanel, BolillaNumero, tarjetas
  screens/     las 4 pantallas + el shell con la barra inferior
```

**El punto importante:** todas las pantallas hablan contra la interfaz
`QuinielaRepository`, nunca contra una implementacion. Hay dos:

- `LoteriaCiudadRepository` — la fuente oficial. Es la que usa la app.
- `MockQuinielaRepository` — datos simulados deterministas (la semilla sale de
  fecha + loteria + turno). La usan todos los tests: corren sin red y siempre
  dan lo mismo.

Se cambia una sola linea en `lib/main.dart` para pasar de una a otra.

## De donde salen los resultados

Fuente: **Loteria de la Ciudad** (`quiniela.loteriadelaciudad.gob.ar`), que es
el organismo que hoy opera los sorteos de la ex Loteria Nacional. Ojo con la
nomenclatura: lo que la calle llama *"Quiniela Nacional"* es oficialmente la
*Quiniela de la Ciudad* — mismo sorteo, dos nombres. *"Provincia"* si es un
sorteo distinto, el de Buenos Aires.

El sitio no tiene API documentada. Se usan tres cosas publicas:

| Que | Como | Para que |
|---|---|---|
| Extracto oficial XML | `GET descarga.php?sorteo=YYYY/MM/QNL51{T}{YYYYMMDD}.xml` | Nacional/Ciudad. La via robusta: se direcciona por fecha y turno, sin depender del HTML |
| Fragmento HTML | `POST consultaResultados.php` con `codigo`, `juridiccion`, `sorteo` | Provincia y las demas jurisdicciones. Es la unica via: solo la Ciudad publica XML |
| Indice de la home | `GET /` | Mapa sorteo -> fecha de los ultimos ~26 dias, de donde sale el `sorteo` del POST |

Letras de turno en el nombre del XML: `R` Previa, `P` Primera, `M` Matutina,
`V` Vespertina, `N` Nocturna. Jurisdicciones: 51 Ciudad, 53 Buenos Aires,
72 Santa Fe, 55 Cordoba, 64 Entre Rios, 59 Mendoza.

**Por que el indice y no aritmetica:** los numeros de sorteo son correlativos y
van 5 por dia, pero los domingos no hay sorteo y la numeracion salta. Calcular
el numero a partir de la fecha da mal en cuanto cruzas un domingo o un feriado.

**Cache.** Un sorteo publicado no cambia nunca, asi que se guarda en disco sin
vencimiento (`lib/data/cache_resultados.dart`). No es opcional: la pantalla de
estadisticas necesita cientos de sorteos y sin cache habria que bajarlos de
nuevo en cada arranque.

### Riesgos de esta fuente

- **El HTML no es un contrato.** Provincia y las demas jurisdicciones salen de
  parsear marcado. Si el sitio lo cambia, esa parte deja de andar. El parser
  valida que vengan las 20 posiciones y falla explicito en vez de devolver datos
  a medias, pero es el punto fragil. El XML de la Ciudad es mucho mas estable.
- **Es un sitio publico que no nos autorizo a consumirlo.** Las peticiones van
  de a 6 en paralelo como maximo, y todo lo descargado se cachea. Para
  produccion de verdad, lo correcto es un backend propio que baje cada turno una
  vez y le sirva a todas las apps, en vez de que cada telefono golpee el sitio.
- **Los fixtures envejecen.** `test/fixtures/` tiene respuestas reales del
  13/08/2026. Los tests de parseo corren contra eso, asi que **siguen pasando
  aunque el sitio cambie**. Para detectarlo hay que correr la verificacion en
  vivo (abajo).

## Pendientes conocidos

- **Diccionario de suenos incompleto.** `lib/data/diccionario_suenos.dart` tiene
  las entradas mas conocidas, pero la cabala va de 00 a 99 y cambia entre
  regiones. Falta completarla y validarla contra una fuente confiable antes de
  publicar. Los numeros que faltan no aparecen en la busqueda; no se inventan.
- **Sin backend propio.** Cada telefono le pega directo al sitio oficial. Ver
  "Riesgos de esta fuente".
- **Estadisticas pesadas la primera vez.** La ventana arranca en 7 dias porque
  30 con las 6 loterias son ~900 sorteos. Se probo con 30 y el spinner no
  terminaba; por eso 90 dias ya no es una opcion. Despues del primer fetch queda
  cacheado. Convendria precargar en segundo plano.
- **Sin datos en vivo.** Los resultados se piden al entrar o al deslizar para
  refrescar; no hay polling ni notificaciones. Ver la conversacion sobre polling
  adaptativo por ventana de sorteo.
- **Fuentes por red.** `google_fonts` descarga Inter y JetBrains Mono en el
  primer arranque. Si se quiere que funcione offline desde el minuto cero, hay
  que empaquetar los `.ttf` en `assets/fonts`.
- **Sin persistencia.** Las jugadas generadas no se guardan.
- `ResultadosScreen` usa `DateTime.now()` directo en vez del reloj del
  repositorio, asi que su estado inicial no es testeable de forma determinista.

## Notas de build en esta maquina

`android/` lleva dos ajustes que no son opcionales aca:

1. `org.gradle.jvmargs` bajado de 8G a 4G en `gradle.properties` — el template
   de Flutter pide mas memoria de la que tolera una maquina de 16 GB.
2. Un bloque `subprojects { plugins.withId(...) }` en `build.gradle.kts` que
   normaliza `compileSdk = 36` y JVM target 17 en los plugins nativos. Se usa
   `plugins.withId` en vez de `afterEvaluate` justamente para no depender del
   orden respecto del `evaluationDependsOn(":app")` del template.

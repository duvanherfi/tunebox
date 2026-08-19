# Estado del trabajo

Este archivo es la memoria entre hilos. Cada feature nueva se trabaja en un hilo
nuevo: se lee esto primero y se actualiza al terminar cada paso, no al final.

## Hecho

- **CI en cada push** (`.github/workflows/ci.yml`). Un job en `ubuntu-latest`:
  `flutter pub get`, `analyze` y `test`, unos tres minutos. Flutter va
  **pineado a 3.41.6**, no siguiendo `stable`: este toolchain es particular
  — `permission_handler` por debajo de 14, `compileSdk` 37 — y un SDK que se
  mueve solo se lee como bug nuestro. `concurrency` con `cancel-in-progress`
  para que un segundo push cancele al primero, y `timeout-minutes: 15` porque
  el defecto son seis horas y un job colgado se come el mes. Sin `pull_request`:
  las ramas son todas nuestras y correría el mismo commit dos veces.
  **Los builds pesados se quedan fuera a propósito** — el repo es privado, así
  que los minutos salen de una cuota fija y los runners de macOS facturan 10×:
  macOS en cada push agota el mes en unos veinte. El de Android sería asequible
  pero no dice nada: el APK que se publica va firmado con la llave de release,
  que CI no tiene, así que un artefacto con firma debug solo probaría que
  compila. Si algún día se quiere que CI publique, la puerta es meter el
  keystore y las contraseñas como secrets y construir sobre el tag.

- **Iconos en todas las plataformas** (punto 1). La marca — la caja blanca con
  la nota sobre el rosa `#C2185B` — solo existía en el adaptive icon de Android;
  el resto de plataformas seguía enseñando el logo de Flutter del `flutter
  create`. Ahora sale toda de `tool/icons/*.svg`, que son los mismos paths del
  `ic_launcher_foreground`, y `tool/icons/generate.sh` los rasteriza a los
  mipmap heredados de Android, al catálogo de macOS, a los quince de iOS, al
  `.ico` de Windows y a un PNG para Linux. Se corre a mano y los resultados se
  versionan: la ilustración cambia una vez al año y un build que reescribe
  binarios rastreados convierte cada diff en una pregunta. **No hay ningún
  `.icns`** — Flutter en macOS usa el catálogo `AppIcon.appiconset` y Xcode lo
  compila dentro de `Assets.car`. De paso, el test de `keep.xml` tenía un hueco:
  buscaba `'drawable/xxx'` y los iconos de los estantes del coche se pasan
  pelados a `_shelf(…)`, así que doce nombres viajaban sin vigilancia y sólo el
  comodín `ic_auto_*` los salvaba por casualidad.

- **Modo mesita de noche**. Pantalla propia sobre negro puro: reloj
  grande con la hora del sistema, fecha, carátula, título, progreso y
  controles, todo configurable pieza a pieza desde una sexta puerta en Ajustes.
  No es el AOD del sistema sino su contrario — el teléfono **despierto**, con el
  wakelock tomado; el de Samsung y los suyos solo existe con la pantalla
  apagada y ya muestra la sesión de medios que `audio_service` publica, sin
  código nuevo. Se entra a mano desde la hoja del reproductor, donde vive el
  temporizador, y sola por inactividad o al enchufar; **las dos automáticas
  nacen apagadas**, porque una app que se va sola a una pantalla negra la
  primera vez que la dejas quieta se lee como un fallo, no como un modo. Los
  tres efectos laterales — wakelock, barras inmersivas y brillo — los deshace un
  `finally` alrededor del push, no el `dispose` de la pantalla: así se limpian
  como sea que termine la ruta. Dependencias nuevas: `screen_brightness` (un
  velo negro baja el contraste, no la retroiluminación) y `battery_plus`.

- **Opciones de artista** (punto 1). La cabecera del artista por fin lleva la
  fila de iconos: suscribirse, radio y menú. Suscribirse es la misma marca local
  que guardar una lista — vale sin cuenta y sobrevive al túnel — pero se
  sincroniza por `subscription/subscribe`, que es el endpoint nuevo; un id `UC`
  se enruta ahí desde `setCollectionSaved`, así que el almacén no aprende la
  taxonomía de YouTube. La radio del artista es el `RDEM` que trae su cabecera
  (`parseArtistDetails`), no un `RDAMPL` sobre su id de canal, que no es una
  lista. El menú gana **Compartir** para lista, álbum y artista, y `collectionLink`
  aprende `/channel/`. En la biblioteca, un artista guardado ya no cae en
  Playlists: la pestaña Artistas muestra primero los seguidos desde aquí y
  después los de la cuenta.
- **Ajustes por dominio.** La hoja de cuenta lleva una sola entrada
  "Settings" a un índice con cinco puertas: Playback and sound, Storage,
  Backups, Appearance y System (esta última solo en Android, que es donde el
  widget existe). Apariencia sale de la hoja a pantalla propia. El temporizador
  se va de ajustes: ya vivía en la hoja del reproductor, que es donde está la
  música. De paso, `SheetBody` se ajusta a su contenido — el `Center` se comía
  toda la altura que le dieran y la hoja recortada salía medio vacía.
- **Acciones de colección** (v0.1.3, publicado). Cabecera compartida con ♡ · 📻 · ⋮
  en playlist, álbum y artista; guardar colecciones en local con sincronización a
  YouTube cuando hay sesión; radio de lista (`RDAMPL`); menú con reproducir,
  aleatorio, radio, siguiente, a la cola, añadir a playlist, descargar todo y
  copiar enlace; sección "Guardadas" en la biblioteca.
- **Foto de perfil al iniciar sesión**. La tarjeta de cuenta escuchaba solo a
  `session` y leía `accountStore` sin escucharlo.
- **macOS arranca**. Entitlements de red (cliente en ambos, servidor en release),
  `Podfile.lock` versionado.
- **Reproducción multiplataforma**. Efectos de Android solo en Android; caché al
  vuelo (`LockCachingAudioSource`) solo donde se midió que funciona; guarda de
  `permission_handler`; ecualizador y caché ocultos donde no hacen nada.
- **Formatos como candidatos**. `parseAudioStreams` devuelve lista ordenada
  (bitrate → códec), `resolveStreams` entrega todos los del cliente que contestó
  con un solo nonce, y el reproductor los recorre hasta que uno abre.
- **Mini reproductor siempre visible**. Las pestañas empujan en un Navigator
  anidado; las 13 hojas y diálogos pasan `useRootNavigator: true`.
- **Fondo de las barras configurable**: sólido, cristal esmerilado, translúcido,
  transparente. En Apariencia, dentro de Ajustes.
- **Contenido a sangre bajo las barras.** El armazón recortaba el viewport con un
  `Padding`, dejando una franja del color del Scaffold bajo cada lista. Ahora el
  alto de las barras viaja como `padding` del `MediaQuery` y cada scrollable lo
  suma a su relleno inferior: el contenido llega al borde y pasa por detrás.

> Todo este bloque está en `main` y subido a `origin` (19 de agosto de 2026).

## Pendiente

Nada abierto. Lo siguiente sale de "Suelto, sin diagnosticar" o de una idea
nueva.

## Sabido y descartado

- **media_kit / just_audio_media_kit para escritorio.** No trae ecualizador
  (lo dice su propia matriz de funciones) y además pierde skip silence y volume
  boost, que sí usamos. macOS ya lo soporta just_audio de forma nativa.
- **Windows y Linux.** `audio_service` y `just_audio` solo declaran android, ios,
  macos y web. `PlayerService` **es** un `BaseAudioHandler`, así que esas
  plataformas compilarían pero morirían en `AudioService.init`. No es una
  verificación, es un proyecto.
- **`deviceSupportsMimeType` de OpenTune.** Es `MediaCodecList` de Android; no
  hay equivalente en Dart. Lo suple el orden de candidatos.

## Suelto, sin diagnosticar

- **Los PNG heredados de Android no se han visto en un lanzador.** Sólo los lee
  API 25 y anterior; el emulador a mano es API 36 y sirve el adaptive icon en su
  lugar. Están comprobados como archivo, no como icono en una pantalla.
- **El icono de macOS está a medias en Tahoe.** macOS 26 mete un icono del
  estilo antiguo dentro de su propio squircle y lo pone sobre una placa, así que
  el cuadrado de 824 se hunde una segunda vez y la marca sale pequeña sobre
  fondo oscuro. Darle el arte a sangre lo arregla ahí y lo rompe en macOS 15 y
  anteriores, donde nadie lo recorta y cae en el Dock como un cuadrado duro. Con
  el destino en 10.15 se queda en la rejilla clásica. La salida buena es un
  `.icon` de Icon Composer, que Tahoe lee de forma nativa.
- **Suscribirse solo se probó sin sesión.** En el emulador la marca local, la
  radio del artista y compartir salieron bien, pero la escritura a la cuenta
  (`subscription/subscribe`) no se ha ejecutado nunca contra una real — el mismo
  hueco que ya tienen crear playlists y añadir canciones.
- **`player_queue_test.dart` falla de vez en cuando** al borrar su directorio
  temporal: `FileSystemException: Deletion failed … Directory not empty`. Salió
  una vez en una tanda y no volvió en siete pasadas seguidas, ni antes ni
  después de tocar nada. Es una carrera del `tearDown`, no del reproductor.
  Ahora que hay CI esto sale en rojo de tanto en tanto sin significar nada;
  el arreglo es el `tearDown`, no un reintento, que escondería los fallos
  de verdad.
- **El brillo por aplicación no se puede verificar en el emulador.** La llamada
  se hace y no falla, pero un `screencap` no captura la retroiluminación, así
  que el 20 % está probado como código y no como luz. Falta mirarlo en un
  teléfono.
- En el reproductor completo, con la cola terminada, la etiqueta izquierda marcó
  **1:48** y la derecha **0:00** con el cursor al principio. No se tocó esa
  pantalla; puede ser transitorio al expandir o un fallo previo de cómo se
  pintan posición y restante al acabar.

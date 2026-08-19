# Estado del trabajo

Este archivo es la memoria entre hilos. Cada feature nueva se trabaja en un hilo
nuevo: se lee esto primero y se actualiza al terminar cada paso, no al final.

## Hecho

- **Modo mesita de noche** (punto 1). Pantalla propia sobre negro puro: reloj
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

> Todo este bloque está en `main`. Hasta la mesita de noche, subido a `origin`
> (18 de agosto de 2026); la mesita está fusionada pero **sin empujar** (19 de
> agosto de 2026).

## Pendiente

1. **Iconos en todas las plataformas.** Recordar que el shrinker del release
   borra los `drawable/` que solo se nombran desde Dart — `res/raw/keep.xml` y
   `test/android_icon_resources_test.dart` los mantienen en pareja. Revisar
   además el icono de la app en macOS (`.icns`).
2. **Workflow de CI.** `flutter analyze`, `flutter test` y build de Android y
   macOS en cada push. Opcionalmente un job de Linux en `continue-on-error` para
   medir cuánto falta, sin bloquear.

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

- **Suscribirse solo se probó sin sesión.** En el emulador la marca local, la
  radio del artista y compartir salieron bien, pero la escritura a la cuenta
  (`subscription/subscribe`) no se ha ejecutado nunca contra una real — el mismo
  hueco que ya tienen crear playlists y añadir canciones.
- **`player_queue_test.dart` falla de vez en cuando** al borrar su directorio
  temporal: `FileSystemException: Deletion failed … Directory not empty`. Salió
  una vez en una tanda y no volvió en siete pasadas seguidas, ni antes ni
  después de tocar nada. Es una carrera del `tearDown`, no del reproductor.
- **El brillo por aplicación no se puede verificar en el emulador.** La llamada
  se hace y no falla, pero un `screencap` no captura la retroiluminación, así
  que el 20 % está probado como código y no como luz. Falta mirarlo en un
  teléfono.
- En el reproductor completo, con la cola terminada, la etiqueta izquierda marcó
  **1:48** y la derecha **0:00** con el cursor al principio. No se tocó esa
  pantalla; puede ser transitorio al expandir o un fallo previo de cómo se
  pintan posición y restante al acabar.

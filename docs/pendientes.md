# Estado del trabajo

Este archivo es la memoria entre hilos. Cada feature nueva se trabaja en un hilo
nuevo: se lee esto primero y se actualiza al terminar cada paso, no al final.

## Hecho

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
  transparente. En Apariencia, dentro de la hoja de cuenta.
- **Contenido a sangre bajo las barras.** El armazón recortaba el viewport con un
  `Padding`, dejando una franja del color del Scaffold bajo cada lista. Ahora el
  alto de las barras viaja como `padding` del `MediaQuery` y cada scrollable lo
  suma a su relleno inferior: el contenido llega al borde y pasa por detrás.

## Pendiente

1. **Separar los ajustes por dominio.** Hoy "Playback and sound" mezcla
   reproducción, ecualizador, almacenamiento, widget del sistema y copias de
   seguridad bajo un título que solo describe lo primero. Partir en entradas
   distintas de la hoja de cuenta. Sin lógica nueva.
2. **Opciones de artista.** Falta radio, compartir y **suscribirse**. Esta última
   no existe en el repo: hace falta endpoint nuevo, como pasó con guardar listas.
3. **AOD.** Copiar el modo mesita de noche de OpenTune
   (`AlwaysOnDisplayScreen.kt`): fondo oscuro, reloj, carátula, progreso,
   controles, activación automática. No es el AOD del sistema, es una pantalla
   propia, así que es portable: `wakelock_plus` (ya en pubspec) y `SystemChrome`.
   Necesita spec antes de empezar.
4. **Iconos en todas las plataformas.** Recordar que el shrinker del release
   borra los `drawable/` que solo se nombran desde Dart — `res/raw/keep.xml` y
   `test/android_icon_resources_test.dart` los mantienen en pareja. Revisar
   además el icono de la app en macOS (`.icns`).
5. **Workflow de CI.** `flutter analyze`, `flutter test` y build de Android y
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

- En el reproductor completo, con la cola terminada, la etiqueta izquierda marcó
  **1:48** y la derecha **0:00** con el cursor al principio. No se tocó esa
  pantalla; puede ser transitorio al expandir o un fallo previo de cómo se
  pintan posición y restante al acabar.

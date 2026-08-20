# Estado del trabajo

Este archivo es la memoria entre hilos. Cada feature nueva se trabaja en un hilo
nuevo: se lee esto primero y se actualiza al terminar cada paso, no al final.

## Pendiente

- **Quitar una canción de la biblioteca sin quitarle el like.** Pedido el 20 de
  agosto de 2026, para que funcione como YouTube Music. Ahora que las dos
  listas están separadas la acción tiene sentido, pero falta sondear con qué
  endpoint se hace: lo más probable es un `feedbackToken` que viene en el menú
  de la propia fila, no `edit_playlist`, que es lo que la app usa para añadir.

- **La cuenta dice 216 me gusta y `LM` contesta 183.** La página dos llega sin
  token, así que no es que el recorrido se corte: son 33 que la API no lista.
  Sin diagnosticar; la sospecha es que son pistas ya no disponibles o de otro
  tipo. Mientras tanto esos 33 salen con el corazón vacío.

- **La letra se queda pegada a la canción con la que se abrió.** Visto el 20 de
  agosto de 2026: se abre la letra en una canción y, al pasar a las siguientes,
  sigue mostrando la letra de la primera. `LyricsView` sí se entera de un
  cambio de pista —`didUpdateWidget` compara `videoId` y vuelve a pedirla
  (`lib/features/player/lyrics_view.dart:32`)—, así que lo que hay que mirar es
  quién le pasa la canción: `full_player.dart:126` lee
  `playerService.currentSong` en el build, y ese widget solo se reconstruye
  cuando lo hace el reproductor completo. Si el `AnimatedSwitcher` conserva el
  hijo sin reconstruirlo, o si el build llega antes de que `currentSong` cambie,
  la vista nunca ve la pista nueva. Sin diagnosticar.

- **Las playlists, los álbumes y el historial siguen en una sola página.** Las
  dos pestañas de canciones ya crecen con `songPages` —"Canciones" llega a 598
  y "Me gusta" a 183—, pero abrir una playlist larga sigue mostrando cien
  pistas como si fueran todas. Es el mismo `songPages` y el mismo
  `_GrowingShelf`; falta llevarlos a `playlist_screen` y a las otras dos.

## Suelto, sin diagnosticar

Cosas que funcionan a medias y conviene mirar antes de dar por cerrada una
versión.

- **En macOS, al iniciar sesión no cargó la foto de la cuenta** (20 de agosto
  de 2026). El avatar de la esquina se quedó en el icono de respaldo. El dato
  que falta y que parte el problema en dos es si el nombre y el correo sí
  aparecieron —en el tooltip del avatar o al abrir el panel—: si aparecieron,
  `accountInfo()` contestó y lo que falla es cargar la imagen; si no, falló la
  llamada entera y nadie lo reintenta.
  Descartado el sandbox: `com.apple.security.network.client` está en los dos
  `.entitlements`, y la propia sesión ya usa la red para iniciarla.
  Por dónde mirar: `AccountStore.refresh` cuelga del listener de la sesión,
  `accountInfo()` se traga cualquier fallo devolviendo null y no hay reintento,
  así que una llamada que salga antes de que las cookies sirvan deja el icono
  puesto hasta reiniciar; además `if (_loading) return;` descarta un segundo
  aviso mientras el primero está en vuelo. La comprobación barata es abrir la
  app otra vez con la sesión ya hecha: si entonces sale la foto, fue la carrera
  y no la imagen.

- **En Android Auto se quedó mudo con el contador corriendo** (20 de agosto de
  2026). Al desconectar el cable USB del carro la misma canción volvió a sonar
  normal. Que el contador siguiera avanzando es el dato que orienta: el
  reproductor no se atascó ni perdió el foco —habría publicado `paused`—, así
  que el audio se estaba yendo a un destino que ya no sonaba. Sin reproducir
  todavía; hace falta el carro o el Desktop Head Unit, y el DHU necesita que
  alguien toque *Start head unit server* en el teléfono en cada intento.
  Ojo: esto es de la sesión de medios y del enrutado, no del `StreamProxy` —
  ese quedó descartado con medición al diagnosticar lo de la duración.
  Dos datos nuevos del 20 de agosto que estrechan el sitio donde mirar. El
  aparato era el Samsung por USB, o sea que el caso del carro y el del teléfono
  son el mismo y no dos: siempre proyectando. Y **pasar a la siguiente canción
  no devolvió el sonido; solo desconectar el cable**. Eso descarta el volumen:
  un volumen mal dejado lo repone `_fadeIn` en la pista siguiente, y además el
  fundido estaba en cero. Queda el destino.
  Descartado también el propio reproductor, con medida: mientras la sesión
  publica PLAYING, el mezclador escribe señal de verdad. Se ve en
  `adb shell dumpsys media.audio_flinger`, en el *Signal power history* del hilo
  de salida — números como −7 dB son música saliendo; −60 o vacío es silencio.
  Es la forma barata de separar "la app no suena" de "el audio no llega al
  altavoz", y sirve igual para el emulador que para el teléfono.

- **El aleatorio arranca siempre con la canción que ya suena.** Pedido el 20 de
  agosto de 2026. Hoy es deliberado: `_shuffleAround` deja la pista actual de
  primera para no cortar la música al barajar. Falta decidir si cambia solo
  cuando se baraja sin nada sonando, o siempre — y si es siempre, qué pasa con
  la canción que se está oyendo en ese momento.

- **El paso de Gatekeeper, comprobado: hay que autorizarla a mano.** Los dos
  caminos probados en macOS 26.6 el 19 de agosto de 2026. Sin cuarentena
  —montada, arrastrada a `/Applications` y abierta desde ahí— funciona y suena.
  Con cuarentena, que es lo que trae cualquier copia bajada de un navegador,
  macOS se niega a abrirla y hay que ir a **Ajustes › Privacidad y seguridad** a
  permitirla; el ctrl-clic de siempre ya no vale en macOS 26. Las notas de la
  versión que estrene el `.dmg` tienen que explicar ese paso.
  Para diagnosticar esto **`spctl` no sirve**: rechaza una firma ad-hoc siempre,
  con cuarentena y sin ella. El que contesta es `syspolicy_check distribution`,
  que es de Apple y dice por qué: `Adhoc Signed App` como aviso y
  `Notary Ticket Missing` como **Fatal**. Quitarlo pide notarizar, y notarizar
  pide el Developer Program de pago y firmar con Developer ID en vez de ad-hoc.
  **Homebrew no es una salida a esto**, aunque lo pareciera: brew pone el
  atributo de cuarentena él mismo, y solo lo libera al actualizar si la
  identidad de firma de la versión nueva coincide con la de la vieja. La de una
  firma ad-hoc es el `cdhash` del binario (`designated => cdhash H"…"`), que
  cambia en cada build, así que el aviso vuelve en **cada** actualización. Una
  firma Developer ID daría una identidad estable
  (`certificate leaf[subject.OU] = …`) y arreglaría las dos cosas a la vez.
- **Los PNG heredados de Android no se han visto en un lanzador.** Sólo los lee
  API 25 y anterior; el emulador a mano es API 36 y sirve el adaptive icon en su
  lugar. Están comprobados como archivo, no como icono en una pantalla.
- **Escribir en la cuenta solo se ha ejercitado con el "me gusta".** Crear
  playlists, añadir canciones y suscribirse (`subscription/subscribe`) están
  implementados y no se han ejecutado nunca contra una cuenta real, para no
  ensuciar la biblioteca de nadie. De suscribirse, en el emulador salieron bien
  la marca local, la radio del artista y compartir; la escritura, no.
- **`player_queue_test.dart` falla de vez en cuando** al borrar su directorio
  temporal: `FileSystemException: Deletion failed … Directory not empty`. Salió
  una vez en una tanda y no volvió en siete pasadas seguidas, ni antes ni
  después de tocar nada. Es una carrera del `tearDown`, no del reproductor.
  Ahora que hay CI esto sale en rojo de tanto en tanto sin significar nada;
  el arreglo es el `tearDown`, no un reintento, que escondería los fallos
  de verdad.
- **El emulador se queda sin sonido y no es la app** (20 de agosto de 2026).
  Comprobado midiendo: con el emulador mudo, `dumpsys media.audio_flinger` daba
  −7 dB de señal continua al altavoz, `Master mute: off` y el volumen de música
  en 15/15. El audio sale de Android entero; lo que se rompe es la entrega al
  Mac, y pasa cuando macOS cambia de salida —auriculares, Bluetooth— con el
  emulador ya abierto. Se arregla reiniciando el emulador, no tocando código.

- **La app se congela y la mata el sistema (ANR + crash nativo).** Reproducido
  el 20 de agosto dos veces seguidas en un emulador recién arrancado, una de
  ellas recién abierta la app y sentada en el reproductor restaurado, sin tocar
  nada. Firma idéntica en los tres registros que hay (18 de agosto, 20 a las
  14:00 y 20 a las 18:22): el hilo principal queda **Runnable** —no bloqueado
  por un candado— quemando CPU dentro de
  `DartMessenger.handleMessageFromDart` → `PlatformTaskQueue.dispatch` →
  `Handler.post`, con 14 s, 24 s y 25 s de tiempo de usuario acumulado, y el
  proceso en **950 MB – 1 GB de RSS**. Es una inundación de mensajes de Dart
  hacia la plataforma, no un bloqueo. Termina en `APP CRASH(NATIVE)` unos
  segundos después.
  Se leen con `adb shell dumpsys dropbox --print data_app_anr` y
  `adb shell dumpsys activity exit-info com.tunebox.tunebox`.
  Dos salvedades antes de sacar conclusiones: todo esto es sobre un **build de
  depuración**, que va mucho más lento que uno de lanzamiento, y en un emulador
  que cayó a **render por software** por falta de memoria en el Mac
  (`Software GL rendering will be used due to system memory pressure` en el log
  del emulador). Las dos cosas inflan un ANR. Aun así, un gigabyte de RSS y
  veinticinco segundos de hilo principal en el mensajero no se explican por
  ahí. Por dónde empezar: quién manda tantos mensajes de plataforma — la
  cadena `positionStream` → `setVolume`/`playbackState` es la sospechosa
  inmediata, porque tira hasta sesenta tics por segundo.

- **El aviso de Play Protect no sale en el emulador**, que no lleva Google Play
  Services. Al instalar un APK de fuera, un teléfono con Play muestra un aviso
  propio antes del instalador; dónde aparece y qué dice es cosa suya, no
  nuestra, pero conviene verlo una vez para que no sorprenda.
- **El brillo por aplicación no se puede verificar en el emulador.** La llamada
  se hace y no falla, pero un `screencap` no captura la retroiluminación, así
  que el 20 % está probado como código y no como luz. Falta mirarlo en un
  teléfono.
- **Las etiquetas del reproductor: la izquierda con la posición vieja y la
  derecha en 0:00.** Visto primero con la cola terminada (1:48 y 0:00) y
  reproducido el 20 de agosto al abrir la app: sale **al restaurar**, con el
  cursor al principio y la izquierda marcando el segundo en que se dejó (1:13).
  Ya no es un misterio de dónde sale: `shownPosition` devuelve a propósito la
  posición recordada mientras no hay stream abierto
  (`player_service.dart:253`), pero `shownDuration` es
  `_player.duration ?? currentSong?.duration`, y si la canción guardada no
  trajo duración eso es null y se pinta 0:00. Las dos etiquetas no hablan de lo
  mismo hasta que alguien le da al play. Falta decidir el arreglo: guardar la
  duración en el punto de reanudación, o no pintar la posición mientras no haya
  una duración con la que casarla.

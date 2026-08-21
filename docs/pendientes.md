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

## Suelto, sin diagnosticar

Cosas que funcionan a medias y conviene mirar antes de dar por cerrada una
versión.

- **En macOS, al iniciar sesión no cargó la foto de la cuenta** (20 de agosto
  de 2026). **Medio cerrado**: el agujero que convertía un fallo pasajero en
  permanente ya está tapado; falta un inicio de sesión para saber si era ese.
  Lo que sí quedó comprobado leyendo el flujo, no suponiendo: en el inicio de
  sesión hay **una sola** notificación —`login_screen` se guarda con `_captured`
  de llamar a `signIn` dos veces—, así que la sospecha de dos avisos pisándose
  no se sostiene. Lo que sí pasa es que `accountInfo()` se traga cualquier fallo
  y contesta null, y `AccountStore` guardaba ese null como si fuera la
  respuesta: una sola petición mal parada dejaba el icono de respaldo **hasta
  reiniciar**, que es exactamente el síntoma.
  Ahora la tienda: no descarta un aviso que llega con otro en vuelo (lo
  encola), no borra una cuenta ya sabida por un null, y vuelve a preguntar a
  los 2, 6 y 20 segundos. Cinco pruebas en `test/account_store_test.dart`, de
  las que cuatro fallan contra la versión anterior.
  Lo que falta y no se puede hacer sin ti: **no hay sesión guardada en este
  Mac** —la app arrancó con `signedIn=false`—, así que no se pudo reproducir.
  Cuando vuelvas a iniciar sesión ahí, el dato que parte el problema en dos
  sigue siendo si el nombre y el correo aparecen: si aparecen y la foto no, el
  fallo es cargar la imagen y esto no lo arregla.

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

## Hecho

- **La letra ya no se queda pegada a la canción con la que se abrió** (20 de
  agosto de 2026). No era que no se recargara: sí lo hacía. Cada cambio de
  pista dejaba **otra `LyricsView` viva encima**, sin `deactivate` ni
  `dispose`, cada una siguiendo la posición por su cuenta; la vieja quedaba
  debajo de la nueva y se leía como una letra pegada. Medido en el emulador
  con contador de instancias: llegaban a tres seguidas sin soltar ninguna.
  La causa está en cómo `AnimatedSwitcher` distingue a sus hijos: sólo por la
  clave —su `defaultTransitionBuilder` fabrica la clave de la transición a
  partir de la del hijo— y `_stage` le daba `const ValueKey('lyrics')`, que no
  cambia nunca. Ahora la letra se clava por canción, igual que ya hacía la
  portada, y el registro muestra el `dispose` de la anterior en cada salto.
  Sin test: ni con la clave constante ni reusando `GlobalKey`s se reproduce en
  `flutter test`, hace falta el temporizado real. Queda comprobado en el
  aparato, antes y después.

- **El `tearDown` que borraba el temporal ya no compite con el reproductor**
  (20 de agosto de 2026). El `FileSystemException: Deletion failed … Directory
  not empty` era una carrera: el reproductor escribe el registro de escuchas y
  el punto de reanudación sin que nadie sostenga sus futuros, así que `stop()`
  no significa "ya terminó de escribir", y `pumpEventQueue()` es una apuesta
  sobre cuánto tarda eso. Al mirarlo resultó que el mismo `tearDown` estaba
  copiado en **cinco** pruebas, y dos de ellas —`player_effects_test` y
  `player_fade_test`— ya se tragaban el fallo en un `try`, dejando basura en el
  temporal en silencio. Ahora las cinco llaman a `removeWhenSettled`
  (`test/temp_directory.dart`), que espera la condición —que el directorio
  salga— en vez de una duración, y sigue lanzando si de verdad no sale.
  Seis tandas seguidas en verde; el fallo era raro, así que esto es el
  mecanismo atendido, no una prueba de que no vuelva.

- **Las playlists, los álbumes y el historial ya crecen página a página**
  (20 de agosto de 2026). Lo que se repetía en cinco sitios —acumular páginas,
  el esqueleto mientras llega la primera, el reintento— vive ahora en
  `SongPages` (`lib/features/shared/song_pages.dart`), y `_GrowingShelf` de la
  biblioteca es un usuario más de él. La playlist usa `playlistSongPages`, el
  historial `historyPages` (y de paso deduplica entre páginas, no solo contra
  lo local), y el álbum se apoya en `MusicPage.continuation`: su primera página
  llega con la portada y el nombre, así que crecer no significa volver a
  pedirla — que es la petición más lenta de todas. Debajo de una lista que
  todavía crece hay un `MoreComing`, y las sugerencias del pie solo salen
  cuando ya está entera, porque bajo cien filas de una lista incompleta se leen
  como su final.
  Comprobado en el emulador con números, no de vista: la playlist "Cool"
  imprimió `songs=0` → `songs=100` → `songs=124 done=true`; antes se quedaba en
  cien. El historial pasó de una página a **375 pistas**.

- **La pestaña "Historial" no se podía abrir** (20 de agosto de 2026).
  Encontrado de paso al ir a paginarla: `DefaultTabController(length: 7)` con
  ocho pestañas. Al añadir la de "Me gusta" nadie subió el número, así que el
  controlador no llegaba al octavo índice: tocar "Historial" no hacía nada y no
  se pintaba ni el indicador. No lanza excepción, que es por lo que llevaba
  días ahí sin que nada se quejara.

- **El aleatorio ya no arranca siempre con la misma canción** (20 de agosto de
  2026). Eran dos caminos distintos con la misma raíz: `_shuffleAround` subía
  al frente la pista de la que se barajaba.
  Al mirarlo salió que el botón **Barajar de una playlist** empezaba
  **siempre por la pista uno**: `setQueue` recibía `startIndex: 0` por defecto
  y no había forma de distinguir "toqué esta fila" de "dame la lista entera".
  Ahora `startIndex` es `int?`: una fila tocada sigue mandando —tocar significa
  "esta", se baraje o no—, y sin fila la decide el azar. Ningún llamador tuvo
  que cambiar: los toques de fila ya pasaban índice y los botones de reproducir
  no.
  Y el **interruptor sobre la cola que suena** baraja sin interrumpir, pero la
  pista que suena ya no queda clavada arriba: toma el sitio que le dé el azar.
  Lo que caiga por encima es la parte del barajado por la que este paso ya no
  vuelve — está a un toque en la cola, y con repetición se llega a ella.
  Seis pruebas nuevas en `player_queue_test.dart`, de las que dos fallan contra
  la versión anterior. En el emulador: tres veces "Barajar" en una playlist de
  124 con otra cosa sonando dieron tres arranques distintos y ninguno la pista
  uno; y apagar y encender el aleatorio dejó "Faded" sonando sin corte
  (0:46 → 0:53) con la cola empezando por otra.

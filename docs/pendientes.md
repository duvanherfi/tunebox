# Estado del trabajo

Este archivo es la memoria entre hilos. Cada feature nueva se trabaja en un hilo
nuevo: se lee esto primero y se actualiza al terminar cada paso, no al final.

## Pendiente

Orden acordado el 21 de agosto de 2026, un hilo por punto. Hechos el primero,
el ANR del mensajero de Dart y el selector de carpetas del escritorio, queda lo
de abajo.

- **Windows y Linux no reproducen nada.** Salió al hacer el selector de
  carpetas (22 de agosto de 2026), y es el bloqueo de verdad de esas dos
  plataformas: `just_audio` 0.10.6 y `audio_service` 0.18.19 declaran
  implementación para `android`, `ios`, `macos` y `web`, y ninguna de las dos
  para Windows ni Linux. La primera llamada al reproductor contesta
  `MissingPluginException`. Lo que haría falta es `just_audio_media_kit` —que
  es libmpv— y decidir qué hace `audio_service` donde no existe: es un feature
  grande y aparte. Hasta entonces la pestaña del dispositivo ahí **lista
  canciones que no suenan**, que es justo la fila contra la que avisa el
  comentario de `extensionsFor`.
  En Linux hay un segundo hueco: `flutter_inappwebview` tampoco tiene
  implementación, y es el navegador del inicio de sesión — o sea que ahí ni
  siquiera se puede entrar a la cuenta. `screen_brightness` tampoco está, así
  que la mesita de noche no regula el brillo.

- **La cuenta dice 216 me gusta y `LM` contesta 183.** La página dos llega sin
  token, así que no es que el recorrido se corte: son 33 que la API no lista.
  Sin diagnosticar; la sospecha es que son pistas ya no disponibles o de otro
  tipo. Mientras tanto esos 33 salen con el corazón vacío.

- **De pódcast: marcar como reproducido y "Episodios para más tarde".** Lo que
  quedó fuera al hacer el resto de acciones del menú (22 de agosto de 2026), y
  con motivo medido: son 2 filas de 200 en el historial, las dos episodios, y
  "Episodios para más tarde" ni siquiera es un `feedbackEndpoint` sino un
  `commandExecutorCommand` —otro mecanismo—. La app no tiene superficie de
  pódcast donde eso signifique algo.

- **Ver el vídeo de una canción, como YouTube Music.** Pedido el 21 de agosto
  de 2026. Son dos cosas distintas y conviene no confundirlas:
  - **El interruptor Canción ↔ Vídeo** necesita un `counterpart` en la
    respuesta de `next`, y **no llega**: medido con `c417rIku6Iw` y
    `J7p4bzqLvCw`, con `WEB_REMIX` contra `music.youtube.com` y con
    `ANDROID_MUSIC` contra `youtubei.googleapis.com`, con y sin
    `playlistId: RDAMVM…` — cero `counterpart` en los cuatro, siempre
    `MUSIC_VIDEO_TYPE_ATV`. Encontrar dónde sirve YouTube ese dato es un sondeo
    propio; los clientes móviles de música contestan **400** contra
    `music.youtube.com`, hay que ir a `youtubei.googleapis.com`.
  - **Pintar la imagen.** Las filas que YouTube marca "Vídeo •" son vídeo de
    verdad y la app ya las reproduce, en audio, porque el reproductor es
    `just_audio` —que no pinta imagen— y el `StreamProxy` sirve el formato de
    audio. Enseñar el vídeo no es pedir otro endpoint: es meter un reproductor
    de vídeo en la app, y decidir qué hace con él la sesión de medios, el carro
    y la pantalla de bloqueo. Feature grande y aparte.

- **El log de reproducciones no distingue una canción escuchada de una
  saltada.** Salió al diseñar un modelo de recomendación sobre el historial
  (22 de agosto de 2026). `_playIndex` llama a `_history.record(song)` en
  cuanto el stream se abre —`player_service.dart:658`—, así que una pista que
  sonó tres segundos y una que sonó entera quedan idénticas en
  `play_log.json`. Todo lo registrado es un positivo, y no hay negativos.

  Lo llamativo es que **la señal ya está calculada y se tira**: catorce líneas
  más abajo, `_watchtime` espera la mitad de la pista o dos minutos —lo que
  llegue antes, que es la regla que piden los servicios de scrobbling— y con
  eso avisa a Last.fm y a ListenBrainz. Ese mismo momento es la etiqueta que
  falta, y hoy no se escribe en el log local.

  Lo que haría falta: que `Play` lleve si la escucha llegó a contar, y que el
  temporizador marque esa fila además de scrobblear. Ojo con dos cosas — la
  fila ya está escrita cuando el temporizador dispara, así que hay que
  actualizarla y no añadir otra; y si la pista se corta antes, el temporizador
  se cancela y la fila se queda sin marcar, que es exactamente lo que se quiere
  registrar.

  **Cuanto antes se haga, más datos habrá**: la etiqueta solo existe hacia
  adelante, no se puede reconstruir de las 5 000 filas ya guardadas. El
  proyecto que la usa está descrito en
  `~/demand-forecast/docs/pendientes.md` y va después de la vuelta 4 de ese
  otro repo, pero **la instrumentación conviene adelantarla** para que el
  historial se vaya llenando mientras tanto.

## Suelto, sin diagnosticar

Cosas que funcionan a medias y conviene mirar antes de dar por cerrada una
versión.

- **El plural de "1 canciones".** Visto al listar una sola pista del
  dispositivo (22 de agosto de 2026), en los dos idiomas: la cabecera de
  `SortedSongs` dice *1 canciones* y *1 tracks*. La clave es `sortCount`, y es
  `"{count} canciones"` a secas — un marcador dentro de una cadena, no un
  `plural`. Arreglarlo es pasarla a `{count, plural, ...}` en `app_en.arb` y
  `app_es.arb`; `collectionDownloading` tiene el mismo defecto. Es de antes de
  este cambio.

- **Las raíces por defecto de Linux no leen los nombres traducidos.**
  `rootsFor('linux')` contesta `~/Music` y `~/Downloads`, y un escritorio en
  español los llama `~/Música` y `~/Descargas`. XDG lo registra en
  `~/.config/user-dirs.dirs`, que es un archivo y no una variable de entorno:
  leerlo volvería impura una función que hoy es pura y está probada con un
  mapa inyectado. Mientras tanto lo cubre el selector, a mano.

- **Elegir una carpeta en GTK se hace desde la carpeta padre.** Medido al
  conducir el diálogo en Linux (22 de agosto de 2026): estando *dentro* de la
  carpeta, el botón *Open* queda inactivo, porque en modo «elegir carpeta»
  GTK exige una fila seleccionada en la lista. Hay que ir al padre y marcarla
  ahí. Es comportamiento de GTK, no de la app, pero conviene saberlo antes de
  dar por rota la pantalla.

- **El menú sigue ofreciendo "Fijar" en una pista que se acaba de fijar.**
  De hacer las acciones del menú (22 de agosto de 2026). Los tokens vienen de la
  página tal como se leyó, y nadie la relee: hasta volver a entrar, el menú
  ofrece fijar una pista que ya está fijada. Volver a mandarlo no rompe nada
  —el token es idempotente— y el pin no se dibuja en ninguna parte de la app,
  así que el coste es sólo esa etiqueta. Arreglarlo bien sería el patrón de
  `Likes`: un registro de lo que se cambió aquí que mande sobre lo que dijo la
  página.

- **Una playlist recién creada lista las sugerencias de YouTube como si fueran
  suyas.** Visto al probar quitar de una lista (22 de agosto de 2026): la
  cabecera dice 3 pistas y debajo salen quince. YouTube cuelga un estante de
  sugerencias de la misma respuesta y `parseSongList` camina el árbol entero, así
  que entran como filas. No es de este cambio —`playlistSongPages` hacía lo
  mismo— y no rompe nada, porque una fila sugerida no trae `setVideoId` y por
  tanto no ofrece quitarse. Arreglarlo pide distinguir el estante de contenidos
  del de sugerencias.

- **El llavero de macOS y la firma ad-hoc, al actualizar: sí pregunta.**
  Medido el 21 de agosto de 2026, que era lo que faltaba. Al abrir un build
  nuevo sobre el llavero que dejó el anterior, macOS pide autorizar el acceso a
  `flutter_secure_storage_service` con la contraseña del llavero. Era lo
  esperado: la identidad de una firma ad-hoc es el `cdhash`, que cambia en cada
  compilación, lo mismo que ya obliga a repetir el permiso de Gatekeeper.
  Autorizarlo devuelve la sesión entera sin volver a iniciarla. Lo que sigue sin
  comprobarse es si "Permitir siempre" evita la pregunta en la compilación
  *siguiente*; por lo que se sabe de la identidad, no debería. Una firma
  Developer ID lo arreglaría, igual que arreglaría lo de Gatekeeper.

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
- **Lo que ya se ha ejercitado contra la cuenta real, y lo que no.** Hechos
  contra la cuenta y comprobados leyendo el resultado: el "me gusta", quitar del
  historial, quitar de una playlist, crear, renombrar y borrar playlists, y
  fijar y desfijar en "Vuelve a escucharlo" (22 de agosto de 2026). Sigue **sin
  ejecutarse nunca** suscribirse a un artista (`subscription/subscribe`): en el
  emulador salieron bien la marca local, la radio del artista y compartir; la
  escritura, no.

- **El emulador se queda sin sonido y no es la app** (20 de agosto de 2026).
  Comprobado midiendo: con el emulador mudo, `dumpsys media.audio_flinger` daba
  −7 dB de señal continua al altavoz, `Master mute: off` y el volumen de música
  en 15/15. El audio sale de Android entero; lo que se rompe es la entrega al
  Mac, y pasa cuando macOS cambia de salida —auriculares, Bluetooth— con el
  emulador ya abierto. Se arregla reiniciando el emulador, no tocando código.

- **En macOS, un permiso denegado se ve igual que "no hay música".** De hacer
  la pestaña del dispositivo (21 de agosto de 2026). Al mirar `~/Music` y
  `~/Downloads` macOS pregunta una vez por carpeta, en el momento de leerla. Si
  la respuesta es *No permitir*, la lectura lanza `FileSystemException`, el
  recorrido se la traga —que es lo que hace falta para que una carpeta prohibida
  no se lleve por delante el resto— y la pestaña sale vacía con su mensaje de
  siempre. Nadie le dice a quien negó el permiso que fue eso. Android sí lo
  distingue, porque ahí el permiso se pide antes y de una vez.

- **El `Info.plist` de macOS no explica para qué pide las carpetas.** Sin
  `NSAppleMusicUsageDescription` ni `NSDownloadsFolderUsageDescription`, macOS
  pone su texto genérico —que al menos llega traducido—. Poner uno propio pide
  además un `InfoPlist.strings` por idioma, o el aviso saldría en inglés a todo
  el mundo.

- **Recorrer el almacenamiento entero no se ha medido en un teléfono lleno.**
  En el emulador, con cinco archivos, es instantáneo. Un teléfono real tiene
  decenas de miles de archivos bajo `/storage/emulated/0`, y el recorrido es
  carpeta a carpeta y en el isolate principal. Si tarda, la pestaña se queda en
  su esqueleto sin decir cuánto falta.

- **Una prueba falló una vez de nueve y no se supo cuál** (21 de agosto de
  2026). Una pasada dio `+218 -1` y las ocho siguientes, seguidas, dieron las
  219 en verde. El resumen no nombra la que falla, así que quedó sin
  identificar; por dónde cayó, la sospecha son las de `player_fade_test`, que
  van contra tiempos. No es de lo que se tocó ese día —el cambio fue
  `DeviceSongs`, los ARB y los entitlements— y conviene volver a mirarlo con
  `--reporter expanded` a la próxima que aparezca, que es lo que sí imprime el
  nombre.

- **El aviso de Play Protect no sale en el emulador**, que no lleva Google Play
  Services. Al instalar un APK de fuera, un teléfono con Play muestra un aviso
  propio antes del instalador; dónde aparece y qué dice es cosa suya, no
  nuestra, pero conviene verlo una vez para que no sorprenda.
- **El brillo por aplicación no se puede verificar en el emulador.** La llamada
  se hace y no falla, pero un `screencap` no captura la retroiluminación, así
  que el 20 % está probado como código y no como luz. Falta mirarlo en un
  teléfono.
- **Las etiquetas del reproductor con la cola terminada** (1:48 y 0:00). El
  caso *al restaurar* quedó arreglado el 21 de agosto, pero este avistamiento
  —el primero, con la cola ya agotada— probablemente es **otro mecanismo** y no
  se ha vuelto a ver desde entonces. Cuando la cola se acaba nadie vuelve a
  emitir posición, así que el `StreamBuilder` se queda con la última que
  recibió mientras `shownDuration`, que es un getter y se relee en cada
  repintado, ya contesta null. Si vuelve a salir, ahí es donde hay que mirar.

## Hecho

- **Las acciones del menú de una fila** (22 de agosto de 2026). Quitar del
  historial, quitar una canción de una playlist, renombrar y borrar playlists,
  fijar y desfijar en "Vuelve a escucharlo", y ver los créditos. Todo medido
  contra la cuenta real antes de escribirlo, y ejercitado en el emulador
  después.
  - `SongActions` (`lib/data/models/song.dart`) agrupa lo que la fila trajo:
    los tokens de biblioteca, historial y pin, el `setVideoId` de la playlist y
    si hay créditos. `Song` tiene un solo campo `actions` en vez de seis nulos,
    y sigue fuera de `toJson` — un token es una credencial de la respuesta en
    que llegó.
  - **Todas las acciones se identifican por `iconType`**, nunca por etiqueta:
    `hl` sigue al idioma del aparato. `REMOVE_FROM_HISTORY`,
    `REMOVE_FROM_PLAYLIST`, `PEOPLE_GROUP` para créditos, `BOOKMARK` y
    `KEEP`/`KEEP_OFF`.
  - **El pin llega con los dos lados invertidos cuando la pista ya está
    fijada.** YouTube pone siempre en `default` la acción que ofrece, así que
    una pista fijada contesta `KEEP_OFF` ahí. Leyendo el lado en vez del icono
    —que es como estaba primero— una pista fijada no ofrecía nada y no había
    forma de desfijarla nunca. Medido pinchando una pista a propósito y
    devolviéndola a su sitio.
  - **`RetiredIds`** (`lib/data/retired_ids.dart`) es el `ChangeNotifier` de lo
    que se quitó aquí, por lista, y `SongPages` lo filtra. Arregla de paso el
    defecto que ya estaba anotado —la fila quitada seguía en pantalla hasta
    recargar— y vale igual para el estante de playlists, que lee sus listas una
    vez y se las queda.
  - **El historial se fusiona por id** (`SongPages.mergeById`). La pestaña se
    llena primero con el log local, que se lee de `play_history.json` y por
    tanto **no trae menú ninguno**, y antes el `seen` descartaba luego la fila
    de la cuenta para esa misma pista: justo las canciones que sonaron aquí
    —las de arriba— eran las únicas que nunca podían quitarse del historial.
    Ahora la fila de la cuenta reemplaza a la local en el sitio que ya tenía.
  - **`playlistPage()`** espeja a `albumPage()` y contesta además si la lista es
    de la cuenta, mirando si trae `musicPlaylistEditHeaderRenderer`. Una lista
    guardada de otro no lo trae, y por eso no ofrece renombrar ni borrar.
  - **Los créditos son pantalla completa**, como en YouTube Music de Android,
    aunque la respuesta venga envuelta en un `dismissableDialogRenderer` —que es
    lo que usa el reproductor web—. El id es literalmente `MPTC` + el `videoId`,
    verificado en las 159 filas de 200 que traían la entrada. Una pista sin
    créditos contesta la misma página vacía, así que la entrada se ofrece sólo
    cuando la fila la trajo.
  - **Escribir y leer no son inmediatos.** Renombrar contesta
    `STATUS_SUCCEEDED` y la lectura siguiente todavía devuelve el nombre viejo,
    así que la pantalla se queda con el nombre nuevo en local en vez de
    releerlo. Lo mismo con el pin en la portada, que tarda unos segundos en
    aparecer en "Vuelve a escucharlo".

  Comprobado en el emulador contra la cuenta real: quitar del historial (la fila
  se va al instante y `FEmusic_history` ya no la lista), quitar de una playlist,
  renombrar y borrar —sobre listas de prueba creadas y borradas para esto—,
  fijar (aparece de primera en "Vuelve a escucharlo") y los créditos. La cuenta
  quedó como estaba salvo la pista quitada del historial.

- **El selector de carpetas del escritorio** (22 de agosto de 2026). La app ya
  llega a Documentos, al escritorio o a un disco externo, en macOS, Windows y
  Linux. Lo que hay:
  - `MusicFolders` (`lib/data/music_folders.dart`) guarda las carpetas
    añadidas en un JSON bajo el directorio de soporte, con `File` inyectable
    como los demás almacenes que crecen. Una carpeta que ahora no se alcanza
    —disco desenchufado, carpeta borrada— **se queda en la lista marcada como
    no disponible** y no se camina: desconectar un disco no es la decisión de
    olvidarla.
  - Los *security-scoped bookmarks* de macOS son **código propio** en
    `macos/Runner/FolderBookmarks.swift`, por `MethodChannel`. El paquete de
    pub para esto, `macos_secure_bookmarks`, está muerto: 0.2.1 de 2022, con
    `sdk: <3.0.0`, no resuelve con Dart 3. El alcance abierto por `resolve` no
    se cierra nunca mientras la app viva; cerrarlo vaciaría la pestaña a media
    sesión.
  - Los entitlements que hacían falta eran **dos**, no uno:
    `files.user-selected.read-only` para el panel y `files.bookmarks.app-scope`
    para que sobreviva al reinicio. En `DebugProfile` y en `Release`.
  - El selector es `file_selector` (1.1.0), que sí tiene implementación viva en
    las tres plataformas de escritorio.
  - `rootsFor` y `extensionsFor` ya contestan para `windows` y `linux`, y
    `asksAtRuntime` sustituye al viejo `_permitted`, que contestaba *denegado*
    en todo lo que no fuera Android o macOS — o sea que en esas dos el
    recorrido se rendía antes de empezar.
  - La gestión vive en *Ajustes › Carpetas de música*, sólo en escritorio, y la
    pestaña del dispositivo tiene su puerta en el estado vacío.

  Comprobado en pantalla, no sólo con pruebas. **En macOS**: elegir
  `~/Documents/tunebox-prueba` —que ningún entitlement alcanza—, verla listada,
  **reproducirla**, cerrar la app y volver a abrirla, y que la carpeta siga
  ahí sin volver a elegirla; el bookmark guardado son 960 caracteres de base64
  que empiezan por la cabecera `book`. **En Linux**, dentro de un contenedor
  (`tool/linux-docker/`, que compila y ejecuta bajo `xvfb` y deja captura):
  elegir la carpeta en el diálogo de GTK, verla guardada con `bookmark: null`
  —que es lo correcto donde no hay sandbox— y verla listada en la pestaña.
  **Windows** no se ejecutó: no hay forma de hacerlo desde este Mac. Lo que sí
  hay es un job de CI que compila `windows-latest`, junto a otro de Linux.

- **Denegar el llavero de macOS dejaba la app sin abrir, para siempre**
  (22 de agosto de 2026). Salió al comprobar lo anterior. `main` hace
  `await session.load()` antes de `runApp`, y con una firma ad-hoc macOS pide
  la contraseña del llavero en cada compilación; si la respuesta es *Denegar*,
  `flutter_secure_storage` lanza `PlatformException(-128)`, nadie la atrapa y
  la ventana se queda negra. `Scrobbler.load` tenía el mismo hueco, con cuatro
  lecturas. Ahora las dos tratan la negativa como «no hay nada guardado», que
  no es lo mismo que borrarlo: **no se toca el llavero**, así que autorizarlo
  en un arranque posterior devuelve la sesión igual que estaba. Lo que sigue
  sin resolverse es que la app se ve *desconectada* sin decir que fue el
  llavero — el mismo defecto que ya tiene apuntado el permiso de carpetas.

- **El ANR del mensajero de Dart era el puente del widget** (22 de agosto de
  2026). La sospecha apuntada aquí —la cadena `positionStream` →
  `setVolume`/`playbackState`, hasta sesenta tics por segundo— era **falsa**, y
  conviene dejarlo escrito: `positionStream` no cruza a la plataforma, la
  posición se calcula en Dart, y en tres minutos de reproducción `setVolume`
  salió **dos** veces. El fundido tampoco: sólo escribe volumen dentro de la
  ventana del fundido, y ahí la cadencia es la del `positionStream`, 200 ms.
  Lo que inunda es `HomeWidgetBridge`. Publicaba en el lanzador **por cada**
  evento de `mediaItem` y de `playbackState`, sin comparar si algo había
  cambiado y sin esperar a que la publicación anterior terminara. Cada
  publicación son **cinco viajes a la plataforma** (cuatro `saveWidgetData` y un
  `updateWidget`) y el `updateWidget` acaba en una emisión
  `APPWIDGET_UPDATE` que vuelve a entrar **por el hilo principal de la propia
  app**. Los eventos del reproductor no llegan repartidos sino a ráfagas —un
  cambio de pista, una tanda de saltos, un arrastre por la barra, el
  `_advance` saltándose pistas que YouTube niega—, así que llegan cientos de
  golpe y el despachador de entrada de Android se cansa a los 5 s.
  Medido, no supuesto. La traza lo dice dos veces: el hilo principal está en
  `DartMessenger.handleMessageFromDart` → `PlatformTaskQueue.dispatch` →
  `Handler.post` —es decir, *poniendo* estos mensajes—, y el `Debug Store` del
  informe es una tira de recepciones seguidas de
  `act=android.appwidget.action.APPWIDGET_UPDATE;cmp=…/.TuneboxWidget` en
  `tname=main`. En los siete ANR registrados aparece 51 veces.
  Con el instrumento de Flutter para esto —`debugProfilePlatformChannels`, que
  imprime cada segundo qué canal manda cuántos bytes— y **25 toques de
  "siguiente"** en el emulador, antes y después del arreglo:

  | | antes | después |
  |---|---|---|
  | `saveWidgetData` | 1498 | 76 |
  | `updateWidget` (emisiones al hilo principal) | 336 | 19 |
  | segundos con tráfico | 73 | 14 |
  | RSS | 503 → 671 MB | 495 → 518 MB |
  | montón de Dart | 176 → 318 MB | 177 → 183 MB |

  El puente era el **95 %** de todo el tráfico Dart → plataforma. Y la memoria
  venía con él: reproducir tres minutos seguidos no movía el RSS, pero la
  tormenta de saltos lo subía 170 MB y no los devolvía; con el arreglo se queda
  plano. Lo de "un gigabyte no se explica por el render por software" era
  cierto — esta vez el emulador iba con Impeller sobre GL y aun así llegó a
  **1.09 GB** y se mató dos veces seguidas.
  El arreglo es uno solo, con la forma que ya usa `Downloads._drain`: un tipo
  `_Wanted` con las cuatro cosas que el widget dibuja (título, artista,
  carátula y si suena), se descarta lo que no cambie nada, y se publica de una
  en una — mientras hay una en vuelo las demás se funden en **una sola**
  pendiente, lo que además acota la cadencia sin necesidad de temporizador.
  De paso arregla un defecto vecino que la misma causa producía: al solaparse,
  las publicaciones se pisaban las cuatro claves y **el último título no
  llegaba nunca**. La prueba lo enseña —contra la versión anterior devuelve
  `null`— y en el aparato el almacén del widget y la sesión de medios ahora
  dicen lo mismo ("El aviador / Saurom / playing=true").
  Y no hace falta tener el widget puesto: en el emulador no hay ninguno
  colocado, la emisión se manda igual y la inundación ocurre igual.
  Cuatro pruebas en `test/home_widget_bridge_test.dart`, tres en rojo contra la
  versión anterior, que interceptan el canal `home_widget` y cuentan los viajes
  de verdad: 40 estados iguales daban 40 publicaciones y 42 solapadas a la vez.

- **Quitar una canción de la biblioteca ya no le quita el like** (21 de agosto
  de 2026). Pedido el 20 de agosto; lo que faltaba era saber por dónde se pide,
  y no era ninguna de las dos suposiciones: ni `edit_playlist` ni
  `like/removelike`. Es **`POST feedback`** con `{"feedbackTokens": [token]}`.
  El token vive en el menú de la propia fila, en un
  `toggleMenuServiceItemRenderer` cuyo lado por defecto guarda en la biblioteca
  y cuyo lado `toggled` la quita. Es **opaco y por fila**: no se deriva del
  `videoId` y no hay endpoint que acepte uno, así que el parser tiene que
  quedárselo — `Song.removeFromLibraryToken` — y una fila que no traiga menú no
  se puede quitar de ninguna manera.
  Dos detalles que costaría volver a descubrir. La entrada se reconoce **por el
  icono, no por el texto**: `hl` sale del idioma del aparato, así que la
  etiqueta llega traducida, mientras que `BOOKMARK` es igual en todas partes. Y
  `isToggled` es lo que dice que la pista está en la biblioteca — sin mirarlo,
  un resultado de búsqueda que nadie guardó traería un token que no quita nada.
  Hace falta porque **la misma fila lleva varios `feedbackToken`**: el de fijar
  en "Vuelve a escucharlo", el lado de añadir de este mismo interruptor y una
  copia dentro del botón de "me gusta" (`addToLibraryFeedbackToken`, que es lo
  que hace que dar like meta la pista en la biblioteca). Cualquiera de ellos
  enviado a `feedback` haría en silencio otra cosa.
  Medido contra la cuenta, no supuesto. Antes de escribir nada: `isToggled`
  cierto en 25/25 filas de la biblioteca, 75/76 de las de "me gusta" que traen
  el interruptor, 147/180 del historial y 0/5 de la búsqueda. Y desde la app en
  el emulador, con "No Se Si Fue" —que estaba en las dos listas—: la biblioteca
  pasó de **598 a 597** pistas y la canción salió de ella, **el "me gusta"
  siguió ahí** (100 de 100), y volver a añadirla la devolvió a 598. Las dos
  pruebas de escritura dejaron la cuenta como estaba.
  Cuatro pruebas de parser en `test/innertube_parser_test.dart` contra un
  fixture nuevo, `test/fixtures/library_songs.json` — una página real de la
  biblioteca **con los tokens tachados**, porque un `feedbackToken` es una
  credencial: quien lo tenga puede editar esa biblioteca. Dos más en
  `test/library_removal_test.dart` para el cuerpo que va por el cable.

- **El reproductor restaurado ya no dice 1:13 de 0:00** (21 de agosto de 2026).
  Las dos etiquetas del bar no hablaban de lo mismo: `shownPosition` devuelve a
  propósito la posición recordada mientras no hay stream, y `shownDuration` se
  quedaba en null porque la canción guardada no traía duración.
  La causa de fondo no era la etiqueta sino **dónde moría la duración
  medida**. `_playIndex` la aprende al abrir el stream y la metía sólo en el
  `mediaItem` de la pista que sonaba en ese momento; la cola seguía con la
  canción tal como la listaron, y el punto de reanudación serializa la cola. Al
  cerrar la app, la única copia de esa duración se iba con ella. Y hay filas que
  no la traen nunca: los videos y los mixes de YouTube, y **todas** las
  canciones del dispositivo, que se listan sin duración.
  Ahora `_rememberDuration` escribe la medida de vuelta en la canción —en
  `_songs` y en `_unshuffled`, porque deshacer el barajado reconstruye desde la
  segunda— y con ella la ganan también la cola del carro y la hoja de cola.
  `Song.withDuration` es la copia. Y como remate, `shownPosition` sólo devuelve
  la posición recordada si hay una duración con la que casarla: sin ella, cero.
  Eso cubre lo que la otra mitad no puede — una cola que se puso y nunca se
  reprodujo, donde nadie midió nada.
  Cuatro pruebas en `test/player_duration_test.dart`, tres en rojo contra la
  versión anterior. Y en el emulador, con el archivo delante: una canción del
  dispositivo de 3:05 dejó `durationMs: 185051` en `resume.json` —antes ese
  campo era null siempre para las del dispositivo— y al volver a abrir la app el
  reproductor salió con **0:20 / 3:05** y el cursor en su sitio, donde antes
  habría salido 0:20 y 0:00.

- **La pestaña ya lee del dispositivo, en el Mac también, y con los formatos
  que cada reproductor abre** (21 de agosto de 2026). Tres cosas que parecían
  independientes y compartían una sola causa: `DeviceSongs` estaba escrito para
  Android y para nadie más.
  El nombre era lo de menos: `libraryDevice` y `libraryDeviceEmpty` en los dos
  ARB, "Del dispositivo" / "On this device".
  **En macOS no estaba roto, es que nunca se escribió.** Las raíces eran cuatro
  rutas `/storage/emulated/0/…` que en un Mac no existen, y el permiso iba por
  `permission_handler`, que no tiene implementación de escritorio. Ahora
  `rootsFor` decide por plataforma. En el Mac son `$HOME/Music` y
  `$HOME/Downloads`, y el truco está en que dentro del sandbox `HOME` **ya es el
  contenedor**, donde macOS deja un enlace a la carpeta real en cuanto el
  entitlement está concedido: no hace falta resolver el home de verdad ni
  guardar bookmarks. Los entitlements son `assets.music.read-only` y
  `files.downloads.read-only`, y **la firma ad-hoc los acepta** — comprobado con
  `codesign -d --entitlements`, al contrario que `keychain-access-groups`. En
  macOS no hay nada que preguntar en tiempo de ejecución: lo pregunta el sistema,
  una vez por carpeta, cuando se va a leer.
  **En Android se pasó de cuatro carpetas a todas.** Una sola raíz,
  `/storage/emulated/0`, y debajo todo menos lo que empieza por `.` y menos
  `Android/`, que es dato privado de otras apps. Eso obligó a dejar de usar
  `list(recursive: true)`: es un único stream, así que la primera carpeta que se
  niegue a ser leída —`Android/data` en cualquier teléfono moderno— lo termina y
  se lleva consigo todo lo que quedara por visitar. Ahora se recorre nivel a
  nivel y una negativa cuesta esa carpeta y nada más.
  **Los formatos son dos listas, no una.** ExoPlayer abre Ogg, Opus, WebM y
  Matroska y no tiene extractor de AIFF; AVFoundation es al revés. Una lista
  única dejaría filas que parecen música y contestan silencio.
  Once pruebas en `test/device_songs_test.dart`, todas en rojo antes; la del
  permiso denegado se comprobó además quitándole el `try` al recorrido, para que
  no pasara por casualidad. Y en los dos aparatos, con números: en el Mac, dos
  archivos en `~/Music` salieron y el `.aiff` sonó, mientras la carpeta oculta
  de al lado no apareció; en el emulador, cinco archivos colocados a propósito
  dieron **3** —un `.mp3` en `Music`, un `.mka` en `Podcasts` y un `.opus` en
  `MiCarpeta/Subcarpeta`, dos carpetas que la versión anterior no miraba— y se
  quedaron fuera el de la carpeta oculta y un `.aiff`, que en Android no se
  lista. Los dos contenedores nuevos se reprodujeron.

- **Cerrar sesión ya cierra sesión de verdad** (21 de agosto de 2026). El
  botón borraba la copia de la app y dejaba intacta la del navegador: el
  webview del login guarda su propio almacén —`WKWebsiteDataStore` en macOS,
  `CookieManager` en Android—, que es del sistema y sobrevive a la app, y nada
  en el repo lo tocaba nunca; `CookieManager` aparecía una sola vez, para leer.
  Google seguía con la sesión abierta ahí, así que el siguiente inicio
  atravesaba la página de login sin detenerse: la misma cuenta, sin selector y
  sin contraseña. Visto desde fuera, un cierre de sesión que no hizo nada — que
  es justo lo que estorba a quien cierra sesión para entrar con otra cuenta.
  Ahora `Session.signOut` vacía los dos. La limpieza vive en
  `features/auth/browser_session.dart` y se inyecta desde `main.dart`, para que
  `core/auth` no dependa del webview; va en `Session` y no en el botón porque
  hay un tercer camino que cierra sesión solo — el 401 de
  `innertube_client.dart:260`.
  De paso, un defecto vecino: `signOut` avisaba **después** de esperar al
  almacén, así que la cuenta seguía en pantalla durante el viaje al llavero, y
  si el almacén fallaba —como fallaba esta misma mañana— para siempre. Ahora
  avisa primero. Dos pruebas en `test/session_test.dart`; la del orden falla
  contra la versión anterior.

- **El inicio de sesión en macOS ya se guarda, y con él vuelve la foto**
  (21 de agosto de 2026). No era la foto ni `AccountStore`: era que **el login
  entero fallaba**. Se vio a la primera al reproducirlo con el registro delante:
  `PlatformException(-34018, A required entitlement isn't present)` desde
  `FlutterSecureStorage.write` ← `Session.signIn` ← `LoginScreen._tryCapture`.
  De ahí salían los dos síntomas a la vez: `signIn` guarda la cookie en memoria
  y lanza **antes** de `notifyListeners`, así que nadie se enteraba de la sesión
  —el avatar se quedaba en su icono de respaldo aunque la biblioteca ya
  funcionara— y nada llegaba al llavero, así que al siguiente arranque
  `signedIn=false`. Eso explica la nota vieja de que "no hay sesión guardada en
  este Mac": no es que no se hubiera iniciado, es que no se podía guardar.
  La causa: `flutter_secure_storage` pide por defecto el llavero **de
  protección de datos** de macOS, y ese solo se abre a una app cuyo entitlement
  declare `keychain-access-groups`. Dos intentos lo descartaron por el camino:
  declararlo hace que Xcode se niegue a compilar —"Runner has entitlements that
  require signing with a development certificate"— y quitar el sandbox no
  cambia nada, el error es idéntico. Lo que resuelve es pedir el llavero de
  archivo de toda la vida: `MacOsOptions(usesDataProtectionKeychain: false)`,
  ahora en `lib/core/auth/secure_storage.dart` y compartido por `Session` y
  `Scrobbler`. El sandbox y los entitlements quedaron **como estaban**.
  Comprobado en el Mac, no supuesto: el login guarda
  (`security dump-keychain` enseña `youtube_cookies`), la cuenta llega
  —`accountInfo` con nombre y foto— y **al reiniciar la app vuelve sola** con
  `signedIn=true`. Dos pruebas en `test/macos_keychain_test.dart`, las dos
  fallan contra la versión anterior.
  Dos datos de paso. Uno corrige la nota anterior: en el inicio de sesión sí
  llegan **dos** avisos, no uno, y el segundo entró mientras el primero estaba
  en vuelo — el encolado que se añadió el 20 de agosto se estrenó aquí. El
  otro: `accountInfo` contesta el nombre pero el **correo vacío**; el panel de
  cuenta lo pinta, así que sale sin correo.

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

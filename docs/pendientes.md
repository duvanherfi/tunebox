# Estado del trabajo

Este archivo es la memoria entre hilos. Cada feature nueva se trabaja en un hilo
nuevo: se lee esto primero y se actualiza al terminar cada paso, no al final.

## Pendiente

Orden acordado el 21 de agosto de 2026, un hilo por punto. Hechos el primero,
el ANR del mensajero de Dart y el selector de carpetas del escritorio, queda lo
de abajo.

Las tres entradas diagnosticadas el 10 de septiembre de 2026 —la búsqueda, el
radio tras buscar y el home— están hechas, y las dos cosas que quedaron fuera de
la búsqueda también, el 11 de septiembre de 2026. Lo de Explorar, ese mismo día.

Lo del vídeo está hecho el 11 de septiembre de 2026, las dos mitades: el
reproductor que pinta la imagen y la búsqueda que encuentra el vídeo de una
canción que no lo es. Lo que queda de ese punto son tres cosas de comprobar y
decidir, no de programar, y están arriba del todo.

- **Firmar y repartir la de iOS.** Compila y corre, pero un `.ipa` no se
  instala tocándolo: iOS sólo ejecuta lo firmado con un certificado que
  reconoce. Sin cuenta de pago hay dos caminos —cable con el Apple ID gratis,
  que caduca a los 7 días, o `.ipa` sin firmar en la release para que cada
  quien lo firme con Sideloadly— y con los 99 USD al año se abren TestFlight
  (los externos pasan por revisión, que esta app no pasa) y ad-hoc con los UDID
  registrados. Falta decidir cuál y, si es el `.ipa`, añadir el job de macOS a
  `release.yml` que empaquete `Runner.app` en `Payload/`.

  Aparte de la firma, en iOS no existen: la autoactualización
  (`installer.dart` es `Platform.isAndroid`), el widget, las cuentas del
  aparato, el ecualizador, la caché de stream en disco y CarPlay —que además
  pide un *entitlement* que Apple concede a petición.

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
  Algo cambió el 11 de septiembre de 2026: al meter el vídeo, **`media_kit` ya
  está en el proyecto**, y con él libmpv registrado también en Windows y Linux
  (`generated_plugin_registrant` de los dos). Eso no hace sonar nada por sí
  solo —`just_audio` sigue sin implementación ahí— pero la mitad cara de
  `just_audio_media_kit`, que es traerse libmpv, ya está pagada.

  En Linux hay un segundo hueco: `flutter_inappwebview` tampoco tiene
  implementación, y es el navegador del inicio de sesión — o sea que ahí ni
  siquiera se puede entrar a la cuenta. `screen_brightness` tampoco está, así
  que la mesita de noche no regula el brillo.

- **La cuenta dice 216 me gusta y `LM` contesta 183.** La página dos llega sin
  token, así que no es que el recorrido se corte: son 33 que la API no lista.
  Sin diagnosticar; la sospecha es que son pistas ya no disponibles o de otro
  tipo. Mientras tanto esos 33 salen con el corazón vacío.

- **El vídeo: falta verlo en un teléfono de verdad.** Hecho el 11 de
  septiembre de 2026 (ver abajo) y funcionando de punta a punta salvo una cosa,
  que el emulador no puede contestar: **la imagen sale negra**. No es la app.
  El log lo dice — `media_kit: Emulator detected. Enforcing S/W rendering.`,
  la superficie se crea a 1280×720, y lo que falla es
  `GFXSTREAM: egl.cpp error 0x3004 (EGL_BAD_ATTRIBUTE)`, que es la capa de GPU
  emulada. Forzar `enableHardwareAcceleration: false` no cambia nada, porque
  media_kit ya baja a software él solo al detectar el emulador.
  Todo lo demás sí está comprobado ahí: el audio sale del mezclador
  (−8 a −20 dB continuos), sigue sonando con la app en segundo plano, la sesión
  de medios publica `PLAYING` con la posición corriendo y sus cuatro acciones
  propias, y el cambio canción↔vídeo conserva el segundo en los dos sentidos
  (0:21 → vídeo → 1:02 de vuelta, sin corte).
  Falta enchufar el Samsung y mirar la imagen. Si ahí también sale negra,
  entonces sí es la app.

- **Y decidir si los 13 MB valen la pena.** `media_kit` trae libmpv, y eso se
  paga en el APK. Medido el 11 de septiembre de 2026, release con
  `--split-per-abi`, antes y después del cambio: arm64-v8a **22,4 → 35,6 MB**
  (+13,2), armeabi-v7a 20,3 → 32,8 (+12,5), x86_64 23,9 → 40,5 (+16,6). Es la
  misma dependencia que desbloquearía Windows y Linux, así que el coste se
  cobra dos veces si se hace aquello; si el vídeo acaba descartándose, quitarla
  devuelve esos megas.

- **La release con el vídeo dentro no se ha instalado.** El emulador lleva la
  de depuración y la firma no deja poner una encima de la otra sin desinstalar
  —y desinstalar se lleva el llavero, o sea la sesión—. No se hizo por eso. El
  riesgo conocido es el de siempre, el encogedor de recursos contra los
  drawables que se nombran desde Dart, y este cambio no añadió ninguno;
  `android_icon_resources_test` sigue en verde. Conviene comprobarlo igual
  antes de publicar.

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

- **Una prueba del reproductor se pone roja bajo carga.** Salió al lanzar la
  0.1.9 (22 de agosto de 2026): en la corrida completa, `player_queue_test` →
  *a queue that ran out with repeat on comes back to the top* falló con
  `PathNotFoundException … history.json` y "*This test failed after it had
  already completed*"; aislada pasa tres de tres, y la corrida siguiente pasó
  entera. Diagnóstico: `_playIndex` graba en el log **sin `await`** —nadie
  guarda ese futuro—, así que la escritura puede seguir en vuelo cuando el
  `tearDown` ya borró la carpeta temporal. `removeWhenSettled` cubre el caso
  contrario —el borrado que falla porque algo escribe— pero no éste. Arreglarlo
  de verdad pide que la prueba pueda esperar a que la última escritura aterrice
  (un futuro observable en `PlayHistory`), no un `delayed` a ojo.

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

- **El flake sigue ahí, y esquiva al reportero que lo nombraría** (11 de
  septiembre de 2026). Salió dos veces en la misma sesión —una con 3 rojas y
  otra con 1— sobre un total de 348, y las dos veces las corridas siguientes
  dieron las 348 en verde, tres seguidas. Lo que se aprendió es un dato para la
  próxima: **con `--reporter expanded` no se reproduce**. Cinco intentos, cinco
  verdes. O sea que depende de la carga o del ritmo, y justo el reportero que
  imprime el nombre es el que lo hace desaparecer —lo que deja sin nombre otra
  vez las dos entradas de abajo—. Probar a la próxima con `--concurrency` alto
  y el reportero expandido a la vez, que es la combinación que falta.

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

- **El vídeo de una canción, hecho** (11 de septiembre de 2026). Las dos
  mitades del punto que se pidió el 21 de agosto, en un hilo.

  **Lo que desbloqueó todo fue dejar de preguntar por el `counterpart`.** Las
  cinco hipótesis de ese campo estaban muertas y el punto llevaba ahí desde
  agosto; la pregunta que sí tenía respuesta era otra: *¿es reproducible la
  imagen con lo que la app ya recibe?* Lo es. Medido sobre la respuesta real:
  `formats` viene vacío —no hay formato mezclado y no vuelve— pero
  `adaptiveFormats` trae 12–18 pistas de vídeo, de 144p a 1080p, **todas con
  `url` en claro y ninguna con `signatureCipher`**, la misma propiedad que hace
  servible el audio del cliente de iOS. Ninguna lleva sonido, así que enseñar
  el vídeo es reproducir dos streams sincronizados.

  **Quién los sincroniza: libmpv.** `media_kit` expone `AudioTrack.uri(url)`,
  que en nativo es el comando `audio-add <url> select` de mpv. Comprobado con
  mpv sobre URLs reales antes de escribir una línea de app: las dos pistas
  abren, mpv marca la de audio `[external]`, y `A-V: 0.000` se mantiene 25
  segundos **y también después de buscar** a 2:30, que era el caso que rompe
  estos montajes. De paso: **el `StreamProxy` no hace falta aquí**, porque mpv
  pide rangos por su cuenta. Todo eso está en `docs/streaming-findings.md`, y
  `test/video_probe.dart` repite la medida (sin sufijo `_test`: habla con
  YouTube y no entra en la suite).

  **La costura resultó pequeña.** `_transformState` ignoraba su argumento y
  leía todo de `_player`, así que bastó con que leyera de un par de getters que
  eligen motor. `just_audio` sigue siendo el motor de audio —con su
  ecualizador, su caché y sus fundidos, que libmpv no tiene— y sólo uno de los
  dos suena a la vez. El cambio conserva el segundo en los dos sentidos.

  **La segunda mitad: el vídeo de una canción que no es vídeo.** Como el dato
  no llega, se busca: `rankVideoMatches` puntúa las filas por título, artista y
  duración, con penalización para las palabras que nombran *otra*
  interpretación (cover, karaoke, remix, live…) salvo que la canción pedida las
  lleve también; y luego `findVideoCounterpart` resuelve las candidatas en ese
  orden hasta que una resulte traer formatos de vídeo de verdad. Ese último
  paso es lo que hace segura la adivinanza: una fila que parecía buena pero era
  otra art track simplemente no tiene imagen y se pasa a la siguiente. Tope de
  tres llamadas, porque corre con alguien esperando. Medido en el emulador
  sobre la canción de Daft Punk: encontró el vídeo y cambió en 3 segundos.

  El botón se ofrece en todas las pistas, no sólo en las que YouTube sirve con
  imagen, y gira mientras busca; cuando no encuentra nada lo dice, que es mejor
  que un botón que no hizo nada.

  Doce pruebas nuevas (365 en verde). Lo que falta comprobar está arriba.

- **Lo que le faltaba a Explorar, hecho** (11 de septiembre de 2026). Los tres
  huecos medidos el mismo día, cerrados en un commit.

  - **El país de las listas.** El selector trae 70 países y ninguno lleva
    `params`: todos apuntan a un `FEmusic_charts` pelado. Lo que los distingue
    es el `formItemEntityKey`, un base64 cuyo texto plano termina en el código
    de dos letras (`…country_menu_316766567CO`), y ése es justo el valor que
    quiere `formData.selectedValues`. Medido contra `US`, `ES` y `ZZ`: cada uno
    volvió con su propio nombre en el selector. El país es un ajuste
    (`chart_country`) y no un toque que se olvida, y se comprobó en el
    emulador: elegido Brasil, sobrevive a reinstalar y relanzar.

    Dos detalles del menú que no estaban a la vista: el país seleccionado es el
    único **sin** `selectedCommand` —y aparece dos veces, fijado arriba y otra
    vez en orden alfabético, de ahí que la lista se deduplique por código—, y
    los nombres llegan traducidos por el `hl` de la propia petición, así que no
    hay ninguna lista de países escrita en el repo.

  - **`FEmusic_explore`, pedido por fin.** Tres de sus cuatro estanterías
    repiten lo que las otras pestañas ya piden por su cuenta —de hecho los tres
    botones de su rejilla *son* esas tres pestañas—, así que la pestaña nueva
    se queda sólo con la cuarta: Tendencias, 20 pistas en orden, que ningún
    otro browse id lista. Se dibuja como lista numerada y no como carrusel,
    porque una clasificación se lee hacia abajo.

  - **La estantería que se caía.** Sus tarjetas son
    `musicNavigationButtonRenderer` y `parseShelves` no leía ninguna, así que
    la fila salía vacía y se descartaba como sección sin contenido. Ahora pasa
    también por `parseMoodChips`, que es el mismo renderer que la pestaña de
    ambientes ya sabía leer.

  Fixtures nuevas, recortadas de la respuesta real anónima con `gl: CO`:
  `charts_page.json` y `explore_page.json`. Cinco pruebas nuevas; 353 en verde.


- **De pódcast: marcar como reproducido y "Episodios para más tarde", hechas**
  (11 de septiembre de 2026).

  El motivo por el que estaban aparcadas se cayó solo: la app ya tiene
  superficie de pódcast desde que la búsqueda encamina un programa, y los dos
  bloqueos anotados eran de la **fixture anónima**, no de la API. Esto se vio
  volcando la respuesta del emulador, que sí tiene la cuenta: la misma página
  que sin sesión trae cinco entradas de menú inertes, con sesión trae ocho, y
  las dos que faltaban son exactamente estas.

  Ninguna de las dos es un mecanismo nuevo:

  - **"Marcar como reproducido"** es un `feedbackEndpoint` corriente, dos
    tokens en un interruptor, el mismo camino que el pin. El
    `videoPlaybackPositionFeedbackToken` que cuelga de la barra de progreso es
    un **tercer** token distinto que hace otra cosa; mandarlo habría sido
    adivinar, y por eso los dos se leen del menú.
  - **"Episodios para más tarde"** es la lista `SE` por `browse/edit_playlist`,
    que es el endpoint que el cliente ya habla. El `commandExecutorCommand` que
    lo hacía parecer otro mecanismo es sólo envoltura: debajo hay un
    `playlistEditEndpoint`. Se quita por id de vídeo
    (`ACTION_REMOVE_VIDEO_BY_VIDEO_ID`), que una playlist normal no puede hacer
    —puede tener dos veces la misma pista y ésta no—, y cada edición barre
    de paso los episodios ya oídos, que es cómo YouTube la mantiene en orden de
    escucha. Los dos `params` van como vinieron.

  **La trampa, y la encontró el aparato y no las pruebas.** Los dos
  interruptores se parecen al pin y no se leen como él: el pin **cambia de
  lado** —pone en `default` la acción que ofrece— y estos dos no. Medido
  marcando un episodio y volviendo a pedir la página: `defaultIcon` se quedó en
  `CHECK` y lo que cambió fue `isToggled`, de false a true, con el progreso
  pasando de 0 a 100 en esa fila y las otras diez sin moverse. Leído como el
  pin, la app marcaba bien y luego seguía ofreciendo "Marcar como reproducido"
  sobre algo ya reproducido. El estado es `isToggled`, igual que en el
  interruptor de la biblioteca.

  Comprobado contra la cuenta real, ida y vuelta en los dos: reproducido →
  `isToggled` true y progreso 100; no reproducido → vuelta a false y 0; añadir
  a la lista → true; quitar → false. La cuenta quedó como estaba. Fixtures
  nuevas recortadas de la respuesta con sesión: `podcast_page_signed_in.json` y
  `podcast_episode_played.json` —la misma fila antes y después, que es lo que
  demuestra que los iconos no se mueven—. Pruebas nuevas: seis en
  `innertube_parser_test` y cuatro en `row_actions_test`, éstas últimas sobre el
  cuerpo que se manda, que es el único de la app que se construye aquí en vez de
  reenviarse.


- **Las dos cosas que quedaron fuera de la búsqueda, hechas** (11 de septiembre
  de 2026).

  **La pulsación larga sobre una colección** abre el mismo menú que la fila de
  una lista en cualquier otra pantalla. Lo que faltaba era de dónde sacar las
  canciones: una fila de búsqueda trae un título, una carátula y un id y nada
  más, así que la página de detrás **se pide al abrir el menú**, no al pintar la
  fila —una pantalla de resultados habría pedido treinta páginas que nadie
  quiere ver—. El menú sale en la pulsación que lo pidió y los verbos que
  necesitan la lista se encienden un momento después, que es al revés de hacer
  esperar a alguien con el dedo encima por una hoja que a lo mejor no era la que
  quería. `collectionSongs` elige la petición igual que `openCollection` elige
  la pantalla, para que el menú y la página nunca discrepen sobre qué es una
  fila.

  El radio no espera a nada: lo trae la propia fila. Y ahí había una trampa
  medida el 11 de septiembre — **el menú de una fila trae dos
  `watchPlaylistEndpoint` y los dos empiezan por `RD`**. En un artista el
  primero es su aleatorio (`RDAO`) y sólo el segundo es su mix (`RDEM`); en un
  álbum o una lista el primero es su propio id y el segundo el `RDAMPL`. Coger
  el primer `RD` que aparece pone un aleatorio donde va el radio, así que los
  dos prefijos que YouTube le da a un radio se nombran a mano.

  Un perfil y un pódcast **no traen ninguno de los dos**, así que a esos no se
  les ofrece radio: un botón que no contesta nada es peor que no tenerlo.

  **La tarjeta de resultado principal** deja de ser una fila más y se dibuja con
  los botones que YouTube le cuelga, que son la razón de que sea una tarjeta.
  Medido contra el endpoint real: siempre son dos, y cuáles depende de qué
  encabeza —un artista trae Aleatorio (`RDAO` con los params del aleatorio) y
  Mix (`RDEM`), un álbum Reproducir y Aleatorio (**el mismo `OLAK` con params
  distintos**, que es lo único que los separa), una canción Reproducir y
  Guardar—. Ese último es un `modalEndpoint`, o sea YouTube pidiendo iniciar
  sesión y no algo que suene, y se tira: un botón que no puede hacer lo que dice
  es peor que no estar. La etiqueta llega traducida y se pinta como vino; lo que
  hace cada botón se lee de su comando, nunca de su texto.

  Comprobado en el emulador con la cuenta: "daft punk" encabeza con la tarjeta
  de Daft Punk (Artista · 79,8 M de oyentes al mes) y sus botones Shuffle y Mix,
  y la pulsación larga sobre *Discovery* abre el menú entero —Play, Shuffle,
  Start radio, Play next, Add to queue, Add to playlist, Save to library,
  Download every track, Share, Copy link— y Play arranca *One More Time*, que es
  la primera del álbum. Pruebas nuevas: cuatro en `innertube_parser_test` —la
  trampa del `RDAO` incluida— y tres en `search_radio_test`.

  Un fallo que encontraron las pruebas al escribirlas: la tarjeta leía la
  carátula como `collection?.thumbnailUrl ?? song!.thumbnailUrl`, que revienta
  en cuanto una colección llega sin carátula. Se lee de un lado o del otro, sin
  mezclar.

- **El home ya no se queda en la primera página** (10 de septiembre de 2026).
  Era lo diagnosticado: `homeFeed()` era un solo `browse('FEmusic_home')` sin
  continuación. Medido en el emulador con la cuenta, la respuesta trae **tres
  estanterías por página y veinte en total**, en siete páginas —la última de
  dos—: la app enseñaba tres de veinte y las llamaba el inicio. Ahora la
  siguiente página se pide **al llegar al pie de la lista**, no todas al abrir:
  el inicio es lo primero que se pinta al arrancar y siete peticiones seguidas
  son mucho que esperar por filas a las que nadie ha bajado todavía.

  Lo que faltaba no era fontanería: `browseContinuation` y
  `parseContinuationToken` ya existían. Lo que sí hacía falta averiguarlo es
  que **la continuación sólo contesta si se pide como quien pidió la primera
  página**: sin el `visitorData` que trajo aquella respuesta, YouTube devuelve
  1 KB con la pestaña vacía en vez de las estanterías siguientes —medido sin
  sesión el 10 de septiembre de 2026: nada sin él, tres estanterías más con
  él—. `homeFeed` lo lee de la primera respuesta y de paso ceba el que
  `visitorData()` iba a buscar por su cuenta, que era una petición de más antes
  de resolver la primera pista.

  Comprobado bajando hasta el final con la cuenta: aparecen las que el
  diagnóstico echaba en falta —De tu biblioteca, Vídeos musicales para ti,
  Canciones en tendencia para ti, Escuchas de larga duración…— y el pie deja de
  girar cuando se acaban. Una página que no llega detiene la lectura ahí y deja
  lo ya leído en pantalla, que es lo mismo que hace el resto de la app.

  **Los diez humores** de la web (Entrenamiento, Energía, Sentirse bien,
  Relax…) están también: vienen en el `chipCloudRenderer` de la propia
  respuesta —traducidos por el `hl` del aparato— y cada uno es el mismo
  `FEmusic_home` con otros `params`, así que tocar uno vuelve a pedir el inicio
  refiltrado y pagina igual. El chip de "Todo" es de la app, como en la
  búsqueda. Comprobado: Entrenamiento contesta Workout Mix 1-3, Listen again y
  Cardio, y "Todo" devuelve el feed personal.

  La fila de chips se fue a `features/shared/chip_row.dart`, que es la misma
  que ya tenía la búsqueda. Fixture nueva: `home_page.json`, recortada de la
  respuesta real. Pruebas nuevas: `test/home_feed_test.dart` —qué se pide y
  cuándo: la primera página al abrir, la siguiente sólo al llegar al pie, una
  nueva primera página al tocar un humor— y las de `parseHomeChips`.

- **Tras una búsqueda, el radio ya no llega catorce canciones tarde** (10 de
  septiembre de 2026). Era lo diagnosticado: la fila de un resultado sembraba
  la cola con las demás pistas de la búsqueda, así que el radio de la que se
  tocó sólo entraba cuando esas catorce se habían acabado. Ahora una fila de
  búsqueda arranca `startRadio`, que es lo que hace YouTube Music con el mismo
  enlace —un `videoId` sin `list=` detrás—: suena la pista y lo que YouTube
  dice que va con ella se encola.

  El interruptor vive en `SongRow` (`startsRadio`), no en la pantalla: el resto
  de las listas —una playlist, los me gusta, un álbum— sí son colas, y tocar
  una fila ahí sigue significando "desde aquí". Los resultados no lo son, sólo
  comparten las palabras que se escribieron.

  Comprobado en el emulador con la cuenta: buscando "daft punk" y tocando
  *Instant Crush*, la cola es la pista y su radio —Aaron Smith, Depeche Mode,
  Calvin Harris, Milky Chance, Tame Impala, Gorillaz, The xx— y no los
  *Derezzed* y *The Grid* que venían debajo en los resultados. Prueba nueva:
  `test/search_radio_test.dart`, que pinta la pantalla de búsqueda con un
  InnerTube de mentira y mira la cola después del toque; con el interruptor
  apagado se pone roja.

  Con "Seguir reproduciendo" apagado la fila reproduce esa pista y para, que es
  lo que dice ese ajuste: `_extendWithRadio` no pide nada si está apagado.

- **La búsqueda ya muestra todo lo que YouTube manda** (10 de septiembre de
  2026). Era lo diagnosticado: `parseSearchResults` era literalmente
  `parseSongList`, que descarta toda fila sin `videoId`, y con "daft punk" eso
  tiraba 18 de 32 filas. Ahora la búsqueda contesta una lista mezclada
  —`SearchResults` en `data/models/search.dart`— con las filas en el orden en
  que YouTube las ordenó, que es lo que hace YouTube Music: la respuesta sin
  filtro no trae cabeceras de sección, así que agrupar por tipo habría sido
  inventarse un agrupamiento que nadie manda, y el tipo ya viene escrito en el
  subtítulo de cada fila y traducido.

  Comprobado en el emulador con la cuenta: la tarjeta de resultado principal
  (Daft Punk, Artista) encabeza la lista, y debajo salen canciones, álbumes,
  listas, perfiles y pódcasts, cada uno a su pantalla. Los álbumes, los
  artistas y las listas ya tenían encaminamiento; los otros dos pedían algo:

  - **Los perfiles** empiezan por `UC` igual que un artista, así que el tipo se
    lee del `navigationEndpoint` de la propia fila y no del prefijo. Van a la
    pantalla de artista a propósito: un canal contesta con la misma forma
    —estanterías de lo que publicó— y la pantalla ya la dibuja. Lo único que
    faltaba era el encabezado, que en un canal es `musicVisualHeaderRenderer` y
    en ningún otro sitio: sin él la página abría sin nombre y sin foto.
  - **Los pódcasts** abrían vacíos por dos motivos: `_asBrowseId` le ponía el
    `VL` delante a un `MPSP…`, que pide una lista que no existe, y sus
    episodios vienen en `musicMultiRowListItemRenderer`, un renderer que no se
    leía en ningún sitio. `parseSongList` lo lee ahora también, así que un
    programa es una lista de pistas como cualquier otra en todas partes.
    Probado: un episodio suena.

  Los filtros pasan de dos escritos a mano a los **nueve que la respuesta trae
  con sus `params` resueltos** —Artistas, Álbumes, Canciones, Vídeos,
  Episodios, Listas de la comunidad, Listas destacadas, Perfiles, Pódcasts—,
  con la etiqueta ya traducida por el `hl` del aparato. Dos de los nueve llegan
  con el `=` escapado y hay que decodificarlos; un token escapado no pide nada.
  Comprobado el de Álbumes: 20 álbumes, que antes habría sido una lista vacía.
  Se fueron `filterSongs` y `filterVideos` de los dos `.arb`; `filterAll` se
  queda, que el chip de "Todo" es de la app.

  La búsqueda no pide continuación, ni con filtro ni sin él: es una página y ya.
  Fixtures nuevas: `podcast_page.json` y `channel_page.json`, recortadas de las
  respuestas reales.

- **La app corre en el iPhone** (26 de agosto de 2026). El proyecto de iOS
  estaba como lo dejó `flutter create`: nunca se había compilado. Cuatro cosas
  faltaban, y las cuatro están hechas.

  `home_widget` pide iOS 14 y el proyecto pedía 13, así que `pod install` ni
  resolvía: subido el objetivo a 14.0 en `ios/Podfile` y en los tres sitios de
  `project.pbxproj`. El `Info.plist` no declaraba `UIBackgroundModes: audio`,
  que es lo que `audio_service` necesita para que la sesión sobreviva a salir
  de pantalla; añadido y comprobado —con la app en el escritorio del simulador
  los buffers de audio siguen encolándose en el log. Xcode 26.6 no tenía
  descargada la plataforma de iOS: `xcodebuild -downloadPlatform iOS`, 8,5 GB,
  y no pidió contraseña. Y CocoaPods está instalado bajo rbenv 3.4.4 mientras
  el ruby por defecto es el 3.3.6, así que Flutter lo ve como "installed but
  broken": hasta que se arregle, los builds de iOS van con
  `RBENV_VERSION=3.4.4` delante.

  Probado en un iPhone 17 Pro con iOS 26.5, sin cuenta: el inicio carga las
  estanterías, la búsqueda contesta y **la reproducción funciona**. Eso último
  era lo dudoso, porque el `StreamProxy` es un `HttpServer` en loopback y ATS
  podía negarse: no se niega. En el log se ven las peticiones por ventanas
  contra googlevideo y los buffers entrando en la cola de audio, y el Now
  Playing de iOS recibe título, artista y carátula. El único error del log es
  un `NSURLErrorDomain -999`, que es una ventana cancelada por el propio proxy.

- **El botón de aleatorio en la biblioteca** (22 de agosto de 2026). El
  aleatorio de servidor ya existía y sólo tenía puerta en playlist, álbum y
  artista: las pestañas de la biblioteca no tenían ninguna, así que la lista
  más larga de todas sólo se podía barajar tocando una fila y dándole al
  interruptor, que ve la cola cargada y no la lista.
  - **Qué baraja YouTube y bajo qué id**, medido contra la cuenta con `next` y
    `params: wAEB8gECKAE%3D`: **`LM`** (Me gusta) da 50 por página y las 183 en
    cuatro llamadas; **`MLCT`** —el id que ofrece la propia página de
    `FEmusic_liked_videos`, que es la pestaña Canciones— pagina de 24 en 24 y
    sigue (361 a las 40 llamadas), con sorteo fresco: dos seguidos comparten 3
    de 25. Una playlist `PL…` y el `OLAK…` de un álbum también. Y contestan
    **cero**: `VLLM`, `FEmusic_liked_videos` y `MPREb…` —hay que mandar el id
    pelado, el `MLCT` y el `OLAK`—.
  - **El historial no se puede barajar en el servidor y no es un olvido**:
    `FEmusic_history` no trae ningún `watchPlaylistEndpoint`. YouTube tampoco
    lo ofrece. Ahí, como en lo del dispositivo, se baraja lo que la pantalla
    tiene.
  - El botón vive en la cabecera de `SortedSongs`, que comparten todas las
    listas de canciones, así que sale de una vez en Me gusta, Canciones,
    Dispositivo, Descargas, Historial y las tres listas automáticas. Cada una
    pasa su id —`LM`, `MLCT`, o ninguno— y `playShuffledList` pide el sorteo al
    servidor si lo hay y baraja lo que tiene si no. Sin claves ARB nuevas: el
    tooltip es el `shuffle` que ya usaba la cabecera de colección.
  - Cuatro pruebas nuevas en `library_shuffle_test.dart`; 314 en verde y
    `flutter analyze` limpio.
  - **Comprobado en el emulador contra la cuenta real**, y las dos rutas se
    distinguen por el tamaño de la cola en `dumpsys media_session`: "Me gusta"
    (183 filas) arrancó en *Hello* de Adele, que no es la fila uno; "Canciones"
    (598 filas en pantalla) arrancó en *Sigues Con Él (Remix)* y la cola quedó
    en **337** —el sorteo del servidor, que fue creciendo de 24 en 24 detrás de
    la música— en vez de las 598 que habría dado barajar lo cargado; y el
    historial (383 filas) dio cola de **383** clavadas, que es el barajado
    local. De paso: `MLCT` se queda en 337 de 598, el mismo hueco que ya está
    apuntado arriba para 183 de 216.

- **El aleatorio, entero** (22 de agosto de 2026). Se probó y se quedaba corto;
  el barajado en sí nunca estuvo mal —`List.shuffle()` es Fisher-Yates— pero
  lo que se barajaba y hasta dónde llegaba, sí. Cuatro cosas, medidas y
  arregladas.
  - **Barajaba sólo lo que había llegado.** El botón sale en cuanto hay una
    fila, y una superficie de biblioteca contesta cien por página: la cola se
    congelaba sobre la primera centena y el resto no entraba nunca. Ahí estaba
    la sensación de "siempre salen las mismas".
  - **YouTube tiene aleatorio de servidor y no lo usábamos.** Está en las
    propias grabaciones: el menú de la playlist trae
    `watchPlaylistEndpoint` con `params: wAEB8gECKAE%3D`, que va a `next`.
    Medido contra la cuenta el 22 de agosto: devuelve **50 por página** con
    continuación, dos llamadas seguidas comparten sólo **22 de 50** —así que
    el sorteo es nuevo cada vez— y **baraja la lista entera**: de las veinte
    primeras que dio para "Cool" (124 pistas), **ocho no estaban** en las 91
    que había listado la primera página del `browse`. Paginando "Me gusta"
    (`LM`) salen las **183** en cuatro peticiones. `VLLM` contesta 0: hay que
    mandar el id pelado, que es lo que ya hacía `_bareId`.
    Ahora `InnertubeClient.shuffledCollection` lo pide y
    `PlayerService.shuffleCollection` lo pone a sonar; lo que la pantalla
    tenía queda como el orden al que se vuelve al apagar el aleatorio, y el
    resto del sorteo entra detrás de la música (`_growQueue`). Si la red o el
    id no dan, se baraja lo que hay, que es lo de antes. Un álbum llega
    entero y un artista no es una lista, así que ésos siguen locales.
  - **Con repetir-todo, la segunda vuelta era la primera.** `_advance` volvía
    al índice 0 sin rebarajar: una sola permutación en bucle. Ahora cada
    vuelta es un sorteo nuevo.
  - **El interruptor a mitad de cola dejaba media cola fuera.** `_shuffleAround`
    soltaba la pista que sonaba en un sitio al azar, y todo lo que caía por
    encima quedaba como parte ya pasada del recorrido: encender el aleatorio
    en la segunda de cien tocaba, de media, cincuenta. Ahora la que suena se
    queda donde está y se baraja lo que falta. Esto **revierte a propósito**
    la mitad de `b6ce096`: aquella decisión estaba atada a que el botón de
    barajar una playlist pasaba por aquí, y ya no —pasa por `setQueue` sin
    índice, que es lo que impide que abra siempre por la pista uno.
  - **El radio que continúa la cola se pegaba sin barajar.** El orden en que
    YouTube lo manda es su ranking; con el aleatorio encendido, ahora se
    baraja también.
  - **Y un defecto que salió al comprobarlo en el emulador**: la cola de 115
    pasaba a **180** al apagar el aleatorio. `_unshuffled` y `_songs` no
    guardan lo mismo mientras hay un sorteo —el orden es lo que listó la
    pantalla, la cola es lo que sacó el sorteo, que llega más lejos—, así que
    una pista nueva *para la cola* no lo era para el orden y se metía dos
    veces. `_rememberOrder` la mete una sola vez. Con la corrección: 115
    únicas antes y después, la música sin cortarse (0:25 → 0:30), y al apagar
    salen las 91 que la pantalla tenía **en su orden** y detrás las 24 que no
    había listado.
  - Comprobado en el emulador contra la cuenta real: tres pulsaciones de
    "Aleatorio" en "Cool" dieron tres arranques distintos, ninguno la pista
    uno —uno de ellos ni siquiera estaba en la primera página—, de 7 a 12
    pistas de cada cola venían de más allá de esa página, y el solapamiento
    entre dos colas fue de 24 de 50. La cola creció sola a 115.
    Trece pruebas nuevas en `player_queue_test.dart` y tres en
    `innertube_collection_test.dart`; 310 en verde y `flutter analyze` limpio.
  - **Lo que quedó abierto de esto:** la puerta que faltaba en la biblioteca,
    hecha justo después —la entrada de abajo—. Sigue abierto que de 124 pistas
    de "Cool" la cola se queda en 115, como "Me gusta" se queda en 183 de 216:
    mismo hueco, sin diagnosticar.

- **La cola sí se expande al acabarse, y no hay ningún servicio que estemos
  desaprovechando** (22 de agosto de 2026). Medido, porque la sospecha era que
  faltaba algo: el radio de una pista (`RDAMVM…`) devuelve 50 y **sin
  continuación**, también pidiéndolo con `enablePersistentPlaylistPanel` y
  `tunerSettingValue: AUTOMIX_SETTING_NORMAL`, que es lo que manda el cliente
  oficial. O sea que la forma de seguir es re-sembrar un radio desde la última
  pista, que es justo lo que `_extendWithRadio` ya hacía. "Seguir sonando" está
  encendida por defecto y no hay clave en las preferencias del emulador que
  diga lo contrario. Ahora hay tres pruebas que lo fijan —una cola que se acaba
  pide radio, una que se vuelve a acabar pide otro, y con la opción apagada no
  pide ninguno—, así que si vuelve a pararse será algo que estas pruebas no
  cubren y hay dónde empezar a mirar.

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

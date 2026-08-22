# Estado del trabajo

Este archivo es la memoria entre hilos. Cada feature nueva se trabaja en un hilo
nuevo: se lee esto primero y se actualiza al terminar cada paso, no al final.

## Pendiente

- **Llegar a Documentos, Escritorio o un disco externo en macOS.** Lo que
  quedó fuera al hacer que la pestaña leyera del dispositivo (21 de agosto de
  2026). El sandbox reparte el disco por carpeta y solo hay entitlement para
  dos: `assets.music.read-only` y `files.downloads.read-only`. Para el resto no
  existe ninguno — hace falta el selector de carpetas y guardar un
  *security-scoped bookmark* para que el permiso sobreviva al reinicio, que pide
  además `files.bookmarks.app-scope` y un paquete nuevo: no hay selector de
  archivos en `pubspec.yaml`. Es un feature aparte, no un ajuste de este.

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

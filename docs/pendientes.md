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
  **Los builds pesados se quedaron fuera por dinero, y ese motivo caducó el 19
  de agosto de 2026**, cuando el repo se abrió: en repos públicos los runners
  estándar son gratis, macOS incluido. Lo que falta ahora no es presupuesto sino
  escribir el job. El que más vale es un `build apk --release` que compruebe que
  el shrinker no borró los drawables pinnados: `android_icon_resources_test`
  verifica que `keep.xml` y los nombres en Dart van en paralelo, **no** que el
  shrinker los respetara, y ese fallo solo aparece en release, donde ningún
  emulador lo enseña.

- **Job de build en CI.** Dos jobs nuevos junto al de analyze/test: `android`
  corre `build apk --release` y `macos` corre `build macos --release`. Van **en
  paralelo** con las comprobaciones, no detrás: un `analyze` en rojo suele ser
  un lint, que no dice nada sobre si la cosa compila, y esperar tres minutos a
  saberlo cuesta más de lo que ahorra.
  El que vale es el de Android. La comprobación de drawables que solo existía
  dentro de `tool/release.sh` se fue a `tool/check_drawables.sh` y la llaman los
  dos, así que una rama y una release se miran con el mismo código en vez de con
  dos copias que se separan. Busca los nombres dentro del APK con `aapt2`, no en
  `keep.xml`: el test unitario ya vigila que `keep.xml` y Dart vayan en paralelo,
  lo que no puede saber es si el shrinker le hizo caso, y ese fallo solo existe
  en release.
  En CI no hay `key.properties`, así que el APK sale firmado con la llave de
  debug. Da igual: lo que se comprueba aquí es el shrinker, no la firma, y nada
  de lo que construye este job se instala nunca. La firma es cosa de
  `release.sh`, donde está la llave de verdad.
  El de macOS firma ad-hoc — el proyecto de Xcode pide identidad `-`, así que no
  necesita certificado y no produce nada distribuible. Está porque macOS es la
  plataforma que nadie corre a mano: los entitlements, los pods y el catálogo de
  iconos se rompen en silencio hasta que alguien los construye.
  Java pineado a Temurin 17 con `setup-java@v5`, que es contra lo que compila
  `build.gradle.kts`; la imagen del runner trae varios JDK y elige el suyo. La
  v4 apunta a Node 20, que los runners ya no llevan, y dejaba dos anotaciones de
  deprecación en cada build.
  **Sin pinear las acciones por SHA**: este workflow no lee ningún secret. Esa
  condición es del de firma, y ahí sí se cumple.
  Verificado en local antes de subir — los doce drawables vivos en un
  `build apk --release` de verdad, el camino de fallo probado metiendo un nombre
  que no existe, y `tunebox.app` construido — y después en el runner: los tres
  jobs en verde y el mismo "all 12 pinned drawables survived". Android tarda
  unos 7 min 30 s y macOS unos 4 min 15 s, en paralelo con el minuto y medio de
  analyze/test.

- **Firmar y publicar desde CI** (`.github/workflows/release.yml`). El portátil
  dejó de firmar releases. `tool/release.sh` se queda con lo que tiene que ser
  cierto **antes** del tag — árbol limpio, rama `main`, versión con número de
  compilación, tag libre, release no publicada, notas escritas en
  `docs/releases/vX.Y.Z.md`, `analyze` y `test` — y termina empujando el tag.
  Eso despierta al workflow, que construye, firma, comprueba y publica.
  El corte está en el tag porque un tag empujado es el único paso de una
  release que no se retira limpiamente; todo lo barato de comprobar se hace
  antes, y lo que necesita la llave, después.
  Las notas se buscan por tag en vez de pasarse como ruta: el workflow no
  recibe argumentos, así que una ruta equivocada solo se descubriría con el tag
  ya subido. Lo comprueban los dos: `release.sh` antes de empujar el tag, y el
  workflow en su segundo paso, antes de los diez minutos de build.
  Las tres condiciones que hacían falta, cumplidas: `environment: release` en el
  job, que es lo que activa la aprobación y lo único que da acceso a la llave;
  las tres acciones de terceros **pineadas por SHA**, no por tag — un tag lo
  mueve su dueño, y ese es el camino realista por el que se fuga una llave que
  no se puede rotar; y disparo solo por tag `v*`, `permissions: contents: write`
  y nada más, y `if: github.repository == 'duvanherfi/tunebox'`, que apaga el
  workflow entero en un fork.
  La comprobación de firma salió de `release.sh` a `tool/check_signature.sh`,
  por el mismo motivo que en su día salió `check_drawables.sh`: que un build
  local y uno publicado se miren con el mismo código. Los dos scripts los llama
  ahora el workflow.
  `gh release create` es el **último** paso, así que un fallo en cualquier otro
  deja el tag sin release, que es el estado del que un tag todavía se borra. La
  llave se borra del disco en un paso con `if: always()`, antes de publicar.
  De paso, `ci.yml` disparaba con `on: push:` sin filtro, que incluye los tags:
  publicar habría corrido los tres jobs por segunda vez sobre un commit que ya
  pasó por ellos al entrar en `main`, en paralelo con el build de la release.
  Ahora filtra `branches: ['**']`.
  Verificado en local hasta donde se puede sin publicar: `check_signature.sh`
  por los dos caminos contra un `build apk --release` de verdad (acepta el APK
  de release, rechaza el de debug), y el paso que reconstruye la llave en CI
  simulado con el keystore real — los bytes salen idénticos tras el
  base64 round-trip y la huella SHA-256 coincide. **Ejecutado de verdad el 19
  de agosto de 2026 con la v0.1.5**: aprobación del environment, build, firma,
  las dos comprobaciones y `gh release create`, todo en verde a la primera, con
  `tunebox-0.1.5+6.apk` publicado.

- **La release lleva también macOS**, como imagen de disco. El build de macOS ya
  corría en cada push para probar que compila, pero no salía nada de él.
  `tool/package_dmg.sh` envuelve `tunebox.app` con el enlace a `/Applications`
  —que es todo el procedimiento de instalación— y **lee la imagen de vuelta** en
  vez de fiarse de haberla escrito: la monta, comprueba que el bundle de dentro
  verifica su propio sello, que trae las dos arquitecturas y que la versión
  coincide con el nombre. Lo de las arquitecturas no es teórico: el runner es
  arm64 y un build solo para el anfitrión se instala en un Mac Intel y se niega
  a abrir allí, que es justo lo que no puede ver quien lo compiló.
  Eso obligó a partir el único job en cuatro. Los dos builds quieren runners
  distintos, así que publicar se fue a un job propio que espera a los dos — y
  así se conserva gratis la propiedad que tenía la forma anterior: que
  `gh release create` es lo último y un fallo más arriba deja el tag sin
  release. El job de macOS **no toma environment ni secrets**: la firma es
  ad-hoc, así que no tiene nada que filtrar ni nada que esperar, y construye
  mientras el APK sigue esperando su aprobación. Y el tag y el pubspec ahora
  tienen que coincidir **antes** de que empiece ningún build, en vez de después
  de diez minutos de uno.
  **La firma es ad-hoc, no Developer ID, y la imagen no está notarizada.** Una
  copia que llega por un navegador trae el atributo de cuarentena y Gatekeeper
  la para hasta que el lector la autoriza a mano; en macOS 26 ya no vale el
  ctrl-clic, hay que ir a Ajustes › Privacidad y seguridad. Notarizar es lo
  único que quita ese paso y pide el certificado de pago. Las notas de la
  versión que lo estrene tienen que decirlo.
  **Publicada en la v0.1.6**, junto a un tap de Homebrew
  (`duvanherfi/homebrew-tunebox`) que **tira** de las releases en vez de recibir
  un empujón desde aquí: así publicar no necesita permiso de escritura sobre el
  otro repo y este no gana ningún secret — que es la regla que protege la llave
  de firma. El cask se genera entero desde `tool/render_cask.sh`, que vive allí.
  Verificado en local: `.dmg` de 24 MB construido, montado, la app de dentro
  universal (`x86_64 arm64`) y con el sello bueno, y el camino de fallo probado
  metiendo un archivo dentro del bundle — lo rechaza. Y por fin **instalada y
  reproduciendo**: hasta ahora macOS solo constaba como que compila, que no dice
  nada sobre el proxy ni la caché; instalada desde el `.dmg` a `/Applications`,
  suena. El job de CI se estrenó con la v0.1.6, en verde.

- **Actualizaciones desde la propia app** (pasos 5-8 del diseño). El updater
  entero, menos publicar la release que lo estrena. `lib/data/updates.dart`
  pregunta a la API pública de GitHub y **nunca lanza**: un túnel, un rate
  limit, una release sin APK y un cuerpo que no es JSON son todos "no hay
  novedad", y una bandera `failed` distingue el silencio que es respuesta del
  que es fallo — la comprobación automática lo ignora, la hoja abierta a mano
  lo dice. La comparación es de `versionCode`, que es lo que Android aplica al
  instalar, y viaja en el nombre del asset (`tunebox-0.1.4+5.apk`) porque una
  release de GitHub no tiene dónde ponerlo; si el nombre no se deja leer se cae
  al tag como semver. Las releases publicadas hasta ahora se llaman
  `tunebox-0.1.3.apk`, sin build, así que la 0.1.4 es la primera que estrena el
  nombre nuevo.
  **El control que hace seguro descargar de un sitio público es la firma**, y
  vive en `Installer.kt`, donde están los certificados: un APK cuyo firmante no
  es el nuestro se rechaza en seco, no se instala "avisando". Desde Android 9 se
  usa `hasSigningCertificate`, que entiende una llave rotada; antes hay que
  comparar los certificados a pelo. También se comprueba el `packageName`: un
  APK de otro paquete se instalaría **al lado** de la app, que es justo cómo
  entra un imitador. El `FileProvider` tiene autoridad propia
  (`${applicationId}.updates`) en vez de reusar la de share_plus, para que el
  instalador vea el directorio de descargas y nada más.
  El aviso automático **nace encendido**, al revés que la mesita de noche: allí
  lo automático te secuestra la pantalla, aquí es una hoja que se descarta.
  Verificado en el emulador contra la API real: silencio al arrancar (0.1.3+4
  instalado, v0.1.3 publicada) y "You are on the latest version" al pulsar
  Ajustes › System › Buscar ahora, y el **ciclo entero** con la v0.1.4 ya
  publicada y un build con el número bajado a `0.1.3+4`: aviso automático,
  permiso de fuentes desconocidas, descarga con progreso, comprobación de firma,
  instalador del sistema y la app en `versionCode=5`. 27 tests nuevos entre
  `updates_test.dart` y `update_sheet_test.dart`.
  De ahí salió `plainNotes`: el cuerpo de una release es Markdown, y sin nadie
  que lo pinte el lector se come los asteriscos y los acentos graves en mitad de
  la frase, además de los saltos de línea que el autor puso a mano y la hoja
  vuelve a romper donde es más estrecha. Se quitan las marcas y se rejuntan los
  párrafos en vez de meter un renderizador entero por un párrafo; lo que
  significa algo — un título, una lista — sobrevive.

- **`tool/release.sh`.** Construye, firma, etiqueta y publica. Comprueba las dos
  cosas que producen una release inservible sin decirlo: que el APK **no** cayó
  en la llave de debug (compara el SHA-256 de `apksigner` con el del keystore) y
  que el shrinker no borró ningún drawable que Dart alcanza por nombre (los
  busca dentro del APK con `aapt2`, no en `keep.xml` — el test unitario ya
  vigila que `keep.xml` y Dart vayan en paralelo, lo que no puede saber es si el
  shrinker le hizo caso). Ambas comprobaciones ejecutadas contra un
  `build apk --release` de verdad: firma correcta y los doce drawables vivos.

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
- **Repositorio abierto y licenciado** (19 de agosto de 2026). El updater estaba
  parado porque los assets de una release privada piden token y un token dentro
  del APK se extrae en dos minutos — y ese token da lectura al código que lo
  privado protegía. Abrir el repo quita el secreto en vez de esconderlo, que es
  lo que hacen NewPipe, InnerTune y OuterTune. Antes se barrieron los 91 commits,
  no solo el árbol: nunca se commiteó `key.properties` ni un `.jks`, no hay
  cookies ni claves reales — los aciertos del grep son código que las maneja y
  fixtures (`secret123`), las de Last.fm las pone el usuario en runtime, y las
  dos fixtures de 400 KB se grabaron sin sesión (sin `datasyncId` ni
  `loggedIn:true`). Cero issues y cero PRs que revisar. **GPL-3.0**, copyleft
  fuerte, para que un fork no se pueda cerrar. La llave de firma no se movió:
  sigue en `android/key.properties`, fuera de git.
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
> **La v0.1.5 está publicada**, y es la primera que salió de CI en vez del
> portátil: `tunebox-0.1.5+6.apk`, firmada con la llave del environment.

## Pendiente

- **Notarizar es lo único que queda por decidir en macOS.** Todo lo demás está
  hecho: la v0.1.6 publicó la primera imagen de disco, y el tap
  `duvanherfi/homebrew-tunebox` la sirve y se mantiene solo. Lo que no se
  resuelve sin pagar es que macOS pide autorización a mano en cada instalación
  y en cada actualización. Son 99 USD/año, y a cambio desaparece el paso, el
  `.dmg` deja de necesitar explicación en las notas y brew deja de re-marcar
  cada versión. Mientras tanto está documentado en los dos sitios donde alguien
  se lo va a encontrar.

## Suelto, sin diagnosticar

Cosas que funcionan a medias y conviene mirar antes de dar por cerrada una
versión.

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
- **Las carátulas no cargan en el navegador del emulador Automotive.** Salen
  como el marcador azul de siempre, y es cosa del emulador: el 18 de agosto de
  2026 se probó la proyección con el DHU sobre un teléfono real y un APK de
  release, y los seis estantes, las carátulas, los cuatro botones propios del
  reproductor y la reproducción desde una lista salieron bien. De ahí salió el
  arreglo de `playFromMediaId`, que se queda sin el estante cuando Android mata
  la app y el coche conserva el árbol.
- **Los PNG heredados de Android no se han visto en un lanzador.** Sólo los lee
  API 25 y anterior; el emulador a mano es API 36 y sirve el adaptive icon en su
  lugar. Están comprobados como archivo, no como icono en una pantalla.
- **El icono de macOS en Tahoe: mirado, y se ve bien.** El aviso anterior decía
  que macOS 26 mete el icono del estilo antiguo dentro de su propio squircle y
  sobre una placa, así que el cuadrado de 824 se hundiría una segunda vez y la
  marca saldría pequeña. Con la app instalada desde el `.dmg` en macOS 26.6, el
  19 de agosto de 2026, se ve normal en el Dock. Queda como nota, no como
  defecto: darle el arte a sangre lo rompería en macOS 15 y anteriores, donde
  nadie lo recorta y cae en el Dock como un cuadrado duro, y con el destino en
  10.15 se queda en la rejilla clásica de todos modos. La salida buena, si algún
  día se ve mal de verdad, es un `.icon` de Icon Composer, que Tahoe lee nativo.
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
- **El aviso de Play Protect no sale en el emulador**, que no lleva Google Play
  Services. Al instalar un APK de fuera, un teléfono con Play muestra un aviso
  propio antes del instalador; dónde aparece y qué dice es cosa suya, no
  nuestra, pero conviene verlo una vez para que no sorprenda.
- **El brillo por aplicación no se puede verificar en el emulador.** La llamada
  se hace y no falla, pero un `screencap` no captura la retroiluminación, así
  que el 20 % está probado como código y no como luz. Falta mirarlo en un
  teléfono.
- En el reproductor completo, con la cola terminada, la etiqueta izquierda marcó
  **1:48** y la derecha **0:00** con el cursor al principio. No se tocó esa
  pantalla; puede ser transitorio al expandir o un fallo previo de cómo se
  pintan posición y restante al acabar.

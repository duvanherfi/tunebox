# Estado del trabajo

Este archivo es la memoria entre hilos. Cada feature nueva se trabaja en un hilo
nuevo: se lee esto primero y se actualiza al terminar cada paso, no al final.

## Pendiente

- **La paginación nueva sólo la usa el "me gusta".** `browseContinuation` y
  `parseContinuationToken` entraron con la sincronización de los me gusta, pero
  las playlists, los álbumes y el historial siguen leyendo la primera página y
  nada más: una lista de 500 pistas se abre con 100. Ninguna pantalla lo dice,
  así que parece que la lista es corta. Falta decidir dónde se pagina al abrir y
  dónde al llegar al final del scroll.

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

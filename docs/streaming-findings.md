# Cómo entrega YouTube el audio: lo medido

Nada de esto está documentado por Google. Todo lo de abajo son mediciones
reales contra la API en vivo, no suposiciones. Se escribe aquí para que la
próxima sesión no vuelva a deducirlo desde cero.

## El muro

Una pista se reproduce durante su primer megabyte aproximado y después todo se
rechaza. Reproducido en dos redes distintas, en emulador y en un teléfono real,
con sesión y sin ella.

```
sin cabecera Range              -> 403
Range: bytes=0-                 -> 403
Range: bytes=0-(último byte)    -> 403
Range: bytes=0-1048575          -> 206   ✅
Range: bytes=1048576-2097151    -> 403   ← el muro
```

Pedir el fichero entero se rechaza **da igual cómo se exprese**. Solo se sirven
ventanas acotadas, y en la práctica solo la primera.

## Lo que NO lo resuelve

Comprobado y descartado, cada uno con su medición:

- **Trocear la descarga.** Es necesario pero no suficiente: el segundo bloque
  se rechaza igual.
- **Re-resolver la URL al fallar.** Cinco intentos con URLs recién obtenidas,
  403 en todos.
- **Rango como parámetro de URL en vez de cabecera.** Mismo resultado.
- **Iniciar sesión.** Con cookies válidas de una cuenta real, `ANDROID_MUSIC` y
  `ANDROID_VR` siguen respondiendo `LOGIN_REQUIRED: "confirma que no eres un
  bot"`. La comprobación pregunta *qué* hace la petición, no *quién*.
- **Instancias públicas de Piped e Invidious.** Las cinco probadas devolvieron
  403, 401 o timeout. Están bloqueadas ellas mismas.
- **Flujo OAuth de código de dispositivo.** Autentica de verdad, pero su token
  es rechazado por los endpoints de música y la API oficial está deshabilitada
  en el proyecto de Google al que pertenecen esas credenciales.

## Lo que sí funciona

**Proof of Origin Token.** Implementado y verificado en dispositivo: se acuña
un token de 168 caracteres ejecutando el BotGuard de Google en un WebView
oculto. Ver `lib/core/auth/po_token.dart`.

Dos correcciones que costaron encontrar:

- El token de integridad llega en el **índice 3** del array de respuesta, no en
  el 0. La posición ha cambiado entre revisiones, así que conviene buscar la
  primera cadena larga en vez de fijar un índice.
- El paso de acuñado **no se puede reimplementar a mano**. Depende de la
  convención de llamada interna de una VM ofuscada cuyo orden de argumentos
  cambia entre versiones; adivinarlo devuelve un array de salida vacío siempre.
  Se delega en `bgutils`.

**`signatureTimestamp`: la pieza que desbloquea el cliente web.** Este fue el
hallazgo grande y no es evidente:

```
WEB_REMIX  sin signatureTimestamp  -> UNPLAYABLE, "el vídeo no está disponible"
WEB_REMIX  con signatureTimestamp  -> OK, 4 pistas de audio (cifradas)
```

El valor se extrae del bundle del reproductor
(`https://www.youtube.com/s/player/<id>/player_ias.vflset/en_US/base.js`,
buscando `signatureTimestamp`). Sin él, el cliente web responde con un error
genérico que parece un problema de disponibilidad y no lo es.

El cliente `IOS` no sirve para esto: devuelve URLs listas pero **no acepta
PoToken**, porque los clientes móviles usan otra atestación. Presentar un token
web a una petición iOS empareja dos identidades distintas y el servidor lo
ignora.

## El cliente web tampoco entrega el audio

Con todo lo anterior resuelto en una sola ejecución fresca — identidad,
atestación de 168 caracteres, `signatureTimestamp` correcto, `estado: OK`,
4 pistas, firma descifrada sin errores — el CDN responde:

```
bloque1  403      ← ni siquiera el primero, que el cliente iOS sí sirve
bloque2  403
bloque3  403
bloque4  403
```

Y la prueba que lo zanja: dejando que **`youtubei.js` haga el trabajo completo**
(sesión, atestación, descifrado y descarga), falla igual con los tres clientes
probados:

```
YTMUSIC  -> respuesta no 2xx
WEB      -> sin URL válida que descifrar
TV       -> sin URL válida que descifrar
```

Es decir: la implementación de referencia que mantiene la comunidad, con un
token válido y un evaluador de JavaScript disponible, **tampoco puede leer el
audio**. El muro no está en este código.

Estado real de la entrega de audio, resumido:

| Cliente | Petición | Descarga |
|---|---|---|
| IOS | OK, URLs listas | ~1 MiB y después 403 |
| WEB / WEB_REMIX | OK con `signatureTimestamp`, cifradas | 403 desde el primer byte |

## La forma exacta del muro

Medido al final, y es lo que explica todo lo anterior. Descargando la misma
pista con distintos tamaños de bloque, cada prueba con URL nueva:

| Bloque | Muere en | Acumulado |
|---|---|---|
| 64 KiB | bloque 16 | 983.040 bytes (23%) |
| 128 KiB | bloque 8 | 917.504 bytes (22%) |
| 256 KiB | bloque 4 | 786.432 bytes (18%) |

Siempre alrededor de **~1 MB acumulado**, sea cual sea el tamaño del bloque. No
es un límite por petición: es una **cuota de bytes**.

Y no se reinicia pidiendo una URL nueva. Al agotarla, resolver desde cero y
reanudar en el mismo desplazamiento falla igual:

```
URL #2 tras 917.504 bytes -> rechazada
URL #3 tras 917.504 bytes -> rechazada
URL #4 tras 917.504 bytes -> rechazada
```

La cuota va atada a la **identidad del cliente**, no a la URL. Un cliente que no
puede atestiguar lo que es recibe aproximadamente un megabyte de cualquier
pista, y ahí se acaba. Encaja con todo lo demás: el cliente iOS entrega ese
megabyte y nada más; el web no entrega ni eso, porque su atestación tampoco le
basta al CDN.

Conclusión: **no hay un fallo que arreglar en este código**. Reintentar,
trocear más fino o refrescar URLs no cambia nada. No volver a intentarlo sin
una idea nueva de verdad.

## Por qué existe la cuota: la entrega ya no va por ahí

Descartadas también las señales que envía un cliente real. Con `cpn` (el nonce
de reproducción) y con los pings de seguimiento —aceptados, devuelven 204— la
descarga muere **en el mismo byte exacto**:

```
sin nada         917.504 / 4.155.462  (403 en bloque 8)
con cpn          917.504 / 4.155.462  (403 en bloque 8)
con cpn + pings  917.504 / 4.155.462  (403 en bloque 8)
```

Idéntico al byte. La cuota no se contabiliza por sesión ni por reproducción.

La explicación aparece al mirar qué anuncia el propio servidor:

```
IOS   status=OK   streamingData: serverAbrStreamingUrl, adaptiveFormats
```

**`serverAbrStreamingUrl` es SABR**, la entrega por POST con protobuf que usan
hoy las apps oficiales. El `videoplayback` por GET con rangos que usa todo este
código es el **camino heredado**, y está limitado a ~1 MB justamente porque ya
no es por donde YouTube sirve música.

Eso reencuadra el problema entero: no estábamos chocando contra una defensa
antibot que sortear, sino usando una puerta en desuso que dejan entreabierta.

### Qué costaría usar SABR

Es un protocolo binario sin documentar: hay que construir los cuerpos protobuf
de petición, interpretar el enmarcado UMP de la respuesta, y mantenerlo cuando
cambie. Las implementaciones de referencia llevan mucho tiempo con soporte
parcial, y para Dart no existe ninguna madura que se pueda adoptar.

No es una tarde. Es un proyecto en sí mismo, y del tipo que exige mantenimiento
continuo — la misma categoría en la que esta sesión aprendió dos veces que hay
que usar una implementación mantenida en vez de escribir la propia.

## Lo que falta

Descifrar la firma de los formatos del cliente web. Las rutinas viven dentro
del bundle ofuscado y se renombran en cada build:

- El parámetro de la rutina de firma era `a` en builds antiguos y es `y` en el
  actual. Cualquier patrón que fije el nombre se rompe.
- En el build `b0d2d49a` la rutina se llama `WJ`. El objeto auxiliar que usa no
  se localizó con el patrón probado.

**Conclusión de método**, aprendida dos veces en esta sesión: los pasos que son
formatos de petición/respuesta se pueden deducir midiendo. Los que dependen de
código ofuscado que Google reconstruye constantemente, no — ahí hay que usar
una implementación mantenida (`bgutils` para la atestación, y algo equivalente
para el descifrado) en vez de extraer con expresiones regulares.

Un evaluador de JavaScript es imprescindible para descifrar. En la app ya
existe: el WebView del PoToken.

## Historial: lo que se reporta y lo que YouTube hace con ello

La respuesta de `player` trae `playbackTracking.videostatsPlaybackUrl` y
`videostatsWatchtimeUrl`. Es el mecanismo con el que los clientes oficiales
cuentan una escucha, así que se implementó tal cual:

- El `cpn` (16 caracteres del alfabeto `A-Za-z0-9-_`) se genera al resolver el
  stream, viaja en la URL de `videoplayback` y en los dos pings. Reproducir
  sigue funcionando con el parámetro añadido.
- Ping de `playback` al empezar; ping de `watchtime` con `st=0&et=<segundos>`
  a los 30 s, cancelado si se cambia de canción antes.
- Sólo cookies en la cabecera: `s.youtube.com` es una baliza, no una API, y las
  cabeceras firmadas del resto del cliente apuntan a otro origen.

**Medición, y la corrección que costó dos vueltas.** Ambos pings responden
**HTTP 204** — que es lo que responde una baliza pase lo que pase — y durante
mucho tiempo pareció que no servían de nada: ninguna reproducción aparecía en
`FEmusic_history`, con cuatro pistas distintas, reinicios y esperas largas.

Lo que en realidad pasaba es que **sí se contaban, pero en el sitio equivocado**:
las escuchas aparecían en el historial de YouTube (`youtube.com/feed/history`) y
no en el de YouTube Music. La baliza no se ignora; se archiva contra la
superficie que la baliza dice ser, y este cliente no decía ninguna.

### Cómo se consigue que la escucha entre en YouTube Music

Medido el 18 de agosto de 2026 contra una cuenta real, con pistas nunca oídas
antes para que la posición en `FEmusic_history` fuera prueba y no coincidencia.
Hacen falta **las dos cosas a la vez**:

1. **La baliza la tiene que acuñar `WEB_REMIX`.** Se le pide `player` al mismo
   cliente que ya manda los "me gusta", sólo para quedarse con sus
   `videostatsPlaybackUrl` y `videostatsWatchtimeUrl`. El audio sigue viniendo
   de quien quiera servirlo. Ojo: **basta la cookie de sesión para que responda
   `OK` y traiga baliza** — sin ella contesta `UNPLAYABLE`, igual que sin
   `signatureTimestamp` más arriba. Una prueba anónima con `curl` dice, por eso,
   que este camino no existe. Existe.
2. **El ping tiene que declarar la superficie**, añadiendo `c=WEB_REMIX` y
   `cver=<versión>` a la query, con el user-agent a juego.

La tabla que lo cierra, una pista nueva por fila:

| Baliza acuñada por | `c`/`cver` en el ping | ¿Entra en `FEmusic_history`? |
| --- | --- | --- |
| `WEB_REMIX` | no | no |
| el cliente que sirvió el audio | sí | no |
| `WEB_REMIX` | sí | **sí, en la posición 0** |

Con las dos, la pista aparece la primera del historial de la cuenta en menos de
tres minutos, contados desde el ping de `watchtime`.

Dos cosas que se descartaron por el camino y conviene no volver a intentar:

- `ANDROID_MUSIC` e `IOS_MUSIC` contestan `LOGIN_REQUIRED` **incluso con la
  sesión iniciada**, así que la preferencia por clientes MUSIC en `_clientOrder`
  nunca llega a aplicarse: siempre acaba sirviendo VISIONOS.
- `WEB_REMIX` sí trae formatos de audio (itag 140 en m4a, 249/250/251 en opus),
  pero **todos con `signatureCipher` y ninguno con `url`**. Reproducir desde ahí
  sigue necesitando el descifrado de firma; para el historial, por suerte, ya no
  hace falta.

El historial que la app muestra sigue siendo **propio**, guardado en el
dispositivo (`PlayHistory`) y mezclado por encima del de la cuenta: funciona sin
sesión y no depende de que nada de lo anterior siga siendo cierto.

### Trampa de `just_audio` que ocultó todo esto

`AudioPlayer.play()` devuelve un futuro que se completa cuando la reproducción
**termina**, no cuando empieza. Con `await _player.play()` todo lo que venía
después — los pings, el registro local — se ejecutaba al acabar la canción, y
`setQueue` no devolvía el control a la interfaz hasta entonces. Sin instrumentar
no se ve: la música suena igual.

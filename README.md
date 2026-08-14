# Tunebox

Reproductor de música en Flutter que lee el catálogo de YouTube Music a través
de InnerTube, la API interna que usa la propia web de YouTube.

**No usa microG ni Google Play Services.** microG existe para que las apps
parcheadas (ReVanced, Vanced) puedan iniciar sesión pese a no estar firmadas por
Google; esa capa emulada es justamente la que cuesta rendimiento. Aquí se habla
directo con la API por HTTP y el audio va a ExoPlayer nativo, sin WebView.

## Estado

| Fase | Alcance | Estado |
|---|---|---|
| 1 | Buscar, reproducir, cola, segundo plano con notificación | Hecho |
| 2 | Login con cuenta, biblioteca / likes / playlists / historial | Hecho (lectura) |
| 3 | Escritura: like, crear playlist, añadir y quitar canciones | Pendiente |
| 4 | Ping de historial de reproducción, feed de inicio personalizado | Pendiente |

## Cuando deje de sonar: lee esto primero

El valor más frágil de todo el repo es `version` en los perfiles de cliente de
`lib/core/innertube/innertube_client.dart`.

YouTube retira builds antiguos de sus apps. Cuando lo hace, el endpoint `player`
empieza a responder HTTP 400 o `LOGIN_REQUIRED` para todas las peticiones. **No
es un bloqueo ni un problema de cookies**: simplemente el número quedó viejo.
Durante el desarrollo de este proyecto, la versión `19.29.1` del cliente iOS ya
daba 400 mientras `20.10.4` funcionaba perfectamente.

Para arreglarlo, sube `_ios.version` a una versión actual de la app de YouTube
para iOS y ajusta el `User-Agent` a juego. Es un cambio de dos líneas.

El cliente iOS se usa a propósito para el audio: es el que todavía devuelve URLs
listas para reproducir, sin cifrado de firma ni *proof-of-origin token*. Eso
mantiene la reproducción en una sola petición en vez de necesitar un intérprete
de JavaScript.

## Arquitectura

```
lib/
  core/innertube/    Cliente HTTP y parsers. Dart puro, sin imports de Flutter.
  core/audio/        AudioHandler sobre just_audio + proxy de troceado.
  data/models/       Song, AudioStream. Portables a iOS y escritorio.
  features/          Pantallas de búsqueda y reproducción.
```

Tres decisiones que conviene no deshacer:

**Los parsers buscan por forma, no por ruta.** `findAll` recorre el árbol JSON
completo buscando el renderer que interesa, en vez de seguir una ruta rígida.
YouTube reordena y reenvuelve sus shelves con frecuencia; el recorrido recursivo
sobrevive a esos cambios, la ruta fija no.

**La cola guarda canciones, no URLs.** Cada stream se resuelve en el momento en
que empieza a sonar, porque las URLs de audio van firmadas y caducan en pocos
minutos. Una cola de URLs pre-resueltas se pudriría mientras suena la primera
canción.

**El audio pasa por un proxy en loopback, y no es opcional.** googlevideo se
niega a entregar un fichero entero en una sola respuesta. Medido contra una URL
real:

| Petición | Respuesta |
|---|---|
| sin cabecera `Range` | 403 |
| `Range: bytes=0-` | 403 |
| `Range: bytes=0-(último byte)` | 403 |
| `Range: bytes=0-131071` | 206 |

Pedir el fichero completo se rechaza da igual cómo se exprese; solo se sirven
ventanas acotadas. ExoPlayer emite exactamente una petición abierta por pista,
así que ninguna combinación de cabeceras podía funcionar: hay que trocear.
`StreamProxy` responde al reproductor con un único flujo continuo mientras por
debajo descarga el origen en bloques de 1 MiB.

Por eso existe `network_security_config.xml`: permite tráfico en claro **solo**
hacia `127.0.0.1`. Nada sale del dispositivo sin cifrar — el proxy habla con
googlevideo por HTTPS.

Si alguna vez ves un 403 al reproducir, empieza por aquí antes de sospechar de
la sesión o de un bloqueo.

## Sesión y biblioteca

No existe OAuth hacia la API interna, así que la autenticación funciona igual
que en la web de YouTube Music: cookies de un login real de Google, más una
cabecera `Authorization` derivada de una de ellas.

El esquema es `SAPISIDHASH`: SHA-1 sobre el timestamp actual, la cookie SAPISID
y el origen, unidos por espacios, enviado junto a ese mismo timestamp. La web de
YouTube lo calcula en JavaScript en cada petición, y por eso la cookie que hace
falta **no** es HttpOnly y se puede leer con `document.cookie` desde el WebView.

Las cookies se guardan cifradas en el dispositivo (`flutter_secure_storage`) y
no salen de él.

Dos detalles que costaron encontrarse y conviene no deshacer:

**El WebView de login se presenta como Firefox de escritorio.** Google rechaza
los inicios de sesión desde navegadores embebidos con "this browser or app may
not be secure". Con el user agent de escritorio la página carga con normalidad.

**`compileSdk` está fijado a 37**, por encima del valor por defecto de Flutter,
porque `flutter_secure_storage` lo exige. Los SDK de Android son retrocompatibles,
así que no cambia en qué dispositivos se puede instalar la app.

Todas las superficies de biblioteca son el mismo endpoint `browse` con un id
distinto (`FEmusic_liked_videos`, `FEmusic_liked_playlists`, `FEmusic_history`),
y el contenido de una playlist es ese id prefijado con `VL`. Por eso comparten
un único parser: las filas de canción usan el mismo renderer en búsqueda,
likes, historial y playlists.

## Desarrollo

```bash
flutter pub get
flutter test          # parsers contra respuestas reales grabadas en test/fixtures/
flutter run
```

Los tests corren contra JSON real capturado de InnerTube. El parsing es la única
parte que YouTube puede romper unilateralmente, así que es la única que tiene
tests: si las pantallas se vacían, estos tests señalan exactamente qué se movió.
Para regrabar los fixtures, captura una respuesta nueva de `search` y `player` y
reemplaza los archivos de `test/fixtures/`.

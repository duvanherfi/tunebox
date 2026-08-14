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
| 2 | Login con cuenta, biblioteca / likes / playlists / historial | Pendiente |
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
  core/audio/        AudioHandler sobre just_audio: cola, notificación, fondo.
  data/models/       Song, AudioStream. Portables a iOS y escritorio.
  features/          Pantallas de búsqueda y reproducción.
```

Dos decisiones que conviene no deshacer:

**Los parsers buscan por forma, no por ruta.** `findAll` recorre el árbol JSON
completo buscando el renderer que interesa, en vez de seguir una ruta rígida.
YouTube reordena y reenvuelve sus shelves con frecuencia; el recorrido recursivo
sobrevive a esos cambios, la ruta fija no.

**La cola guarda canciones, no URLs.** Cada stream se resuelve en el momento en
que empieza a sonar, porque las URLs de audio van firmadas y caducan en pocos
minutos. Una cola de URLs pre-resueltas se pudriría mientras suena la primera
canción.

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

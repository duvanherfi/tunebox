# Pendiente

Lo que falta de la lista de funcionalidades y, sobre todo, **qué bloquea cada
cosa**. Todo lo de aquí está parado porque hace falta una credencial o una
decisión, no porque falte escribir código.

Estado al publicar la 0.1.0 (16 de agosto de 2026).

## Reconocer la canción que está sonando

Escuchar unos segundos por el micrófono e identificar la pista, como Shazam.

**Bloqueado por:** hace falta un servicio de huellas acústicas. No es algo que
se pueda calcular en el dispositivo: la huella se compara contra un catálogo
enorme que solo tienen unos pocos.

- **AudD** — API HTTP sencilla, de pago desde el primer día.
- **ShazamKit** — gratis, pero exige una clave de desarrollador de Apple y su
  SDK de Android está descontinuado.

**Decisión pendiente:** si vale la pena pagar por esto. Es la única de la lista
con coste recurrente.

## Actualizaciones desde la propia app

Mirar la última release de GitHub, comparar con `version` de `pubspec.yaml`,
descargar el APK y lanzar el instalador (`REQUEST_INSTALL_PACKAGES`).

**Bloqueado por:** el repositorio es privado, y los assets de una release
privada no se descargan sin un token. Meter un token dentro del APK es
regalarlo: cualquiera puede extraerlo.

**Decisión pendiente:** hacer público el repositorio, o dejar las
actualizaciones a mano.

## Copia de seguridad en Google Drive

`data/backup.dart` ya exporta e importa los ajustes y el historial; lo que falta
es subir ese archivo a Drive y hacerlo cada cierto tiempo.

**Bloqueado por:** un proyecto nuevo en Google Cloud con la API de Drive
activada y el scope `drive.appdata` — el que deja a la app guardar en una
carpeta oculta que solo ella ve, sin pedir acceso a los archivos de nadie.

## Importar de Spotify

**Descartado** por decisión del proyecto.

# Cabos sueltos

Cosas que funcionan a medias y conviene mirar antes de dar por cerrada una
versión:

- **Las carátulas no cargan en el navegador del coche.** El árbol de Android
  Auto se ve y suena, pero las portadas salen como el marcador azul de
  siempre. Verificado en un emulador Automotive.
- **La interfaz de Android Auto proyectada no se ha probado.** El emulador
  Automotive es el sistema operativo del coche, no la proyección desde el
  teléfono; para eso hace falta el DHU o una radio de verdad.
- **Escribir en la cuenta solo se probó con el "me gusta".** Crear playlists y
  añadir canciones está implementado pero nunca se ejecutó contra la cuenta
  real, para no ensuciar la biblioteca de nadie.

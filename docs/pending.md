# Pendiente

Lo que falta de la lista de funcionalidades y, sobre todo, **qué bloquea cada
cosa**.

## Actualizaciones desde la propia app

Mirar la última release, comparar con el `versionCode` de `pubspec.yaml`,
descargar el APK y lanzar el instalador (`REQUEST_INSTALL_PACKAGES`).

**Bloqueado por:** el repositorio es privado, y los assets de una release
privada no se descargan sin un token. Meter un token dentro del APK es
regalarlo — y además ese token da lectura al código, que es justo lo que el
repo privado protege.

**Decisión pendiente:** publicar las releases en un repo público aparte
(`tunebox-releases`, sin código: solo tag, changelog y el APK firmado), que la
app consulta sin credencial ninguna. Falta decidir dónde se firma: keystore
como secret de Actions, o seguir construyendo en local y solo publicar.

# Descartado

- **Reconocer la canción que está sonando** (tipo Shazam). Exige un servicio de
  huellas acústicas: la huella se compara contra un catálogo enorme que solo
  tienen unos pocos, no es algo que se calcule en el dispositivo. AudD es de
  pago desde el primer día y ShazamKit tiene su SDK de Android descontinuado.
  Era la única función de la lista con coste recurrente.
- **Copia de seguridad en Google Drive.** `data/backup.dart` ya exporta e
  importa ajustes e historial a un archivo; subirlo a Drive exigía un proyecto
  nuevo en Google Cloud con la API activada y el scope `drive.appdata`. El
  export/import a mano se queda como está.
- **Importar de Spotify.**

# Cabos sueltos

Cosas que funcionan a medias y conviene mirar antes de dar por cerrada una
versión.

El 18 de agosto de 2026 se probó por fin la proyección con el DHU sobre un
teléfono real y un APK de release: los seis estantes, las carátulas, los cuatro
botones propios del reproductor y la reproducción desde una lista salieron bien.
De ahí salió el arreglo de `playFromMediaId`, que se queda sin el estante cuando
Android mata la app y el coche conserva el árbol.

- **Las carátulas no cargan en el navegador del emulador Automotive.** Salen
  como el marcador azul de siempre. Es cosa del emulador: en la proyección
  real, con el DHU, las portadas cargan tanto en las listas como en el
  reproductor.
- **Escribir en la cuenta solo se probó con el "me gusta".** Crear playlists y
  añadir canciones está implementado pero nunca se ejecutó contra la cuenta
  real, para no ensuciar la biblioteca de nadie.

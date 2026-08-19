# Actualizaciones desde la propia app

Diseño validado el 19 de agosto de 2026. Cierra la única entrada abierta de
`docs/pending.md`.

## Qué desbloquea esto y a qué precio

Hasta ahora el feature estaba parado por una sola cosa: los assets de una
release privada no se descargan sin un token, y un token dentro del APK se
extrae con `apktool` en dos minutos — y ese token, además, da lectura al código
que el repo privado protege.

La salida elegida es **abrir el repositorio**, como NewPipe, InnerTune, OuterTune
y OpenTune. Con `duvanherfi/tunebox` público, la app consulta
`api.github.com/repos/duvanherfi/tunebox/releases/latest` sin credencial ninguna:
no hay secreto que filtrar porque no hay secreto. Se descartó un repo de
releases aparte (`tunebox-releases`) por innecesario una vez que el repo entero
es público, y se descartó un proxy que guardase el token porque el APK acaba
igual de descargable, con una pieza más que mantener.

La llave de firma **no se mueve**: sigue en `android/key.properties`, ignorado por
git, y los builds se firman en local. CI nunca la ve.

### Lo que se comprobó antes de decidirlo

Barrido de los 91 commits del historial, no solo del árbol actual, porque al
abrir el repo se publica también lo borrado:

- Nunca se añadió `key.properties`, `*.jks`, `*.keystore`, `.env`, `.pem` ni
  `google-services.json`, en ningún commit.
- Ni una cookie real, ni un `Authorization:`, ni un `ghp_`/`github_pat_`, ni una
  clave `AIza…`. Los aciertos del grep son código que *maneja* cookies y
  fixtures obvias (`secret123`, `secret456`, `'KEY'`).
- La clave y el secreto de Last.fm los introduce el usuario en tiempo de
  ejecución y viven en `flutter_secure_storage`. No hay ninguna embebida.
- Las dos fixtures de `test/fixtures` (400 KB de JSON de YouTube) se grabaron
  **sin sesión**: no llevan `datasyncId`, ni `delegatedSessionId`, ni
  `loggedIn:true`. Su `visitorData` es un identificador anónimo ya caducado.
- `docs/streaming-findings.md` no contiene cookies, URLs firmadas ni ids de
  cuenta. `ci.yml` no usa secrets.

Queda fuera del alcance de un grep, y le toca al humano: los títulos y cuerpos
de issues y PRs, que también se hacen públicos.

### Consecuencias de abrir que no son secretos

1. **CI pasa a ser gratis.** Los repos públicos tienen Actions sin límite, así
   que el párrafo de `docs/pendientes.md` sobre la cuota fija y los runners de
   macOS a 10× queda diciendo lo contrario de lo que toca. Hay que reescribirlo.
   Firmar en CI se vuelve viable; no se hace ahora, pero deja de estar cerrado
   por dinero.
2. **Licencia GPL-3.0.** Copyleft fuerte: cualquiera puede forkear y
   redistribuir, pero está obligado a publicar su fuente bajo la misma licencia.
   Es la convención del nicho y es compatible con las dependencias, todas
   permisivas (Flutter BSD, `just_audio` y `audio_service` MIT).
3. **Es irreversible en la práctica.** Volver a privado no borra forks, clones
   ni cachés de terceros.
4. El email del autor queda en los 90 commits. Cambiarlo por el `noreply` de
   GitHub exige reescribir el historial y mover todos los SHA: no compensa.

## Decisiones tomadas

1. **La comprobación automática nace encendida**, con interruptor para apagarla.
   Se aparta a propósito de la regla que rige la mesita de noche, donde lo
   automático nace apagado: allí lo automático te secuestraba la pantalla, aquí
   solo aparece una hoja que se descarta. Un updater apagado por defecto es un
   updater que nadie usa.
2. **La comparación es de `versionCode`, no del nombre de versión.** Es lo que
   Android aplica al instalar. Una release de GitHub no lleva ese campo en
   ninguna parte, así que viaja en el nombre del asset:
   `tunebox-0.1.4+5.apk`. Si el nombre no se deja parsear se cae a comparar el
   `tag_name` como semver, que es la señal peor pero nunca ausente.
3. **Un solo APK universal, sin `--split-per-abi`.** Partirlo obliga a la app a
   elegir ABI para no ganar nada aquí.
4. **Se verifica la firma del APK descargado** contra la de la app instalada
   antes de lanzar el instalador. Es el control que hace seguro descargar de un
   sitio público: sin él, secuestrar el repo basta para colar un binario. Un APK
   que no coincide se descarta con un error, no se instala "avisando".
5. **`MethodChannel` propio en vez de plugin.** Los plugins de instalación que
   hay (`install_plugin`, `ota_update`, `app_installer`) llevan años sin
   mantener y cubren menos que las ~50 líneas de Kotlin que hacen falta. El
   repo ya tiene precedente: `TuneboxWidget` y `DeviceAccounts` son código
   nativo propio.
6. **Solo Android.** `REQUEST_INSTALL_PACKAGES` no tiene equivalente en las
   demás plataformas y la entrada vive en Ajustes › System, que el índice ya
   oculta fuera de Android.

## Dependencias

Una sola nueva: **`package_info_plus`**, que es de donde sale el `versionCode`
del build instalado para poder compararlo. `http` y `path_provider` ya están.
No entra ningún plugin de instalación, por la decisión 5.

## Arquitectura

Tres piezas con una frontera clara entre ellas.

**`lib/data/updates.dart` — qué versión hay ahí fuera.** Dart puro, sin imports
de Flutter salvo `ChangeNotifier`, igual que `core/innertube`: recibe un cliente
`http` inyectable para poder probarse contra JSON grabado. Expone
`Release?` (versión, `versionCode`, changelog, URL y tamaño del asset), el
resultado de comparar contra `package_info_plus`, y el progreso de la descarga
como fracción. No sabe nada de instalar.

**`android/…/Installer.kt` + `MethodChannel` — entregar el archivo al sistema.**
Tres métodos: `canInstall()` sobre `canRequestPackageInstalls()`,
`openInstallSettings()` que lanza `ACTION_MANAGE_UNKNOWN_APP_SOURCES`, y
`install(path)` que primero compara el certificado del APK
(`getPackageArchiveInfo` con `GET_SIGNING_CERTIFICATES`) con el de la app
instalada y solo entonces emite el `ACTION_VIEW` con un `content://` del
`FileProvider` y `FLAG_GRANT_READ_URI_PERMISSION`.

**`lib/features/settings/…` — la interfaz.** Una entrada en
`system_settings_screen.dart` con la versión actual de subtítulo y un
interruptor para la comprobación diaria, más una hoja (`SheetBody`, como todas)
que muestra changelog, tamaño y el progreso de descarga.

### Flujo

El arranque, si el ajuste está encendido y ha pasado un día desde la última
consulta guardada en `shared_preferences`, pide la release en segundo plano. Si
el `versionCode` es mayor, se muestra la hoja; si no, silencio absoluto — un
updater que dice "ya estás al día" sin que se lo pidan es ruido. El botón manual
en ajustes sí responde siempre, incluido el caso "estás al día".

Descargar lleva el APK al directorio de caché de la app, no a Descargas: es
temporal y se borra tras instalar o al arrancar si quedó de una vez anterior.

### Errores

La red sin respuesta, un `rate limit` de GitHub, una release sin asset que
parsear y un certificado que no coincide son todos el mismo tipo de evento y se
tratan igual que un estante que el túnel rechaza en `getChildren`: se informa en
la hoja si el usuario la abrió a mano, y se calla si la comprobación fue
automática. Nada de esto tira la app ni bloquea nada.

El caso que sí necesita voz propia es `canInstall()` en falso: ahí la hoja
explica que Android exige el permiso y ofrece el botón que lleva al ajuste.

## Pruebas

`test/updates_test.dart`, Dart puro contra una respuesta de GitHub grabada en
`test/fixtures/release_latest.json`: que un `versionCode` mayor se detecte, que
uno igual o menor no, que un nombre de asset ilegible caiga a comparar el tag,
que una release sin APK no proponga nada, y que un 403 de rate limit devuelva
"no hay novedad" en vez de propagar.

Lo que ningún test cubre y hay que ver en el emulador: el permiso, el
`FileProvider` y el instalador del sistema. Se verifica publicando la `v0.1.4`
real y luego instalando un build local con la versión bajada a `0.1.3+4` —
mismo código, solo el número, y ese build no se publica — para recorrer el
ciclo entero: aviso, descarga, comprobación de firma, instalador, app
actualizada.

Queda fuera del emulador el aviso de Play Protect, que solo aparece con Google
Play Services. Va a `docs/pending.md` como cabo suelto para un teléfono real.

## Orden de trabajo

Lo que hace el humano, porque es su cuenta y es irreversible:

1. Revisar títulos y cuerpos de issues y PRs.
2. `gh repo edit duvanherfi/tunebox --visibility public --accept-visibility-change-consequences`.

Lo demás, en este orden, porque cada paso deja algo verificable:

3. `LICENSE` con el texto de GPL-3.0 y la nota de licencia en el README.
4. Reescribir en `docs/pendientes.md` el párrafo de CI que da por buena una
   cuota que ya no existe.
5. `lib/data/updates.dart` con su test, contra la fixture grabada. Sin interfaz
   todavía: aquí es donde vive la lógica y donde se puede equivocar en silencio.
6. `Installer.kt`, el `FileProvider` y el permiso en el manifiesto.
7. La entrada en ajustes, la hoja, el ajuste en `Settings` y las claves en
   `app_en.arb` y `app_es.arb`.
8. `tool/release.sh`, que construye, firma con la llave local, etiqueta y
   publica con `gh release create` nombrando el asset con su `versionCode`.
9. Publicar la `v0.1.4` y recorrer el ciclo en el emulador.

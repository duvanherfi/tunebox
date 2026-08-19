# Modo mesita de noche (AOD)

Diseño validado el 18 de agosto de 2026. Corresponde al punto 1 de
`docs/pendientes.md`.

## Qué es y qué no es

Una pantalla propia de la app para el teléfono **despierto**, apoyado en la
mesita: fondo negro, reloj grande, carátula, progreso y controles. Toma el
wakelock, así que mientras está delante la pantalla no se apaga.

No es el AOD del sistema. El de Samsung y los suyos es el panel de bajo consumo
que dibuja el sistema con la pantalla **apagada**; ninguna app pinta ahí. Los dos
se excluyen: con esta pantalla delante la pantalla está encendida y el AOD del
sistema no aparece; al bloquear, esta pantalla deja de importar y el del sistema
toma el relevo mostrando la sesión de medios que `audio_service` ya publica.

Por ser una pantalla Flutter corriente es portable: no hay nada de Android en
ella salvo el modo inmersivo, que se guarda por plataforma.

## Decisiones tomadas

Dos que conviene poder revocar de un vistazo:

1. **Las dos activaciones automáticas nacen apagadas.** Una app que se va sola a
   una pantalla negra la primera vez que la dejas quieta no se lee como un modo,
   se lee como un fallo. Se encienden desde su puerta en ajustes, donde el texto
   dice qué hacen.
2. **El brillo por defecto es el 20 %.** Suficiente para leer la hora de noche
   sin iluminar la habitación. Ajustable de 5 a 100.

Y tres estructurales:

3. **Ruta a pantalla completa, no overlay.** `PlayerSheet` ya es un `Positioned`
   dentro del armazón con la navegación y el mini reproductor debajo; meter el
   AOD ahí sería pelearse con esa pila. Una ruta opaca sobre el `rootNavigator`
   tapa todo por construcción, igual que hacen las hojas con
   `useRootNavigator: true`.
4. **El wakelock aquí es incondicional**, no `settings.keepAwake`. En el
   reproductor completo mantener la pantalla encendida es una preferencia; aquí
   es el punto del modo.
5. **Dos dependencias nuevas**: `screen_brightness` y `battery_plus`. Un velo
   negro con alpha no sustituye al primero — baja el contraste, no la
   retroiluminación, y en un OLED a oscuras eso se nota. El segundo es la única
   vía para saber que el teléfono está enchufado.

## Ajustes

Nueve escalares nuevos en `data/settings.dart`. Escalares, luego preferencias:
no hace falta almacén nuevo.

| Clave | Tipo | Por defecto |
| --- | --- | --- |
| `nightstand_clock` | bool | `true` |
| `nightstand_art` | bool | `true` |
| `nightstand_title` | bool | `true` |
| `nightstand_progress` | bool | `true` |
| `nightstand_controls` | String (`always` / `onTouch` / `never`) | `onTouch` |
| `nightstand_dim` | int, 5–100, porcentaje de brillo | `20` |
| `nightstand_burn_in` | bool | `true` |
| `nightstand_idle_seconds` | int, 0 = nunca | `0` |
| `nightstand_on_charge` | bool | `false` |

`nightstand_controls` se guarda como cadena y se lee a un `enum
NightstandControls`; un valor desconocido cae a `onTouch` en vez de lanzar, que
es lo que hace falta cuando una versión vieja lee las preferencias de una nueva.

Viven tras una **sexta puerta** en `SettingsScreen`, "Mesita de noche", coherente
con darle a cada dominio la suya. La puerta existe en todas las plataformas: al
contrario que el widget, aquí hay algo detrás en todas.

## La pantalla

`features/nightstand/nightstand_screen.dart`.

Fondo negro puro, no `surface`: en un OLED el negro real no enciende el píxel.
Contenido centrado en columna, y en fila cuando el ancho supera al alto — el
mismo reparto que ya hace `FullPlayer`, por la misma razón: apilar una carátula
cuadrada sobre los controles en un teléfono tumbado deja la carátula en una
rendija.

De arriba abajo, cada bloque condicionado a su interruptor:

- **Reloj.** Grande, peso 200. Hora y fecha del locale del dispositivo vía
  `intl`, que ya es dependencia: el formato de 12 o 24 horas no es un mando, es
  del sistema.
- **Carátula.** Cuadrada, dimensionada por `LayoutBuilder` sobre lo que le den,
  no sobre el tamaño de pantalla.
- **Título y artista.**
- **Progreso.** Barra arrastrable con los dos tiempos.
- **Controles.** Anterior, play/pausa, siguiente.

### Los controles y la salida

`nightstand_controls` decide tres comportamientos:

- `always` — pintados fijos.
- `onTouch` — a opacidad 0; un toque en cualquier sitio los trae durante cinco
  segundos y se van solos. Con ellos aparece un chevron de salida.
- `never` — no existen, y cualquier toque sale al reproductor.

El gesto de atrás sale siempre, en los tres modos. En `never` el toque es la
salida; en los otros dos el toque despierta y la salida es el chevron o atrás.

### Protección de quemado

Con `nightstand_burn_in`, todo el contenido va dentro de un
`Transform.translate` cuyo desplazamiento recorre cuatro posiciones de ±8 px, una
cada 60 s, con transición de dos segundos. El cálculo es la función pura
`Offset nightstandDrift(int tick)` en `nightstand.dart`, que por eso se prueba
sin pintar nada.

## Entrar y salir

`openNightstand(BuildContext)` en `features/nightstand/nightstand.dart` es el
único camino de entrada. Hace, en este orden:

1. Comprueba un `bool` estático de reentrada y no hace nada si ya está abierta.
   Con tres vías de activación, dos pueden dispararse a la vez.
2. Toma el wakelock, pone `SystemUiMode.immersiveSticky` (solo Android) y baja
   el brillo a `nightstand_dim`.
3. Empuja una `PageRouteBuilder` opaca con fade sobre el `rootNavigator`.

Un `finally` alrededor del push deshace las tres cosas y baja el flag. En un
`finally` y no en el `dispose` de la pantalla porque el `await` del push termina
como termine la ruta — nuestro chevron, el gesto de atrás, un `pop` de otro
sitio — y además cubre el caso de que nunca llegara a abrirse.

### Las tres activaciones

- **Manual.** Un `ListTile` arriba de `playback_sheet.dart`, encima del
  temporizador. Las dos cosas de dormir juntas, en la hoja a la que se llega
  desde el reproductor.
- **Inactividad.** `IdleWatcher` envuelve el contenido de `FullPlayer`. Como
  `FullPlayer` solo se monta cuando el panel pasa de un cuarto de recorrido, la
  condición "el reproductor está abierto" sale gratis del montaje y no hay que
  observar el controlador de la hoja. Un `Listener(onPointerDown:)` reinicia el
  temporizador. Se arma solo si `nightstand_idle_seconds > 0` y
  `playbackState.playing`; cambiar cualquiera de los dos lo rearma o lo desarma.
- **Al cargar.** `ChargeWatcher`, creado en `main.dart` con los demás globales,
  suscrito a `Battery().onBatteryStateChanged`. Entra cuando el estado pasa a
  `charging` o `full`, `nightstand_on_charge` está puesto y hay algo sonando.
  Guardado a Android e iOS, que es donde `battery_plus` contesta algo útil.
  Necesita un `navigatorKey` en el `MaterialApp`, que hoy no existe: es un
  observador sin `BuildContext`.

## Ficheros

Nuevos:

- `lib/features/nightstand/nightstand.dart` — `openNightstand`, el flag de
  reentrada, wakelock/inmersivo/brillo, `nightstandDrift`, `NightstandControls`.
- `lib/features/nightstand/nightstand_screen.dart` — la pantalla.
- `lib/features/nightstand/idle_watcher.dart`
- `lib/features/nightstand/charge_watcher.dart`
- `lib/features/settings/nightstand_settings_screen.dart`

Tocados:

- `lib/data/settings.dart` — los nueve escalares y sus setters.
- `lib/features/settings/settings_screen.dart` — la sexta entrada.
- `lib/features/player/playback_sheet.dart` — la entrada manual.
- `lib/features/player/full_player.dart` — envolver en `IdleWatcher`.
- `lib/main.dart` — `navigatorKey` y `chargeWatcher`.
- `lib/l10n/app_en.arb` y `app_es.arb` — unas veinte claves, y regenerar.
- `pubspec.yaml` — `screen_brightness`, `battery_plus`.

## Pruebas

- `test/nightstand_test.dart` — `nightstandDrift` cicla por cuatro posiciones y
  nunca se pasa de ±8 px; `NightstandControls` lee un valor desconocido como
  `onTouch`; el `IdleWatcher` dispara a los N segundos y un toque lo reinicia.
- `test/nightstand_settings_test.dart` — ida y vuelta de los nueve escalares
  contra `SharedPreferences.setMockInitialValues`.
- `test/settings_index_test.dart` — ya existe; añadir que la sexta puerta está.
- Widget test de la pantalla: con reloj, carátula y progreso apagados no se pinta
  ninguno de los tres, y quedan el título y los controles.

Y verificación en el emulador con captura, que en este repo ha sido la única
forma de ver varios fallos de disposición.

## Riesgos conocidos

- `screen_brightness` cambia el brillo de la ventana, no el del sistema, y se
  restaura al salir. El brillo adaptativo del teléfono vuelve a mandar entonces.
- El modo Dormir de las rutinas de Samsung atenúa y desatura todo el sistema; se
  aplicaría encima de esta pantalla. Es cosmético.
- `immersiveSticky` no existe fuera de Android; ahí el paso se salta.
- `battery_plus` no está probado en macOS y no hace falta que lo esté: un
  portátil enchufado no es una mesita de noche.

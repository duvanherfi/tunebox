# Tunebox

[![Latest version](https://img.shields.io/github/v/release/duvanherfi/tunebox?label=version)](https://github.com/duvanherfi/tunebox/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/duvanherfi/tunebox/total?label=downloads)](https://github.com/duvanherfi/tunebox/releases)
[![License](https://img.shields.io/github/license/duvanherfi/tunebox)](LICENSE)

A Flutter music player that reads the YouTube Music catalogue through InnerTube,
the internal API that YouTube's own web app uses. It runs on Android and macOS,
and it gets daily use.

**No microG, no Google Play Services.** microG exists so that patched apps
(ReVanced, Vanced) can sign in despite not being signed by Google; that emulated
layer is exactly what costs performance. Here the API is spoken to directly over
HTTP and the audio goes to native ExoPlayer, with no WebView.

History is **not** written back to the YouTube account: the pings are sent
exactly as the web app sends them, YouTube answers 204, and nothing shows up in
`FEmusic_history`. That is why history, statistics and scrobbling are kept on
the device. The measurements are in
[`docs/streaming-findings.md`](docs/streaming-findings.md).

## What it looks like

| Home | Player | Synced lyrics | Queue |
|---|---|---|---|
| ![Home](docs/screenshots/inicio.png) | ![Player](docs/screenshots/reproductor.png) | ![Synced lyrics](docs/screenshots/letra.png) | ![Queue](docs/screenshots/cola.png) |

| Explore | Search | Sleep timer, speed and equalizer | Nightstand mode |
|---|---|---|---|
| ![Explore](docs/screenshots/explorar.png) | ![Search](docs/screenshots/buscar.png) | ![Sleep timer, speed and equalizer](docs/screenshots/ajustes-reproduccion.png) | ![Nightstand mode](docs/screenshots/mesita.png) |

On the Mac it is the same app and the same code; what changes is that the player
opens in two columns and the shelves fit whole.

![Home on macOS](docs/screenshots/macos-inicio.png)

![Player on macOS](docs/screenshots/macos-reproductor.png)

The Android screenshots show the interface in English and the Mac ones in
Spanish: same build, reading the device's language. The account picture is
blurred on purpose.

## Install

The APK for each version is on the
[releases](https://github.com/duvanherfi/tunebox/releases) page. It is
universal: a single file carrying `arm64-v8a`, `armeabi-v7a` and `x86_64`, so it
works on any phone running Android 7 or later.

From 0.1.4 on, **the app updates itself**: it checks once a day for a new
version, offers it and installs it. It verifies that the downloaded APK is
signed with the same key as the installed copy before handing it to the system
installer; one that is not gets discarded. It can be turned off in
Settings › System.

Windows and Linux are not there: `audio_service` and `just_audio` only declare
android, ios, macos and web, and the player **is** a `BaseAudioHandler`, so
those platforms would build and then die as soon as the service started.

## Build

```bash
flutter pub get
flutter test
flutter run
```

A signed build needs `android/key.properties` — git-ignored — pointing at the
keystore:

```properties
storePassword=…
keyPassword=…
keyAlias=tunebox
storeFile=tunebox-release.jks
```

Without that file the build still works and signs with the debug key. **The
release key must not be lost**: Android refuses to update an installed app if
the new version is signed with a different key, and there is no store here to
re-sign it.

Publishing a version is `tool/release.sh <notes>`, which builds, checks the
signature and the resources the shrinker might have eaten, tags, and uploads the
release with the APK named after its build number.

## Where everything else is

- [`CLAUDE.md`](CLAUDE.md) — the working map: how the project is wired, the
  decision behind each piece, and what should not be undone.
- [`docs/streaming-findings.md`](docs/streaming-findings.md) — what was measured
  against YouTube's servers: why playback needs a chunking proxy, which client
  identities work, and what happens with history. **Read it before touching
  `core/innertube` or `core/audio`**: nearly every obvious simplification in
  there has already been tried, and failed.
- [`docs/pendientes.md`](docs/pendientes.md) — what is done, what is missing and
  what was left half-way.

If playback suddenly stops working — `player` answering 400 or `LOGIN_REQUIRED`
for everything — it is not a block and not a cookie problem: YouTube retired the
client build. Bump `version` in the profiles in
`lib/core/innertube/innertube_client.dart` and the matching user agent. It is a
two-line change and it is explained in `CLAUDE.md`.

## License

GPL-3.0. Copyright (C) 2026 Duvan Hernandez Figueroa. The full text is in
[`LICENSE`](LICENSE).

Strong copyleft: you may use, study, modify and redistribute this code, but if
you distribute a version — modified or not — you are required to publish its
source under this same license. It is the one NewPipe, InnerTune and OuterTune
use, and it comes with no warranty of any kind.

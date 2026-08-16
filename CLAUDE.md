# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get
flutter analyze                      # must be clean before committing
flutter test                         # all tests
flutter test test/backup_test.dart   # one file
flutter test --plain-name "ranks what was played most"   # one test
flutter gen-l10n --arb-dir=lib/l10n  # after touching lib/l10n/*.arb
flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Development happens against an Android emulator driven with `adb` (`adb shell
monkey -p com.tunebox.tunebox …`, `adb shell input tap …`, `adb exec-out
screencap -p > shot.png`). An Android Automotive AVD is the only way to exercise
the media-browsing tree end to end:

```bash
adb -s <automotive> shell am start -a android.car.intent.action.MEDIA_TEMPLATE \
  --es android.car.intent.extra.MEDIA_COMPONENT \
  "com.tunebox.tunebox/com.ryanheise.audioservice.AudioService"
```

## Read first

`docs/streaming-findings.md` records what was measured against YouTube's servers
— why playback needs a chunking proxy, why the app's own playback reports never
land in YouTube's history, which client identities work. Read it before changing
anything in `core/innertube` or `core/audio`; most "obvious" simplifications
there were already tried and failed.

The single most fragile value in the repo is `version` inside the client
profiles in `lib/core/innertube/innertube_client.dart`. When YouTube retires a
build, `player` starts answering 400 or `LOGIN_REQUIRED` for everything. That is
not a ban and not a cookie problem — bump the version and the matching user
agent.

## Architecture

**Wiring.** `lib/main.dart` builds every long-lived object as a top-level `late
final` global (`playerService`, `innertube`, `session`, `settings`,
`playHistory`, `downloads`, `localPlaylists`, `likes`, …) and initialises them
before `runApp`. Widgets import `main.dart` and use them directly; there is no
DI container and no state-management package. New shared state goes in `lib/data`
as a `ChangeNotifier` and is wired the same way.

**`core/innertube`** is pure Dart with no Flutter imports, so it is testable
against recorded JSON. `InnertubeClient` posts to InnerTube; `parsers.dart` turns
responses into models by walking the whole JSON tree for a renderer key
(`findAll`) rather than following fixed paths — YouTube reorders and rewraps its
shelves constantly. Every library surface is `browse` with a different id
(`FEmusic_liked_videos`, `FEmusic_history`, `FEmusic_liked_albums`, …), and
playlist contents are that id prefixed with `VL`.

**`core/audio`.** `PlayerService` is the single `BaseAudioHandler`: it owns the
queue as `Song`s (never URLs — signed URLs expire in minutes), resolves audio at
the moment a track starts, and decides the source in this order: local file
(`local:` id prefix) → download → cached stream → proxied stream. `StreamProxy`
is not optional: googlevideo refuses unbounded requests, so playback goes through
a loopback server that fetches 1 MiB windows. Anything that must survive across
launches (`ResumePoint`) or reach other surfaces (notification, Android Auto) is
published through `playbackState` / `mediaItem` / `queue`.

**Storage is split by kind.** Scalar settings → `shared_preferences`
(`data/settings.dart`, `core/theme/theme_controller.dart`). Growing records →
JSON files under `getApplicationSupportDirectory()` (play log, downloads index,
local playlists, resume point) — each store takes an optional `File`/`Directory`
in its constructor so tests can inject a temp path. Credentials (session cookies,
scrobbler tokens) → `flutter_secure_storage`, never preferences, never backups.

**`features/`** is one folder per surface plus `features/shared` for what several
of them need: `SongRow`/`SongListView` (tap plays from here, long press opens the
menu), `SheetBody` (every bottom sheet is capped, centred and scrollable — a
landscape phone is shorter than most sheets), `ShelfRow` (the carousel the home
feed, explore and artist pages are all built from), `Measured` (report a widget's
real size instead of guessing at layout constants).

**Localisation.** Every user-visible string is an ARB key; `lib/l10n/app_en.arb`
is the template and `app_es.arb` must gain the same keys. Strings are added by
editing both files and regenerating. `InnertubeClient` also takes `hl`/`gl` from
the device locale, so YouTube's own labels arrive translated.

## Conventions

- Code comments and commit messages are written in **English**, even when the
  conversation is in Spanish. Comments explain *why*, not what.
- Verify changes on the emulator (screenshot) as well as with tests; several bugs
  here — dead space above the navigation, a 161px sheet overflow, a player fading
  a track late — were only visible on a device.
- `permission_handler` is pinned below 14 (its Gradle script does not compile
  with this toolchain), and `compileSdk` is 37 because `flutter_secure_storage`
  requires it.

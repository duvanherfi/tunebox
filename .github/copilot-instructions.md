# Copilot instructions

## Build, test, and lint

Run these from the repository root:

```bash
flutter pub get
flutter analyze
flutter test
flutter test test/backup_test.dart
flutter test --plain-name "ranks what was played most"
flutter gen-l10n --arb-dir=lib/l10n
flutter build apk --debug
```

The CI workflow uses Flutter 3.41.6. After editing either `lib/l10n/*.arb`,
keep the English and Spanish keys in sync and regenerate localizations. The
Android release build shrinks resources; `tool/check_drawables.sh` and
`test/android_icon_resources_test.dart` verify that Dart-referenced drawables
are kept.

## Architecture

- `lib/main.dart` constructs and loads process-wide services as top-level
  `late final` globals before `runApp`. Widgets import these directly; there is
  no DI container or state-management package. Shared mutable state belongs in
  `lib/data` as a `ChangeNotifier`, wired in `main.dart`.
- `lib/features` contains UI surfaces; `features/shared` holds reusable
  components such as song lists, shelves, and bottom-sheet layout. `lib/core`
  contains playback, InnerTube, auth, lyrics, scrobbling, and platform logic.
  `lib/data` owns settings and persistent user data.
- `PlayerService` is the single `BaseAudioHandler`. Its queue stores `Song`s,
  not signed stream URLs; resolve a URL when a track starts. Playback chooses
  local files, downloads, cached streams, then proxied streams. The
  `StreamProxy` is required because YouTube's CDN rejects unbounded requests.
  Playback state, media item, and queue also drive the notification and
  Android Automotive.
- `lib/core/innertube` is pure Dart and is tested against JSON fixtures in
  `test/fixtures`. `InnertubeClient` handles requests and `parsers.dart` finds
  renderer keys recursively (`findAll`) because YouTube changes response
  nesting. Library views use `browse` with different IDs; playlist contents
  use the corresponding ID prefixed with `VL`.
- Storage is split by data type: scalar settings use `shared_preferences`;
  growing records use JSON files under application support; credentials use
  `flutter_secure_storage`. Stores that use files accept injectable paths for
  tests.

## Repository-specific constraints

- Before changing `lib/core/innertube` or `lib/core/audio`, read
  `docs/streaming-findings.md`. It records measured server behavior and failed
  approaches that are not obvious from the client code.
- If InnerTube's player endpoint starts returning HTTP 400 or
  `LOGIN_REQUIRED` broadly, check the client profile `version` and matching
  user agent in `lib/core/innertube/innertube_client.dart`; retired client
  builds are a known failure mode.
- A refused track is a normal playback outcome: the queue skips it, up to five
  consecutive refusals. Preserve this behavior rather than surfacing an
  unhandled async error.
- Any Android `drawable` looked up by name from Dart must be listed in
  `android/app/src/main/res/raw/keep.xml`. Release shrinking can remove
  string-referenced resources, breaking media-session state even when debug
  builds work.
- Audio effects and stream caching are Android-only in `PlayerService`; do not
  assume the platform plugins behave the same on macOS.
- Every user-visible string belongs in both `lib/l10n/app_en.arb` and
  `lib/l10n/app_es.arb`. InnerTube's `hl` and `gl` also come from the device
  locale.
- Code comments and commit messages are in English. For platform testing,
  emulator and Android Automotive details are in `CLAUDE.md`.

See `README.md` for supported platforms and release workflow, and `CLAUDE.md`
for additional implementation and device-testing details.

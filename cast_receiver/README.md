# TuneBox Custom Web Receiver

This static CAF receiver is a feasibility spike for Cast audio and video. It
plays the request's primary media using CAF and can attach a second audio URL to
a video request to measure and correct playback drift. It is not evidence that
the current TuneBox streams stay synchronized; that must be measured on a real
receiver over several minutes before product integration.

## GitHub Pages setup

The workflow publishes only `cast_receiver/` to the project site when changes
reach `main`. Before the first deployment, enable **Settings → Pages → Build and
deployment → Source: GitHub Actions**. The expected receiver URL is
`https://duvanherfi.github.io/tunebox/`.

In the Google Cast SDK Developer Console, edit the existing **Custom Receiver**
application and set its URL to that HTTPS address. Enable support for
audio-only devices so the Nest Mini can launch it. Register the Nest Mini as a
development device while the receiver is unpublished. The application ID is
public configuration; do not put it in this site's source.

Run the sender probe with the registered application ID:

```sh
cd tool/cast_probe
flutter run -d <android-device-id> \
  --dart-define=CAST_RECEIVER_APP_ID=<registered-application-id>
```

## Sender contract

For ordinary audio or video, send a standard CAF `LOAD` request. For separate
video and audio streams, use the video as the primary media and include:

```json
{
  "tuneboxCast": {
    "version": 1,
    "audioUrl": "https://example.invalid/audio"
  }
}
```

The audio URL may use HTTP for the LAN media-server feasibility test. This
receiver does not accept credentials in media URLs, log media URLs, or provide
an HTTP server. The media server must provide the CORS and byte-range behavior
validated by the separate LAN test.

## Receiver-side test

1. Load a short video-only resource and a matching separate audio resource.
2. Verify receiver state, pause/resume, seek, and end behavior from the sender.
3. Keep it playing for several minutes and observe the on-screen A/V drift and
   maximum observed drift.
4. Repeat with representative TuneBox tracks. A successful short sample does
   not pass the viability gate.

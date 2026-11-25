# TuneBox Custom Web Receiver

This static CAF receiver is a feasibility spike for Cast audio. It plays the
request's primary media using CAF. Experimental support for attaching a second
audio URL to video remains available for a future phase, but video is deferred
and has not been validated with TuneBox streams.

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

## Deferred A/V sender contract

The current phase sends audio-only media through a standard CAF `LOAD` request.
For a future separate video and audio stream experiment, use the video as the
primary media and include:

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

## Current receiver-side test

1. Load an audio-only sample.
2. Verify receiver state, pause/resume, seek, and end behavior from the sender.
3. Repeat with representative TuneBox audio tracks. A successful short sample
   does not pass the viability gate.

Video playback and A/V drift measurement are deferred until a later phase with
a Cast receiver connected to a screen.

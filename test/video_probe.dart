// Probe, not a test: it talks to YouTube. Named without the `_test` suffix so
// the suite does not collect it; run it on purpose with
// `flutter test test/video_probe.dart --plain-name probe`.
//
// It reports what a player response offers for *showing* a track, and writes an
// mpv command that opens the picture with the sound attached — the same pairing
// media_kit performs with `AudioTrack.uri`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/core/innertube/innertube_client.dart';

void main() {
  test('probe', () async {
    final videoId = Platform.environment['VIDEO_ID'] ?? '5NV6Rdv1a3I';
    final innertube = InnertubeClient();

    final tracks = await innertube.resolveTracks(videoId);
    stdout.writeln('videoId: $videoId');
    stdout.writeln('audio formats: ${tracks.audio.length}');
    for (final a in tracks.audio.take(3)) {
      stdout.writeln(
          '  ${a.mimeType.split(';').first}  ${a.bitrate} bps  ${a.duration}');
    }
    stdout.writeln('video formats: ${tracks.video.length}');
    for (final v in tracks.video) {
      stdout.writeln('  ${v.qualityLabel}\t${v.width}x${v.height}\t${v.fps}fps\t'
          '${v.bitrate} bps\t${v.mimeType.split(';').first}');
    }

    if (tracks.video.isEmpty) {
      stdout.writeln('\nNo video track: nothing to show for this one.');
      return;
    }

    final video = tracks.video.first;
    final audio = tracks.audio.first;
    final file = File('${Directory.systemTemp.path}/tunebox_probe.sh');
    await file.writeAsString(
      '#!/bin/sh\n'
      'mpv --user-agent="${video.userAgent}" \\\n'
      '  --audio-file="${audio.url}" \\\n'
      '  "${video.url}"\n',
    );
    stdout.writeln('\nwrote ${file.path}');
  }, timeout: const Timeout(Duration(minutes: 2)));
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/core/audio/cast_server.dart';

void main() {
  late Directory dir;
  late CastServer server;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cast_server');
    server = CastServer(address: () async => InternetAddress.loopbackIPv4);
  });

  tearDown(() async {
    await server.stop();
    await dir.delete(recursive: true);
  });

  Future<File> mp4(int size) async {
    final bytes = List<int>.generate(size, (i) => i % 251);
    bytes.setRange(4, 8, 'ftyp'.codeUnits);
    return File('${dir.path}/song.audio')..writeAsBytesSync(bytes);
  }

  Future<HttpClientResponse> get(Uri url, {String? range}) async {
    final client = HttpClient();
    final request = await client.getUrl(url);
    if (range != null) request.headers.set(HttpHeaders.rangeHeader, range);
    final response = await request.close();
    client.close();
    return response;
  }

  test('serves a published file whole and by range', () async {
    final file = await mp4(5000);
    final media = await server.publishFile(file);

    expect(media.contentType, 'audio/mp4');

    final whole = await get(media.url);
    expect(whole.statusCode, HttpStatus.ok);
    expect((await whole.expand((b) => b).toList()).length, 5000);

    final part = await get(media.url, range: 'bytes=1000-1999');
    expect(part.statusCode, HttpStatus.partialContent);
    expect(part.headers.value('content-range'), 'bytes 1000-1999/5000');
    final body = await part.expand((b) => b).toList();
    expect(body, file.readAsBytesSync().sublist(1000, 2000));

    final tail = await get(media.url, range: 'bytes=4990-');
    expect(tail.headers.value('content-range'), 'bytes 4990-4999/5000');
    expect((await tail.expand((b) => b).toList()).length, 10);
  });

  test('answers nothing outside what was published', () async {
    final media = await server.publishFile(await mp4(100));
    final segments = media.url.pathSegments;

    final wrongToken = media.url.replace(path: '/nottoken/${segments[1]}');
    expect((await get(wrongToken)).statusCode, HttpStatus.notFound);

    final wrongId = media.url.replace(path: '/${segments[0]}/nothing');
    expect((await get(wrongId)).statusCode, HttpStatus.notFound);
  });

  test('reads the container from the bytes, not the name', () {
    File write(String name, List<int> bytes) =>
        File('${dir.path}/$name')..writeAsBytesSync([...bytes, 0, 0, 0, 0]);

    expect(CastServer.sniffContentType(write('a', [0x1A, 0x45, 0xDF, 0xA3])),
        'audio/webm');
    expect(CastServer.sniffContentType(write('b', 'fLaC'.codeUnits)),
        'audio/flac');
    expect(CastServer.sniffContentType(write('c', 'ID3'.codeUnits)),
        'audio/mpeg');
  });
}

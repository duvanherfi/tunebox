import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/data/downloads.dart';
import 'package:tunebox/data/models/song.dart';

Song _song(String id) => Song(videoId: id, title: 'Track $id', subtitle: '');

void main() {
  late Directory directory;
  Downloads store() => Downloads(directory: directory);

  setUp(() => directory = Directory.systemTemp.createTempSync('tunebox_dl'));
  tearDown(() => directory.deleteSync(recursive: true));

  test('fetches one at a time, in the order asked for', () async {
    final downloads = store();
    final order = <String>[];
    var running = 0;

    Future<void> fetch(Song song) async {
      running++;
      expect(running, 1, reason: 'the queue must not run two at once');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      order.add(song.videoId);
      running--;
    }

    downloads.enqueue(_song('a'), fetch);
    downloads.enqueue(_song('b'), fetch);
    downloads.enqueue(_song('c'), fetch);

    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(order, ['a', 'b', 'c']);
  });

  test('a failure does not stop the queue', () async {
    final downloads = store();
    final done = <String>[];

    Future<void> fetch(Song song) async {
      if (song.videoId == 'b') throw Exception('no');
      done.add(song.videoId);
    }

    downloads.enqueue(_song('a'), fetch);
    downloads.enqueue(_song('b'), fetch);
    downloads.enqueue(_song('c'), fetch);

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(done, ['a', 'c']);
  });

  test('a track already queued is not queued twice', () async {
    final downloads = store();
    var calls = 0;

    Future<void> fetch(Song song) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }

    downloads.enqueue(_song('a'), fetch);
    downloads.enqueue(_song('a'), fetch);

    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(calls, 1);
  });

  // The queue marks a track as current before fetching it, and `add` refuses
  // a track that is already downloading: for three months every download
  // from the app ended there, silently, with nothing written.
  test('a queued track is actually saved when its fetch calls add', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response
        ..add(List.filled(64, 7))
        ..close();
    });
    addTearDown(server.close);
    final url = Uri.parse('http://127.0.0.1:${server.port}/a');

    final downloads = store();
    downloads.enqueue(
      _song('a'),
      (song) => downloads.add(song, url, userAgent: 'test'),
    );

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(downloads.has('a'), isTrue);
    expect(downloads.fileFor('a').lengthSync(), 64);
  });

  test('cancelling drops it before its turn comes', () async {
    final downloads = store();
    final done = <String>[];

    Future<void> fetch(Song song) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      done.add(song.videoId);
    }

    downloads.enqueue(_song('a'), fetch);
    downloads.enqueue(_song('b'), fetch);
    downloads.cancel('b');

    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(done, ['a']);
  });
}

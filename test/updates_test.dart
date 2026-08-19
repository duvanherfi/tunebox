import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tunebox/data/updates.dart';

/// The updater decides, without anyone watching, whether to interrupt the
/// listener — so what it must never do is offer an update that is not one, or
/// turn a tunnel into an error. Everything here is that judgement, checked
/// against a recorded answer from GitHub.
void main() {
  const installed = AppVersion(name: '0.1.3', build: 4);

  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('updates_test');
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  Map<String, dynamic> release() => jsonDecode(
        File('test/fixtures/release_latest.json').readAsStringSync(),
      ) as Map<String, dynamic>;

  Updates updates(Object body, {int status = 200}) => Updates(
        installed: installed,
        directory: directory,
        httpClient: MockClient(
          (_) async => http.Response(
            body is String ? body : jsonEncode(body),
            status,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

  test('offers a release whose build is above the installed one', () async {
    final store = updates(release());

    final found = await store.check();

    expect(found, isNotNull);
    expect(found!.build, 5);
    expect(found.version, '0.1.4');
    expect(found.notes, contains('Actualizaciones desde la propia app'));
    expect(found.size, 43118592);
    // The name arrives percent-encoded because '+' is not literal in a URL.
    expect(found.url.toString(), endsWith('tunebox-0.1.4%2B5.apk'));
    expect(store.available, same(found));
    expect(store.failed, isFalse);
  });

  test('stays quiet when the published build is the installed one', () async {
    final body = release();
    (body['assets'] as List).first['name'] = 'tunebox-0.1.3+4.apk';
    body['tag_name'] = 'v0.1.3';

    expect(await updates(body).check(), isNull);
  });

  test('stays quiet when the published build is older', () async {
    final body = release();
    (body['assets'] as List).first['name'] = 'tunebox-0.1.2+3.apk';
    body['tag_name'] = 'v0.1.2';

    expect(await updates(body).check(), isNull);
  });

  test('falls back to the tag when the asset name carries no build', () async {
    final body = release();
    (body['assets'] as List).first['name'] = 'tunebox.apk';

    final found = await updates(body).check();

    expect(found, isNotNull);
    expect(found!.build, isNull);
    expect(found.version, '0.1.4');
  });

  test('does not read an equal tag as an update', () async {
    final body = release();
    (body['assets'] as List).first['name'] = 'tunebox.apk';
    body['tag_name'] = 'v0.1.3';

    expect(await updates(body).check(), isNull);
  });

  test('proposes nothing when the release ships no apk', () async {
    final body = release();
    (body['assets'] as List).first['name'] = 'tunebox-0.1.4+5.aab';

    expect(await updates(body).check(), isNull);
  });

  test('answers no news when GitHub rate-limits the check', () async {
    final store = updates(
      {'message': "API rate limit exceeded for 203.0.113.7."},
      status: 403,
    );

    expect(await store.check(), isNull);
    expect(store.failed, isTrue);
  });

  test('answers no news when the body is not the JSON expected', () async {
    final store = updates('<html>maintenance</html>');

    expect(await store.check(), isNull);
    expect(store.failed, isTrue);
  });

  test('answers no news when the network refuses', () async {
    final store = Updates(
      installed: installed,
      directory: directory,
      httpClient: MockClient((_) async => throw const SocketException('down')),
    );

    expect(await store.check(), isNull);
    expect(store.failed, isTrue);
  });

  test('downloads the asset and reports progress on the way', () async {
    final progress = <double>[];
    final store = Updates(
      installed: installed,
      directory: directory,
      httpClient: MockClient(
        (request) async => request.url.path.endsWith('.apk')
            ? http.Response.bytes(List.filled(2048, 7), 200)
            : http.Response(jsonEncode(release()), 200),
      ),
    );
    store.addListener(() {
      if (store.progress != null) progress.add(store.progress!);
    });

    final found = await store.check();
    final file = await store.download(found!);

    expect(file, isNotNull);
    expect(file!.readAsBytesSync(), hasLength(2048));
    expect(file.path, endsWith('.apk'));
    expect(progress, isNotEmpty);
    expect(progress.last, 1);
    // Nothing is left downloading once the file is on disk.
    expect(store.progress, isNull);
  });

  test('keeps no half-written apk when the download breaks', () async {
    final store = Updates(
      installed: installed,
      directory: directory,
      httpClient: MockClient(
        (request) async => request.url.path.endsWith('.apk')
            ? http.Response('nope', 404)
            : http.Response(jsonEncode(release()), 200),
      ),
    );

    final found = await store.check();

    expect(await store.download(found!), isNull);
    expect(store.failed, isTrue);
    expect(directory.listSync(), isEmpty);
    expect(store.progress, isNull);
  });

  group('release notes', () {
    // GitHub keeps the body as Markdown, which is right for the release page
    // and wrong for a bottom sheet: unrendered, the reader gets asterisks and
    // backticks in the middle of the sentence.
    test('drops the marks the sheet cannot draw', () {
      expect(
        plainNotes('Ya **se actualiza sola**, con `--split-per-abi` fuera.'),
        'Ya se actualiza sola, con --split-per-abi fuera.',
      );
    });

    test('takes emphasis off without eating a bullet written with one', () {
      expect(
        plainNotes('No es el *always-on*.\n\n* Lo uno\n* Lo otro'),
        'No es el always-on.\n\n\u2022 Lo uno\n\u2022 Lo otro',
      );
    });

    test('leaves snake_case alone', () {
      expect(plainNotes('Mira `key_properties` y foo_bar_baz.'),
          'Mira key_properties y foo_bar_baz.');
    });

    test('reads a link as the words, not the address', () {
      expect(
        plainNotes('Ver [las notas](https://example.com/x) completas.'),
        'Ver las notas completas.',
      );
    });

    test('joins a paragraph the author wrapped by hand', () {
      expect(
        plainNotes('Una frase que sigue\nen la linea siguiente.'),
        'Una frase que sigue en la linea siguiente.',
      );
    });

    test('keeps one item per line and marks it', () {
      expect(
        plainNotes('### Que cambia\n\n- Lo uno\n- Lo otro'),
        'Que cambia\n\n\u2022 Lo uno\n\u2022 Lo otro',
      );
    });

    test('keeps the blank line between paragraphs', () {
      expect(plainNotes('Uno.\n\nDos.'), 'Uno.\n\nDos.');
    });

    test('answers empty for a release with nothing written', () {
      expect(plainNotes('   \n\n  '), '');
    });
  });

  test('clears an apk left behind by an earlier run', () async {
    File('${directory.path}/tunebox-0.1.4+5.apk').writeAsBytesSync([1, 2, 3]);

    await updates(release()).load();

    expect(directory.listSync(), isEmpty);
  });
}

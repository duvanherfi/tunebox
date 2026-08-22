import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/data/models/song.dart';
import 'package:tunebox/data/retired_ids.dart';
import 'package:tunebox/features/shared/song_pages.dart';
import 'package:tunebox/main.dart' as app;

/// A row the listener took off a list has to leave the screen at once.
///
/// What a tab shows is the page the network answered with, and nobody edits
/// that page: before this, a track removed from the library or from the history
/// stayed on screen until the list was read again, which reads as an action
/// that did not work.
///
/// The lists are kept apart on purpose. Taking a track out of the history says
/// nothing about the library, and a track dropped from one playlist is still in
/// the other.
Song _song(String id) => Song(videoId: id, title: id, subtitle: '');

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() => app.retiredIds.clear());

  Widget pages({required String list, required List<Song> songs}) => SongPages(
        list: list,
        pages: () => Stream.value(songs),
        build: (view) => Text(
          view.songs.map((song) => song.videoId).join(','),
          textDirection: TextDirection.ltr,
        ),
      );

  testWidgets('keeps every track until one is retired', (tester) async {
    await tester.pumpWidget(
      pages(list: RetiredIds.history, songs: [_song('a'), _song('b')]),
    );
    await tester.pump();

    expect(find.text('a,b'), findsOneWidget);
  });

  testWidgets('drops a track retired from this list', (tester) async {
    await tester.pumpWidget(
      pages(list: RetiredIds.history, songs: [_song('a'), _song('b')]),
    );
    await tester.pump();

    app.retiredIds.retire(RetiredIds.history, 'a');
    await tester.pump();

    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('keeps a track retired from a different list', (tester) async {
    await tester.pumpWidget(
      pages(list: RetiredIds.history, songs: [_song('a'), _song('b')]),
    );
    await tester.pump();

    app.retiredIds.retire(RetiredIds.library, 'a');
    await tester.pump();

    expect(find.text('a,b'), findsOneWidget);
  });

  testWidgets('leaves a list that named no surface alone', (tester) async {
    await tester.pumpWidget(
      SongPages(
        pages: () => Stream.value([_song('a'), _song('b')]),
        build: (view) => Text(
          view.songs.map((song) => song.videoId).join(','),
          textDirection: TextDirection.ltr,
        ),
      ),
    );
    await tester.pump();

    app.retiredIds.retire(RetiredIds.history, 'a');
    await tester.pump();

    expect(
      find.text('a,b'),
      findsOneWidget,
      reason: 'an album or a search result offers no way to retire anything, '
          'and must not inherit the withdrawals of another',
    );
  });

  testWidgets('a reload does not bring a retired track back', (tester) async {
    await tester.pumpWidget(
      pages(list: RetiredIds.history, songs: [_song('a'), _song('b')]),
    );
    await tester.pump();

    app.retiredIds.retire(RetiredIds.history, 'a');
    await tester.pump();
    await tester.tap(find.text('b'), warnIfMissed: false);
    await tester.pump();

    expect(find.text('b'), findsOneWidget);
  });

  test('answers for a shelf of playlists as well as one of tracks', () {
    final retired = RetiredIds();

    retired.retire(RetiredIds.playlists, 'VLPL123');

    expect(retired.isRetired(RetiredIds.playlists, 'VLPL123'), isTrue);
    expect(
      retired.isRetired(RetiredIds.library, 'VLPL123'),
      isFalse,
      reason: 'a playlist deleted from its own screen leaves the shelf that '
          'listed it, and nothing else',
    );
  });

  test('keeps the withdrawals of each list apart', () {
    final retired = RetiredIds();

    retired.retire(RetiredIds.history, 'a');

    expect(retired.isRetired(RetiredIds.history, 'a'), isTrue);
    expect(retired.isRetired(RetiredIds.library, 'a'), isFalse);
  });

  test('tells its listeners, so a list on screen can redraw', () {
    final retired = RetiredIds();
    var told = 0;
    retired.addListener(() => told++);

    retired.retire(RetiredIds.history, 'a');

    expect(told, 1);
  });

  test('says nothing when the same track is retired twice', () {
    final retired = RetiredIds();
    retired.retire(RetiredIds.history, 'a');
    var told = 0;
    retired.addListener(() => told++);

    retired.retire(RetiredIds.history, 'a');

    expect(told, 0);
  });
}

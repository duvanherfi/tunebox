import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/data/models/song.dart';
import 'package:tunebox/features/shared/song_pages.dart';

/// A list fed from two sources can be told the same track twice, and the two
/// tellings are not equally useful.
///
/// The history is the case: the device knows what it just played, instantly and
/// with no menu at all — a track read back from the play log is a name and a
/// cover — while the account answers later with the row YouTube attached its
/// actions to. Dropping the second leaves the tracks played here as the only
/// ones that can never be taken out of the history, which is backwards.
Song _song(String id, {String title = ''}) =>
    Song(videoId: id, title: title.isEmpty ? id : title, subtitle: '');

void main() {
  Widget pages({
    required List<List<Song>> emissions,
    bool mergeById = false,
    List<Song> first = const [],
  }) =>
      SongPages(
        first: first,
        mergeById: mergeById,
        pages: () => Stream.fromIterable(emissions),
        build: (view) => Text(
          view.songs.map((song) => song.title).join(','),
          textDirection: TextDirection.ltr,
        ),
      );

  testWidgets('appends a repeated track when told to keep both', (tester) async {
    await tester.pumpWidget(pages(emissions: [
      [_song('a')],
      [_song('a')],
    ]));
    await tester.pumpAndSettle();

    expect(
      find.text('a,a'),
      findsOneWidget,
      reason: 'a playlist can hold the same track twice, and each row is its '
          'own row',
    );
  });

  testWidgets('replaces the earlier telling when merging', (tester) async {
    await tester.pumpWidget(pages(
      mergeById: true,
      emissions: [
        [_song('a', title: 'from the device')],
        [_song('a', title: 'from the account')],
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('from the account'), findsOneWidget);
  });

  testWidgets('keeps the place the track already had', (tester) async {
    await tester.pumpWidget(pages(
      mergeById: true,
      emissions: [
        [_song('a', title: 'first'), _song('b', title: 'second')],
        [_song('a', title: 'again')],
      ],
    ));
    await tester.pumpAndSettle();

    expect(
      find.text('again,second'),
      findsOneWidget,
      reason: 'the history is in the order it was heard, and a page arriving '
          'later does not make the track more recent',
    );
  });

  testWidgets('merges against what was in hand before the reading',
      (tester) async {
    await tester.pumpWidget(pages(
      mergeById: true,
      first: [_song('a', title: 'from the device')],
      emissions: [
        [_song('a', title: 'from the account')],
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('from the account'), findsOneWidget);
  });
}

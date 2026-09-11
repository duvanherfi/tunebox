import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/core/innertube/innertube_client.dart';
import 'package:tunebox/data/models/playlist.dart';
import 'package:tunebox/features/home/home_feed_screen.dart';
import 'package:tunebox/l10n/app_localizations.dart';
import 'package:tunebox/main.dart' as app;

/// The front page arrives a handful of shelves at a time.
///
/// `FEmusic_home` hands over six and hides the rest behind a continuation, so
/// the screen that asked once was showing a third of the page and calling it
/// the front page. What is asked for and when is the whole of it: the first
/// page on opening, the next only once the list has been scrolled that far, and
/// a fresh first page whenever a mood chip is tapped.
typedef _HomePage = ({
  List<Shelf> shelves,
  List<Playlist> chips,
  String? nextToken,
});

class _StubInnertube extends InnertubeClient {
  /// Every call, in order, so a test can say what was asked and what was not.
  final asked = <({String? params, String? continuation})>[];

  /// What to answer with. Set per test.
  late Future<_HomePage> Function(String? params, String? continuation) answer;

  @override
  Future<_HomePage> homeFeed({String? params, String? continuation}) {
    asked.add((params: params, continuation: continuation));
    return answer(params, continuation);
  }
}

/// A shelf of one cover, with no thumbnail: what is being counted here is rows
/// arriving, and a test that loads images counts the network instead.
Shelf _shelf(String title) => Shelf(
      title: title,
      playlists: [Playlist(browseId: 'VL$title', title: '$title cover')],
    );

List<Shelf> _shelves(String prefix, int count) =>
    [for (var i = 1; i <= count; i++) _shelf('$prefix$i')];

const _moods = [
  Playlist(browseId: 'FEmusic_home', title: 'Relax', params: 'relaxToken'),
  Playlist(browseId: 'FEmusic_home', title: 'Fiesta', params: 'partyToken'),
];

void main() {
  late _StubInnertube innertube;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    innertube = _StubInnertube();
    app.innertube = innertube;
  });

  setUp(() => innertube.asked.clear());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: HomeFeedScreen()),
      ),
    );
    // One for the request, one for the frame that paints its answer.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('asks for the next page only once the list reaches its foot',
      (tester) async {
    // Five rows are taller than the viewport and its cache extent, so the foot
    // of the list is not built until it is scrolled to.
    innertube.answer = (params, continuation) async => switch (continuation) {
          null => (
            shelves: _shelves('first', 5),
            chips: _moods,
            nextToken: 'page2',
          ),
          _ => (
            shelves: _shelves('second', 2),
            chips: const <Playlist>[],
            nextToken: null,
          ),
        };

    await open(tester);

    expect(find.text('first1'), findsOneWidget);
    expect(
      innertube.asked,
      hasLength(1),
      reason: 'nothing has been scrolled to yet',
    );

    await tester.drag(find.text('first1'), const Offset(0, -2000));
    await tester.pump();
    await tester.pump();

    expect(innertube.asked.last.continuation, 'page2');
    expect(find.text('second1'), findsOneWidget);
    expect(
      find.text('first5'),
      findsOneWidget,
      reason: 'a page lands under what was already read, not over it',
    );
  });

  testWidgets('a mood asks for the front page again with its token',
      (tester) async {
    innertube.answer = (params, continuation) async => (
          shelves: params == null ? _shelves('plain', 1) : _shelves('relax', 1),
          chips: _moods,
          nextToken: null,
        );

    await open(tester);
    expect(find.text('plain1'), findsOneWidget);

    await tester.tap(find.text('Relax'));
    await tester.pump();
    await tester.pump();

    expect(innertube.asked.last.params, 'relaxToken');
    expect(find.text('relax1'), findsOneWidget);
    expect(
      find.text('plain1'),
      findsNothing,
      reason: 'a mood refilters the page rather than adding to it',
    );
  });

  testWidgets('keeps what arrived when a later page never does', (tester) async {
    innertube.answer = (params, continuation) async {
      if (continuation != null) throw InnertubeException('no network');
      return (
        shelves: _shelves('first', 5),
        chips: _moods,
        nextToken: 'page2',
      );
    };

    await open(tester);
    await tester.drag(find.text('first1'), const Offset(0, -2000));
    await tester.pump();
    await tester.pump();

    expect(find.text('first5'), findsOneWidget);
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'the reading stops there rather than spinning for a page that '
          'is not coming',
    );
  });

  testWidgets('says so when the first page fails, and tries again',
      (tester) async {
    var attempts = 0;
    innertube.answer = (params, continuation) async {
      if (++attempts == 1) throw InnertubeException('no network');
      return (
        shelves: _shelves('first', 1),
        chips: _moods,
        nextToken: null,
      );
    };

    await open(tester);
    expect(find.textContaining('no network'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump();

    expect(find.text('first1'), findsOneWidget);
  });
}

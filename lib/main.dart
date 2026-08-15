import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'core/audio/player_service.dart';
import 'core/auth/session.dart';
import 'core/innertube/innertube_client.dart';
import 'core/lyrics/lyrics_client.dart';
import 'core/scrobble/scrobbler.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'data/audio_cache.dart';
import 'data/backup.dart';
import 'data/downloads.dart';
import 'data/likes.dart';
import 'data/play_history.dart';
import 'data/recent_searches.dart';
import 'data/settings.dart';
import 'features/home/home_screen.dart';
import 'l10n/app_localizations.dart';

/// Single shared instances. The audio handler is a process-wide singleton by
/// nature — there is exactly one media session — and the session and API client
/// follow it, so routing them through a state management package would add
/// indirection without adding anything else.
late final PlayerService playerService;
late final InnertubeClient innertube;
late final Session session;
late final ThemeController themeController;
late final PlayHistory playHistory;
late final Settings settings;
late final Downloads downloads;
late final AudioCache audioCache;
late final Scrobbler scrobbler;
late final Backup backup;
late final Likes likes;
late final RecentSearches recentSearches;
final LyricsClient lyricsClient = LyricsClient();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restored before the first frame so the library tab knows whether it is
  // signed in without flashing the login prompt.
  session = Session();
  await session.load();

  // Loaded before the first frame so the app never flashes the wrong theme.
  themeController = ThemeController();
  await themeController.load();

  // Loaded up front so the History tab can show what this device played
  // without waiting on the network.
  playHistory = PlayHistory();
  await playHistory.load();

  settings = Settings();
  await settings.load();

  // Loaded before the first frame so a downloaded track plays offline without
  // a moment of pretending it has to be fetched.
  downloads = Downloads();
  await downloads.load();

  audioCache = AudioCache();
  await audioCache.load();

  scrobbler = Scrobbler();
  await scrobbler.load();

  backup = Backup(history: playHistory);
  await backup.load();
  // Not awaited: a copy is worth writing, never worth delaying the first frame.
  unawaited(backup.maybeWriteAutomatic());

  // Built from the device locale so search results come back in the same
  // language the interface is drawn in.
  final locale = PlatformDispatcher.instance.locale;
  innertube = InnertubeClient(
    session: session,
    hl: locale.languageCode,
    gl: locale.countryCode ?? 'US',
  );
  // Resolved here because the audio handler runs without a widget tree, and
  // the shelf names a car shows still have to be in the listener's language.
  final l10n = await AppLocalizations.delegate.load(
    AppLocalizations.delegate.isSupported(locale) ? locale : const Locale('en'),
  );

  likes = Likes(innertube);

  recentSearches = RecentSearches();
  await recentSearches.load();

  playerService = await AudioService.init(
    builder: () => PlayerService(
      innertube,
      playHistory,
      settings,
      downloads,
      audioCache,
      scrobbler,
      likes,
      (downloads: l10n.libraryDownloads, history: l10n.libraryHistory),
    ),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.tunebox.tunebox.audio',
      androidNotificationChannelName: 'Reproducción',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      // A flat silhouette, not the launcher icon: Android tints the status bar
      // icon solid white and a full-colour one arrives as a smudge.
      androidNotificationIcon: 'drawable/ic_notification',
      // Covers arrive at 544 px and the shade draws them much smaller; keeping
      // the full size costs memory on every track change for no visible gain.
      artDownscaleWidth: 320,
      artDownscaleHeight: 320,
      // How a car should lay the browsing tree out: the two shelves as a list
      // of categories, their tracks as a grid of covers. Without declaring
      // support, Android Auto falls back to its plainest list for everything.
      androidBrowsableRootExtras: const {
        AndroidContentStyle.supportedKey: true,
        AndroidContentStyle.browsableHintKey:
            AndroidContentStyle.categoryListItemHintValue,
        AndroidContentStyle.playableHintKey:
            AndroidContentStyle.gridItemHintValue,
      },
    ),
  );

  // The colours follow whatever is playing, when that is switched on.
  playerService.mediaItem.listen(
    (item) => themeController.adoptArtwork(item?.artUri?.toString()),
  );

  runApp(const TuneboxApp());
}

class TuneboxApp extends StatelessWidget {
  const TuneboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => MaterialApp(
        title: 'Tunebox',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(themeController.lightFromArtwork),
        darkTheme: AppTheme.dark(themeController.darkFromArtwork),
        themeMode: themeController.mode,
        // Flutter resolves the device locale against this list and falls back
        // to English when the phone speaks something we do not.
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/audio/player_service.dart';
import 'core/auth/session.dart';
import 'core/innertube/innertube_client.dart';
import 'core/install/installer.dart';
import 'core/lyrics/lyrics_client.dart';
import 'core/scrobble/scrobbler.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/browser_session.dart';
import 'features/shared/app_background.dart';
import 'data/account_store.dart';
import 'data/audio_cache.dart';
import 'data/backup.dart';
import 'data/device_songs.dart';
import 'data/downloads.dart';
import 'data/home_widget_bridge.dart';
import 'data/likes.dart';
import 'data/music_folders.dart';
import 'data/saved_collections.dart';
import 'data/local_playlists.dart';
import 'data/play_history.dart';
import 'data/recent_searches.dart';
import 'data/retired_ids.dart';
import 'data/resume_point.dart';
import 'data/settings.dart';
import 'data/updates.dart';
import 'features/home/home_screen.dart';
import 'features/nightstand/charge_watcher.dart';
import 'features/settings/update_sheet.dart';
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
late final AccountStore accountStore;
late final LocalPlaylists localPlaylists;
late final SavedCollections savedCollections;
late final MusicFolders musicFolders;
late final DeviceSongs deviceSongs;
late final RecentSearches recentSearches;

/// What was taken off a list here, so the list on screen stops showing it.
/// Nothing to load: it only ever holds this session's own withdrawals.
final RetiredIds retiredIds = RetiredIds();
late final ResumePoint resumePoint;
late final Updates updates;

/// The navigator, reachable from things that are not widgets. The nightstand's
/// charge watcher is the first of them: it lives on a stream, not on a screen.
final navigatorKey = GlobalKey<NavigatorState>();

late final ChargeWatcher chargeWatcher;
final LyricsClient lyricsClient = LyricsClient();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restored before the first frame so the library tab knows whether it is
  // signed in without flashing the login prompt.
  session = Session(forgetBrowser: forgetBrowserSession);
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
  await likes.load();
  // Not awaited: the saved list is what the hearts read while the account's own
  // is on its way, and that read is a dozen requests.
  unawaited(likes.refresh());

  localPlaylists = LocalPlaylists();
  await localPlaylists.load();

  savedCollections = SavedCollections(innertube: innertube);
  await savedCollections.load();

  // Not awaited: the corner shows an icon until the photo arrives, and a
  // portrait is never worth delaying the first frame for.
  accountStore = AccountStore(innertube, session);
  unawaited(accountStore.refresh());

  recentSearches = RecentSearches();
  await recentSearches.load();

  // Loaded before the tab that reads it, because loading is what reopens the
  // bookmarked folders: on macOS the paths are not reachable until it has run.
  musicFolders = MusicFolders();
  await musicFolders.load();
  deviceSongs = DeviceSongs(folders: musicFolders);

  // Read before the handler exists, so the first frame can already show what
  // was playing when the app was last closed.
  resumePoint = ResumePoint();
  await resumePoint.load();

  playerService = await AudioService.init(
    builder: () => PlayerService(
      innertube,
      playHistory,
      settings,
      downloads,
      audioCache,
      scrobbler,
      likes,
      resumePoint,
      (
        likes: l10n.libraryLikes,
        playlists: l10n.libraryPlaylists,
        albums: l10n.libraryAlbums,
        artists: l10n.libraryArtists,
        downloads: l10n.libraryDownloads,
        history: l10n.libraryHistory,
        shuffle: l10n.shuffle,
        repeat: l10n.repeat,
        radio: l10n.menuRadio,
      ),
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

  // Paused, at the second it stopped on: reopening the app answers "what was
  // I listening to" without asking the network anything.
  await playerService.restore();

  // What the launcher's widget shows, for as long as the app is alive; its
  // buttons keep working after that, since they talk to the service directly.
  HomeWidgetBridge().listen(playerService);

  // The colours follow whatever is playing, when that is switched on.
  playerService.mediaItem.listen(
    (item) => themeController.adoptArtwork(item?.artUri?.toString()),
  );

  // Started before the first frame; the key it holds is only read once a
  // battery event arrives, which is long after the navigator exists.
  chargeWatcher = ChargeWatcher(navigatorKey: navigatorKey)..start();

  // Only Android can install what this would find, and load() reads the
  // package info the settings screen shows besides.
  updates = Updates();
  if (Installer.isSupported) await updates.load();

  runApp(const TuneboxApp());

  // Asked after the first frame is on its way, so the dialog has a window to
  // land on.
  unawaited(_askAboutNotifications());

  // Not awaited either: a release from last week can wait for the network,
  // and nothing on screen depends on the answer.
  unawaited(_maybeOfferUpdate());
}

/// Looks for a new release once a day, and speaks only when there is one.
///
/// Silence is the whole design: an updater that reports "you are up to date"
/// unasked is noise, and one that reports a tunnel is noise about something
/// nobody can act on. Both answers are kept for the button in settings, which
/// was asked.
Future<void> _maybeOfferUpdate() async {
  if (!Installer.isSupported || !settings.updateCheck) return;

  final last = DateTime.fromMillisecondsSinceEpoch(settings.updateCheckedAt);
  if (DateTime.now().difference(last) < const Duration(days: 1)) return;

  final release = await updates.check();
  await settings.setUpdateCheckedAt(DateTime.now());
  if (release == null) return;

  final context = navigatorKey.currentContext;
  if (context == null || !context.mounted) return;
  await showUpdateSheet(context);
}

/// Asks for the notification permission Android 13 introduced.
///
/// Declaring it in the manifest is not enough — it is denied until the user is
/// actually asked — and audio_service does not ask on the app's behalf. Without
/// the grant the playback notification is dropped in silence, which leaves a
/// music player that cannot be controlled from the lock screen, the shade or a
/// watch, and gives no hint why.
///
/// Only ever asked when the answer is still open: a refusal is remembered by
/// the system, and this returns without putting a dialog up again.
Future<void> _askAboutNotifications() async {
  if (!Platform.isAndroid) return;
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

class TuneboxApp extends StatelessWidget {
  const TuneboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => MaterialApp(
        title: 'Tunebox',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(
          themeController.lightFromArtwork,
          themeController.seed == null ? null : Color(themeController.seed!),
        ),
        darkTheme: AppTheme.dark(
          themeController.darkFromArtwork,
          themeController.seed == null ? null : Color(themeController.seed!),
        ),
        themeMode: themeController.mode,
        // Flutter resolves the device locale against this list and falls back
        // to English when the phone speaks something we do not.
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // The wash lives behind every route rather than inside one screen, so
        // it stays put while navigating instead of sliding with the page.
        builder: (context, child) => AppBackground(child: child!),
        home: const HomeScreen(),
      ),
    );
  }
}

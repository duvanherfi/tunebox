import 'dart:ui' show PlatformDispatcher;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'core/audio/player_service.dart';
import 'core/auth/session.dart';
import 'core/innertube/innertube_client.dart';
import 'core/lyrics/lyrics_client.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'data/downloads.dart';
import 'data/play_history.dart';
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

  // Built from the device locale so search results come back in the same
  // language the interface is drawn in.
  final locale = PlatformDispatcher.instance.locale;
  innertube = InnertubeClient(
    session: session,
    hl: locale.languageCode,
    gl: locale.countryCode ?? 'US',
  );
  playerService = await AudioService.init(
    builder: () => PlayerService(innertube, playHistory, settings, downloads),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.tunebox.tunebox.audio',
      androidNotificationChannelName: 'Reproducción',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
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

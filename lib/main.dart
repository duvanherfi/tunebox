import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'core/audio/player_service.dart';
import 'core/innertube/innertube_client.dart';
import 'features/search/search_screen.dart';

/// Single shared instance. The audio handler is a process-wide singleton by
/// nature — there is exactly one media session — so routing it through a state
/// management package would add indirection without adding anything else.
late final PlayerService playerService;
late final InnertubeClient innertube;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  innertube = InnertubeClient();
  playerService = await AudioService.init(
    builder: () => PlayerService(innertube),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.tunebox.tunebox.audio',
      androidNotificationChannelName: 'Reproducción',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(const TuneboxApp());
}

class TuneboxApp extends StatelessWidget {
  const TuneboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tunebox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF0033),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0B0F),
      ),
      home: const SearchScreen(),
    );
  }
}

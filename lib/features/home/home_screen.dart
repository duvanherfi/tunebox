import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../account/account_sheet.dart';
import '../library/library_screen.dart';
import '../player/player_sheet.dart';
import '../search/search_screen.dart';
import 'home_feed_screen.dart';

/// Shell holding the two top-level surfaces, the navigation, and the player.
///
/// Everything is stacked rather than slotted into the Scaffold, because the
/// player has to be able to grow over the navigation bar. An IndexedStack keeps
/// search results and loaded library shelves alive across tab switches.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _navHeight = 80.0;

  int _index = 0;

  @override
  void initState() {
    super.initState();
    session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tunebox'),
        actions: [
          IconButton(
            tooltip: l10n.accountTooltip,
            icon: Icon(
              session.isSignedIn
                  ? Icons.account_circle
                  : Icons.account_circle_outlined,
            ),
            onPressed: () => showAccountSheet(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Padded so the collapsed player and the navigation never sit on top
          // of the last row of a list — but only reserving the player's height
          // once there is a player, since the sheet draws nothing until a track
          // is loaded and the gap would otherwise show as dead space.
          StreamBuilder<MediaItem?>(
            stream: playerService.mediaItem,
            builder: (context, snapshot) {
              final playerHeight = snapshot.data == null
                  ? 0.0
                  : PlayerSheetState.collapsedHeight;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: _navHeight + playerHeight + bottomSafe,
                ),
                child: IndexedStack(
                  index: _index,
                  children: const [
                    HomeFeedScreen(),
                    SearchScreen(),
                    LibraryScreen(),
                  ],
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (index) => setState(() => _index = index),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home_rounded),
                  label: l10n.navHome,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.search_rounded),
                  label: l10n.navSearch,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.library_music_outlined),
                  selectedIcon: const Icon(Icons.library_music_rounded),
                  label: l10n.navLibrary,
                ),
              ],
            ),
          ),
          PlayerSheet(bottomInset: _navHeight + bottomSafe),
        ],
      ),
    );
  }
}

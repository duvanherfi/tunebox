import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../account/account_avatar.dart';
import '../browse/explore_screen.dart';
import '../library/library_screen.dart';
import '../shared/measured.dart';
import 'floating_nav.dart';
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
  /// Space between the floating bar and the screen's bottom edge.
  static const _navGap = 10.0;

  /// What the floating bar occupies in total: its own height, the gesture inset
  /// under it and the gap. A starting guess only — the first frame corrects it.
  double _navHeight = 92;

  /// Which tab is showing. A notifier rather than plain state because the tabs
  /// now live inside a route of the nested navigator, and a route does not
  /// rebuild just because the widget that generated it did.
  final _index = ValueNotifier(0);

  /// The navigator the tabs push into. Its routes land *inside* the shell, so
  /// the player and the navigation stay on top of a playlist or an album —
  /// which is the whole point: what is playing should not disappear the moment
  /// you open the list you are playing from.
  final _tabs = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    session.removeListener(_onSessionChanged);
    _index.dispose();
    super.dispose();
  }

  /// Tapping a tab goes to that tab, not to whatever was left open on top of
  /// it. One stack shared by four tabs is only confusing if it is never
  /// unwound.
  void _select(int index) {
    _tabs.currentState?.popUntil((route) => route.isFirst);
    _index.value = index;
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // The header lives in the body rather than in the Scaffold, so the player
    // can rise over it: a full-screen now-playing view with the app's title
    // still showing above it would look like a dialog, not a screen.
    return PopScope(
      // Back unwinds what the tabs opened before it ever leaves the app.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final navigator = _tabs.currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        } else {
          Navigator.of(context, rootNavigator: true).maybePop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Padded so the floating navigation and the collapsed player never
            // sit on top of the last row of a list — and only by the player's
            // height once there is a player, since the sheet draws nothing
            // until a track is loaded. The padding wraps the navigator rather
            // than the tabs, so a pushed page is inset by the same amount.
            StreamBuilder<MediaItem?>(
              stream: playerService.mediaItem,
              builder: (context, snapshot) {
                final playerHeight = snapshot.data == null
                    ? 0.0
                    // The bar plus the air under it, so a list ends above the
                    // pair rather than behind either of them.
                    : PlayerSheetState.collapsedHeight + PlayerSheetState.gap;
                return Padding(
                  padding: EdgeInsets.only(bottom: _navHeight + playerHeight),
                  child: Navigator(
                    key: _tabs,
                    onGenerateRoute: (_) => MaterialPageRoute(
                      builder: (_) => Column(
                        children: [
                          AppBar(
                            title: const Text('Tunebox'),
                            actions: const [
                              Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: AccountAvatar(),
                              ),
                            ],
                          ),
                          Expanded(
                            child: ValueListenableBuilder<int>(
                              valueListenable: _index,
                              builder: (context, index, _) => IndexedStack(
                                index: index,
                                children: const [
                                  HomeFeedScreen(),
                                  ExploreScreen(),
                                  SearchScreen(),
                                  LibraryScreen(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 10,
              child: Measured(
                // What it actually measures, so the content above it is padded
                // by exactly that and never by a guess.
                onSize: (size) {
                  final total =
                      size.height + MediaQuery.paddingOf(context).bottom + _navGap;
                  if (total != _navHeight) setState(() => _navHeight = total);
                },
                child: ValueListenableBuilder<int>(
                  valueListenable: _index,
                  builder: (context, index, _) => FloatingNav(
                    index: index,
                    onSelected: _select,
                    destinations: [
                      NavDestination(
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home_rounded,
                        label: l10n.navHome,
                      ),
                      NavDestination(
                        icon: Icons.explore_outlined,
                        selectedIcon: Icons.explore_rounded,
                        label: l10n.navExplore,
                      ),
                      NavDestination(
                        icon: Icons.search_outlined,
                        selectedIcon: Icons.search_rounded,
                        label: l10n.navSearch,
                      ),
                      NavDestination(
                        icon: Icons.library_music_outlined,
                        selectedIcon: Icons.library_music_rounded,
                        label: l10n.navLibrary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PlayerSheet(bottomInset: _navHeight),
          ],
        ),
      ),
    );
  }
}

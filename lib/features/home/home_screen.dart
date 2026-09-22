import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
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

  /// The player, asked first whenever back is pressed.
  final _player = GlobalKey<PlayerSheetState>();

  @override
  void initState() {
    super.initState();
    session.addListener(_onSessionChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  /// Tells Android again, on every return, that back is ours to answer.
  ///
  /// Flutter only reports that when navigation changes, and Android forgets it
  /// with the activity. Leaving by back finishes the activity but not the
  /// engine — audio_service keeps it running for playback — so coming back
  /// builds a new activity on the same widget tree, nothing navigates, and
  /// until something did, back skipped the shell entirely and closed the app
  /// even with the player open.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemNavigator.setFrameworkHandlesBack(true);
    }
  }

  @override
  void dispose() {
    session.removeListener(_onSessionChanged);
    WidgetsBinding.instance.removeObserver(this);
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
    final media = MediaQuery.of(context);

    // The header lives in the body rather than in the Scaffold, so the player
    // can rise over it: a full-screen now-playing view with the app's title
    // still showing above it would look like a dialog, not a screen.
    return PopScope(
      // The only answer to back in the shell, and in this order: an open
      // player closes, then the tabs unwind what they opened, and only then
      // does the app leave.
      //
      // One handler rather than one per surface, because every PopScope on a
      // route hears the same back press — with the player keeping its own, a
      // single press closed the panel and unwound a tab at once. And leaving
      // is SystemNavigator.pop, not the root navigator's maybePop: this route
      // refuses to pop, so maybePop called straight back into this handler,
      // which called maybePop again. The loop never yielded — each round a
      // Future, each one a platform message — and on a device it held the main
      // thread until the Java heap filled and Android killed the app.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final player = _player.currentState;
        final navigator = _tabs.currentState;
        if (player != null && player.isExpanded) {
          player.collapse();
        } else if (navigator != null && navigator.canPop()) {
          navigator.pop();
        } else {
          SystemNavigator.pop();
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
                // Handed down rather than cut off: padding here would shrink
                // the viewport and leave the app's own background showing as a
                // band under every list. The content runs to the bottom edge
                // and passes behind the bars — which is the whole point of
                // letting them be see-through — while each list adds this to
                // its own bottom padding so its last row is still reachable.
                return MediaQuery(
                  data: media.copyWith(
                    padding: media.padding.copyWith(
                      bottom: media.padding.bottom + _navHeight + playerHeight,
                    ),
                  ),
                  // Kept from reaching the app. Every navigator reports up
                  // whether it can take a back press, and the app hands the
                  // last report to Android; this one reports "no" whenever a
                  // tab is at its root, which overrode the shell's "yes" and
                  // let Android close the app on back — player open or not.
                  // The shell answers back in every state, so it is the only
                  // report that should land.
                  child: NotificationListener<NavigationNotification>(
                    onNotification: (_) => true,
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
            PlayerSheet(key: _player, bottomInset: _navHeight),
          ],
        ),
      ),
    );
  }
}

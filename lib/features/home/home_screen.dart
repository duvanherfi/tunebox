import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../core/theme/theme_controller.dart';
import '../../main.dart';
import '../auth/login_screen.dart';
import '../library/library_screen.dart';
import '../player/player_sheet.dart';
import '../search/search_screen.dart';

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

  /// Theme picker as a bottom sheet: it lives one tap from anywhere and does
  /// not warrant a screen of its own for a single choice.
  Future<void> _pickTheme() async {
    final l10n = AppLocalizations.of(context)!;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => ListenableBuilder(
        listenable: themeController,
        builder: (context, _) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.themeTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              RadioGroup<ThemeMode>(
                groupValue: themeController.mode,
                onChanged: (picked) {
                  if (picked != null) themeController.select(picked);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final mode in ThemeController.options)
                      RadioListTile<ThemeMode>(
                        value: mode,
                        title: Text(_themeLabel(l10n, mode)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  static String _themeLabel(AppLocalizations l10n, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => l10n.themeLight,
      ThemeMode.dark => l10n.themeDark,
      ThemeMode.system => l10n.themeSystem,
    };
  }

  Future<void> _account() async {
    final l10n = AppLocalizations.of(context)!;
    if (session.isSignedIn) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.signOut),
          content: Text(l10n.signOutBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.signOut),
            ),
          ],
        ),
      );
      if (confirmed ?? false) await session.signOut();
    } else {
      if (!mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => LoginScreen(session: session)),
      );
    }
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
            tooltip: l10n.themeTooltip,
            icon: const Icon(Icons.palette_outlined),
            onPressed: _pickTheme,
          ),
          IconButton(
            tooltip: session.isSignedIn ? l10n.signOut : l10n.signIn,
            icon: Icon(
              session.isSignedIn
                  ? Icons.account_circle
                  : Icons.account_circle_outlined,
            ),
            onPressed: _account,
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
                  children: const [SearchScreen(), LibraryScreen()],
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

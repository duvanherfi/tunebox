import 'package:flutter/material.dart';

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

  Future<void> _account() async {
    if (session.isSignedIn) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text(
            'Se borrarán las cookies guardadas en este dispositivo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cerrar sesión'),
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
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tunebox'),
        actions: [
          IconButton(
            tooltip: session.isSignedIn ? 'Cerrar sesión' : 'Iniciar sesión',
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
          // of the last row of a list.
          Padding(
            padding: EdgeInsets.only(
              bottom: _navHeight + PlayerSheetState.collapsedHeight + bottomSafe,
            ),
            child: IndexedStack(
              index: _index,
              children: const [SearchScreen(), LibraryScreen()],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (index) => setState(() => _index = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.search_rounded),
                  label: 'Buscar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music_rounded),
                  label: 'Biblioteca',
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

import 'package:flutter/material.dart';

import '../../main.dart';
import '../auth/login_screen.dart';
import '../library/library_screen.dart';
import '../player/mini_player.dart';
import '../search/search_screen.dart';

/// Shell holding the two top-level surfaces plus the persistent mini player.
///
/// An IndexedStack rather than swapping widgets, so search results and loaded
/// library shelves survive switching tabs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tunebox'),
        backgroundColor: Colors.transparent,
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
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [SearchScreen(), LibraryScreen()],
            ),
          ),
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: 'Biblioteca',
          ),
        ],
      ),
    );
  }
}

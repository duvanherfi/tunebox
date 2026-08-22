import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../main.dart';

/// The folders someone pointed the app at, on top of what the platform gives.
///
/// Desktop only. Android hands over its whole shared storage behind a single
/// permission, so there is nothing to pick there; a sandboxed Mac hands over
/// Music and Downloads and nothing else, which is what this screen is for.
class MusicFoldersScreen extends StatelessWidget {
  const MusicFoldersScreen({super.key});

  /// Where a folder outside the default ones is worth asking for. Not the web,
  /// which has no file system of its own to walk.
  static bool get isSupported =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsMusicFolders)),
      body: ListenableBuilder(
        listenable: musicFolders,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                l10n.musicFoldersBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (musicFolders.folders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l10n.musicFoldersEmpty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final folder in musicFolders.folders)
              ListTile(
                leading: Icon(
                  folder.available
                      ? Icons.folder_outlined
                      : Icons.folder_off_outlined,
                  color: folder.available
                      ? null
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(folder.name),
                // The full path, because two folders called Music are the
                // normal case and the name alone cannot tell them apart.
                subtitle: Text(
                  folder.available
                      ? folder.path
                      : '${folder.path}\n${l10n.musicFoldersUnavailable}',
                ),
                isThreeLine: !folder.available,
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: l10n.musicFoldersRemove,
                  onPressed: () => _remove(folder.path),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: _add,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: Text(l10n.musicFoldersAdd),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Picking a folder is what grants access to it, so the scan follows the
  /// pick: leaving the tab to be refreshed by hand would show an empty list
  /// right after someone said where the music is.
  Future<void> _add() async {
    final path = await getDirectoryPath();
    if (path == null) return;

    await musicFolders.add(path);
    await deviceSongs.scan();
  }

  Future<void> _remove(String path) async {
    await musicFolders.remove(path);
    await deviceSongs.scan();
  }
}

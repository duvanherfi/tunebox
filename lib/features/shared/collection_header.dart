import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import 'collection_menu.dart';

/// Cover, name, and everything one can do to a collection as a whole.
///
/// The two ways in — straight through or shuffled — are the buttons; the rest
/// (keeping it, its radio, the long list of the rest) sits underneath as icons,
/// because a phone in portrait cannot hold five labelled controls in a row
/// without breaking one of them onto two lines.
///
/// [collection] is what the actions act on. Without it only the two ways in are
/// offered. An artist's page uses this header too, with [artist] set: the same
/// three controls, except that keeping an artist is subscribing to them and
/// their mix is an id of its own rather than one derived from the page's.
class CollectionHeader extends StatelessWidget {
  const CollectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.thumbnailUrl,
    required this.songs,
    this.collection,
    this.round = false,
    this.artist = false,
    this.radioPlaylistId,
    this.onRename,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final String? thumbnailUrl;
  final List<Song> songs;
  final Playlist? collection;

  /// Artists are people, and a circle reads as one; a record is a square.
  final bool round;

  /// Whether [collection] is an artist, which changes what keeping it means.
  final bool artist;

  /// The mix to start, when it is not the collection's own id.
  final String? radioPlaylistId;

  /// Offered only on a list the account made. Null everywhere else — on an
  /// album, on an artist, and on a playlist that was saved rather than made,
  /// none of which is anybody's here to rename or delete.
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final collection = this.collection;

    return Stack(
      children: [
        // The cover again, blurred and fading out behind its own header, so a
        // record's page takes the colour of the record.
        if (thumbnailUrl != null)
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
                stops: const [0, 0.7, 0.92],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Image.network(
                  thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(
            children: [
              Artwork(
                url: thumbnailUrl,
                size: 200,
                radius: round ? 100 : AppTheme.radiusCard,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: songs.isEmpty
                        ? null
                        : () async {
                            await playerService.setShuffleMode(
                              AudioServiceShuffleMode.none,
                            );
                            await playerService.setQueue(songs);
                          },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(l10n.play),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: songs.isEmpty
                        ? null
                        : () async {
                            // Shuffle first, so the queue arrives already scrambled
                            // rather than starting on track one and jumping.
                            await playerService.setShuffleMode(
                              AudioServiceShuffleMode.all,
                            );
                            await playerService.setQueue(songs);
                          },
                    icon: const Icon(Icons.shuffle_rounded),
                    label: Text(l10n.shuffle),
                  ),
                ],
              ),
              if (collection != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ListenableBuilder(
                      listenable: savedCollections,
                      builder: (context, _) {
                        final saved = savedCollections.isSaved(
                          collection.browseId,
                        );
                        return IconButton(
                          tooltip: artist
                              ? (saved
                                    ? l10n.artistUnsubscribe
                                    : l10n.artistSubscribe)
                              : (saved
                                    ? l10n.collectionRemove
                                    : l10n.collectionSave),
                          onPressed: () => toggleCollectionSaved(
                            context,
                            collection,
                            artist: artist,
                          ),
                          icon: Icon(
                            artist
                                ? (saved
                                      ? Icons.how_to_reg_rounded
                                      : Icons.person_add_alt_1_rounded)
                                : (saved
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded),
                            color: saved ? theme.colorScheme.primary : null,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: l10n.menuRadio,
                      onPressed: () => startCollectionRadio(
                        context,
                        collection,
                        radioId: radioPlaylistId,
                      ),
                      icon: const Icon(Icons.radio_rounded),
                    ),
                    IconButton(
                      tooltip: l10n.collectionMore,
                      onPressed: () => showCollectionMenu(
                        context,
                        collection: collection,
                        songs: songs,
                        artist: artist,
                        radioId: radioPlaylistId,
                        onRename: onRename,
                        onDelete: onDelete,
                      ),
                      icon: const Icon(Icons.more_vert_rounded),
                    ),
                  ],
                ),
              ] else
                const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

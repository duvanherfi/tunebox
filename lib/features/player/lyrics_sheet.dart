import 'package:flutter/material.dart';

import '../../core/lyrics/lyrics.dart';
import '../../data/models/song.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';

/// The words, following the music when the source knew when to.
Future<void> showLyricsSheet(BuildContext context, Song song) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.8,
    ),
    builder: (_) => _LyricsSheet(song: song),
  );
}

class _LyricsSheet extends StatefulWidget {
  const _LyricsSheet({required this.song});

  final Song song;

  @override
  State<_LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<_LyricsSheet> {
  late final Future<Lyrics?> _lyrics = lyricsClient.forSong(widget.song);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(
            widget.song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Flexible(
          child: FutureBuilder<Lyrics?>(
            future: _lyrics,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final lyrics = snapshot.data;
              if (lyrics == null) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                  child: Text(
                    l10n.lyricsNone,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              if (!lyrics.isSynced) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  child: Text(
                    lyrics.plain,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                );
              }

              return _SyncedLyrics(lyrics: lyrics);
            },
          ),
        ),
      ],
    );
  }
}

/// Timed lyrics that follow playback: the current line is lit and held near the
/// middle of the panel, so reading it never means chasing it.
class _SyncedLyrics extends StatefulWidget {
  const _SyncedLyrics({required this.lyrics});

  final Lyrics lyrics;

  @override
  State<_SyncedLyrics> createState() => _SyncedLyricsState();
}

class _SyncedLyricsState extends State<_SyncedLyrics> {
  static const _lineHeight = 56.0;

  final _controller = ScrollController();
  int _current = -1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _followTo(int index, double viewport) {
    if (index == _current || !_controller.hasClients) return;
    _current = index;
    final target = (index * _lineHeight) - viewport / 2 + _lineHeight;
    _controller.animateTo(
      target.clamp(0.0, _controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return StreamBuilder<Duration>(
          stream: playerService.player.positionStream,
          builder: (context, snapshot) {
            final active = widget.lyrics.indexAt(
              snapshot.data ?? Duration.zero,
            );

            // Scrolling during a build would be a layout mutation mid-layout,
            // so the follow happens once the frame is on screen.
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _followTo(active, constraints.maxHeight),
            );

            return ListView.builder(
              controller: _controller,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 80),
              itemCount: widget.lyrics.lines.length,
              itemBuilder: (context, index) {
                final sung = index == active;
                return SizedBox(
                  height: _lineHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: theme.textTheme.titleMedium!.copyWith(
                        color: sung
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                        fontWeight: sung ? FontWeight.w700 : FontWeight.w500,
                      ),
                      child: Text(widget.lyrics.lines[index].text),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/lyrics/lyrics.dart';
import '../../data/models/song.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import 'lyrics_card.dart';

/// The words, in the place the cover was.
///
/// Not a panel over the player: reading along and reaching for pause are the
/// same moment, so the transport stays exactly where it was and only the
/// picture changes.
class LyricsView extends StatefulWidget {
  const LyricsView({super.key, required this.song});

  final Song? song;

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  late Future<Lyrics?> _lyrics = _load();

  Future<Lyrics?> _load() async {
    final song = widget.song;
    return song == null ? null : lyricsClient.forSong(song);
  }

  @override
  void didUpdateWidget(LyricsView old) {
    super.didUpdateWidget(old);
    if (old.song?.videoId != widget.song?.videoId) {
      setState(() => _lyrics = _load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return FutureBuilder<Lyrics?>(
      future: _lyrics,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final lyrics = snapshot.data;
        if (lyrics == null) {
          return Center(
            child: Text(
              l10n.lyricsNone,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        // The share button rides on top of the words rather than beside them:
        // the panel is already full, and this is a second thought, not a
        // control anyone reaches for mid-song.
        return Stack(
          children: [
            Positioned.fill(child: _words(context, lyrics)),
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                tooltip: l10n.lyricsShare,
                icon: const Icon(Icons.ios_share_rounded),
                onPressed: () {
                  final song = widget.song;
                  if (song != null) {
                    showLyricsCard(context, song: song, lyrics: lyrics);
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _words(BuildContext context, Lyrics lyrics) {
    final theme = Theme.of(context);
    {
        if (!lyrics.isSynced) {
          return SingleChildScrollView(
            child: Text(
              lyrics.plain,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(height: 1.8),
            ),
          );
        }

        return _Synced(lyrics: lyrics);
    }
  }
}

/// Timed lyrics that follow playback: the line being sung is lit and held in
/// the middle, the rest fade back so the eye never has to hunt for it.
class _Synced extends StatefulWidget {
  const _Synced({required this.lyrics});

  final Lyrics lyrics;

  @override
  State<_Synced> createState() => _SyncedState();
}

class _SyncedState extends State<_Synced> {
  final _controller = ScrollController();
  int _current = -1;

  /// Line heights vary with wrapping, so positions are measured from the laid
  /// out list rather than assumed: a two-line chorus would otherwise drag the
  /// highlight out of the middle a little further with every verse.
  final _keys = <int, GlobalKey>{};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _follow(int index) {
    if (index == _current || index < 0 || !_controller.hasClients) return;
    _current = index;

    final key = _keys[index];
    final box = key?.currentContext?.findRenderObject() as RenderBox?;
    final viewport = _controller.position.viewportDimension;
    if (box == null) return;

    final offset = _controller.offset +
        box.localToGlobal(Offset.zero, ancestor: context.findRenderObject()).dy -
        viewport / 2 +
        box.size.height / 2;

    _controller.animateTo(
      offset.clamp(0.0, _controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<Duration>(
      stream: playerService.shownPosition,
      builder: (context, snapshot) {
        final active = widget.lyrics.indexAt(snapshot.data ?? Duration.zero);

        // Scrolling during a build would mutate layout mid-layout, so the
        // follow happens once the frame is on screen.
        WidgetsBinding.instance.addPostFrameCallback((_) => _follow(active));

        return ShaderMask(
          // The list fades out at both ends instead of being cut off by them.
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0, 0.12, 0.88, 1],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: ListView.builder(
            controller: _controller,
            padding: const EdgeInsets.symmetric(vertical: 40),
            itemCount: widget.lyrics.lines.length,
            itemBuilder: (context, index) {
              final sung = index == active;
              final key = _keys.putIfAbsent(index, GlobalKey.new);

              return Padding(
                key: key,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: theme.textTheme.titleMedium!.copyWith(
                    fontSize: sung ? 22 : 19,
                    color: sung
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.45,
                          ),
                    fontWeight: sung ? FontWeight.w700 : FontWeight.w500,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                  child: Text(
                    widget.lyrics.lines[index].text,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

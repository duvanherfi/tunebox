import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/lyrics/lyrics.dart';
import '../../data/models/song.dart';
import '../../l10n/app_localizations.dart';
import '../shared/sheet_body.dart';

/// Turns chosen lines into a card worth sending someone.
///
/// A quote from a song travels as an image, not as text: it keeps the artwork,
/// the artist and the shape of the lines, and it survives being pasted into any
/// app. The card is drawn as a normal widget and captured — no image library,
/// no template, and it inherits the app's own colours.
Future<void> showLyricsCard(
  BuildContext context, {
  required Song song,
  required Lyrics lyrics,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    builder: (_) => _LyricsCardSheet(song: song, lyrics: lyrics),
  );
}

class _LyricsCardSheet extends StatefulWidget {
  const _LyricsCardSheet({required this.song, required this.lyrics});

  final Song song;
  final Lyrics lyrics;

  @override
  State<_LyricsCardSheet> createState() => _LyricsCardSheetState();
}

class _LyricsCardSheetState extends State<_LyricsCardSheet> {
  final _boundary = GlobalKey();
  final _chosen = <int>{};
  bool _busy = false;

  List<String> get _lines => widget.lyrics.isSynced
      ? [for (final line in widget.lyrics.lines) line.text]
      : widget.lyrics.plain.split('\n').where((l) => l.trim().isNotEmpty).toList();

  /// Four lines is a quote; a page is the whole song, which is not a card.
  static const _maxLines = 4;

  void _toggle(int index) {
    setState(() {
      if (_chosen.contains(index)) {
        _chosen.remove(index);
      } else {
        if (_chosen.length >= _maxLines) return;
        _chosen.add(index);
      }
    });
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final object = _boundary.currentContext?.findRenderObject();
      if (object is! RenderRepaintBoundary) return;

      // Three times the logical size: the card is meant to be looked at on
      // someone else's screen, and a 1x capture arrives soft.
      final image = await object.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;

      final file = await _write(bytes.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '${widget.song.title} — ${widget.song.artist ?? ''}'.trim(),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<File> _write(Uint8List bytes) async {
    final directory = await getTemporaryDirectory();
    final file = await File('${directory.path}/tunebox-lyrics.png')
        .writeAsBytes(bytes);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final lines = _lines;

    return SheetBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              _chosen.isEmpty ? l10n.lyricsPickLines : l10n.lyricsCardReady,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (_chosen.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: RepaintBoundary(
                key: _boundary,
                child: _Card(
                  song: widget.song,
                  lines: [
                    for (final index in _chosen.toList()..sort()) lines[index],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: lines.length,
              itemBuilder: (context, index) => CheckboxListTile(
                dense: true,
                value: _chosen.contains(index),
                onChanged: (_) => _toggle(index),
                title: Text(lines[index]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _chosen.isEmpty || _busy ? null : _share,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_rounded),
              label: Text(l10n.lyricsShare),
            ),
          ),
        ],
      ),
    );
  }
}

/// The card itself: cover, words, and who they belong to.
class _Card extends StatelessWidget {
  const _Card({required this.song, required this.lines});

  final Song song;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                line,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (song.thumbnailUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    song.thumbnailUrl!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      song.artist ?? song.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Tunebox',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../shared/sheet_body.dart';

/// What is going to play, and in what order.
///
/// A queue is only useful if it can be argued with, so every row here is
/// interactive: tap to jump, drag to reorder, swipe to drop. It opens over the
/// expanded player rather than replacing it, because the queue is a detour from
/// what is playing, not a different place.
Future<void> showQueueSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // Above the shell, or it opens under the player bar.
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    // Tall enough to be a list rather than a peek, short enough to keep the
    // player visible behind it.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.75,
    ),
    builder: (_) => const _QueueSheet(),
  );
}

class _QueueSheet extends StatelessWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return StreamBuilder<List<MediaItem>>(
      stream: playerService.queue,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <MediaItem>[];
        final current = playerService.currentIndex;

        return SheetBody(
          scrollable: false,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.queueTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const ShuffleButton(),
                  const RepeatButton(),
                ],
              ),
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Text(
                  l10n.queueEmpty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Flexible(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: items.length,
                  onReorder: (from, to) {
                    // ReorderableListView reports the destination as if the row
                    // were still in place; the handler wants it after removal.
                    playerService.moveQueueItem(from, to > from ? to - 1 : to);
                  },
                  itemBuilder: (context, index) => _QueueRow(
                    key: ValueKey(items[index].id),
                    item: items[index],
                    index: index,
                    playing: index == current,
                  ),
                ),
              ),
          ],
          ),
        );
      },
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    super.key,
    required this.item,
    required this.index,
    required this.playing,
  });

  final MediaItem item;
  final int index;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Dismissible(
      key: ValueKey('dismiss-${item.id}'),
      background: ColoredBox(
        color: theme.colorScheme.errorContainer,
        child: const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Icon(Icons.delete_outline_rounded),
          ),
        ),
      ),
      secondaryBackground: ColoredBox(
        color: theme.colorScheme.errorContainer,
        child: const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Icon(Icons.delete_outline_rounded),
          ),
        ),
      ),
      onDismissed: (_) {
        playerService.removeQueueItemAt(index);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.queueRemoved)),
        );
      },
      child: ListTile(
        onTap: () => playerService.skipToQueueItem(index),
        leading: Artwork(url: item.artUri?.toString(), size: 44, radius: 8),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: playing ? FontWeight.w700 : FontWeight.w500,
            color: playing ? theme.colorScheme.primary : null,
          ),
        ),
        subtitle: Text(
          item.artist ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        // The drag handle is explicit rather than a long press: a long press on
        // a queue row will mean the track menu soon enough.
        trailing: ReorderableDragStartListener(
          index: index,
          child: Tooltip(
            message: l10n.tipReorder,
            child: const Icon(Icons.drag_handle_rounded),
          ),
        ),
      ),
    );
  }
}

/// Toggles shuffle, reading its state from the player rather than holding one.
class ShuffleButton extends StatelessWidget {
  const ShuffleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return StreamBuilder<PlaybackState>(
      stream: playerService.playbackState,
      builder: (context, snapshot) {
        final on = snapshot.data?.shuffleMode == AudioServiceShuffleMode.all;
        return IconButton(
          tooltip: on ? l10n.shuffleOn : l10n.shuffleOff,
          isSelected: on,
          color: on ? theme.colorScheme.primary : null,
          icon: const Icon(Icons.shuffle_rounded),
          onPressed: () => playerService.setShuffleMode(
            on ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all,
          ),
        );
      },
    );
  }
}

/// Cycles off → queue → track, the order every music player uses.
class RepeatButton extends StatelessWidget {
  const RepeatButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return StreamBuilder<PlaybackState>(
      stream: playerService.playbackState,
      builder: (context, snapshot) {
        final mode = snapshot.data?.repeatMode ?? AudioServiceRepeatMode.none;
        final (icon, label, next) = switch (mode) {
          AudioServiceRepeatMode.none => (
              Icons.repeat_rounded,
              l10n.repeatOff,
              AudioServiceRepeatMode.all,
            ),
          AudioServiceRepeatMode.one => (
              Icons.repeat_one_rounded,
              l10n.repeatOne,
              AudioServiceRepeatMode.none,
            ),
          _ => (
              Icons.repeat_rounded,
              l10n.repeatAll,
              AudioServiceRepeatMode.one,
            ),
        };
        final on = mode != AudioServiceRepeatMode.none;

        return IconButton(
          tooltip: label,
          isSelected: on,
          color: on ? theme.colorScheme.primary : null,
          icon: Icon(icon),
          onPressed: () => playerService.setRepeatMode(next),
        );
      },
    );
  }
}

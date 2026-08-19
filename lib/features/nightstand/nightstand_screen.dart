import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/settings.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../player/full_player.dart' show FullPlayer;
import 'nightstand.dart';

/// The phone awake on the nightstand: a clock, a cover, and as little light as
/// the settings allow.
///
/// Everything is drawn on pure black and in plain white rather than in theme
/// colours. On an OLED a true black pixel is an unlit one, which is the whole
/// reason this screen exists; and a surface colour that followed the artwork
/// would light the room a different amount for every track.
class NightstandScreen extends StatefulWidget {
  const NightstandScreen({super.key});

  @override
  State<NightstandScreen> createState() => _NightstandScreenState();
}

class _NightstandScreenState extends State<NightstandScreen> {
  Timer? _clock;
  Timer? _drift;
  Timer? _controlsFade;

  /// Which step of the burn-in cycle the content is on.
  int _tick = 0;

  /// Whether a recent touch has brought the controls up.
  bool _awake = false;

  @override
  void initState() {
    super.initState();
    _scheduleClock();
    if (settings.nightstandBurnIn) {
      _drift = Timer.periodic(
        const Duration(minutes: 1),
        (_) => setState(() => _tick++),
      );
    }
  }

  /// Wakes on the minute rather than every second. A screen that is meant to
  /// be left on all night should not rebuild sixty times for each change it
  /// has to show.
  void _scheduleClock() {
    final now = DateTime.now();
    final nextMinute =
        DateTime(now.year, now.month, now.day, now.hour, now.minute)
            .add(const Duration(minutes: 1));
    _clock = Timer(nextMinute.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleClock();
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _drift?.cancel();
    _controlsFade?.cancel();
    super.dispose();
  }

  void _touched() {
    switch (settings.nightstandControls) {
      case NightstandControls.never:
        Navigator.of(context).pop();
      case NightstandControls.onTouch:
        setState(() => _awake = true);
        _controlsFade?.cancel();
        _controlsFade = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _awake = false);
        });
      case NightstandControls.always:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _touched,
        child: StreamBuilder<MediaItem?>(
          stream: playerService.mediaItem,
          builder: (context, snapshot) => SafeArea(
            child: TweenAnimationBuilder<Offset>(
              tween: Tween(
                begin: Offset.zero,
                end: settings.nightstandBurnIn
                    ? nightstandDrift(_tick)
                    : Offset.zero,
              ),
              // Slow enough that the move is never the thing you notice.
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              builder: (context, offset, child) =>
                  Transform.translate(offset: offset, child: child),
              child: _layout(context, snapshot.data),
            ),
          ),
        ),
      ),
    );
  }

  /// Side by side once the screen is wider than it is tall, for the same
  /// reason the full player does it: stacking a square cover above the rest on
  /// a phone lying down leaves the cover a sliver.
  Widget _layout(BuildContext context, MediaItem? item) {
    final size = MediaQuery.sizeOf(context);
    final cover =
        settings.nightstandArt ? const Center(child: NightstandCover()) : null;

    if (size.width > size.height && cover != null) {
      return Row(
        children: [
          Expanded(child: cover),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _panel(context, item),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (cover != null) Flexible(child: cover),
        ..._panel(context, item),
      ],
    );
  }

  List<Widget> _panel(BuildContext context, MediaItem? item) {
    final l10n = AppLocalizations.of(context)!;
    final mode = settings.nightstandControls;
    final showing = mode == NightstandControls.always ||
        (mode == NightstandControls.onTouch && _awake);

    return [
      if (settings.nightstandClock) ...[
        const _Clock(),
        const SizedBox(height: 24),
      ],
      if (settings.nightstandTitle)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Text(
                item?.title ?? l10n.nightstandNothing,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (item?.artist != null) ...[
                const SizedBox(height: 4),
                Text(
                  item!.artist!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      if (settings.nightstandProgress && item != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
          child: _Progress(total: item.duration ?? Duration.zero),
        ),
      // Kept in the tree at zero opacity rather than removed: a layout that
      // jumps every time the controls come and go is worse than a dim row.
      if (mode != NightstandControls.never)
        AnimatedOpacity(
          opacity: showing ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          child: IgnorePointer(
            ignoring: !showing,
            child: const _Controls(),
          ),
        ),
    ];
  }
}

/// The time as the phone itself writes it, so a listener who set their device
/// to 24 hours gets 24 hours without this screen owning a preference for it.
class _Clock extends StatelessWidget {
  const _Clock();

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    final now = DateTime.now();

    return Column(
      children: [
        Text(
          material.formatTimeOfDay(
            TimeOfDay.fromDateTime(now),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 72,
            fontWeight: FontWeight.w200,
            letterSpacing: -2,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          material.formatMediumDate(now),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

/// The cover, sized from what it is given rather than from the screen, so the
/// same widget fits both layouts.
class NightstandCover extends StatelessWidget {
  const NightstandCover({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: playerService.mediaItem,
      builder: (context, snapshot) {
        final url = snapshot.data?.artUri?.toString();
        return LayoutBuilder(
          builder: (context, constraints) {
            final side = [
              constraints.maxWidth,
              constraints.maxHeight,
              320.0,
            ].reduce((a, b) => a < b ? a : b);
            return Artwork(url: url, size: side, radius: 20);
          },
        );
      },
    );
  }
}

/// Driven by the player's own position stream rather than the media session,
/// so the handle moves smoothly instead of once per state broadcast.
class _Progress extends StatelessWidget {
  const _Progress({required this.total});

  final Duration total;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: playerService.shownPosition,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = playerService.shownDuration ?? total;
        final max = duration.inMilliseconds.toDouble();
        final value = position.inMilliseconds.clamp(0, max.toInt()).toDouble();

        final labels = TextStyle(
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 12,
        );

        return Column(
          children: [
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: Colors.white.withValues(alpha: 0.8),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: max <= 0 ? 0 : value,
                max: max <= 0 ? 1 : max,
                onChanged: max <= 0
                    ? null
                    : (next) => playerService.seek(
                          Duration(milliseconds: next.round()),
                        ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(FullPlayer.format(position), style: labels),
                Text(FullPlayer.format(duration), style: labels),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Transport, plus the way out. The chevron travels with the controls because
/// it is the same question: what can I press.
class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<PlaybackState>(
      stream: playerService.playbackState,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 34,
                  color: Colors.white,
                  tooltip: l10n.tipPrevious,
                  icon: const Icon(Icons.skip_previous_rounded),
                  onPressed: playerService.skipToPrevious,
                ),
                const SizedBox(width: 16),
                IconButton(
                  iconSize: 44,
                  color: Colors.white,
                  tooltip: playing ? l10n.tipPause : l10n.tipPlay,
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  onPressed: playing ? playerService.pause : playerService.play,
                ),
                const SizedBox(width: 16),
                IconButton(
                  iconSize: 34,
                  color: Colors.white,
                  tooltip: l10n.tipNext,
                  icon: const Icon(Icons.skip_next_rounded),
                  onPressed: playerService.skipToNext,
                ),
              ],
            ),
            IconButton(
              color: Colors.white.withValues(alpha: 0.5),
              tooltip: l10n.nightstandExit,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../settings/settings_screen.dart';

/// The three things that change how the music sounds and how long it lasts,
/// reachable from the player rather than from settings.
///
/// They were in settings because that is where knobs live, but nobody reaches
/// for a sleep timer while browsing preferences — they reach for it in bed,
/// with the player open. Speed and the equalizer are the same: they are
/// adjusted against what is playing, by ear, so they belong next to it.
Future<void> showPlaybackSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    builder: (_) => const _PlaybackSheet(),
  );
}

class _PlaybackSheet extends StatelessWidget {
  const _PlaybackSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Label(l10n.settingsSleep),
            const SleepTimerControls(),
            _Label(l10n.settingsSpeed(settings.speed.toStringAsFixed(2))),
            const _Speed(),
            _Label(l10n.settingsEqualizer),
            SwitchListTile(
              title: Text(l10n.settingsEqualizerOn),
              value: settings.equalizerEnabled,
              onChanged: settings.setEqualizerEnabled,
            ),
            if (settings.equalizerEnabled) const EqualizerBands(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Speed as a row of the values people actually use, plus the fine slider
/// underneath for the ones they do not.
class _Speed extends StatelessWidget {
  const _Speed();

  static const _presets = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              for (final preset in _presets)
                ChoiceChip(
                  label: Text('$preset×'),
                  selected: (settings.speed - preset).abs() < 0.01,
                  onSelected: (_) => settings.setSpeed(preset),
                ),
            ],
          ),
        ),
        Slider(
          value: settings.speed,
          min: 0.5,
          max: 2,
          divisions: 30,
          label: '${settings.speed.toStringAsFixed(2)}×',
          onChanged: settings.setSpeed,
        ),
      ],
    );
  }
}

/// Sleep timer: the usual three, a countdown once one is running, and a picker
/// for any other length.
class SleepTimerControls extends StatelessWidget {
  const SleepTimerControls({super.key});

  static const _presets = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 60),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ValueListenableBuilder<DateTime?>(
      valueListenable: playerService.sleepAt,
      builder: (context, endsAt, _) {
        if (endsAt != null) {
          return _Countdown(endsAt: endsAt);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _presets)
                ActionChip(
                  label: Text(l10n.settingsSleepMinutes(preset.inMinutes)),
                  onPressed: () => playerService.sleepAfter(preset),
                ),
              ActionChip(
                avatar: Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                label: Text(l10n.sleepCustom),
                onPressed: () => _pick(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pick(BuildContext context) async {
    final chosen = await showDialog<Duration>(
      context: context,
      builder: (_) => const _DurationDialog(),
    );
    if (chosen != null) playerService.sleepAfter(chosen);
  }
}

/// What is left, counted down every second.
///
/// A timer that only says "in 15 min" from the moment it was set is useless
/// five minutes later — the question is always how long is left now.
class _Countdown extends StatefulWidget {
  const _Countdown({required this.endsAt});

  final DateTime endsAt;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late final Stream<void> _tick = Stream.periodic(const Duration(seconds: 1));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return StreamBuilder<void>(
      stream: _tick,
      builder: (context, _) {
        final left = widget.endsAt.difference(DateTime.now());
        if (left.isNegative) return const SizedBox.shrink();

        final hours = left.inHours;
        final minutes = left.inMinutes.remainder(60).toString().padLeft(2, '0');
        final seconds = left.inSeconds.remainder(60).toString().padLeft(2, '0');

        return ListTile(
          leading: Icon(
            Icons.bedtime_rounded,
            color: theme.colorScheme.primary,
          ),
          title: Text(
            hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          subtitle: Text(l10n.sleepRunning),
          trailing: TextButton(
            onPressed: () => playerService.sleepAfter(null),
            child: Text(l10n.cancel),
          ),
        );
      },
    );
  }
}

/// Any length at all: a number from 0 to 99 and the unit it is measured in.
class _DurationDialog extends StatefulWidget {
  const _DurationDialog();

  @override
  State<_DurationDialog> createState() => _DurationDialogState();
}

class _DurationDialogState extends State<_DurationDialog> {
  static const _unitSeconds = 0;
  static const _unitMinutes = 1;
  static const _unitHours = 2;

  int _amount = 20;
  int _unit = _unitMinutes;

  Duration get _duration => switch (_unit) {
        _unitSeconds => Duration(seconds: _amount),
        _unitHours => Duration(hours: _amount),
        _ => Duration(minutes: _amount),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.sleepCustom),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 160,
            child: ListWheelScrollView.useDelegate(
              controller: FixedExtentScrollController(initialItem: _amount),
              itemExtent: 52,
              perspective: 0.004,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (value) =>
                  setState(() => _amount = value),
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: 100,
                builder: (context, index) => Center(
                  // Two digits always, so the numbers do not jitter sideways
                  // as the wheel passes from 9 to 10.
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight:
                          index == _amount ? FontWeight.w700 : FontWeight.w400,
                      color: index == _amount
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: _unitSeconds, label: Text(l10n.unitSeconds)),
              ButtonSegment(value: _unitMinutes, label: Text(l10n.unitMinutes)),
              ButtonSegment(value: _unitHours, label: Text(l10n.unitHours)),
            ],
            selected: {_unit},
            onSelectionChanged: (picked) =>
                setState(() => _unit = picked.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          // Zero is not a timer, it is an immediate stop, which is what the
          // pause button is for.
          onPressed: _amount == 0
              ? null
              : () => Navigator.of(context).pop(_duration),
          child: Text(l10n.sleepStart),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';

/// Where the app's colour is chosen: a seed, and optionally a wash behind it.
///
/// The presets cover most of it; this screen is for the rest. The picker is
/// built from plain sliders rather than a colour wheel — hue, saturation and
/// brightness are the three questions actually being asked, and each is easier
/// to answer on its own axis than by hunting a point in a disc.
class PaletteScreen extends StatelessWidget {
  const PaletteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.themePalette)),
      body: ListenableBuilder(
        listenable: themeController,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _Label(l10n.paletteBaseColour),
            _ColourPicker(
              colour: Color(themeController.seed ?? AppTheme.seed.toARGB32()),
              onChanged: (colour) =>
                  themeController.setSeed(colour.toARGB32()),
            ),
            _Label(l10n.paletteBackground),
            _GradientChoice(),
            if (themeController.gradient != AppGradient.none) ...[
              _Label(l10n.paletteGradientColours),
              const _GradientColours(),
            ],
            if (themeController.gradient == AppGradient.custom) ...[
              _Label(l10n.paletteAngle),
              Slider(
                value: themeController.gradientAngle,
                divisions: 8,
                label: '${(themeController.gradientAngle * 360).round()}°',
                onChanged: themeController.setGradientAngle,
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: () {
                  themeController.setSeed(null);
                  themeController.setGradient(AppGradient.none);
                  themeController.setGradientColours(const []);
                },
                child: Text(l10n.paletteReset),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientChoice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    String label(AppGradient kind) => switch (kind) {
          AppGradient.none => l10n.paletteFlat,
          AppGradient.linear => l10n.paletteLinear,
          AppGradient.radial => l10n.paletteRadial,
          AppGradient.custom => l10n.paletteCustom,
        };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        children: [
          for (final kind in AppGradient.values)
            ChoiceChip(
              label: Text(label(kind)),
              selected: themeController.gradient == kind,
              onSelected: (_) => themeController.setGradient(kind),
            ),
        ],
      ),
    );
  }
}

/// The colours the wash runs through: as many as wanted, in order.
///
/// Editing one opens the same picker used for the base colour, so there is one
/// way to choose a colour in this app rather than two.
class _GradientColours extends StatelessWidget {
  const _GradientColours();

  static const _fallback = [0xFF1A1A1A, 0xFFC2185B];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colours = themeController.gradientColours.isEmpty
        ? _fallback
        : themeController.gradientColours;

    Future<void> edit(int index) async {
      final picked = await showDialog<int>(
        context: context,
        // Above the shell, or it opens under the player bar.
        useRootNavigator: true,
        builder: (_) => _ColourDialog(colour: Color(colours[index])),
      );
      if (picked == null) return;
      final next = List.of(colours)..[index] = picked;
      await themeController.setGradientColours(next);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < colours.length; i++)
            GestureDetector(
              onTap: () => edit(i),
              // Long press removes, but never below the two a gradient needs.
              onLongPress: colours.length <= 2
                  ? null
                  : () => themeController.setGradientColours(
                        List.of(colours)..removeAt(i),
                      ),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(colours[i]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
          if (colours.length < 6)
            InkWell(
              onTap: () => themeController.setGradientColours(
                [...colours, colours.last],
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: const Icon(Icons.add_rounded),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 14),
            child: Text(
              l10n.paletteHoldToRemove,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// The picker in a dialog, for choosing one colour of a gradient.
class _ColourDialog extends StatefulWidget {
  const _ColourDialog({required this.colour});

  final Color colour;

  @override
  State<_ColourDialog> createState() => _ColourDialogState();
}

class _ColourDialogState extends State<_ColourDialog> {
  late Color _colour = widget.colour;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      content: SingleChildScrollView(
        child: _ColourPicker(
          colour: _colour,
          onChanged: (colour) => setState(() => _colour = colour),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_colour.toARGB32()),
          child: Text(l10n.create),
        ),
      ],
    );
  }
}

/// Hue, saturation and brightness, one slider each, over a live swatch.
class _ColourPicker extends StatelessWidget {
  const _ColourPicker({required this.colour, required this.onChanged});

  final Color colour;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(colour);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(AppTheme.radiusArtwork),
            ),
          ),
          _Slider(
            label: l10n.paletteHue,
            value: hsv.hue,
            max: 360,
            // The track shows the choice being made rather than a grey rail.
            colours: [
              for (var degree = 0; degree <= 360; degree += 60)
                HSVColor.fromAHSV(1, degree.toDouble(), 1, 1).toColor(),
            ],
            onChanged: (value) => onChanged(hsv.withHue(value).toColor()),
          ),
          _Slider(
            label: l10n.paletteSaturation,
            value: hsv.saturation,
            max: 1,
            colours: [
              HSVColor.fromAHSV(1, hsv.hue, 0, hsv.value).toColor(),
              HSVColor.fromAHSV(1, hsv.hue, 1, hsv.value).toColor(),
            ],
            onChanged: (value) =>
                onChanged(hsv.withSaturation(value).toColor()),
          ),
          _Slider(
            label: l10n.paletteBrightness,
            value: hsv.value,
            max: 1,
            colours: [
              Colors.black,
              HSVColor.fromAHSV(1, hsv.hue, hsv.saturation, 1).toColor(),
            ],
            onChanged: (value) => onChanged(hsv.withValue(value).toColor()),
          ),
        ],
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.max,
    required this.colours,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final List<Color> colours;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colours),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  thumbColor: theme.colorScheme.onSurface,
                ),
                child: Slider(value: value, max: max, onChanged: onChanged),
              ),
            ],
          ),
        ],
      ),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
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

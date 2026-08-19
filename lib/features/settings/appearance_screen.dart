import 'package:flutter/material.dart';

import '../../core/theme/theme_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import 'palette_screen.dart';
import 'section_label.dart';

/// How the app looks: light or dark, what colour everything is generated from,
/// and how much shows through the two bars that are always on screen.
///
/// This used to sit inline at the bottom of the account sheet, where it was
/// half the scroll and pushed everything else out of sight.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountAppearance)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const _ThemeOptions(),
          ListenableBuilder(
            listenable: themeController,
            builder: (context, _) => SwitchListTile(
              secondary: const Icon(Icons.palette_outlined),
              title: Text(l10n.themeDynamic),
              subtitle: Text(l10n.themeDynamicBody),
              value: themeController.dynamicColors,
              onChanged: (value) async {
                await themeController.setDynamicColors(value);
                if (value) {
                  await themeController.adoptArtwork(
                    playerService.mediaItem.value?.artUri?.toString(),
                  );
                }
              },
            ),
          ),
          const _Palette(),
          const _BarBackgroundOptions(),
        ],
      ),
    );
  }
}

/// How much of the app shows through the two bars that are always on screen.
///
/// Offered rather than decided: reading a label over a bright cover and seeing
/// the list move behind the bar want opposite things, and the blur that
/// reconciles them costs something on a slow device.
class _BarBackgroundOptions extends StatelessWidget {
  const _BarBackgroundOptions();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    String name(BarBackground kind) => switch (kind) {
      BarBackground.solid => l10n.barSolid,
      BarBackground.glass => l10n.barGlass,
      BarBackground.translucent => l10n.barTranslucent,
      BarBackground.clear => l10n.barClear,
    };
    String body(BarBackground kind) => switch (kind) {
      BarBackground.solid => l10n.barSolidBody,
      BarBackground.glass => l10n.barGlassBody,
      BarBackground.translucent => l10n.barTranslucentBody,
      BarBackground.clear => l10n.barClearBody,
    };

    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => RadioGroup<BarBackground>(
        groupValue: themeController.barBackground,
        onChanged: (picked) {
          if (picked != null) themeController.setBarBackground(picked);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsLabel(l10n.appearanceBars),
            for (final kind in BarBackground.values)
              RadioListTile<BarBackground>(
                value: kind,
                title: Text(name(kind)),
                subtitle: Text(body(kind)),
              ),
          ],
        ),
      ),
    );
  }
}

/// The colour everything else is generated from.
class _Palette extends StatelessWidget {
  const _Palette();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.themePalette, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final value in ThemeController.seeds)
                  _Swatch(
                    color: Color(value),
                    selected:
                        (themeController.seed ?? ThemeController.seeds.first) ==
                            value,
                    onTap: () => themeController.setSeed(
                      value == ThemeController.seeds.first ? null : value,
                    ),
                  ),
                _Swatch(
                  color: Theme.of(context).colorScheme.primary,
                  selected: false,
                  custom: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PaletteScreen()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.custom = false,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  /// The way out of the presets: anything at all, plus the background wash.
  final bool custom;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: colors.onSurface, width: 3)
              : null,
        ),
        child: custom
            ? const Icon(Icons.tune_rounded, color: Colors.white, size: 20)
            : selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : null,
      ),
    );
  }
}

class _ThemeOptions extends StatelessWidget {
  const _ThemeOptions();

  static String _label(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
    ThemeMode.light => l10n.themeLight,
    ThemeMode.dark => l10n.themeDark,
    ThemeMode.system => l10n.themeSystem,
  };

  static IconData _icon(ThemeMode mode) => switch (mode) {
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
    ThemeMode.system => Icons.brightness_auto_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => RadioGroup<ThemeMode>(
        groupValue: themeController.mode,
        onChanged: (picked) {
          if (picked != null) themeController.select(picked);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ThemeController.options)
              RadioListTile<ThemeMode>(
                value: mode,
                secondary: Icon(_icon(mode)),
                title: Text(_label(l10n, mode)),
              ),
          ],
        ),
      ),
    );
  }
}

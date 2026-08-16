import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../auth/login_screen.dart';
import '../settings/settings_screen.dart';
import '../shared/sheet_body.dart';
import '../settings/scrobble_screen.dart';
import '../stats/stats_screen.dart';

/// Everything about "you and this app" in one place: who is signed in, and how
/// the app looks.
///
/// Replaces two separate icons in the app bar. They were cheap to add and
/// would have kept multiplying — a bar of unlabelled glyphs is how settings
/// get lost. One avatar, one sheet, room to grow.
Future<void> showAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _AccountSheet(),
  );
}

class _AccountSheet extends StatefulWidget {
  const _AccountSheet();

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  Future<void> _signIn() async {
    final signedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LoginScreen(session: session)),
    );
    if (signedIn ?? false) await accountStore.refresh();
  }

  Future<void> _signOut() => session.signOut();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SheetBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _AccountCard(onSignIn: _signIn, onSignOut: _signOut),
          ),
          ListTile(
            leading: const Icon(Icons.insights_rounded),
            title: Text(l10n.accountStats),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const StatsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: Text(l10n.accountSettings),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.timeline_rounded),
            title: Text(l10n.accountScrobble),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ScrobbleScreen()));
            },
          ),
          _SectionLabel(l10n.accountAppearance),
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
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.onSignIn, required this.onSignOut});

  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          if (!session.isSignedIn) {
            return Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.person_outline_rounded),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    l10n.accountSignedOut,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                FilledButton(onPressed: onSignIn, child: Text(l10n.signIn)),
              ],
            );
          }

          final info = accountStore.account;

          return Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                foregroundImage: info?.photoUrl == null
                    ? null
                    : NetworkImage(info!.photoUrl!),
                child: const Icon(Icons.person_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      // Falls back to a plain confirmation: the panel is
                      // useful even when the name never arrives.
                      info?.name ?? l10n.accountSignedIn,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (info != null && info.email.isNotEmpty)
                      Text(
                        info.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              TextButton(onPressed: onSignOut, child: Text(l10n.signOut)),
            ],
          );
        },
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
                    selected: (themeController.seed ?? ThemeController.seeds.first) ==
                        value,
                    onTap: () => themeController.setSeed(
                      value == ThemeController.seeds.first ? null : value,
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
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

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
        child: selected
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
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

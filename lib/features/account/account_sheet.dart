import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../auth/login_screen.dart';
import '../settings/settings_screen.dart';
import '../shared/sheet_body.dart';
import '../settings/scrobble_screen.dart';
import '../stats/stats_screen.dart';

/// Everything about "you and this app" in one place: who is signed in, what
/// they have been listening to, and the way into the settings.
///
/// Replaces two separate icons in the app bar. They were cheap to add and
/// would have kept multiplying — a bar of unlabelled glyphs is how settings
/// get lost. One avatar, one sheet, room to grow.
Future<void> showAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // Above the shell, or it opens under the player bar.
    useRootNavigator: true,
    showDragHandle: true,
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
            leading: const Icon(Icons.settings_outlined),
            title: Text(l10n.settingsTitle),
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
      // Both, because the card is telling one story out of two sources that
      // change at different moments: the session flips the instant someone
      // signs in, and the name and photo land from the network afterwards.
      // Listening only to the session leaves the panel showing the fallback
      // until something else happens to rebuild it — which is what closing and
      // reopening the sheet was doing.
      child: ListenableBuilder(
        listenable: Listenable.merge([session, accountStore]),
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


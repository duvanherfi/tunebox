import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../main.dart';
import 'account_sheet.dart';

/// The way into everything about "you": your photo, in the corner.
///
/// A face is a better button than a glyph — it says at a glance which account
/// the app is looking at, which matters as soon as someone has two. Signed out
/// it falls back to an outline, since there is no face to show and pretending
/// otherwise would be worse than admitting it.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, this.radius = 20});

  final double radius;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: accountStore,
      builder: (context, _) {
        final photo = accountStore.account?.photoUrl;

        return Tooltip(
          message: accountStore.account?.name ?? l10n.accountTooltip,
          child: InkWell(
            onTap: () => showAccountSheet(context),
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: CircleAvatar(
                radius: radius,
                backgroundColor: colors.surfaceContainerHighest,
                foregroundImage: photo == null ? null : NetworkImage(photo),
                child: Icon(
                  session.isSignedIn
                      ? Icons.person_rounded
                      : Icons.person_outline_rounded,
                  size: radius,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

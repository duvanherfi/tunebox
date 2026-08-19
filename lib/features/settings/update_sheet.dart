import 'package:flutter/material.dart';

import '../../core/install/installer.dart';
import '../../data/updates.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../shared/sheet_body.dart';

/// Offers the release the updater found, and walks it onto the phone.
///
/// [checkOnOpen] separates the two ways in. Opened by hand from settings it
/// looks first and reports whatever it finds, "you are up to date" included.
/// Opened by the automatic check it already has the answer, and it would
/// never have appeared if that answer were "nothing".
Future<void> showUpdateSheet(BuildContext context, {bool checkOnOpen = false}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _UpdateSheet(checkOnOpen: checkOnOpen),
  );
}

class _UpdateSheet extends StatefulWidget {
  const _UpdateSheet({required this.checkOnOpen});

  final bool checkOnOpen;

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  static const _installer = Installer();

  bool _checking = false;

  /// Android has not been told this app may install packages. It is the one
  /// failure with a way out, so it gets a button rather than a line of text.
  bool _needsPermission = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.checkOnOpen) _check();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    await updates.check();
    await settings.setUpdateCheckedAt(DateTime.now());
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _checking = false;
      _error = updates.failed ? l10n.updateFailed : null;
    });
  }

  Future<void> _install(Release release) async {
    final l10n = AppLocalizations.of(context)!;

    if (!await _installer.canInstall()) {
      if (mounted) setState(() => _needsPermission = true);
      return;
    }

    final file = await updates.download(release);
    if (!mounted) return;
    if (file == null) {
      setState(() => _error = l10n.updateFailed);
      return;
    }

    final failure = await _installer.install(file.path);
    if (!mounted || failure == null) return;
    setState(() {
      _error = failure == InstallFailure.signature
          ? l10n.updateSignature
          : l10n.updateFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SheetBody(
      child: ListenableBuilder(
        listenable: updates,
        builder: (context, _) {
          final release = updates.available;
          final downloading = updates.progress != null;

          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            // Full width on purpose: the sheet centres whatever it is given,
            // and a column that shrink-wraps its widest line drifts to the
            // middle when the answer is short and stays left when it is long.
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _checking
                        ? l10n.updateChecking
                        : release == null
                            ? l10n.updateUpToDate
                            : l10n.updateTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                  if (release != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.updateSubtitle(
                        release.version,
                        (release.size / (1024 * 1024)).toStringAsFixed(1),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (release.notes.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(l10n.updateNotes, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      // Capped rather than free: a changelog is as long as
                      // whoever wrote it felt like, and the button below it has
                      // to stay on screen.
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: SingleChildScrollView(
                          child: Text(
                            release.notes,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ],
                  ],
                  if (_needsPermission) ...[
                    const SizedBox(height: 20),
                    Text(
                      l10n.updatePermission,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: () async {
                          await _installer.openInstallSettings();
                          if (mounted) setState(() => _needsPermission = false);
                        },
                        child: Text(l10n.updatePermissionOpen),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      _error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  if (downloading) ...[
                    const SizedBox(height: 24),
                    LinearProgressIndicator(value: updates.progress),
                    const SizedBox(height: 8),
                    Text(
                      l10n.updateDownloading,
                      style: theme.textTheme.bodySmall,
                    ),
                  ] else if (release != null) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _install(release),
                        child: Text(l10n.updateInstall),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

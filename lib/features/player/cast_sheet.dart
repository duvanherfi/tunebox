import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/entities.dart';

import '../../core/audio/cast_engine.dart';
import '../../l10n/app_localizations.dart';
import '../shared/sheet_body.dart';

/// The button that sends the music to a speaker, or brings it back.
///
/// Drawn only where casting exists; elsewhere it keeps its place empty so the
/// header stays centred.
class CastButton extends StatelessWidget {
  const CastButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!CastEngine.supported) return const SizedBox(width: 48);
    final cast = CastEngine.instance;
    final colors = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: Listenable.merge([cast.device, cast.connecting]),
      builder: (context, _) => SizedBox(
        width: 48,
        child: IconButton(
          tooltip: AppLocalizations.of(context)!.castTip,
          icon: cast.connecting.value
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  cast.connected
                      ? Icons.cast_connected_rounded
                      : Icons.cast_rounded,
                  color: cast.connected ? colors.primary : null,
                ),
          onPressed: () => showCastSheet(context),
        ),
      ),
    );
  }
}

Future<void> showCastSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    builder: (_) => const _CastSheet(),
  );
}

class _CastSheet extends StatefulWidget {
  const _CastSheet();

  @override
  State<_CastSheet> createState() => _CastSheetState();
}

class _CastSheetState extends State<_CastSheet> {
  final _cast = CastEngine.instance;

  /// Set once a device was chosen, so closing the sheet does not tear down
  /// the route the session is still being built on.
  bool _picked = false;

  @override
  void initState() {
    super.initState();
    // Only while someone is looking: discovery keeps multicast running and
    // costs battery for a list nobody reads.
    _cast.startDiscovery();
  }

  @override
  void dispose() {
    // A session is a selected MediaRouter route, and stopping discovery
    // removes the callback that keeps routes published: the route vanishes
    // and the session ends the instant it began. The engine stops discovery
    // itself once the session is over.
    if (!_picked && !_cast.connected) _cast.stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([_cast.device, _cast.connecting]),
      builder: (context, _) {
        final current = _cast.device.value;
        if (current != null) {
          return SheetBody(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.cast_connected_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(current.friendlyName),
                  subtitle: Text(l10n.castPlayingOn),
                ),
                ListTile(
                  leading: const Icon(Icons.phone_android_rounded),
                  title: Text(l10n.castStop),
                  onTap: () {
                    Navigator.of(context).pop();
                    _cast.disconnect();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        }

        return StreamBuilder<List<GoogleCastDevice>>(
          stream: _cast.devices,
          builder: (context, snapshot) {
            final devices = snapshot.data ?? const <GoogleCastDevice>[];
            return SheetBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Text(l10n.castTitle,
                        style: theme.textTheme.titleMedium),
                  ),
                  if (devices.isEmpty)
                    ListTile(
                      leading: const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      title: Text(l10n.castSearching),
                      subtitle: Text(l10n.castSameWifi),
                    ),
                  for (final device in devices)
                    ListTile(
                      leading: const Icon(Icons.speaker_rounded),
                      title: Text(device.friendlyName),
                      subtitle: device.modelName == null
                          ? null
                          : Text(device.modelName!),
                      enabled: !_cast.connecting.value,
                      onTap: () {
                        _picked = true;
                        Navigator.of(context).pop();
                        _cast.connect(device);
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

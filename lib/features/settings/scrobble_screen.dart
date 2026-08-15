import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../l10n/app_localizations.dart';
import '../../main.dart';

/// Connects the services that will keep a listening history when YouTube will
/// not: ListenBrainz with a token, Last.fm with its approval dance.
class ScrobbleScreen extends StatefulWidget {
  const ScrobbleScreen({super.key});

  @override
  State<ScrobbleScreen> createState() => _ScrobbleScreenState();
}

class _ScrobbleScreenState extends State<ScrobbleScreen> {
  final _listenBrainz = TextEditingController();
  final _lastFmKey = TextEditingController();
  final _lastFmSecret = TextEditingController();

  @override
  void dispose() {
    _listenBrainz.dispose();
    _lastFmKey.dispose();
    _lastFmSecret.dispose();
    super.dispose();
  }

  void _report(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _connectLastFm() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await scrobbler.setLastFmCredentials(
        _lastFmKey.text,
        _lastFmSecret.text,
      );
      final auth = await scrobbler.beginLastFmAuth();
      if (!mounted) return;

      // The approval page is Last.fm's, and it wants a browser. It comes back
      // with nothing to intercept — the listener presses a button when they are
      // done — so this is a plain page, not a redirect to catch.
      final approved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _ApprovalPage(url: auth.approvalUrl),
        ),
      );
      if (approved != true || !mounted) return;

      await scrobbler.completeLastFmAuth(auth.token);
      if (mounted) _report(l10n.scrobbleConnected);
    } catch (error) {
      if (mounted) _report('$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.scrobbleTitle)),
      body: ListenableBuilder(
        listenable: scrobbler,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(l10n.scrobbleBody, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            Text(
              'ListenBrainz',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (scrobbler.listenBrainzConnected)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Text(l10n.scrobbleConnected),
                trailing: TextButton(
                  onPressed: () => scrobbler.setListenBrainzToken(null),
                  child: Text(l10n.scrobbleDisconnect),
                ),
              )
            else ...[
              TextField(
                controller: _listenBrainz,
                decoration: InputDecoration(
                  labelText: l10n.scrobbleTokenHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () async {
                  await scrobbler.setListenBrainzToken(_listenBrainz.text);
                  if (context.mounted) _report(l10n.scrobbleConnected);
                },
                child: Text(l10n.scrobbleConnect),
              ),
            ],
            const SizedBox(height: 32),
            Text(
              'Last.fm',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (scrobbler.lastFmConnected)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Text(l10n.scrobbleConnected),
                trailing: TextButton(
                  onPressed: scrobbler.disconnectLastFm,
                  child: Text(l10n.scrobbleDisconnect),
                ),
              )
            else ...[
              Text(
                l10n.scrobbleLastFmBody,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _lastFmKey,
                decoration: const InputDecoration(
                  labelText: 'API key',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _lastFmSecret,
                decoration: const InputDecoration(
                  labelText: 'Shared secret',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _connectLastFm,
                child: Text(l10n.scrobbleConnect),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Last.fm's own approval page, with the only control this app can offer: a
/// button that says "I did it".
class _ApprovalPage extends StatelessWidget {
  const _ApprovalPage({required this.url});

  final Uri url;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Last.fm'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.scrobbleApproved),
          ),
        ],
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri.uri(url)),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../l10n/app_localizations.dart';

/// Signs in by pasting the session cookie from a desktop browser.
///
/// Three other routes were built and measured before settling here. An embedded
/// WebView carrying Google's login page is blocked on purpose — Google answers
/// "this browser or app may not be secure" at the credential step. The
/// device-code flow television apps use does authenticate, but its token is
/// refused by the music endpoints and the Data API is disabled on the project
/// those credentials belong to, so it returns an empty library.
///
/// And a Google account already on the phone reaches nothing: Android issues
/// the weblogin token, but following it never leaves accounts.google.com and
/// no session cookie comes back.
///
/// Pasting is unglamorous and takes a minute, but it is the one route measured
/// to reach the real library, and nothing Google ships can quietly break it.
/// On desktop it is barely an inconvenience — the browser is right there.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});

  final Session session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final pasted = _controller.text.trim();

    // Checked before storing: a cookie string without this value cannot sign
    // anything, and failing here is far clearer than an empty library later.
    if (Session.sapisidOf(pasted) == null) {
      setState(() => _error = l10n.loginNoSapisid);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    await widget.session.signIn(pasted);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l10n.loginPasteTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          _Steps(
            steps: [
              l10n.loginStep1,
              l10n.loginStep2,
              l10n.loginStep3,
              l10n.loginStep4,
              l10n.loginStep5,
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            maxLines: 6,
            minLines: 4,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: InputDecoration(
              hintText: 'VISITOR_INFO1_LIVE=…; SAPISID=…; …',
              errorText: _error,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.loginSave),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.loginStorageNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 22, child: Text('${i + 1}.', style: style)),
                Expanded(child: Text(steps[i], style: style)),
              ],
            ),
          ),
      ],
    );
  }
}

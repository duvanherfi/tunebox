import 'package:flutter/material.dart';

import '../../core/auth/session.dart';

/// Signs in by pasting the session cookie from a desktop browser.
///
/// Two other routes were built and measured before settling here. An embedded
/// WebView carrying Google's login page is blocked on purpose — Google answers
/// "this browser or app may not be secure" at the credential step. The
/// device-code flow television apps use does authenticate, but its token is
/// refused by the music endpoints and the Data API is disabled on the project
/// those credentials belong to, so it returns an empty library.
///
/// Pasting the cookie is unglamorous and takes a minute, but it is the one
/// route that reaches the real library, and nothing Google ships can quietly
/// break it.
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
    final pasted = _controller.text.trim();

    // Checked before storing: a cookie string without this value cannot sign
    // anything, and failing here is far clearer than an empty library later.
    if (Session.sapisidOf(pasted) == null) {
      setState(() => _error = 'No encuentro la cookie de sesión (SAPISID) en '
          'lo que pegaste. Asegúrate de copiar la cabecera Cookie completa.');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Pega tu cookie de sesión',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          const _Steps(),
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
                : const Text('Guardar sesión'),
          ),
          const SizedBox(height: 16),
          Text(
            'Se guarda cifrada en este dispositivo y no se envía a ningún sitio '
            'salvo a YouTube. Para revocarla, cierra sesión en tu cuenta de '
            'Google desde cualquier navegador.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps();

  static const _steps = [
    'Abre music.youtube.com en el navegador del ordenador, con tu sesión ya iniciada.',
    'Pulsa F12 y ve a la pestaña Network (Red).',
    'Recarga la página y haz clic en cualquier petición de la lista.',
    'En Request Headers, copia el valor completo de Cookie.',
    'Pégalo aquí abajo.',
  ];

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: Text('${i + 1}.', style: style),
                ),
                Expanded(child: Text(_steps[i], style: style)),
              ],
            ),
          ),
      ],
    );
  }
}

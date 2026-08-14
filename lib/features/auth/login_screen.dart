import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/auth/session.dart';

/// Signs in through a real Google login page and keeps the resulting cookies.
///
/// Google refuses sign-in from embedded browsers, answering "this browser or
/// app may not be secure", so the view presents itself with a desktop browser
/// user agent. That is also why the flow targets the plain web login rather
/// than an OAuth consent screen, which is blocked far more aggressively.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});

  final Session session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _desktopUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:130.0) '
      'Gecko/20100101 Firefox/130.0';

  late final WebViewController _controller;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_desktopUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: (url) => _tryCapture(url)),
      )
      ..loadRequest(Uri.parse(
        'https://accounts.google.com/ServiceLogin'
        '?service=youtube&continue=https%3A%2F%2Fmusic.youtube.com%2F',
      ));
  }

  /// Reads the session cookies once the browser lands back on YouTube Music.
  ///
  /// `document.cookie` is enough because the cookie the API needs is the same
  /// one YouTube's own JavaScript reads to sign its requests, so it is
  /// deliberately not HttpOnly.
  Future<void> _tryCapture(String url) async {
    if (_capturing || !url.contains('music.youtube.com')) return;
    _capturing = true;

    try {
      final raw = await _controller.runJavaScriptReturningResult(
        'document.cookie',
      );
      final cookies = raw.toString().replaceAll(RegExp(r'^"|"$'), '');

      if (Session.sapisidOf(cookies) == null) {
        _capturing = false;
        return; // Landed on YouTube Music but not signed in yet.
      }

      await widget.session.signIn(cookies);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      _capturing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: WebViewWidget(controller: _controller),
    );
  }
}

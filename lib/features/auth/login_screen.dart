import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/auth/session.dart';
import '../../l10n/app_localizations.dart';

/// Signs in through Google's own login page, and keeps the session cookies it
/// leaves behind.
///
/// An earlier attempt at this was abandoned as impossible after Google
/// answered "this browser or app may not be secure". It was wrong on two
/// counts, and both mattered:
///
/// It presented a desktop browser's user agent, believing that would slip past
/// the check. A desktop browser reporting itself from a phone is the shape
/// that check looks for — the disguise was the trigger. The browser here is
/// left to introduce itself honestly.
///
/// And it read `document.cookie`, which by design cannot see HttpOnly cookies —
/// several of the ones a Google session depends on. Even a successful login
/// would have yielded an incomplete set. The platform's cookie store has them
/// all.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});

  final Session session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Sign in to Google, then continue on to YouTube Music so the session lands
  /// on the host whose cookies are wanted.
  static const _loginUrl =
      'https://accounts.google.com/ServiceLogin'
      '?continue=https%3A%2F%2Fmusic.youtube.com';

  /// Google spreads a YouTube session across these hosts, so all three are
  /// merged rather than trusting any one of them to hold everything.
  static const _cookieHosts = [
    'https://music.youtube.com',
    'https://www.youtube.com',
    'https://youtube.com',
  ];

  bool _captured = false;

  /// Harvests cookies once the browser lands back on YouTube.
  ///
  /// Called on every page load rather than once, because the session is only
  /// complete after the final redirect — earlier pages carry a partial set.
  Future<void> _tryCapture(WebUri? url) async {
    if (_captured) return;
    if (url == null || !url.host.contains('youtube.com')) return;

    final manager = CookieManager.instance();
    final jar = <String, String>{};

    for (final host in _cookieHosts) {
      for (final cookie in await manager.getCookies(url: WebUri(host))) {
        if (cookie.name.isNotEmpty) jar[cookie.name] = cookie.value.toString();
      }
    }

    final header = jar.entries.map((e) => '${e.key}=${e.value}').join('; ');

    // The signing cookie is what makes a session usable; without it the login
    // has not finished, so this waits for a later page rather than storing a
    // half-formed one.
    if (Session.sapisidOf(header) == null) return;

    _captured = true;
    await widget.session.signIn(header);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(_loginUrl)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          // No user agent is set on purpose. See the note on this class.
          thirdPartyCookiesEnabled: true,
          supportZoom: true,
        ),
        onLoadStop: (controller, url) => _tryCapture(url),
      ),
    );
  }
}

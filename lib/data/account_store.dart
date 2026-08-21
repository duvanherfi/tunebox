import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/auth/session.dart';
import '../core/innertube/innertube_client.dart';
import 'models/playlist.dart';

/// Who is signed in, fetched once and shared.
///
/// The name and the photo are wanted in two places at once — the button in the
/// corner and the panel it opens — and asking YouTube twice for the same answer
/// on every rebuild is how an avatar turns into a network request per frame.
class AccountStore extends ChangeNotifier {
  AccountStore(this._innertube, this._session, {List<Duration>? waits})
    : _waits = waits ?? _defaultWaits {
    _session.addListener(refresh);
  }

  /// How long to wait before asking again, and how many times to bother.
  ///
  /// [InnertubeClient.accountInfo] answers null for every kind of failure, so a
  /// call that goes out in the same breath as a sign-in — before the cookies it
  /// was handed are worth anything to YouTube — cannot be told apart from an
  /// account with no name. Without asking again the corner keeps its fallback
  /// icon until the app is started afresh, which is exactly what a sign-in on
  /// macOS looked like on 20 August 2026.
  static const _defaultWaits = [
    Duration(seconds: 2),
    Duration(seconds: 6),
    Duration(seconds: 20),
  ];

  final InnertubeClient _innertube;
  final Session _session;
  final List<Duration> _waits;

  Account? account;
  bool _loading = false;
  bool _askAgain = false;
  Timer? _waiting;

  /// Reads the account again, or forgets it when there is no longer one.
  Future<void> refresh() async {
    _waiting?.cancel();

    if (!_session.isSignedIn) {
      account = null;
      notifyListeners();
      return;
    }

    // A second notice arriving while one is in flight is not noise to drop: the
    // answer already on its way was asked for with whatever the session held
    // before, and the whole reason there is a second notice is that it holds
    // something else now.
    if (_loading) {
      _askAgain = true;
      return;
    }

    await _read(attempt: 0);
  }

  Future<void> _read({required int attempt}) async {
    _loading = true;
    Account? found;
    try {
      found = await _innertube.accountInfo();
    } catch (_) {
      // A missing name is not worth an error: the button falls back to an icon.
    } finally {
      _loading = false;
    }

    if (_askAgain) {
      _askAgain = false;
      unawaited(refresh());
      return;
    }

    // Replaced only by an answer. Null is how accountInfo() reports a failure,
    // and emptying the corner because one request went wrong trades something
    // true for something that is not.
    if (found != null) {
      account = found;
      notifyListeners();
      return;
    }

    notifyListeners();
    if (attempt < _waits.length && _session.isSignedIn) {
      _waiting = Timer(_waits[attempt], () => _read(attempt: attempt + 1));
    }
  }

  @override
  void dispose() {
    _waiting?.cancel();
    _session.removeListener(refresh);
    super.dispose();
  }
}

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
  AccountStore(this._innertube, this._session) {
    _session.addListener(refresh);
  }

  final InnertubeClient _innertube;
  final Session _session;

  Account? account;
  bool _loading = false;

  /// Reads the account again, or forgets it when there is no longer one.
  Future<void> refresh() async {
    if (!_session.isSignedIn) {
      account = null;
      notifyListeners();
      return;
    }
    if (_loading) return;

    _loading = true;
    try {
      account = await _innertube.accountInfo();
    } catch (_) {
      // A missing name is not worth an error: the button falls back to an icon.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _session.removeListener(refresh);
    super.dispose();
  }
}

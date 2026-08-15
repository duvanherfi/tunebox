import 'package:flutter/foundation.dart';

import '../core/innertube/innertube_client.dart';
import 'models/song.dart';

/// What has been liked from this app, so the heart can fill in immediately.
///
/// YouTube does not say whether a track is already liked in any response this
/// app reads — that state arrives only inside the watch page's menus. Rather
/// than fetch a second page per track to colour one icon, this remembers what
/// was liked here and shows the heart accordingly: unknown looks the same as
/// not liked, and a listener who taps it finds out immediately either way.
///
/// Deliberately not persisted. A remembered guess that survives a restart would
/// go stale against likes made on other devices; within a session it is only
/// ever describing what just happened.
class Likes extends ChangeNotifier {
  Likes(this._innertube);

  final InnertubeClient _innertube;
  final _liked = <String>{};

  bool isLiked(String videoId) => _liked.contains(videoId);

  /// Whether liking is possible at all — it writes to an account, and without
  /// one the control should not be offered anywhere, notification included.
  bool get canLike => _innertube.session?.isSignedIn ?? false;

  /// Flips the heart at once, then tells YouTube. On failure it flips back —
  /// an icon that lies about what the account holds is worse than a stutter.
  Future<void> toggle(Song song) async {
    final liked = !_liked.contains(song.videoId);
    _apply(song.videoId, liked);
    try {
      await _innertube.setLiked(song.videoId, liked);
    } catch (_) {
      _apply(song.videoId, !liked);
      rethrow;
    }
  }

  void _apply(String videoId, bool liked) {
    if (liked) {
      _liked.add(videoId);
    } else {
      _liked.remove(videoId);
    }
    notifyListeners();
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/innertube/innertube_client.dart';
import 'models/playlist.dart';

/// Playlists and albums the listener marked to keep.
///
/// YouTube already knows which collections the account saved, but only for an
/// account, only over the network, and only once the library page answers.
/// This is the shelf Tunebox owns: it fills instantly, works signed out, and
/// survives a tunnel. When there is a session the mark is forwarded to
/// YouTube as well, so a list saved here turns up in YouTube Music too.
///
/// Unlike [Likes], this is persisted. A liked track is a guess about state that
/// lives on the account; a saved collection *is* the state — losing it on
/// restart would lose the shelf itself.
class SavedCollections extends ChangeNotifier {
  SavedCollections({InnertubeClient? innertube, File? file})
      : _innertube = innertube,
        _file = file;

  static const _fileName = 'saved_collections.json';

  final InnertubeClient? _innertube;
  File? _file;
  List<Playlist> _collections = [];

  /// Newest save first, which is the order a shelf of them reads best in.
  List<Playlist> get all => List.unmodifiable(_collections);

  bool isSaved(String browseId) {
    final id = _key(browseId);
    return _collections.any((c) => _key(c.browseId) == id);
  }

  Future<void> load() async {
    final file = await _resolve();
    if (!file.existsSync()) return;
    try {
      final rows = jsonDecode(file.readAsStringSync());
      if (rows is! List) return;
      _collections = rows
          .whereType<Map<String, dynamic>>()
          .map(Playlist.fromJson)
          .toList();
      notifyListeners();
    } catch (_) {
      // Unreadable is the same as empty; the alternative is refusing to start.
    }
  }

  /// Flips the mark, then tells YouTube if there is anyone to tell.
  ///
  /// The local record stands whatever the account answers: the write can fail
  /// for reasons that have nothing to do with the listener's intent — no
  /// signal, a mix that YouTube will not let anyone save — and dropping the
  /// shelf entry over that would be the app losing something it was asked to
  /// keep. The failure is rethrown so the surface can say the account did not
  /// hear about it, not so the mark can be undone.
  Future<void> toggle(Playlist collection) async {
    final saved = !isSaved(collection.browseId);
    final id = _key(collection.browseId);
    _collections.removeWhere((c) => _key(c.browseId) == id);
    if (saved) _collections.insert(0, collection);
    await _save();

    if (_innertube?.session?.isSignedIn != true) return;
    await _innertube!.setCollectionSaved(collection.browseId, saved);
  }

  /// A library shelf prefixes its ids with `VL` and a home card does not, so
  /// the bare id is the only thing that identifies a collection across the
  /// places one can be opened from.
  static String _key(String browseId) =>
      browseId.startsWith('VL') ? browseId.substring(2) : browseId;

  /// Records something the account already keeps, without telling it again.
  ///
  /// An artist's page says whether the account follows them, and that answer is
  /// older than this shelf: someone who subscribed on the web would otherwise
  /// be offered "subscribe" here and would send the same write a second time.
  /// Nothing is removed on the strength of this — the mark is the listener's,
  /// and a page that answers signed out says nothing about it.
  Future<void> remember(Playlist collection) async {
    if (isSaved(collection.browseId)) return;
    _collections.insert(0, collection);
    await _save();
  }

  Future<void> _save() async {
    notifyListeners();
    final file = await _resolve();
    await file.writeAsString(
      jsonEncode([for (final collection in _collections) collection.toJson()]),
    );
  }

  Future<File> _resolve() async {
    return _file ??= File(
      '${(await getApplicationSupportDirectory()).path}/$_fileName',
    );
  }
}

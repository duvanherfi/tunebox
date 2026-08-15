import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The last few things looked for.
///
/// Searching for the same artist twice in a week is the normal case, and typing
/// it again is the kind of small friction that makes an app feel worse than it
/// is. Ten is enough to cover a session's worth of returning to the same
/// things, and short enough to stay a list rather than a history to manage.
class RecentSearches extends ChangeNotifier {
  RecentSearches({this.limit = 10});

  static const _key = 'recent_searches';

  final int limit;
  List<String> _queries = const [];

  List<String> get queries => _queries;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _queries = prefs.getStringList(_key) ?? const [];
    notifyListeners();
  }

  Future<void> record(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    // Repeating a search moves it to the top rather than adding a duplicate.
    _queries = [
      trimmed,
      ..._queries.where((q) => q.toLowerCase() != trimmed.toLowerCase()),
    ];
    if (_queries.length > limit) _queries = _queries.sublist(0, limit);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _queries);
  }

  Future<void> remove(String query) async {
    _queries = _queries.where((q) => q != query).toList();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _queries);
  }

  Future<void> clear() async {
    _queries = const [];
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

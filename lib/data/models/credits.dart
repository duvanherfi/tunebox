/// Who made a track, as YouTube files it.
///
/// A handful of role-and-name pairs, and never more than a screenful: the
/// longest seen on a real account was four. Not every track has any — 41 of 200
/// history rows carried no credits entry at all — and the ones that do answer
/// with the same page whether or not it has anything in it, so an empty
/// [entries] is an ordinary answer rather than a failure.
class TrackCredits {
  const TrackCredits({
    this.title = '',
    this.artist = '',
    this.subtitle = '',
    this.thumbnailUrl,
    this.entries = const [],
  });

  final String title;
  final String artist;

  /// What kind of thing it is and when it came out — "Canción • 2014" — as
  /// YouTube writes it, already joined and already translated.
  final String subtitle;

  final String? thumbnailUrl;
  final List<CreditEntry> entries;

  bool get isEmpty => entries.isEmpty;
}

/// One line of the credits: a role, and who filled it.
class CreditEntry {
  const CreditEntry({required this.role, required this.name});

  /// "Escrita por", "Producida por". YouTube's own wording, in the language the
  /// client asked for, which is why nothing here is translated by the app.
  final String role;
  final String name;
}

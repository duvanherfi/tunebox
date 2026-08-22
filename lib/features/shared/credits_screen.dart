import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/credits.dart';
import '../../data/models/song.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';

/// Who made a track, as YouTube files it.
///
/// A screen rather than a dialog, which is how YouTube Music draws it on
/// Android — the response arrives wrapped in a dialog renderer because that is
/// what the web player uses, and following that would have been copying the
/// wrong client.
///
/// Only reachable from a row that said it has credits. A track without them
/// answers the same page with nothing in it, so the empty state here is for the
/// network failing rather than for the ordinary case.
class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key, required this.song});

  final Song song;

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  /// Held in a field rather than built in `build`, or every rebuild would ask
  /// for the page again.
  late final Future<TrackCredits> _credits =
      innertube.trackCredits(widget.song.videoId);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.creditsTitle)),
      body: FutureBuilder<TrackCredits>(
        future: _credits,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          // The row that opened this already knew the name and the cover, so
          // the heading is drawn from the track even when the page failed.
          final credits = snapshot.data ?? const TrackCredits();
          final title = credits.title.isEmpty ? widget.song.title : credits.title;
          final artist =
              credits.artist.isEmpty ? widget.song.subtitle : credits.artist;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Center(
                child: Artwork(
                  url: credits.thumbnailUrl ?? widget.song.highResThumbnailUrl,
                  size: 220,
                  radius: 12,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [artist, credits.subtitle]
                    .where((line) => line.isNotEmpty)
                    .join(' · '),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              if (credits.isEmpty)
                Text(
                  l10n.creditsEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                for (final entry in credits.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // YouTube's own wording, in the language the client
                        // asked for: nothing here is translated by the app.
                        Text(
                          entry.role,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

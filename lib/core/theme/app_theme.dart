import 'package:flutter/material.dart';

/// The app's visual language: Material 3, generated from a single seed.
///
/// One seed rather than hand-picked colours, because Material 3 derives the
/// whole tonal system from it — surfaces, containers, text and states all stay
/// in step, in both themes, without anything being tuned twice.
///
/// Corner radii are pushed past the Material defaults on purpose. Artwork is
/// the content here, and rounder frames read as softer and less clinical than
/// the near-square defaults, which suits an app that is mostly album covers.
class AppTheme {
  const AppTheme._();

  /// Deep raspberry: warm enough to feel musical, far enough from YouTube's
  /// red that the app never looks like a copy of it.
  static const seed = Color(0xFFC2185B);

  static const radiusCard = 20.0;
  static const radiusArtwork = 12.0;
  static const radiusPill = 28.0;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,

      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colors.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),

      // A tonal container rather than an outline: at this size a border draws
      // more attention than the field deserves.
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor:
            WidgetStatePropertyAll(colors.surfaceContainerHigh),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 20),
        ),
      ),

      chipTheme: ChipThemeData(
        side: BorderSide.none,
        backgroundColor: colors.surfaceContainerHigh,
        selectedColor: colors.secondaryContainer,
        labelStyle: TextStyle(
          color: colors.onSurface,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surfaceContainer,
        indicatorColor: colors.secondaryContainer,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
      ),

      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.surfaceContainerHighest,
        thumbColor: colors.primary,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),

      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        space: 1,
        thickness: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: TextStyle(color: colors.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

/// Section heading with a short accent bar.
///
/// The bar exists so headings register while scrolling past album art without
/// having to shout in uppercase or oversized type.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Album art with the app's rounded frame and a graceful empty state.
class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.url,
    this.size = 52,
    this.radius = AppTheme.radiusArtwork,
  });

  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: size,
      height: size,
      color: colors.surfaceContainerHighest,
      child: Icon(
        Icons.music_note_rounded,
        size: size * 0.45,
        color: colors.onSurfaceVariant,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? placeholder
          : Image.network(
              url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

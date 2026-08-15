import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// One destination of the floating navigation bar.
class NavDestination {
  const NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The app's navigation, as a pill floating over the content.
///
/// Material's own NavigationBar is a full-width slab, and on this device it
/// measures 157dp tall — nearly a sixth of the screen given over to four icons,
/// which read as a band of dead space above it whatever is padded around it.
/// A pill takes the height it needs, lets the music scroll underneath, and puts
/// the labels only where they are useful: on the destination you are in.
class FloatingNav extends StatelessWidget {
  const FloatingNav({
    super.key,
    required this.index,
    required this.onSelected,
    required this.destinations,
  });

  final int index;
  final ValueChanged<int> onSelected;
  final List<NavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerHigh,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < destinations.length; i++)
              _Destination(
                destination: destinations[i],
                selected: i == index,
                onTap: () => onSelected(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Tooltip(
      message: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 16 : 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 24,
                color: selected
                    ? colors.onSecondaryContainer
                    : colors.onSurfaceVariant,
              ),
              // The label only where it earns its space: naming the other three
              // is decoration, since their icons are what is being read.
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          destination.label,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

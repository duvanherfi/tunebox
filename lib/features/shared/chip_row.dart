import 'package:flutter/material.dart';

/// One choice in a [ChipRow].
typedef ChipOption = ({String label, bool selected, VoidCallback onSelected});

/// The row of chips that narrows what is under it.
///
/// Both surfaces that have one narrow a list they did not write: search offers
/// back the filters its own response arrived with, and the home the moods
/// YouTube puts over its front page. Neither knows what the labels will say —
/// they come translated by the device's locale — so the row only lays them out
/// and scrolls, since ten chips do not fit across a phone.
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.options});

  final List<ChipOption> options;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(option.label),
                selected: option.selected,
                showCheckmark: true,
                onSelected: (_) => option.onSelected(),
              ),
            ),
        ],
      ),
    );
  }
}

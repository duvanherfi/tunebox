import 'package:flutter/material.dart';

/// The heading that separates one block of settings from the next.
///
/// Shared rather than copied into each screen: the domains are separate doors
/// now, and headings that drift apart in weight or colour make them read like
/// separate apps.
class SettingsLabel extends StatelessWidget {
  const SettingsLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

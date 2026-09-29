import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import 'lsf_renderer.dart';

/// Donne accès, pour n'importe quel texte de l'application, à son
/// équivalent en LSF (avatar, vidéo ou texte selon les préférences).
class LsfExplainButton extends StatelessWidget {
  final String text;
  final double iconSize;

  /// Affiche « Voir en LSF » à côté de l'icône.
  final bool showLabel;

  const LsfExplainButton({
    super.key,
    required this.text,
    this.iconSize = 20,
    this.showLabel = false,
  });

  static Future<void> open(BuildContext context, String text) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          final theme = Theme.of(context);
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.85),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Icon(Icons.sign_language_rounded,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(tr('Explication en LSF', 'LSF explanation'),
                          style: theme.textTheme.titleMedium),
                    ]),
                    const SizedBox(height: 8),
                    Text(text,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 16),
                    LsfRenderer(text: text),
                  ],
                ),
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final tooltip = tr('Voir en LSF', 'View in LSF');
    if (showLabel) {
      return TextButton.icon(
        onPressed: () => open(context, text),
        icon: Icon(Icons.sign_language_rounded, size: iconSize),
        label: Text(tooltip),
      );
    }
    return IconButton(
      tooltip: tooltip,
      icon: Icon(Icons.sign_language_rounded,
          color: Theme.of(context).colorScheme.primary, size: iconSize),
      onPressed: () => open(context, text),
    );
  }
}

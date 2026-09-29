import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';

/// Profil d'un utilisateur : ce qu'il reçoit et comment il s'exprime.
class UserType {
  final String id;
  final IconData icon;
  final String emoji;
  final String title;
  final String subtitle;

  const UserType(this.id, this.icon, this.emoji, this.title, this.subtitle);

  static List<UserType> get all => [
        UserType(
          'deaf',
          Icons.sign_language_rounded,
          '🤟',
          tr('Sourd ou malentendant', 'Deaf or hard of hearing'),
          tr('Je signe, et je reçois les messages en langue des signes.',
              'I sign, and I receive messages in sign language.'),
        ),
        UserType(
          'hearing',
          Icons.record_voice_over_rounded,
          '🗣️',
          tr('Entendant', 'Hearing'),
          tr('J’écris ou je parle, et je reçois les messages en texte et à voix haute.',
              'I type or speak, and I receive messages as text and aloud.'),
        ),
        UserType(
          'both',
          Icons.diversity_3_rounded,
          '🤝',
          tr('Les deux', 'Both'),
          tr('Signes, texte et voix sont proposés ensemble.',
              'Signs, text and voice are offered together.'),
        ),
      ];

  static UserType? of(String? id) {
    for (final type in all) {
      if (type.id == id) return type;
    }
    return null;
  }
}

/// Choix du profil : trois cartes, une seule sélectionnée.
class UserTypeSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;

  /// Message affiché sous les cartes (choix obligatoire non fait).
  final String? errorText;

  const UserTypeSelector(
      {super.key,
      required this.value,
      required this.onChanged,
      this.errorText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final type in UserType.all)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: value == type.id
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: value == type.id
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                  width: value == type.id ? 2 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onChanged(type.id),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Icon(type.icon,
                        size: 28,
                        color: value == type.id
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(type.title, style: theme.textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(type.subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Icon(
                        value == type.id
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: value == type.id
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline),
                  ]),
                ),
              ),
            ),
          ),
        if (errorText != null)
          Text(errorText!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error)),
      ],
    );
  }
}

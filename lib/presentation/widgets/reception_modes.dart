import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/preferences/app_preferences.dart';
import '../screens/preferences_screen.dart';
import 'avatar_portrait.dart';

/// Façons de recevoir les messages traduits en LSF.
class ReceptionMode {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;

  const ReceptionMode(this.id, this.icon, this.title, this.subtitle);

  static List<ReceptionMode> get all => [
        ReceptionMode(
          'avatar',
          Icons.accessibility_new_rounded,
          tr('Avatar animé', 'Animated avatar'),
          tr('Un avatar reproduit chaque signe, mains et expressions.',
              'An avatar performs each sign, hands and expressions.'),
        ),
        ReceptionMode(
          'video',
          Icons.smart_display_outlined,
          tr('Vidéo (GIF animé)', 'Video (animated GIF)'),
          tr('Un interprète réel signe chaque mot.',
              'A real interpreter signs each word.'),
        ),
        ReceptionMode(
          'landmarks',
          Icons.scatter_plot_outlined,
          tr('Landmarks', 'Landmarks'),
          tr('Le squelette des mains, du corps et du visage.',
              'The skeleton of the hands, body and face.'),
        ),
        ReceptionMode(
          'text',
          Icons.notes_rounded,
          tr('Texte affiché', 'Displayed text'),
          tr('Le message et la description des signes.',
              'The message and a description of each sign.'),
        ),
      ];

  static ReceptionMode of(String id) =>
      all.firstWhere((m) => m.id == id, orElse: () => all.first);
}

/// Bouton compact indiquant le mode de réception actuel ; il ouvre le
/// sélecteur rapide (changement possible à tout moment).
class ReceptionModeButton extends StatelessWidget {
  const ReceptionModeButton({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppPreferences.instance,
        builder: (context, _) {
          final mode = ReceptionMode.of(AppPreferences.instance.responseFormat);
          final color = Theme.of(context).colorScheme.primary;
          return TextButton.icon(
            onPressed: () => showReceptionModePicker(context),
            icon: Icon(mode.icon, size: 18),
            label: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(mode.title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              Icon(Icons.expand_more_rounded, size: 18, color: color),
            ]),
          );
        },
      );
}

/// Sélecteur rapide : mode de réception et style d'avatar.
Future<void> showReceptionModePicker(BuildContext context) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ListenableBuilder(
        listenable: AppPreferences.instance,
        builder: (context, _) {
          final prefs = AppPreferences.instance;
          final theme = Theme.of(context);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Text(
                        tr('Recevoir les messages en', 'Receive messages as'),
                        style: theme.textTheme.titleMedium),
                  ),
                  RadioGroup<String>(
                    groupValue: prefs.responseFormat,
                    onChanged: (value) {
                      if (value == null) return;
                      prefs.responseFormat = value;
                      prefs.save();
                    },
                    child: Column(children: [
                      for (final mode in ReceptionMode.all)
                        RadioListTile<String>(
                          value: mode.id,
                          secondary: Icon(mode.icon),
                          title: Text(mode.title),
                          subtitle: Text(mode.subtitle),
                        ),
                    ]),
                  ),
                  if (prefs.responseFormat == 'avatar') ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      child: Text(tr('Style de l’avatar', 'Avatar style'),
                          style: theme.textTheme.titleSmall),
                    ),
                    SizedBox(
                      height: 72,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final id in AvatarPortrait.photoAssets.keys)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  prefs.signingAvatar = id;
                                  prefs.save();
                                },
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: prefs.signingAvatar == id
                                          ? theme.colorScheme.primary
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: AvatarPortrait(variant: id),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const PreferencesScreen()));
                    },
                    icon: const Icon(Icons.tune_rounded),
                    label:
                        Text(tr('Toutes les préférences', 'All preferences')),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

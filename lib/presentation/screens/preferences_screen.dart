import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/preferences/app_preferences.dart';
import '../../data/services/admin_data_service.dart';
import '../widgets/avatar_portrait.dart';
import '../widgets/lsf_explain_button.dart';
import '../widgets/reception_modes.dart';
import '../widgets/ui_kit.dart';

/// Préférences : mode de réception, style d'avatar, langue, thème et niveau.
/// Chaque changement est appliqué et enregistré immédiatement.
class PreferencesScreen extends StatefulWidget {
  final bool isFirstSetup;
  final VoidCallback? onCompleted;

  const PreferencesScreen(
      {super.key, this.isFirstSetup = false, this.onCompleted});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final _prefs = AppPreferences.instance;
  bool _saving = false;

  Future<void> _update(VoidCallback change) async {
    setState(change);
    await _prefs.save();
  }

  Future<void> _finishSetup() async {
    setState(() => _saving = true);
    await _prefs.save(completedSetup: true);
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isFirstSetup,
        title: Text(widget.isFirstSetup
            ? tr('Personnalisation', 'Personalisation')
            : tr('Préférences', 'Preferences')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            if (widget.isFirstSetup) ...[
              Text(tr('Adaptez NeuroSigne à vous', 'Make NeuroSigne yours'),
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                tr('Vous pourrez modifier ces choix à tout moment depuis votre profil.',
                    'You can change these choices at any time from your profile.'),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
            ],
            _Section(
              title: tr(
                  'Mode de réception des réponses', 'How you receive answers'),
              description: tr(
                  'Comment les messages de vos interlocuteurs vous sont présentés.',
                  'How messages from the people you talk to are shown to you.'),
              child: Column(children: [
                for (final mode in ReceptionMode.all)
                  _FormatOption(
                    icon: mode.icon,
                    title: mode.title,
                    subtitle: mode.subtitle,
                    selected: _prefs.responseFormat == mode.id,
                    onTap: () => _update(() => _prefs.responseFormat = mode.id),
                  ),
              ]),
            ),
            _Section(
              title: tr('Style de l’avatar', 'Avatar style'),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: AdminDataService.cachedAvatars(),
                builder: (context, snapshot) {
                  final avatars =
                      (snapshot.data ?? AdminDataService.defaultAvatars)
                          .where((a) => a['enabled'] == true)
                          .toList();
                  return LayoutBuilder(builder: (context, constraints) {
                    final width = (constraints.maxWidth - 2 * 12) / 3;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final avatar in avatars)
                          SizedBox(
                            width: width,
                            child: _AvatarOption(
                              id: avatar['id'] as String,
                              label: avatar['name'] as String? ?? '',
                              selected: _prefs.signingAvatar == avatar['id'],
                              onTap: () => _update(() => _prefs.signingAvatar =
                                  avatar['id'] as String),
                            ),
                          ),
                      ],
                    );
                  });
                },
              ),
            ),
            _Section(
              title: tr('Langue de l’interface', 'Interface language'),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Français', label: Text('Français')),
                    ButtonSegment(value: 'English', label: Text('English')),
                  ],
                  selected: {_prefs.writtenLanguage},
                  onSelectionChanged: (value) =>
                      _update(() => _prefs.writtenLanguage = value.first),
                ),
              ),
            ),
            _Section(
              title: tr('Thème', 'Theme'),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                        value: ThemeMode.light,
                        icon: const Icon(Icons.light_mode_outlined),
                        label: Text(tr('Clair', 'Light'))),
                    ButtonSegment(
                        value: ThemeMode.dark,
                        icon: const Icon(Icons.dark_mode_outlined),
                        label: Text(tr('Sombre', 'Dark'))),
                  ],
                  selected: {_prefs.themeMode},
                  onSelectionChanged: (value) =>
                      _update(() => _prefs.themeMode = value.first),
                ),
              ),
            ),
            if (widget.isFirstSetup) ...[
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _saving ? null : _finishSetup,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Colors.white))
                    : Text(tr('Commencer', 'Get started')),
              ),
            ] else
              Row(children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 18, color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Text(tr('Enregistré automatiquement', 'Saved automatically'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ]),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;

  const _Section({required this.title, this.description, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            LsfExplainButton(
                text: description == null ? title : '$title. $description'),
          ]),
          if (description != null) ...[
            Text(description!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _FormatOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _FormatOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              IconTile(icon: icon, color: scheme.primary, size: 42),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? scheme.primary : scheme.outline,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _AvatarOption extends StatelessWidget {
  final String id;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AvatarOption({
    required this.id,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(children: [
            SizedBox.square(dimension: 64, child: AvatarPortrait(variant: id)),
            const SizedBox(height: 8),
            Text(label,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium),
          ]),
        ),
      ),
    );
  }
}

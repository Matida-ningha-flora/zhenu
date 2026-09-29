import 'package:flutter/material.dart';

import '../../../core/l10n/tr.dart';
import '../../../data/services/admin_data_service.dart';
import '../../widgets/avatar_portrait.dart';
import '../../widgets/ui_kit.dart';

/// Bibliothèque des styles d'avatars proposés aux utilisateurs.
class AdminContentSection extends StatelessWidget {
  const AdminContentSection({super.key});

  @override
  Widget build(BuildContext context) => const _AvatarsTab();
}

class _AvatarsTab extends StatefulWidget {
  const _AvatarsTab();

  @override
  State<_AvatarsTab> createState() => _AvatarsTabState();
}

class _AvatarsTabState extends State<_AvatarsTab> {
  List<Map<String, dynamic>> _avatars = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final avatars = await AdminDataService.loadAvatars();
    if (mounted) setState(() => _avatars = avatars);
  }

  Future<void> _save(List<Map<String, dynamic>> avatars) async {
    await AdminDataService.saveAvatars(avatars);
    await _load();
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final formKey = GlobalKey<FormState>();
    final name =
        TextEditingController(text: existing?['name'] as String? ?? '');
    final source =
        TextEditingController(text: existing?['source'] as String? ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null
            ? tr('Nouvel avatar', 'New avatar')
            : tr('Modifier l’avatar', 'Edit avatar')),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: name,
                decoration: InputDecoration(labelText: tr('Nom', 'Name')),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? tr('Nom requis.', 'Name required.')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: source,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: tr('URL de l’image (HTTPS)', 'Image URL (HTTPS)'),
                  helperText: existing == null
                      ? null
                      : tr('Laisser vide pour l’image intégrée.',
                          'Leave empty to use the built-in image.'),
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) {
                    return existing == null
                        ? tr('URL requise.', 'URL required.')
                        : null;
                  }
                  return value.startsWith('https://')
                      ? null
                      : tr('Utilisez une URL HTTPS.', 'Use an HTTPS URL.');
                },
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('Annuler', 'Cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: Text(tr('Enregistrer', 'Save')),
          ),
        ],
      ),
    );
    if (saved == true) {
      final item = {
        'id': existing?['id'] ??
            'avatar_${DateTime.now().millisecondsSinceEpoch}',
        'name': name.text.trim(),
        'type': existing?['type'] ?? 'photo',
        'source': source.text.trim(),
        'enabled': existing?['enabled'] ?? true,
      };
      await _save(existing == null
          ? [..._avatars, item]
          : [for (final a in _avatars) a['id'] == existing['id'] ? item : a]);
    }
    name.dispose();
    source.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = _avatars.where((a) => a['enabled'] == true).length;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('Nouvel avatar', 'New avatar')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            tr('$enabled avatar(s) proposé(s) aux utilisateurs. Au moins un avatar doit rester actif.',
                '$enabled avatar(s) offered to users. At least one must stay enabled.'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (var i = 0; i < _avatars.length; i++) ...[
                if (i > 0) const Divider(indent: 76),
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
                  leading: SizedBox.square(
                      dimension: 44,
                      child:
                          AvatarPortrait(variant: _avatars[i]['id'] as String)),
                  title: Text(_avatars[i]['name'] as String? ?? ''),
                  subtitle: Text(
                      (_avatars[i]['source'] as String? ?? '').isEmpty
                          ? tr('Image intégrée', 'Built-in image')
                          : _avatars[i]['source'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Switch.adaptive(
                      value: _avatars[i]['enabled'] == true,
                      onChanged: (value) {
                        if (!value && enabled <= 1) return;
                        _save([
                          for (final a in _avatars)
                            a['id'] == _avatars[i]['id']
                                ? {...a, 'enabled': value}
                                : a,
                        ]);
                      },
                    ),
                    PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'edit') _edit(_avatars[i]);
                        if (action == 'delete' && _avatars.length > 1) {
                          _save([..._avatars]..removeAt(i));
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                            value: 'edit', child: Text(tr('Modifier', 'Edit'))),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(tr('Supprimer', 'Delete'),
                              style: TextStyle(color: theme.colorScheme.error)),
                        ),
                      ],
                    ),
                  ]),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

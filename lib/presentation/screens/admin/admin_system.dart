import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../../data/services/admin_data_service.dart';
import '../../../data/services/echosign_api_client.dart';
import '../../widgets/ui_kit.dart';

/// Supervision du modèle IA, notifications et règles de sécurité.
class AdminSystemSection extends StatefulWidget {
  const AdminSystemSection({super.key});

  @override
  State<AdminSystemSection> createState() => _AdminSystemSectionState();
}

class _AdminSystemSectionState extends State<AdminSystemSection> {
  Map<String, dynamic> _model = {};
  Map<String, dynamic> _settings = {};
  List<Map<String, dynamic>> _announcements = [];
  bool _loading = true;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait<Object>([
      AdminDataService.loadModelConfig(),
      AdminDataService.loadSettings(),
      AdminDataService.loadAnnouncements(),
    ]);
    if (!mounted) return;
    setState(() {
      _model = results[0] as Map<String, dynamic>;
      _settings = results[1] as Map<String, dynamic>;
      _announcements = results[2] as List<Map<String, dynamic>>;
      _loading = false;
    });
  }

  Future<void> _updateSetting(String key, Object value) async {
    final updated = {..._settings, key: value};
    setState(() => _settings = updated);
    await AdminDataService.saveSettings(updated);
  }

  // --- Modèle IA -----------------------------------------------------------

  Future<void> _editModel() async {
    final formKey = GlobalKey<FormState>();
    final endpoint =
        TextEditingController(text: _model['endpoint'] as String? ?? '');
    final version =
        TextEditingController(text: _model['version'] as String? ?? '');
    final notes = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Mettre à jour le modèle', 'Update the model')),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: endpoint,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: tr('Adresse du serveur', 'Server address'),
                  hintText: 'http://192.168.1.20:8000',
                  helperText: tr(
                      'Adresse IP du PC qui exécute le serveur (pas « localhost »).',
                      'IP address of the computer running the server (not “localhost”).'),
                  helperMaxLines: 2,
                ),
                validator: (v) => EchoSignApiClient.resolve(v ?? '') == null
                    ? tr('Adresse invalide.', 'Invalid address.')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: version,
                decoration: InputDecoration(
                    labelText: tr('Version déployée', 'Deployed version')),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? tr('Version requise.', 'Version required.')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notes,
                decoration: InputDecoration(
                    labelText: tr('Notes de version (facultatif)',
                        'Release notes (optional)')),
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
            child: Text(tr('Déployer', 'Deploy')),
          ),
        ],
      ),
    );
    if (saved == true) {
      final history = [
        {
          'version': version.text.trim(),
          'notes': notes.text.trim(),
          'date': DateTime.now().toIso8601String(),
        },
        ...((_model['history'] as List?) ?? const []),
      ].take(10).toList();
      final updated = {
        ..._model,
        'endpoint': endpoint.text.trim(),
        'version': version.text.trim(),
        'status': 'configured',
        'lastUpdate': DateTime.now().toIso8601String(),
        'history': history,
      };
      await AdminDataService.saveModelConfig(updated);
      setState(() => _model = updated);
      await _checkModel();
    }
    endpoint.dispose();
    version.dispose();
    notes.dispose();
  }

  Future<void> _checkModel() async {
    final address = _model['endpoint'] as String? ?? '';
    if (EchoSignApiClient.resolve(address) == null) return;
    setState(() => _checking = true);
    final health = await EchoSignApiClient.checkHealth(address);
    final status = health == null
        ? 'unreachable'
        : health.modelLoaded
            ? 'online'
            : 'no_model';
    final updated = {
      ..._model,
      'status': status,
      if (health != null) 'latencyMs': health.latency.inMilliseconds,
      if (health != null) 'signCount': health.signCount,
      'lastCheck': DateTime.now().toIso8601String(),
    };
    await AdminDataService.saveModelConfig(updated);
    if (!mounted) return;
    setState(() {
      _model = updated;
      _checking = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(switch (status) {
        'online' => tr(
            'Serveur en ligne : ${health?.signCount} signes reconnus.',
            'Server online: ${health?.signCount} signs recognised.'),
        'no_model' => tr('Serveur joignable, mais le modèle n’est pas chargé.',
            'Server reachable, but the model is not loaded.'),
        _ => tr(
            'Serveur injoignable. Vérifiez l’adresse IP, que le serveur tourne et que le téléphone est sur le même Wi-Fi.',
            'Server unreachable. Check the IP address, that the server is running and that the phone is on the same Wi-Fi.'),
      }),
    ));
  }

  // --- Notifications ------------------------------------------------------

  Future<void> _compose() async {
    final title = TextEditingController();
    final message = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Nouvelle notification', 'New notification')),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: title,
                decoration: InputDecoration(labelText: tr('Titre', 'Title')),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: message,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                    labelText: tr('Message', 'Message'),
                    alignLabelWithHint: true),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? tr('Message requis.', 'Message required.')
                    : null,
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('Annuler', 'Cancel'))),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(tr('Envoyer', 'Send')),
          ),
        ],
      ),
    );
    if (send == true) {
      await AdminDataService.saveAnnouncement(message.text, title: title.text);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('Notification envoyée à tous les utilisateurs.',
                'Notification sent to all users.'))));
      }
    }
    title.dispose();
    message.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final theme = Theme.of(context);
    final english = AppPreferences.instance.isEnglish;
    final status = _model['status'] as String? ?? 'not_configured';
    final (statusLabel, statusColor) = switch (status) {
      'online' => (tr('En ligne', 'Online'), AppColors.success),
      'unreachable' => (
          tr('Injoignable', 'Unreachable'),
          theme.colorScheme.error
        ),
      'configured' => (tr('Configuré', 'Configured'), AppColors.info),
      'no_model' => (
          tr('Modèle non chargé', 'Model not loaded'),
          AppColors.warning
        ),
      _ => (tr('Non configuré', 'Not configured'), AppColors.warning),
    };
    final history = ((_model['history'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final timeout = _settings['sessionTimeoutMinutes'] as int? ?? 30;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        SectionHeader(tr('Modèle d’intelligence artificielle', 'AI model')),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                IconTile(
                    icon: Icons.memory_rounded,
                    color: theme.colorScheme.primary,
                    size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (_model['version'] as String? ?? '').isEmpty
                            ? tr('Reconnaissance LSF', 'LSF recognition')
                            : '${tr('Reconnaissance LSF', 'LSF recognition')} v${_model['version']}',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        (_model['endpoint'] as String? ?? '').isEmpty
                            ? tr(
                                'Aucune API configurée : l’application fonctionne en mode démonstration.',
                                'No API configured: the app runs in demo mode.')
                            : _model['endpoint'] as String,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                StatusPill(label: statusLabel, color: statusColor),
              ]),
              if (_model['latencyMs'] != null) ...[
                const SizedBox(height: 12),
                Text(
                  [
                    if (_model['signCount'] != null)
                      '${_model['signCount']} ${tr('signes reconnus', 'signs recognised')}',
                    '${tr('Temps de réponse', 'Response time')} : ${_model['latencyMs']} ms',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: _editModel,
                  icon: const Icon(Icons.system_update_alt_rounded, size: 18),
                  label: Text(tr('Mettre à jour', 'Update')),
                ),
                OutlinedButton.icon(
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed:
                      _checking || (_model['endpoint'] as String? ?? '').isEmpty
                          ? null
                          : _checkModel,
                  icon: _checking
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.network_check_rounded, size: 18),
                  label: Text(tr('Tester la connexion', 'Test connection')),
                ),
              ]),
              if (history.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(tr('Historique des versions', 'Version history'),
                    style: theme.textTheme.labelLarge),
                for (final h in history)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_rounded, size: 20),
                    title: Text('v${h['version']}'),
                    subtitle: Text([
                      relativeTime(h['date'] as String? ?? '',
                          english: english),
                      if ((h['notes'] as String? ?? '').isNotEmpty) h['notes'],
                    ].join(' · ')),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
        SectionHeader(tr('Notifications', 'Notifications'),
            actionLabel: tr('Nouvelle', 'New'), onAction: _compose),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            SwitchListTile.adaptive(
              title:
                  Text(tr('Notifications activées', 'Notifications enabled')),
              subtitle: Text(tr(
                  'Les utilisateurs reçoivent les annonces en temps réel.',
                  'Users receive announcements in real time.')),
              value: _settings['notificationsEnabled'] != false,
              onChanged: (v) => _updateSetting('notificationsEnabled', v),
            ),
            if (_announcements.isNotEmpty) const Divider(),
            for (final a in _announcements.take(5))
              ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: Text(
                    (a['title'] as String? ?? '').isEmpty
                        ? a['message'] as String? ?? ''
                        : a['title'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(relativeTime(a['createdAt'] as String? ?? '',
                    english: english)),
              ),
          ]),
        ),
        const SizedBox(height: 28),
        SectionHeader(tr('Sécurité', 'Security')),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text(tr('Déconnexion automatique', 'Automatic sign-out')),
              subtitle: Text(tr('Après une période d’inactivité',
                  'After a period of inactivity')),
              trailing: DropdownButton<int>(
                value: [15, 30, 60, 120].contains(timeout) ? timeout : 30,
                underline: const SizedBox.shrink(),
                items: [
                  for (final m in [15, 30, 60, 120])
                    DropdownMenuItem(value: m, child: Text('$m min')),
                ],
                onChanged: (v) {
                  if (v != null) _updateSetting('sessionTimeoutMinutes', v);
                },
              ),
            ),
            const Divider(),
            SwitchListTile.adaptive(
              secondary: const Icon(Icons.verified_user_outlined),
              title: Text(tr('Modération des signes', 'Sign moderation')),
              subtitle: Text(tr(
                  'Les signes proposés doivent être validés avant publication.',
                  'Suggested signs must be approved before publication.')),
              value: _settings['communityModerationRequired'] != false,
              onChanged: (v) =>
                  _updateSetting('communityModerationRequired', v),
            ),
            const Divider(),
            SwitchListTile.adaptive(
              secondary: const Icon(Icons.offline_pin_outlined),
              title: Text(tr('Accès hors ligne', 'Offline access')),
              subtitle: Text(tr(
                  'Dictionnaire et reconnaissance de base disponibles sans connexion.',
                  'Dictionary and basic recognition available offline.')),
              value: _settings['offlineAccessEnabled'] != false,
              onChanged: (v) => _updateSetting('offlineAccessEnabled', v),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.lock_outline_rounded),
              title: Text(tr('Rôles', 'Roles')),
              subtitle: Text(tr(
                  'Inscription publique = utilisateur. Seul un administrateur peut créer ou promouvoir un administrateur.',
                  'Public sign-up = user. Only an administrator can create or promote an administrator.')),
            ),
          ]),
        ),
      ],
    );
  }
}

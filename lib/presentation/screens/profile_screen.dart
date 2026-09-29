import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/l10n/tr.dart';
import '../../data/services/firebase_auth_service.dart';
import '../../data/services/sign_repository.dart';
import '../../data/services/notification_center.dart';
import '../../data/services/translation_history_service.dart';
import '../navigation.dart';
import '../widgets/ui_kit.dart';
import 'history_screen.dart';
import 'notifications_screen.dart';
import 'preferences_screen.dart';
import 'propose_sign_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String email;
  final String name;

  const ProfileScreen({super.key, required this.email, this.name = ''});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _name =
      widget.name.isEmpty ? widget.email.split('@').first : widget.name;

  Future<void> _editName() async {
    final controller = TextEditingController(text: _name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Modifier le nom', 'Edit name')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration:
              InputDecoration(labelText: tr('Nom complet', 'Full name')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('Annuler', 'Cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(tr('Enregistrer', 'Save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return;
    await FirebaseAuthService().updateName(widget.email, result);
    if (mounted) setState(() => _name = result);
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Se déconnecter ?', 'Sign out?')),
        content: Text(tr(
            'Vos préférences et votre historique restent enregistrés sur cet appareil.',
            'Your preferences and history stay saved on this device.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('Annuler', 'Cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Se déconnecter', 'Sign out')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await signOutAndReturnToLogin(context);
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Profil', 'Profile'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              // Initiales : les avatars servent à signer les messages reçus.
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                child: Text(
                  _name
                      .trim()
                      .split(RegExp(r'\s+'))
                      .where((w) => w.isNotEmpty)
                      .take(2)
                      .map((w) => w[0].toUpperCase())
                      .join(),
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name,
                        style: theme.textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(widget.email,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(
                tooltip: tr('Modifier le nom', 'Edit name'),
                onPressed: _editName,
                icon: const Icon(Icons.edit_outlined),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          _StatsRow(),
          const SizedBox(height: 24),
          SectionHeader(tr('Mon compte', 'My account')),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              MenuRow(
                icon: Icons.tune_rounded,
                title: tr('Préférences', 'Preferences'),
                subtitle: tr('Mode de réception, style d’avatar, langue, thème',
                    'Display mode, avatar style, language, theme'),
                onTap: () => _push(const PreferencesScreen()),
              ),
              const Divider(indent: 72),
              MenuRow(
                icon: Icons.history_rounded,
                title: tr('Historique', 'History'),
                subtitle: tr('Traductions et conversations',
                    'Translations and conversations'),
                onTap: () => _push(const HistoryScreen()),
              ),
              const Divider(indent: 72),
              ListenableBuilder(
                listenable: NotificationCenter.instance,
                builder: (context, _) {
                  final count = NotificationCenter.instance.unreadCount;
                  return MenuRow(
                    icon: Icons.notifications_none_rounded,
                    title: tr('Notifications', 'Notifications'),
                    subtitle: count == 0
                        ? tr('Tout est lu', 'All caught up')
                        : tr('$count non lue(s)', '$count unread'),
                    trailing: count == 0 ? null : Badge(label: Text('$count')),
                    onTap: () => _push(const NotificationsScreen()),
                  );
                },
              ),
            ]),
          ),
          const SizedBox(height: 24),
          SectionHeader(tr('Communauté', 'Community')),
          AppCard(
            padding: EdgeInsets.zero,
            child: MenuRow(
              icon: Icons.add_circle_outline_rounded,
              title: tr('Proposer un signe', 'Suggest a sign'),
              subtitle: tr('Enrichissez le dictionnaire LSF',
                  'Help grow the LSF dictionary'),
              onTap: () => _push(ProposeSignScreen(author: _name)),
            ),
          ),
          const SizedBox(height: 24),
          AppCard(
            padding: EdgeInsets.zero,
            child: MenuRow(
              icon: Icons.logout_rounded,
              title: tr('Se déconnecter', 'Sign out'),
              color: theme.colorScheme.error,
              onTap: _confirmSignOut,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('NeuroSigne · version 1.0.0',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: TranslationHistoryService.changes,
        builder: (context, _, __) => FutureBuilder(
          future: Future.wait([
            TranslationHistoryService.getHistory(),
            SignRepository.favorites(),
          ]),
          builder: (context, snapshot) {
            final history =
                snapshot.data?[0] as List<Map<String, dynamic>>? ?? const [];
            final favorites = snapshot.data?[1] as Set<String>? ?? const {};
            final conversations =
                history.where((e) => e['type'] == 'conversation').length;
            return Row(children: [
              _Stat(
                  value: '${history.length - conversations}',
                  label: tr('Traductions', 'Translations')),
              const SizedBox(width: 12),
              _Stat(
                  value: '$conversations',
                  label: tr('Conversations', 'Conversations')),
              const SizedBox(width: 12),
              _Stat(
                  value: '${favorites.length}',
                  label: tr('Favoris', 'Favourites')),
            ]);
          },
        ),
      );
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(children: [
          Text(value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                maxLines: 1,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        ]),
      ),
    );
  }
}

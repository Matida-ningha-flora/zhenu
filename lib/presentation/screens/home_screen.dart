import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/l10n/tr.dart';
import '../../core/preferences/app_preferences.dart';
import '../../data/services/notification_center.dart';
import '../../data/services/translation_history_service.dart';
import '../widgets/lsf_explain_button.dart';
import '../widgets/motion.dart';
import '../widgets/ui_kit.dart';
import 'history_screen.dart';
import 'notifications_screen.dart';
import 'translator_screen.dart';

/// Onglet d'accueil : accès direct aux trois façons de communiquer,
/// raccourcis et activité récente.
class HomeScreen extends StatelessWidget {
  final String name;
  final ValueChanged<TranslatorMode> onOpenTranslator;
  final ValueChanged<int> onOpenTab;

  const HomeScreen({
    super.key,
    required this.name,
    required this.onOpenTranslator,
    required this.onOpenTab,
  });

  String get _firstName => name.trim().split(' ').first;

  /// Entrée en cascade des blocs de l'accueil (les espacements restent fixes).
  static List<Widget> _cascade(List<Widget> children) {
    var index = 0;
    return [
      for (final child in children)
        child is SizedBox
            ? child
            : FadeSlideIn(
                delay: FadeSlideIn.stagger(index++, stepMs: 80, startMs: 60),
                child: child),
    ];
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5 || hour >= 18) return tr('Bonsoir', 'Good evening');
    return tr('Bonjour', hour < 12 ? 'Good morning' : 'Good afternoon');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              sliver: SliverToBoxAdapter(
                child: FadeSlideIn(
                    child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _firstName.isEmpty
                              ? _greeting()
                              : '${_greeting()}, $_firstName',
                          style: theme.textTheme.headlineSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr('Avec qui communiquez-vous aujourd’hui ?',
                              'Who are you talking to today?'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const _NotificationBell(),
                ])),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              sliver: SliverList.list(
                  children: _cascade([
                _PrimaryActions(onOpen: onOpenTranslator),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.groups_rounded,
                  color: AppColors.terracotta,
                  title: tr('Conversation à plusieurs', 'Group conversation'),
                  subtitle: tr(
                      'Échangez avec un ou plusieurs interlocuteurs, chaque message est traduit.',
                      'Talk with one or more people, every message is translated.'),
                  onTap: () => onOpenTranslator(TranslatorMode.conversation),
                ),
                const SizedBox(height: 28),
                SectionHeader(tr('Accès rapide', 'Quick access')),
                Row(children: [
                  Expanded(
                    child: _ShortcutTile(
                      icon: Icons.menu_book_rounded,
                      label: tr('Dictionnaire LSF', 'LSF dictionary'),
                      color: AppColors.olive,
                      onTap: () => onOpenTab(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ShortcutTile(
                      icon: Icons.history_rounded,
                      label: tr('Historique', 'History'),
                      color: AppColors.amber,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const HistoryScreen())),
                    ),
                  ),
                ]),
                const SizedBox(height: 28),
                SectionHeader(tr('Activité récente', 'Recent activity'),
                    actionLabel: tr('Tout voir', 'See all'),
                    onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const HistoryScreen()))),
                const _RecentActivity(),
              ])),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: NotificationCenter.instance,
        builder: (context, _) {
          final count = NotificationCenter.instance.unreadCount;
          return IconButton(
            tooltip: tr('Notifications', 'Notifications'),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            icon: Badge(
              isLabelVisible: count > 0,
              label: Text(count > 9 ? '9+' : '$count'),
              child: const Icon(Icons.notifications_none_rounded, size: 28),
            ),
          );
        },
      );
}

class _PrimaryActions extends StatelessWidget {
  final ValueChanged<TranslatorMode> onOpen;
  const _PrimaryActions({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(tr('Traduction instantanée', 'Instant translation'),
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: Colors.white)),
            ),
            Theme(
              data: theme.copyWith(
                  colorScheme:
                      theme.colorScheme.copyWith(primary: Colors.white)),
              child: LsfExplainButton(
                  text: tr(
                      'Traduction instantanée. Signez pour être traduit en texte et en voix, ou parlez pour être traduit en LSF.',
                      'Instant translation. Sign to be translated into text and speech, or speak to be translated into LSF.')),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            tr('Choisissez dans quel sens vous communiquez.',
                'Choose which way you are communicating.'),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 18),
          IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // L'action propre au profil vient en premier.
              for (final (i, mode)
                  in (AppPreferences.instance.userProfile == 'hearing'
                          ? [TranslatorMode.speech, TranslatorMode.sign]
                          : [TranslatorMode.sign, TranslatorMode.speech])
                      .indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: mode == TranslatorMode.sign
                      ? _HeroButton(
                          icon: Icons.front_hand_rounded,
                          title: tr('Je signe', 'I sign'),
                          subtitle:
                              tr('LSF → texte et voix', 'LSF → text & speech'),
                          onTap: () => onOpen(TranslatorMode.sign),
                        )
                      : _HeroButton(
                          icon: Icons.mic_rounded,
                          title: tr('Je parle', 'I speak'),
                          subtitle:
                              tr('Voix ou texte → LSF', 'Voice or text → LSF'),
                          onTap: () => onOpen(TranslatorMode.speech),
                        ),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HeroButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: icon, color: AppColors.primary, size: 40),
              const SizedBox(height: 12),
              Text(title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      child: Row(children: [
        IconTile(icon: icon, color: color, size: 48),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurfaceVariant),
      ]),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShortcutTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        child: Row(children: [
          IconTile(icon: icon, color: color, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.titleSmall, maxLines: 2),
          ),
        ]),
      );
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: TranslationHistoryService.changes,
        builder: (context, _, __) => FutureBuilder<List<Map<String, dynamic>>>(
          future: TranslationHistoryService.getHistory(),
          builder: (context, snapshot) {
            final items = (snapshot.data ?? const []).take(3).toList();
            if (items.isEmpty) {
              final theme = Theme.of(context);
              return AppCard(
                child: Row(children: [
                  Icon(Icons.history_toggle_off_rounded,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr('Vos traductions et conversations apparaîtront ici.',
                          'Your translations and conversations will appear here.'),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ]),
              );
            }
            return AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(indent: 72),
                  HistoryTile(entry: items[i], dense: true),
                ],
              ]),
            );
          },
        ),
      );
}

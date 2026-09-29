import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/preferences/app_preferences.dart';
import '../../data/services/notification_center.dart';
import '../widgets/lsf_explain_button.dart';
import '../widgets/ui_kit.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _center = NotificationCenter.instance;

  /// Notifications non lues à l'ouverture : restent mises en avant pendant
  /// la consultation, même après leur marquage comme lues.
  late final Set<String> _unreadOnOpen = {
    for (final item in _center.items)
      if (_center.isUnread(item)) item['id'].toString(),
  };

  @override
  void initState() {
    super.initState();
    _center.markAllRead();
  }

  @override
  Widget build(BuildContext context) {
    final english = AppPreferences.instance.isEnglish;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Notifications', 'Notifications'))),
      body: ListenableBuilder(
        listenable: _center,
        builder: (context, _) {
          final items = _center.items;
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_none_rounded,
              title: tr('Aucune notification', 'No notifications'),
              message: tr(
                  'Les annonces de l’équipe NeuroSigne apparaîtront ici en temps réel.',
                  'Announcements from the NeuroSigne team will appear here in real time.'),
            );
          }
          return RefreshIndicator(
            onRefresh: _center.refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                final theme = Theme.of(context);
                final unread = _unreadOnOpen.contains(item['id'].toString());
                final title = (item['title'] as String? ?? '').trim();
                final message = item['message'] as String? ?? '';
                return AppCard(
                  color: unread
                      ? theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.5)
                      : null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconTile(
                          icon: Icons.campaign_outlined,
                          color: theme.colorScheme.primary,
                          size: 40),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text(
                                  title.isEmpty
                                      ? tr('Annonce', 'Announcement')
                                      : title,
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                              if (unread)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ]),
                            const SizedBox(height: 4),
                            Text(message, style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 6),
                            Row(children: [
                              Text(
                                relativeTime(item['createdAt'] as String? ?? '',
                                    english: english),
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant),
                              ),
                              const Spacer(),
                              LsfExplainButton(
                                  text: title.isEmpty
                                      ? message
                                      : '$title. $message'),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

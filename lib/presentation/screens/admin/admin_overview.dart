import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/tr.dart';
import '../../../data/services/admin_data_service.dart';
import '../../../data/services/admin_user_service.dart';
import '../../../data/services/sign_repository.dart';
import '../../widgets/ui_kit.dart';

class AdminOverviewSection extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  const AdminOverviewSection({super.key, required this.onNavigate});

  @override
  State<AdminOverviewSection> createState() => _AdminOverviewSectionState();
}

class _AdminOverviewSectionState extends State<AdminOverviewSection> {
  late Future<List<Object>> _data = _load();

  Future<List<Object>> _load() => Future.wait<Object>([
        AdminDataService.loadAnalytics(),
        AdminUserService.listUsers(),
        SignRepository.officialSigns(),
        SignRepository.communitySuggestions(),
        AdminDataService.loadModelConfig(),
      ]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<Object>>(
      future: _data,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final analytics = snapshot.data![0] as Map<String, dynamic>;
        final users = snapshot.data![1] as List<Map<String, dynamic>>;
        final signs = snapshot.data![2] as List;
        final pending = (snapshot.data![3] as List<Map<String, dynamic>>)
            .where((s) => s['status'] != 'Rejeté')
            .length;
        final model = snapshot.data![4] as Map<String, dynamic>;
        final admins = users.where((u) => u['role'] == 'admin').length;
        final top = AdminDataService.topSearches(analytics, limit: 6);

        final metrics = [
          (
            icon: Icons.translate_rounded,
            color: AppColors.primary,
            label: tr('Traductions', 'Translations'),
            value: '${analytics['translations'] ?? 0}'
          ),
          (
            icon: Icons.search_rounded,
            color: AppColors.secondary,
            label: tr('Recherches', 'Searches'),
            value: '${analytics['dictionarySearches'] ?? 0}'
          ),
          (
            icon: Icons.people_outline_rounded,
            color: AppColors.terracotta,
            label: tr('Comptes', 'Accounts'),
            value: '${users.length}'
          ),
          (
            icon: Icons.menu_book_outlined,
            color: AppColors.amber,
            label: tr('Signes publiés', 'Published signs'),
            value: '${signs.length}'
          ),
        ];

        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _data = _load());
            await _data;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth > 700 ? 4 : 2;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final m in metrics)
                    SizedBox(
                      width: width,
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconTile(icon: m.icon, color: m.color, size: 38),
                            const SizedBox(height: 14),
                            Text(m.value, style: theme.textTheme.headlineSmall),
                            Text(m.label,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                ]);
              }),
              const SizedBox(height: 16),
              if (pending > 0)
                AppCard(
                  onTap: () => widget.onNavigate(1),
                  color: theme.colorScheme.primaryContainer,
                  child: Row(children: [
                    Icon(Icons.pending_actions_rounded,
                        color: theme.colorScheme.onPrimaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr('$pending signe(s) proposé(s) en attente de validation',
                            '$pending proposed sign(s) awaiting review'),
                        style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: theme.colorScheme.onPrimaryContainer),
                  ]),
                ),
              const SizedBox(height: 24),
              SectionHeader(
                  tr('Signes les plus recherchés', 'Most searched signs')),
              AppCard(
                child: top.isEmpty
                    ? Text(
                        tr('Aucune recherche enregistrée pour le moment.',
                            'No searches recorded yet.'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant))
                    : Column(children: [
                        for (final entry in top)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(children: [
                              SizedBox(
                                width: 120,
                                child: Text(entry.key,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium),
                              ),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: entry.value / top.first.value,
                                    minHeight: 10,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 44,
                                child: Text('${entry.value}',
                                    textAlign: TextAlign.end,
                                    style: theme.textTheme.labelLarge),
                              ),
                            ]),
                          ),
                      ]),
              ),
              const SizedBox(height: 24),
              SectionHeader(tr('Plateforme', 'Platform')),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  MenuRow(
                    icon: Icons.memory_rounded,
                    title: tr('Modèle de reconnaissance', 'Recognition model'),
                    subtitle: switch (model['status']) {
                      'online' =>
                        '${tr('En ligne', 'Online')} · v${model['version']}',
                      'unreachable' => tr('Injoignable', 'Unreachable'),
                      'configured' =>
                        '${tr('Configuré', 'Configured')} · v${model['version']}',
                      _ => tr('Non configuré (mode démonstration)',
                          'Not configured (demo mode)'),
                    },
                    onTap: () => widget.onNavigate(4),
                  ),
                  const Divider(indent: 72),
                  MenuRow(
                    icon: Icons.admin_panel_settings_outlined,
                    title: tr('Administrateurs', 'Administrators'),
                    subtitle: '$admins',
                    onTap: () => widget.onNavigate(2),
                  ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

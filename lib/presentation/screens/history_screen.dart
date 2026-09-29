import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/l10n/tr.dart';
import '../../core/preferences/app_preferences.dart';
import '../../data/services/translation_history_service.dart';
import '../widgets/lsf_renderer.dart';
import '../widgets/ui_kit.dart';

({IconData icon, Color color, String label}) historyTypeMeta(String type) =>
    switch (type) {
      'sign_to_text' => (
          icon: Icons.front_hand_rounded,
          color: AppColors.primary,
          label: tr('LSF → texte', 'LSF → text'),
        ),
      'text_to_sign' => (
          icon: Icons.sign_language_rounded,
          color: AppColors.secondary,
          label: tr('Texte → LSF', 'Text → LSF'),
        ),
      'conversation' => (
          icon: Icons.forum_rounded,
          color: AppColors.terracotta,
          label: tr('Conversation', 'Conversation'),
        ),
      _ => (
          icon: Icons.translate_rounded,
          color: AppColors.textMuted,
          label: tr('Traduction', 'Translation'),
        ),
    };

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'all';
  String _query = '';

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Effacer l’historique ?', 'Clear history?')),
        content: Text(tr(
            'Toutes vos traductions et conversations enregistrées sur cet appareil seront supprimées.',
            'All translations and conversations saved on this device will be deleted.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('Annuler', 'Cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Effacer', 'Clear')),
          ),
        ],
      ),
    );
    if (confirmed == true) await TranslationHistoryService.clearHistory();
  }

  bool _matches(Map<String, dynamic> entry) {
    if (_filter != 'all' && entry['type'] != _filter) return false;
    if (_query.isEmpty) return true;
    final haystack = '${entry['input']} ${entry['output']}'.toLowerCase();
    return haystack.contains(_query.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: TranslationHistoryService.changes,
      builder: (context, _, __) => FutureBuilder<List<Map<String, dynamic>>>(
        future: TranslationHistoryService.getHistory(),
        builder: (context, snapshot) {
          final all = snapshot.data ?? const [];
          final items = all.where(_matches).toList();
          return Scaffold(
            appBar: AppBar(
              title: Text(tr('Historique', 'History')),
              actions: [
                if (all.isNotEmpty)
                  IconButton(
                    tooltip: tr('Tout effacer', 'Clear all'),
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: _confirmClearAll,
                  ),
              ],
            ),
            body: !snapshot.hasData
                ? const Center(child: CircularProgressIndicator())
                : all.isEmpty
                    ? EmptyState(
                        icon: Icons.history_rounded,
                        title: tr('Aucun historique', 'No history yet'),
                        message: tr(
                            'Vos traductions et conversations apparaîtront ici automatiquement.',
                            'Your translations and conversations will appear here automatically.'),
                      )
                    : Column(children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: TextField(
                            onChanged: (v) => setState(() => _query = v.trim()),
                            decoration: InputDecoration(
                              hintText: tr('Rechercher dans l’historique',
                                  'Search history'),
                              prefixIcon: const Icon(Icons.search_rounded),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 44,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              for (final f in const [
                                'all',
                                'sign_to_text',
                                'text_to_sign',
                                'conversation'
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(f == 'all'
                                        ? tr('Tout', 'All')
                                        : historyTypeMeta(f).label),
                                    selected: _filter == f,
                                    showCheckmark: false,
                                    onSelected: (_) =>
                                        setState(() => _filter = f),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: items.isEmpty
                              ? EmptyState(
                                  icon: Icons.search_off_rounded,
                                  title: tr('Aucun résultat', 'No results'),
                                  message: tr('Essayez un autre filtre.',
                                      'Try another filter.'),
                                )
                              : ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 32),
                                  itemCount: items.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final entry = items[index];
                                    return Dismissible(
                                      key: ValueKey(entry['id']),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: const Icon(Icons.delete_outline,
                                            color: Colors.white),
                                      ),
                                      onDismissed: (_) =>
                                          TranslationHistoryService.deleteEntry(
                                              entry['id'] as String),
                                      child: AppCard(
                                        padding: EdgeInsets.zero,
                                        child: HistoryTile(entry: entry),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ]),
          );
        },
      ),
    );
  }
}

/// Ligne d'historique réutilisée sur l'accueil.
class HistoryTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  final bool dense;

  const HistoryTile({super.key, required this.entry, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = historyTypeMeta(entry['type'] as String? ?? '');
    final output = entry['output'] as String? ?? '';
    final english = AppPreferences.instance.isEnglish;
    return ListTile(
      onTap: () => _openDetail(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: IconTile(icon: meta.icon, color: meta.color, size: 40),
      title: Text(entry['input'] as String? ?? '',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${meta.label} · ${relativeTime(entry['timestamp'] as String? ?? '', english: english)}'
        '${!dense && output.isNotEmpty ? '\n$output' : ''}',
        maxLines: dense ? 1 : 3,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: !dense && output.isNotEmpty,
      trailing: Icon(Icons.chevron_right_rounded,
          color: theme.colorScheme.onSurfaceVariant),
    );
  }

  void _openDetail(BuildContext context) {
    final meta = historyTypeMeta(entry['type'] as String? ?? '');
    final messages = ((entry['messages'] as List?) ?? const [])
        .map((m) => Map<String, dynamic>.from(m as Map))
        .toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.85),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Row(children: [
                  IconTile(icon: meta.icon, color: meta.color, size: 36),
                  const SizedBox(width: 12),
                  Text(meta.label, style: theme.textTheme.titleMedium),
                ]),
                const SizedBox(height: 16),
                Text(entry['input'] as String? ?? '',
                    style: theme.textTheme.titleLarge),
                if ((entry['output'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(entry['output'] as String,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
                if (messages.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  for (final message in messages)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(
                            text: '${message['speaker']} : ',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: message['text'] as String? ?? ''),
                      ])),
                    ),
                ],
                if (entry['type'] == 'text_to_sign') ...[
                  const SizedBox(height: 20),
                  LsfRenderer(
                      text: entry['input'] as String? ?? '', autoplay: false),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/l10n/tr.dart';
import '../../../data/services/sign_repository.dart';
import '../../widgets/ui_kit.dart';
import '../dictionary_screen.dart';

/// Validation des signes proposés par la communauté.
class AdminSignsSection extends StatefulWidget {
  const AdminSignsSection({super.key});

  @override
  State<AdminSignsSection> createState() => _AdminSignsSectionState();
}

class _AdminSignsSectionState extends State<AdminSignsSection> {
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _official = [];
  bool _loading = true;
  String _query = '';

  List<Map<String, dynamic>> get _pending => _suggestions
      .where((s) => (s['status'] ?? 'En attente') == 'En attente')
      .toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      SignRepository.communitySuggestions(),
      SignRepository.officialSigns(),
    ]);
    if (!mounted) return;
    setState(() {
      _suggestions = results[0];
      _official = results[1]
        ..sort((a, b) =>
            (a['word'] as String? ?? '').compareTo(b['word'] as String? ?? ''));
      _loading = false;
    });
  }

  Future<void> _decide(Map<String, dynamic> suggestion, bool approve) async {
    final word = suggestion['word'] as String? ?? '';
    if (!approve) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('Rejeter « $word » ?', 'Reject “$word”?')),
          content: Text(tr('La proposition ne sera pas publiée.',
              'The proposal will not be published.')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr('Annuler', 'Cancel'))),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('Rejeter', 'Reject')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await SignRepository.setSuggestionStatus(suggestion,
          approve ? SignRepository.approved : SignRepository.rejected);
      if (approve) {
        await SignRepository.publishSign({
          'id': 'community_${suggestion['id']}',
          'word': word,
          'category': suggestion['category'] ?? 'Vie quotidienne',
          'gestureEmoji': suggestion['gestureEmoji'] ?? '🤟',
          'gestureSummary':
              suggestion['gestureSummary'] ?? suggestion['description'] ?? '',
          'description': suggestion['description'] ?? '',
          'variant': suggestion['variant'] ?? 'LSF',
          'difficulty': 'Moyen',
          'author': suggestion['author'],
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('Action impossible. Vérifiez la connexion.',
                'Action failed. Check your connection.'))));
      }
      return;
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve
            ? tr('« $word » est publié dans le dictionnaire.',
                '“$word” is now in the dictionary.')
            : tr('Proposition rejetée.', 'Proposal rejected.'))));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final pending = _pending;
    final query = SignRepository.normalize(_query);
    final official = _official
        .where((s) =>
            query.isEmpty ||
            SignRepository.normalize(s['word'] as String? ?? '')
                .contains(query))
        .toList();
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        TabBar(tabs: [
          Tab(text: '${tr('En attente', 'Pending')} (${pending.length})'),
          Tab(text: '${tr('Publiés', 'Published')} (${_official.length})'),
        ]),
        Expanded(
          child: TabBarView(children: [
            pending.isEmpty
                ? EmptyState(
                    icon: Icons.task_alt_rounded,
                    title: tr('Tout est traité', 'All caught up'),
                    message: tr('Aucune proposition en attente de validation.',
                        'No proposal awaiting review.'),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      itemCount: pending.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _SuggestionCard(
                        suggestion: pending[i],
                        onApprove: () => _decide(pending[i], true),
                        onReject: () => _decide(pending[i], false),
                      ),
                    ),
                  ),
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: tr('Rechercher un signe', 'Search a sign'),
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (var i = 0; i < official.length; i++) ...[
                      if (i > 0) const Divider(indent: 72),
                      ListTile(
                        leading: Text(
                            official[i]['gestureEmoji'] as String? ?? '🤟',
                            style: const TextStyle(fontSize: 24)),
                        title: Text(official[i]['word'] as String? ?? ''),
                        subtitle:
                            Text(official[i]['category'] as String? ?? ''),
                        trailing: official[i]['author'] != null
                            ? StatusPill(
                                label: tr('Communauté', 'Community'),
                                color: Theme.of(context).colorScheme.secondary)
                            : null,
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    SignDetailScreen(sign: official[i]))),
                      ),
                    ],
                  ]),
                ),
              ],
            ),
          ]),
        ),
      ]),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final Map<String, dynamic> suggestion;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _SuggestionCard(
      {required this.suggestion,
      required this.onApprove,
      required this.onReject});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(suggestion['gestureEmoji'] as String? ?? '🤟',
                  style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(suggestion['word'] as String? ?? '',
                      style: theme.textTheme.titleSmall),
                  Text(
                    '${suggestion['category'] ?? ''} · ${tr('par', 'by')} ${suggestion['author'] ?? tr('Anonyme', 'Anonymous')}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if ((suggestion['votes'] as num? ?? 0) > 0)
              StatusPill(
                label: '${suggestion['votes']} ${tr('soutiens', 'votes')}',
                color: theme.colorScheme.secondary,
                icon: Icons.thumb_up_alt_outlined,
              ),
          ]),
          const SizedBox(height: 12),
          Text(suggestion['description'] as String? ?? '',
              style: theme.textTheme.bodyMedium),
          if ((suggestion['variant'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('${tr('Variante', 'Variant')} : ${suggestion['variant']}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: onReject,
                icon: const Icon(Icons.close_rounded),
                label: Text(tr('Rejeter', 'Reject')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: onApprove,
                icon: const Icon(Icons.check_rounded),
                label: Text(tr('Valider', 'Approve')),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

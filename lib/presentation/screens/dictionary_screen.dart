import 'dart:async';
import '../../core/constants/app_colors.dart';

import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../data/services/admin_data_service.dart';
import '../../data/services/firebase_auth_service.dart';
import '../../data/services/sign_repository.dart';
import '../../data/services/voice_services.dart';
import '../widgets/lsf_explain_button.dart';
import '../widgets/lsf_renderer.dart';
import '../widgets/motion.dart';
import '../widgets/ui_kit.dart';
import 'propose_sign_screen.dart';

/// Dictionnaire LSF : recherche par mot, par catégorie ou par paramètres du
/// geste. Les signes sont embarqués et consultables hors connexion.
class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  static const handshapes = [
    'Main plate',
    'Poing',
    'Index',
    'Paume ouverte',
    'Pince',
    'C-shape',
    'Victoire',
    'Cornes',
  ];
  static const locations = [
    'Tête / Visage',
    'Bouche / Menton',
    'Torse / Poitrine',
    'Bras / Poignet',
    'Espace neutre',
  ];
  static const movements = [
    'Fixe',
    'Linéaire (Haut/Bas)',
    'Circulaire',
    'Repétitif',
    'Oscillant',
  ];

  List<Map<String, dynamic>> _signs = [];
  Set<String> _favorites = {};
  bool _loading = true;
  String _query = '';
  String? _category;
  bool _favoritesOnly = false;
  String? _handshape;
  String? _location;
  String? _movement;
  Timer? _analyticsTimer;

  int get _parameterCount =>
      [_handshape, _location, _movement].where((v) => v != null).length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _analyticsTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait<Object>([
      SignRepository.officialSigns(),
      SignRepository.favorites(),
    ]);
    if (!mounted) return;
    setState(() {
      _signs = (results[0] as List<Map<String, dynamic>>)
        ..sort((a, b) =>
            (a['word'] as String? ?? '').compareTo(b['word'] as String? ?? ''));
      _favorites = results[1] as Set<String>;
      _loading = false;
    });
  }

  void _onSearch(String value) {
    setState(() => _query = value);
    _analyticsTimer?.cancel();
    _analyticsTimer = Timer(const Duration(milliseconds: 900),
        () => AdminDataService.recordDictionarySearch(value));
  }

  Future<void> _toggleFavorite(String id) async {
    setState(() {
      if (!_favorites.remove(id)) _favorites.add(id);
    });
    await SignRepository.saveFavorites(_favorites);
  }

  List<Map<String, dynamic>> get _filtered {
    final query = SignRepository.normalize(_query);
    return _signs.where((sign) {
      if (_favoritesOnly && !_favorites.contains(sign['id'])) return false;
      if (_category != null && sign['category'] != _category) return false;
      if (_handshape != null && sign['handshape'] != _handshape) return false;
      if (_location != null && sign['location'] != _location) return false;
      if (_movement != null && sign['movement'] != _movement) return false;
      if (query.isEmpty) return true;
      return SignRepository.normalize(
              '${sign['word']} ${sign['gestureSummary']} ${sign['category']}')
          .contains(query);
    }).toList();
  }

  Future<void> _openParameters() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          final theme = Theme.of(context);
          Widget group(String title, List<String> values, String? selected,
                  ValueChanged<String?> onChanged) =>
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final value in values)
                      FilterChip(
                        label: Text(value),
                        selected: selected == value,
                        onSelected: (on) {
                          setSheet(() => onChanged(on ? value : null));
                          setState(() {});
                        },
                      ),
                  ]),
                  const SizedBox(height: 20),
                ],
              );
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('Rechercher par le geste', 'Search by gesture'),
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    tr('Vous avez vu un signe sans connaître le mot ? Décrivez-le.',
                        'Saw a sign but don’t know the word? Describe it.'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  group(tr('Forme de la main', 'Handshape'), handshapes,
                      _handshape, (v) => _handshape = v),
                  group(tr('Emplacement', 'Location'), locations, _location,
                      (v) => _location = v),
                  group(tr('Mouvement', 'Movement'), movements, _movement,
                      (v) => _movement = v),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setSheet(
                              () => _handshape = _location = _movement = null);
                          setState(() {});
                        },
                        child: Text(tr('Réinitialiser', 'Reset')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(tr('${_filtered.length} résultat(s)',
                            '${_filtered.length} result(s)')),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _propose() async {
    final user = await FirebaseAuthService().getCurrentUser();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProposeSignScreen(
            author: user?['name'] as String? ?? tr('Membre', 'Member'))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Dictionnaire LSF', 'LSF dictionary')),
        actions: [
          IconButton(
            tooltip: tr('Proposer un signe', 'Suggest a sign'),
            onPressed: _propose,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      onChanged: _onSearch,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: tr('Rechercher un signe', 'Search a sign'),
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Badge(
                    isLabelVisible: _parameterCount > 0,
                    label: Text('$_parameterCount'),
                    child: IconButton.outlined(
                      style: IconButton.styleFrom(
                        minimumSize: const Size(52, 52),
                        side:
                            BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      tooltip:
                          tr('Rechercher par le geste', 'Search by gesture'),
                      onPressed: _openParameters,
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ),
                ]),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: Icon(
                            _favoritesOnly
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 18),
                        label: Text(tr('Favoris', 'Favourites')),
                        selected: _favoritesOnly,
                        showCheckmark: false,
                        onSelected: (v) => setState(() => _favoritesOnly = v),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(tr('Toutes', 'All')),
                        selected: _category == null,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _category = null),
                      ),
                    ),
                    for (final category in SignRepository.categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: _category == category,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _category =
                              _category == category ? null : category),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(children: [
                  Expanded(
                    child: Text(
                        tr('${results.length} signe(s)',
                            '${results.length} sign(s)'),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ),
                  Icon(Icons.offline_pin_outlined,
                      size: 16, color: theme.colorScheme.secondary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(tr('Hors ligne', 'Offline'),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: theme.colorScheme.secondary)),
                  ),
                ]),
              ),
              Expanded(
                child: results.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off_rounded,
                        title: tr('Aucun signe trouvé', 'No sign found'),
                        message: tr(
                            'Essayez un autre mot ou proposez ce signe à la communauté.',
                            'Try another word or suggest this sign to the community.'),
                        action: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 44)),
                          onPressed: _propose,
                          icon: const Icon(Icons.add_rounded),
                          label:
                              Text(tr('Proposer un signe', 'Suggest a sign')),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final sign = results[index];
                          final id = sign['id'].toString();
                          return FadeSlideIn(
                              delay: FadeSlideIn.stagger(index < 8 ? index : 0,
                                  stepMs: 45),
                              offset: 12,
                              child: _SignCard(
                                sign: sign,
                                favorite: _favorites.contains(id),
                                onFavorite: () => _toggleFavorite(id),
                                onTap: () async {
                                  await Navigator.of(context)
                                      .push(MaterialPageRoute(
                                          builder: (_) => SignDetailScreen(
                                                sign: sign,
                                                favorite:
                                                    _favorites.contains(id),
                                                onFavorite: () =>
                                                    _toggleFavorite(id),
                                              )));
                                  if (mounted) setState(() {});
                                },
                              ));
                        },
                      ),
              ),
            ]),
    );
  }
}

class _SignCard extends StatelessWidget {
  final Map<String, dynamic> sign;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  const _SignCard({
    required this.sign,
    required this.favorite,
    required this.onFavorite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(sign['gestureEmoji'] as String? ?? '🤟',
              style: const TextStyle(fontSize: 26)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sign['word'] as String? ?? '',
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(sign['gestureSummary'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Text(sign['category'] as String? ?? '',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.primary)),
            ],
          ),
        ),
        IconButton(
          tooltip: favorite
              ? tr('Retirer des favoris', 'Remove from favourites')
              : tr('Ajouter aux favoris', 'Add to favourites'),
          onPressed: onFavorite,
          icon: Icon(favorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: favorite
                  ? AppColors.secondary
                  : theme.colorScheme.onSurfaceVariant),
        ),
      ]),
    );
  }
}

/// Fiche détaillée d'un signe.
class SignDetailScreen extends StatefulWidget {
  final Map<String, dynamic> sign;
  final bool favorite;
  final VoidCallback? onFavorite;

  const SignDetailScreen(
      {super.key, required this.sign, this.favorite = false, this.onFavorite});

  @override
  State<SignDetailScreen> createState() => _SignDetailScreenState();
}

class _SignDetailScreenState extends State<SignDetailScreen> {
  late bool _favorite = widget.favorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sign = widget.sign;
    final word = sign['word'] as String? ?? '';
    final steps = [
      for (final key in ['step1', 'step2', 'step3'])
        if ((sign[key] as String? ?? '').isNotEmpty) sign[key] as String,
    ];
    final example = sign['exampleSentence'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(word),
        actions: [
          IconButton(
            tooltip: tr('Écouter le mot', 'Hear the word'),
            onPressed: () => SpeechOutput.instance.speak(word),
            icon: const Icon(Icons.volume_up_outlined),
          ),
          if (widget.onFavorite != null)
            IconButton(
              tooltip: tr('Favori', 'Favourite'),
              onPressed: () {
                widget.onFavorite!();
                setState(() => _favorite = !_favorite);
              },
              icon: Icon(
                  _favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: _favorite ? AppColors.secondary : null),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            StatusPill(
                label: sign['category'] as String? ?? '',
                color: theme.colorScheme.primary),
            if ((sign['difficulty'] as String? ?? '').isNotEmpty)
              StatusPill(
                  label: sign['difficulty'] as String,
                  color: theme.colorScheme.secondary),
            if ((sign['variant'] as String? ?? '').isNotEmpty)
              StatusPill(
                  label: sign['variant'] as String,
                  color: theme.colorScheme.onSurfaceVariant),
          ]),
          const SizedBox(height: 16),
          LsfRenderer(text: word, stageHeight: 220, autoplay: false),
          const SizedBox(height: 20),
          Text(sign['description'] as String? ?? '',
              style: theme.textTheme.bodyLarge),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 24),
            SectionHeader(tr('Comment le réaliser', 'How to sign it')),
            AppCard(
              child: Column(children: [
                for (var i = 0; i < steps.length; i++)
                  Padding(
                    padding:
                        EdgeInsets.only(bottom: i < steps.length - 1 ? 14 : 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text('${i + 1}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onPrimaryContainer)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(steps[i],
                                style: theme.textTheme.bodyMedium)),
                      ],
                    ),
                  ),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          SectionHeader(tr('Paramètres du geste', 'Gesture parameters')),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _Parameter(Icons.back_hand_outlined, tr('Forme', 'Handshape'),
                  sign['handshape'] as String?),
              const Divider(indent: 56),
              _Parameter(Icons.place_outlined, tr('Emplacement', 'Location'),
                  sign['location'] as String?),
              const Divider(indent: 56),
              _Parameter(Icons.open_with_rounded, tr('Mouvement', 'Movement'),
                  sign['movement'] as String?),
              if ((sign['dactylology'] as String? ?? '').isNotEmpty) ...[
                const Divider(indent: 56),
                _Parameter(
                    Icons.abc_rounded,
                    tr('Dactylologie', 'Fingerspelling'),
                    sign['dactylology'] as String?),
              ],
            ]),
          ),
          if (example.isNotEmpty) ...[
            const SizedBox(height: 24),
            SectionHeader(tr('Exemple', 'Example')),
            AppCard(
              child: Row(children: [
                Expanded(
                  child: Text('« $example »',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontStyle: FontStyle.italic)),
                ),
                LsfExplainButton(text: example),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _Parameter extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  const _Parameter(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing:
            Text(value ?? '—', style: Theme.of(context).textTheme.bodyMedium),
      );
}

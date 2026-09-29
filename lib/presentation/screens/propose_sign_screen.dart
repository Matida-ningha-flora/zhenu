import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../data/services/admin_data_service.dart';
import '../../data/services/sign_repository.dart';

/// Proposition d'un nouveau signe par la communauté. Il n'apparaît dans le
/// dictionnaire qu'après validation par un administrateur.
class ProposeSignScreen extends StatefulWidget {
  final String author;
  const ProposeSignScreen({super.key, required this.author});

  @override
  State<ProposeSignScreen> createState() => _ProposeSignScreenState();
}

class _ProposeSignScreenState extends State<ProposeSignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _word = TextEditingController();
  final _description = TextEditingController();
  final _variant = TextEditingController();
  String _category = SignRepository.categories.first;
  bool _saving = false;

  @override
  void dispose() {
    _word.dispose();
    _description.dispose();
    _variant.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final settings = await AdminDataService.loadSettings();
    final moderated = settings['communityModerationRequired'] != false;
    final proposal = {
      'word': _word.text.trim().toUpperCase(),
      'category': _category,
      'description': _description.text.trim(),
      'gestureSummary': _description.text.trim().split('.').first,
      'gestureEmoji': '🤟',
      'variant': _variant.text.trim().isEmpty ? 'LSF' : _variant.text.trim(),
      'author': widget.author,
    };
    await SignRepository.proposeSign(proposal,
        status: moderated ? SignRepository.pending : SignRepository.approved);
    if (!moderated) {
      await SignRepository.publishSign({
        ...proposal,
        'id': 'community_${DateTime.now().microsecondsSinceEpoch}',
      });
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(moderated
          ? tr('Merci ! Votre proposition sera examinée par l’équipe.',
              'Thank you! Your proposal will be reviewed by the team.')
          : tr('Merci ! Le signe a été ajouté au dictionnaire.',
              'Thank you! The sign has been added to the dictionary.')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Proposer un signe', 'Suggest a sign'))),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Icon(Icons.verified_outlined,
                      color: theme.colorScheme.onSecondaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr('Chaque proposition est vérifiée par un administrateur avant d’être ajoutée au dictionnaire.',
                          'Each proposal is checked by an administrator before being added to the dictionary.'),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _word,
                maxLength: 60,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                    labelText: tr('Mot ou expression', 'Word or phrase')),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? tr('Saisissez le mot.', 'Enter the word.')
                    : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration:
                    InputDecoration(labelText: tr('Catégorie', 'Category')),
                items: [
                  for (final c in SignRepository.categories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                maxLength: 1000,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: tr('Description du geste', 'Gesture description'),
                  hintText: tr('Forme de la main, emplacement, mouvement…',
                      'Handshape, location, movement…'),
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v ?? '').trim().length < 10
                    ? tr('Décrivez le geste (10 caractères minimum).',
                        'Describe the gesture (at least 10 characters).')
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _variant,
                decoration: InputDecoration(
                    labelText: tr('Région ou variante (facultatif)',
                        'Region or variant (optional)')),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(tr('Envoyer la proposition', 'Send proposal')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/l10n/tr.dart';
import '../../../data/services/admin_user_service.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/ui_kit.dart';

/// Gestion des comptes utilisateurs et administrateurs.
class AdminAccountsSection extends StatefulWidget {
  final String currentEmail;
  const AdminAccountsSection({super.key, required this.currentEmail});

  @override
  State<AdminAccountsSection> createState() => _AdminAccountsSectionState();
}

class _AdminAccountsSectionState extends State<AdminAccountsSection> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _query = '';
  String _role = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final users = await AdminUserService.listUsers();
    if (!mounted) return;
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  bool _isSelf(Map<String, dynamic> user) =>
      (user['email'] as String? ?? '').toLowerCase() ==
      widget.currentEmail.toLowerCase();

  Future<void> _run(Future<void> Function() action, String success) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(tr('Action impossible : ${cleanError(e)}',
              'Action failed: ${cleanError(e)}'))));
    }
    await _load();
  }

  Future<bool> _confirm(String title, String message, String action,
      {bool destructive = false}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('Annuler', 'Cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor:
                  destructive ? Theme.of(context).colorScheme.error : null,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _onAction(Map<String, dynamic> user, String action) async {
    final name = user['name'] as String? ?? user['email'] as String? ?? '';
    switch (action) {
      case 'role':
        final toAdmin = user['role'] != 'admin';
        if (await _confirm(
          toAdmin
              ? tr('Nommer $name administrateur ?',
                  'Make $name an administrator?')
              : tr('Retirer les droits administrateur ?',
                  'Remove admin rights?'),
          toAdmin
              ? tr('Ce compte aura accès à toute l’administration.',
                  'This account will have full admin access.')
              : tr('Ce compte redeviendra un utilisateur.',
                  'This account will become a regular user.'),
          tr('Confirmer', 'Confirm'),
        )) {
          await _run(
              () => AdminUserService.update(
                  user, {'role': toAdmin ? 'admin' : 'user'}),
              tr('Rôle mis à jour.', 'Role updated.'));
        }
      case 'suspend':
        final suspend = user['suspended'] != true;
        if (!suspend ||
            await _confirm(
              tr('Suspendre $name ?', 'Suspend $name?'),
              tr('La personne ne pourra plus se connecter.',
                  'This person will no longer be able to sign in.'),
              tr('Suspendre', 'Suspend'),
              destructive: true,
            )) {
          await _run(
              () => AdminUserService.update(user, {'suspended': suspend}),
              suspend
                  ? tr('Compte suspendu.', 'Account suspended.')
                  : tr('Compte réactivé.', 'Account reactivated.'));
        }
      case 'delete':
        if (await _confirm(
          tr('Supprimer $name ?', 'Delete $name?'),
          tr('Cette action est définitive.', 'This cannot be undone.'),
          tr('Supprimer', 'Delete'),
          destructive: true,
        )) {
          await _run(() => AdminUserService.delete(user),
              tr('Compte supprimé.', 'Account deleted.'));
        }
    }
  }

  Future<void> _create() async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    var role = 'user';
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(tr('Nouveau compte', 'New account')),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: name,
                  decoration: InputDecoration(
                      labelText: tr('Nom complet', 'Full name')),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? tr('Nom requis.', 'Name required.')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                      labelText: tr('Adresse e-mail', 'Email address')),
                  validator: (v) => emailPattern.hasMatch(v?.trim() ?? '')
                      ? null
                      : tr('Adresse invalide.', 'Invalid address.'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: password,
                  decoration: InputDecoration(
                      labelText:
                          tr('Mot de passe temporaire', 'Temporary password')),
                  validator: (v) => (v ?? '').length < 8
                      ? tr('8 caractères minimum.', 'At least 8 characters.')
                      : null,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                          value: 'user',
                          icon: const Icon(Icons.person_outline_rounded),
                          label: Text(tr('Utilisateur', 'User'))),
                      ButtonSegment(
                          value: 'admin',
                          icon: const Icon(Icons.admin_panel_settings_outlined),
                          label: Text(tr('Admin', 'Admin'))),
                    ],
                    selected: {role},
                    onSelectionChanged: (v) => setDialog(() => role = v.first),
                  ),
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
              child: Text(tr('Créer', 'Create')),
            ),
          ],
        ),
      ),
    );
    if (created == true) {
      await _run(
        () => AdminUserService.create(
          name: name.text,
          email: email.text,
          password: password.text,
          role: role,
        ),
        tr('Compte créé.', 'Account created.'),
      );
    }
    name.dispose();
    email.dispose();
    password.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    final query = _query.toLowerCase();
    final users = _users.where((u) {
      if (_role != 'all' && u['role'] != _role) return false;
      if (query.isEmpty) return true;
      return '${u['name']} ${u['email']}'.toLowerCase().contains(query);
    }).toList();
    final admins = _users.where((u) => u['role'] == 'admin').length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(tr('Nouveau compte', 'New account')),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: tr(
                    'Rechercher par nom ou e-mail', 'Search by name or email'),
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              for (final entry in {
                'all': '${tr('Tous', 'All')} (${_users.length})',
                'user':
                    '${tr('Utilisateurs', 'Users')} (${_users.length - admins})',
                'admin': '${tr('Administrateurs', 'Admins')} ($admins)',
              }.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _role == entry.key,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _role = entry.key),
                ),
            ]),
            const SizedBox(height: 12),
            if (users.isEmpty)
              EmptyState(
                icon: Icons.person_search_outlined,
                title: tr('Aucun compte', 'No account'),
                message: tr('Aucun compte ne correspond à la recherche.',
                    'No account matches your search.'),
              )
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (var i = 0; i < users.length; i++) ...[
                    if (i > 0) const Divider(indent: 72),
                    _UserRow(
                      user: users[i],
                      isSelf: _isSelf(users[i]),
                      onAction: (a) => _onAction(users[i], a),
                    ),
                  ],
                ]),
              ),
            const SizedBox(height: 12),
            Text(
              tr('Seul un administrateur peut créer ou promouvoir un autre administrateur. L’inscription publique crée toujours un compte utilisateur.',
                  'Only an administrator can create or promote another administrator. Public sign-up always creates a user account.'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isSelf;
  final ValueChanged<String> onAction;

  const _UserRow(
      {required this.user, required this.isSelf, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = user['name'] as String? ?? '';
    final isAdmin = user['role'] == 'admin';
    final suspended = user['suspended'] == true;
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
      leading: CircleAvatar(
        backgroundColor: isAdmin
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isAdmin
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant)),
      ),
      title: Row(children: [
        Flexible(
          child: Text(isSelf ? '$name (${tr('vous', 'you')})' : name,
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        if (isAdmin)
          StatusPill(label: 'Admin', color: theme.colorScheme.primary),
        if (suspended) ...[
          const SizedBox(width: 6),
          StatusPill(
              label: tr('Suspendu', 'Suspended'),
              color: theme.colorScheme.error),
        ],
      ]),
      subtitle: Text(user['email'] as String? ?? ''),
      trailing: isSelf
          ? null
          : PopupMenuButton<String>(
              tooltip: tr('Actions', 'Actions'),
              onSelected: onAction,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'role',
                  child: Text(isAdmin
                      ? tr('Retirer les droits admin', 'Remove admin rights')
                      : tr('Nommer administrateur', 'Make administrator')),
                ),
                PopupMenuItem(
                  value: 'suspend',
                  child: Text(suspended
                      ? tr('Réactiver', 'Reactivate')
                      : tr('Suspendre', 'Suspend')),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(tr('Supprimer', 'Delete'),
                      style: TextStyle(color: theme.colorScheme.error)),
                ),
              ],
            ),
    );
  }
}

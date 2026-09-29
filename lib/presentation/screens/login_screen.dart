import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../data/services/firebase_auth_service.dart';
import '../navigation.dart';
import '../widgets/auth_layout.dart';
import '../widgets/motion.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = FirebaseAuthService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user =
          await _auth.login(email: _email.text, password: _password.text);
      if (!mounted) return;
      if (user == null) {
        setState(() => _error = tr('Connexion impossible.', 'Sign-in failed.'));
      } else {
        openHomeFor(context, user);
      }
    } catch (e) {
      if (mounted) setState(() => _error = cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Mot de passe oublié', 'Forgot password')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr(
              'Saisissez votre adresse e-mail : nous vous enverrons un lien pour choisir un nouveau mot de passe.',
              'Enter your email address and we will send you a link to choose a new password.')),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: InputDecoration(
              labelText: tr('Adresse e-mail', 'Email address'),
              prefixIcon: const Icon(Icons.mail_outline_rounded),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('Annuler', 'Cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(tr('Envoyer le lien', 'Send link')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _auth.sendPasswordReset(email);
      messenger.showSnackBar(SnackBar(
          content: Text(tr('Lien envoyé à $email.', 'Link sent to $email.'))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(cleanError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthLayout(
      title: tr('Bon retour', 'Welcome back'),
      subtitle: tr(
          'Connectez-vous pour retrouver vos conversations et votre historique.',
          'Sign in to get back to your conversations and history.'),
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlowOnFocus(
                  child: TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: tr('Adresse e-mail', 'Email address'),
                      prefixIcon: const Icon(Icons.mail_outline_rounded),
                    ),
                    validator: (value) =>
                        emailPattern.hasMatch(value?.trim() ?? '')
                            ? null
                            : tr('Saisissez une adresse e-mail valide.',
                                'Enter a valid email address.'),
                  ),
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _password,
                  label: tr('Mot de passe', 'Password'),
                  onSubmitted: (_) => _submit(),
                  validator: (value) => (value ?? '').isEmpty
                      ? tr('Saisissez votre mot de passe.',
                          'Enter your password.')
                      : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child:
                        Text(tr('Mot de passe oublié ?', 'Forgot password?')),
                  ),
                ),
                const SizedBox(height: 8),
                if (_error != null) FormErrorBanner(_error!),
                PressableScale(
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: Colors.white))
                        : Text(tr('Se connecter', 'Sign in')),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(tr('Pas encore de compte ?', 'No account yet?'),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          TextButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RegisterScreen())),
            child: Text(tr('Créer un compte', 'Create an account')),
          ),
        ]),
        if (_auth.demoAccountsEnabled) ...[
          const SizedBox(height: 16),
          _DemoAccountsHint(onPick: (email) {
            _email.text = email;
            _password.text = 'password';
            _submit();
          }),
        ],
      ],
    );
  }
}

/// Raccourci réservé au développement : visible seulement lorsque les comptes
/// de démonstration sont autorisés.
class _DemoAccountsHint extends StatelessWidget {
  final ValueChanged<String> onPick;
  const _DemoAccountsHint({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.science_outlined,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(tr('Comptes de démonstration', 'Demo accounts'),
                style: theme.textTheme.labelLarge),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(
              avatar: const Icon(Icons.person_outline_rounded, size: 18),
              label: Text(tr('Utilisateur', 'User')),
              onPressed: () => onPick('user@test.com'),
            ),
            ActionChip(
              avatar: const Icon(Icons.admin_panel_settings_outlined, size: 18),
              label: Text(tr('Administrateur', 'Administrator')),
              onPressed: () => onPick('admin@test.com'),
            ),
          ]),
        ],
      ),
    );
  }
}

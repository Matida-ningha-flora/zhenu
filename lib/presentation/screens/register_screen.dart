import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../data/services/firebase_auth_service.dart';
import '../navigation.dart';
import '../widgets/auth_layout.dart';
import '../widgets/motion.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Score de 0 à 4 : longueur, majuscule, chiffre, caractère spécial.
  int get _strength {
    final value = _password.text;
    if (value.isEmpty) return 0;
    var score = value.length >= 8 ? 1 : 0;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    return score;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await FirebaseAuthService().register(
        name: _name.text,
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      if (user != null) openHomeFor(context, user);
    } catch (e) {
      if (mounted) setState(() => _error = cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strength = _strength;
    final strengthColor = [
      theme.colorScheme.outlineVariant,
      theme.colorScheme.error,
      const Color(0xFFD97706),
      const Color(0xFF65A30D),
      const Color(0xFF15803D),
    ][strength];
    final strengthLabel = [
      '',
      tr('Faible', 'Weak'),
      tr('Moyen', 'Fair'),
      tr('Bon', 'Good'),
      tr('Excellent', 'Strong'),
    ][strength];

    return AuthLayout(
      showBack: Navigator.of(context).canPop(),
      title: tr('Créer votre compte', 'Create your account'),
      subtitle: tr('Quelques secondes suffisent pour commencer à communiquer.',
          'It only takes a few seconds to start communicating.'),
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlowOnFocus(
                  child: TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: InputDecoration(
                      labelText: tr('Nom complet', 'Full name'),
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) => (value ?? '').trim().length < 2
                        ? tr('Saisissez votre nom.', 'Enter your name.')
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
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
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) => (value ?? '').length < 8
                      ? tr('8 caractères minimum.', 'At least 8 characters.')
                      : null,
                ),
                const SizedBox(height: 10),
                Row(children: [
                  for (var i = 1; i <= 4; i++)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 4,
                        margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                        decoration: BoxDecoration(
                          color: i <= strength
                              ? strengthColor
                              : theme.colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 64,
                    child: Text(strengthLabel,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: strengthColor)),
                  ),
                ]),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _confirm,
                  label: tr('Confirmer le mot de passe', 'Confirm password'),
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _submit(),
                  validator: (value) => value != _password.text
                      ? tr('Les mots de passe ne correspondent pas.',
                          'Passwords do not match.')
                      : null,
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Icon(Icons.verified_user_outlined,
                      size: 18, color: theme.colorScheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('Vos données sont chiffrées et ne sont jamais partagées.',
                          'Your data is encrypted and never shared.'),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                if (_error != null) FormErrorBanner(_error!),
                PressableScale(
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: Colors.white))
                        : Text(tr('Créer mon compte', 'Create my account')),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(tr('Déjà inscrit ?', 'Already registered?'),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          TextButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context)
                    .pushReplacement(fadeRoute(const LoginScreen()));
              }
            },
            child: Text(tr('Se connecter', 'Sign in')),
          ),
        ]),
      ],
    );
  }
}

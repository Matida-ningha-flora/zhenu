import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/preferences/app_preferences.dart';
import '../../core/constants/app_colors.dart';
import 'lsf_explain_button.dart';
import 'motion.dart';
import 'ui_kit.dart';

/// Mise en page commune des écrans de connexion et d'inscription.
class AuthLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBack;

  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: showBack,
        actions: [
          ListenableBuilder(
            listenable: AppPreferences.instance,
            builder: (context, _) {
              final english = AppPreferences.instance.isEnglish;
              return TextButton.icon(
                onPressed: () => AppPreferences.instance
                    .setGuestLanguage(english ? 'Français' : 'English'),
                icon: const Icon(Icons.language_rounded, size: 18),
                label: Text(english ? 'FR' : 'EN'),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(children: [
        Positioned.fill(
          child: AmbientBlobs(
            colors: const [AppColors.primary, AppColors.secondary],
            opacity: theme.brightness == Brightness.dark ? 0.16 : 0.12,
          ),
        ),
        SafeArea(
          top: false,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo « qui respire » et entrée en cascade (animations d'origine).
                    const FadeSlideIn(
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: Breathing(child: BrandMark(size: 56))),
                    ),
                    const SizedBox(height: 24),
                    FadeSlideIn(
                      delay: FadeSlideIn.stagger(1, stepMs: 90),
                      child: Text(title, style: theme.textTheme.headlineMedium),
                    ),
                    const SizedBox(height: 6),
                    FadeSlideIn(
                      delay: FadeSlideIn.stagger(2, stepMs: 90),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(subtitle,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant)),
                          ),
                          LsfExplainButton(text: '$title. $subtitle'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    for (var i = 0; i < children.length; i++)
                      FadeSlideIn(
                        delay: FadeSlideIn.stagger(i + 3, stepMs: 90),
                        offset: 26,
                        child: children[i],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Champ de mot de passe avec bouton afficher / masquer.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final List<String> autofillHints;

  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => GlowOnFocus(
          child: TextFormField(
        controller: widget.controller,
        obscureText: _obscure,
        validator: widget.validator,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onSubmitted,
        autofillHints: widget.autofillHints,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            tooltip: _obscure
                ? tr('Afficher le mot de passe', 'Show password')
                : tr('Masquer le mot de passe', 'Hide password'),
            icon: Icon(_obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ));
}

/// Message d'erreur affiché au-dessus du bouton de validation.
class FormErrorBanner extends StatelessWidget {
  final String message;
  const FormErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, color: scheme.error, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(message,
                style: TextStyle(color: scheme.error, fontSize: 13.5))),
      ]),
    );
  }
}

String cleanError(Object error) =>
    error.toString().replaceFirst('Exception: ', '');

final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Halo coloré animé autour d'un champ lorsqu'il a le focus.
class GlowOnFocus extends StatefulWidget {
  final Widget child;
  const GlowOnFocus({super.key, required this.child});

  @override
  State<GlowOnFocus> createState() => _GlowOnFocusState();
}

class _GlowOnFocusState extends State<GlowOnFocus> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (value) => setState(() => _focused = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            if (_focused && !Motion.reduced(context))
              BoxShadow(
                color: color.withValues(alpha: 0.22),
                blurRadius: 14,
                spreadRadius: 1,
              ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

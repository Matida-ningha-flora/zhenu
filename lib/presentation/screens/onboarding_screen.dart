import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/l10n/tr.dart';
import '../../core/preferences/app_preferences.dart';
import '../navigation.dart';
import '../widgets/lsf_explain_button.dart';
import '../widgets/motion.dart';
import '../widgets/ui_kit.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Page d'accueil : présente les fonctions principales avant la connexion.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Slide {
  final IconData from;
  final IconData to;
  final Color color;
  final String title;
  final String body;

  const _Slide(this.from, this.to, this.color, this.title, this.body);
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  List<_Slide> get _slides => [
        _Slide(
          Icons.front_hand_rounded,
          Icons.record_voice_over_rounded,
          AppColors.primary,
          tr('Signez, on vous entend', 'Sign, and be heard'),
          tr('Signez devant la caméra : vos signes LSF sont traduits en texte et en voix pour votre interlocuteur.',
              'Sign in front of the camera: your LSF signs are translated into text and speech for the other person.'),
        ),
        _Slide(
          Icons.mic_rounded,
          Icons.sign_language_rounded,
          AppColors.secondary,
          tr('Parlez, on vous répond en LSF', 'Speak, get answers in LSF'),
          tr('Parlez ou écrivez : le message est traduit en LSF par un avatar, une vidéo ou du texte, selon votre choix.',
              'Speak or type: your message is translated into LSF by an avatar, a video or text, as you prefer.'),
        ),
        _Slide(
          Icons.groups_rounded,
          Icons.forum_rounded,
          AppColors.terracotta,
          tr('Conversez à plusieurs', 'Talk with several people'),
          tr('Échangez avec un ou plusieurs interlocuteurs en même temps. Chaque message est traduit en direct.',
              'Talk with one or more people at once. Every message is translated live.'),
        ),
        _Slide(
          Icons.search_rounded,
          Icons.menu_book_rounded,
          AppColors.amber,
          tr('Le dictionnaire LSF en poche',
              'The LSF dictionary in your pocket'),
          tr('Cherchez un signe par mot, par catégorie ou par geste, même sans connexion.',
              'Look up a sign by word, category or gesture, even offline.'),
        ),
      ];

  Future<void> _finish(Widget next) async {
    await AppPreferences.markOnboardingSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(fadeRoute(next));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slides = _slides;
    final isLast = _page == slides.length - 1;

    return Scaffold(
      body: Stack(children: [
        // Taches de couleur qui se déplacent à chaque page (animation d'origine).
        Positioned.fill(
          child: AmbientBlobs(
            phase: _page,
            colors: [
              slides[_page].color,
              AppColors.secondary,
              AppColors.primary,
            ],
            opacity: theme.brightness == Brightness.dark ? 0.22 : 0.16,
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(children: [
                  const BrandMark(size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('NeuroSigne',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium),
                  ),
                  _LanguageToggle(onChanged: () => setState(() {})),
                  if (!isLast)
                    TextButton(
                      onPressed: () => _controller.animateToPage(
                          slides.length - 1,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic),
                      child: Text(tr('Passer', 'Skip')),
                    ),
                ]),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: slides.length,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (context, index) =>
                      _SlideView(slide: slides[index]),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  slides.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: isLast
                    ? Column(children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => _finish(const RegisterScreen()),
                            child: Text(
                                tr('Créer un compte', 'Create an account')),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => _finish(const LoginScreen()),
                            child: Text(tr("J'ai déjà un compte",
                                'I already have an account')),
                          ),
                        ),
                      ])
                    : SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => _controller.nextPage(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic),
                          child: Text(tr('Continuer', 'Continue')),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeSlideIn(
                offset: 28,
                child: Floating(child: _Illustration(slide: slide)),
              ),
              const SizedBox(height: 40),
              FadeSlideIn(
                delay: const Duration(milliseconds: 120),
                child: Text(slide.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                delay: const Duration(milliseconds: 220),
                child: Text(slide.body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
              const SizedBox(height: 8),
              LsfExplainButton(
                  text: '${slide.title}. ${slide.body}', showLabel: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  final _Slide slide;
  const _Illustration({required this.slide});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 280,
      height: 200,
      decoration: BoxDecoration(
        color: slide.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: slide.color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _bubble(scheme, slide.from),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child:
                Icon(Icons.arrow_forward_rounded, color: slide.color, size: 28),
          ),
          _bubble(scheme, slide.to),
        ],
      ),
    );
  }

  Widget _bubble(ColorScheme scheme, IconData icon) => Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: slide.color.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: slide.color, size: 40),
      );
}

class _LanguageToggle extends StatelessWidget {
  final VoidCallback onChanged;
  const _LanguageToggle({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final english = AppPreferences.instance.isEnglish;
    return TextButton.icon(
      onPressed: () async {
        await AppPreferences.instance
            .setGuestLanguage(english ? 'Français' : 'English');
        onChanged();
      },
      icon: const Icon(Icons.language_rounded, size: 18),
      label: Text(english ? 'FR' : 'EN'),
    );
  }
}

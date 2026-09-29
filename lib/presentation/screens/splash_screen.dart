import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/l10n/tr.dart';
import '../../core/preferences/app_preferences.dart';
import '../../data/services/firebase_auth_service.dart';
import '../navigation.dart';
import '../widgets/motion.dart';
import '../widgets/ui_kit.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Animation d'origine : apparition en fondu et rebond élastique du logo.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();
  late final Animation<double> _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn));
  late final Animation<double> _scale = Tween(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.8, curve: Curves.elasticOut)));

  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final results = await Future.wait<Object?>([
      FirebaseAuthService()
          .getCurrentUser()
          .timeout(const Duration(seconds: 4), onTimeout: () => null)
          .catchError((_) => null),
      AppPreferences.hasSeenOnboarding(),
      Future<void>.delayed(const Duration(milliseconds: 1900)),
    ]);
    if (!mounted) return;
    final user = results[0] as Map<String, dynamic>?;
    final seenOnboarding = results[1] as bool;
    if (user != null) {
      openHomeFor(context, user);
      return;
    }
    Navigator.of(context).pushReplacement(fadeRoute(
        seenOnboarding ? const LoginScreen() : const OnboardingScreen()));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(children: [
        // Fond « mesh gradient » : taches caramel et or qui dérivent.
        const Positioned.fill(
          child: AmbientBlobs(
            colors: [
              AppColors.primary,
              AppColors.secondary,
              AppColors.primaryDark
            ],
            opacity: 0.55,
          ),
        ),
        Positioned.fill(
          child: Container(color: Colors.black.withValues(alpha: 0.12)),
        ),
        SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.18),
                          Colors.white.withValues(alpha: 0.04),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const BrandMark(size: 84),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FadeSlideIn(
                delay: const Duration(milliseconds: 500),
                child: Text(
                  'NeuroSigne',
                  style: theme.textTheme.headlineLarge?.copyWith(
                      color: Colors.white, fontSize: 38, letterSpacing: 1.5),
                ),
              ),
              const SizedBox(height: 10),
              FadeSlideIn(
                delay: const Duration(milliseconds: 750),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.16)),
                  ),
                  child: Text(
                    tr('LA LANGUE DES SIGNES, POUR TOUS',
                        'SIGN LANGUAGE, FOR EVERYONE'),
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 1.6),
                  ),
                ),
              ),
              const Spacer(flex: 3),
              FadeSlideIn(
                delay: const Duration(milliseconds: 1000),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ]),
    );
  }
}

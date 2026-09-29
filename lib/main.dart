import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/preferences/app_preferences.dart';
import 'core/themes/app_theme.dart';
import 'firebase_options.dart';
import 'presentation/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // La police Inter est embarquée (assets/google_fonts) : aucun
  // téléchargement n'est nécessaire, l'interface reste identique hors ligne.
  GoogleFonts.config.allowRuntimeFetching = false;
  try {
    // Délai maximal : sans réseau (bibliothèques Firebase injoignables),
    // l'application démarre quand même en mode local au lieu de rester
    // bloquée sur une page blanche.
    await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform)
        .timeout(const Duration(seconds: 10));
    // Cache local : dictionnaire, modules et conversations restent
    // consultables sans connexion, puis se synchronisent au retour du réseau.
    FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
  } catch (_) {
    // Sans Firebase, l'application fonctionne en mode local (hors ligne).
  }
  await AppPreferences.instance.load();
  runApp(const NeuroSigneApp());
}

class NeuroSigneApp extends StatelessWidget {
  const NeuroSigneApp({super.key});

  static final lightTheme = AppTheme.lightTheme;
  static final darkTheme = AppTheme.darkTheme;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppPreferences.instance,
        builder: (context, _) => MaterialApp(
          title: 'NeuroSigne',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: AppPreferences.instance.themeMode,
          home: const SplashScreen(),
        ),
      );
}

/// Compatibilité avec les tests qui utilisaient l'ancien nom.
class ZhenduApp extends NeuroSigneApp {
  const ZhenduApp({super.key});
}

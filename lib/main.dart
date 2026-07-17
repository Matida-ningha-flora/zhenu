import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/themes/app_theme.dart';
import 'presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase initialisé avec succès.");
  } catch (e) {
    print("Erreur d'initialisation Firebase (Utilisation du mode démo local) : $e");
  }
  
  runApp(const ZhenduApp());
}

class ZhenduApp extends StatelessWidget {
  const ZhenduApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zhẽnù',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, // Par défaut Light, avec possibilité de basculer
      home: const SplashScreen(),
    );
  }
}

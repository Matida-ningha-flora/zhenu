import 'package:flutter/material.dart';

class AppColors {
  // Brand identity: Premium Brown and Warm Gold Palette
  static const Color primary = Color(0xFFC76F26); // Marron chaud caramel #C76F26
  static const Color primaryDark = Color(0xFF5D3F1D); // Espresso sombre / Chocolat noir
  static const Color secondary = Color(0xFFE5A93B); // Or chaud / Caramel vibrant
  static const Color secondaryDark = Color(0xFFC68E2D); // Bronze doré
  
  // Base interfaces
  static const Color background = Color(0xFFFAF7F2); // Warm Cream / Ivoire chaleureux (luxueux et cosy)
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFDC2626); // Rouge brique premium
  
  // Premium Dark Mode / Dark containers (Warm Espresso base instead of cold slate/blue)
  static const Color darkBackground = Color(0xFF1E1715); // Espresso ultra-sombre
  static const Color darkSurface = Color(0xFF2C221F); // Chocolat noir doux
  static const Color darkCard = Color(0xFF3D2F2B); // Brun chaud intermédiaire
  
  // LSC & Status colors
  static const Color signLanguageBlue = Color(0xFF5B859D); // Bleu ardoise adouci
  static const Color signLanguageYellow = Color(0xFFE5A93B); // Or chaud
  static const Color success = Color(0xFF15803D); // Vert forêt / Émeraude foncée
  static const Color warning = Color(0xFFD97706); // Ambre / Caramel
  
  // Premium Linear Gradients (Competition-grade aesthetics)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFC76F26), Color(0xFF5D3F1D)], // #C76F26 to Espresso
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFFE5A93B), Color(0xFFD97706)], // Gold to Warm Amber
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emergencyGradient = LinearGradient(
    colors: [Color(0xFFB91C1C), Color(0xFFD97706)], // Dark Red to Caramel Orange
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient learningGradient = LinearGradient(
    colors: [Color(0xFFE5A93B), Color(0xFFB91C1C)], // Gold to Dark Red
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF2C221F), Color(0xFF1E1715)], // Espresso shades
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

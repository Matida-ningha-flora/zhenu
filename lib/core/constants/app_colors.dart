import 'package:flutter/material.dart';

/// Palette NeuroSigne : caramel, espresso et or sur fond ivoire.
///
/// Les teintes « deep » sont les mêmes couleurs, assombries pour les textes
/// et les boutons afin de garantir un contraste AA sur fond clair.
class AppColors {
  // Marque
  static const Color primary = Color(0xFFC76F26); // caramel
  static const Color primaryDeep =
      Color(0xFFA8581C); // caramel profond (texte, boutons)
  static const Color primaryDark = Color(0xFF5D3F1D); // espresso
  static const Color primarySoft = Color(0xFFF8EADC);
  static const Color secondary = Color(0xFFE5A93B); // or
  static const Color secondaryDark = Color(0xFFC68E2D); // bronze doré
  static const Color secondaryDeep = Color(0xFF8C6512); // or profond (texte)
  static const Color secondarySoft = Color(0xFFFBF0D9);

  // Accents chauds (catégories, participants)
  static const Color terracotta = Color(0xFF9C4A2F);
  static const Color amber = Color(0xFFB7791F);
  static const Color olive = Color(0xFF6B7A3A);
  static const Color slate = Color(0xFF4F7A8C);
  static const Color cocoa = Color(0xFF7B5B45);

  // Neutres (thème clair)
  static const Color background = Color(0xFFFAF7F2); // ivoire
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF3ECE3);
  static const Color border = Color(0xFFEADBCE);
  static const Color textPrimary = Color(0xFF2B1D14);
  static const Color textSecondary = Color(0xFF5E4B3C);
  static const Color textMuted = Color(0xFF7C6958);

  // Neutres (thème sombre espresso)
  static const Color darkBackground = Color(0xFF1E1715);
  static const Color darkSurface = Color(0xFF2C221F);
  static const Color darkCard = Color(0xFF3D2F2B);
  static const Color darkBorder = Color(0xFF4A3A34);
  static const Color stage = Color(0xFF1A1310); // fond caméra / vidéo

  // États
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFB45309);
  static const Color error = Color(0xFFC0392B);
  static const Color info = slate;

  // Alias conservés pour les écrans existants
  static const Color signLanguageBlue = slate;
  static const Color signLanguageYellow = secondary;

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFC76F26), Color(0xFF5D3F1D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFFE5A93B), Color(0xFFC68E2D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF2C221F), Color(0xFF1E1715)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Couleurs attribuées aux participants d'une conversation.
  static const participants = [
    primaryDeep,
    secondaryDeep,
    terracotta,
    slate,
    olive,
    cocoa,
  ];
}

import '../preferences/app_preferences.dart';

/// Renvoie le libellé dans la langue d'interface choisie par l'utilisateur.
///
/// Les écrans se reconstruisent au changement de langue : le tableau de bord
/// reconstruit son arborescence à chaque modification des préférences.
String tr(String fr, String en) => AppPreferences.instance.isEnglish ? en : fr;

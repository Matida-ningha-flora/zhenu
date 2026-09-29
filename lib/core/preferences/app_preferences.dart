import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Préférences de l'utilisateur NeuroSigne, enregistrées par compte.
///
/// - [responseFormat] : mode de réception (`avatar`, `video`, `landmarks`, `text`)
/// - [signingAvatar] : style de l'avatar signant
/// - [writtenLanguage] : langue de l'interface (`Français` ou `English`)
/// - [themeMode] : thème clair ou sombre
/// - [userProfile] : `deaf` (sourd / malentendant), `hearing` (entendant)
///   ou `both` ; l'application montre à chacun ce qui le concerne
class AppPreferences extends ChangeNotifier {
  AppPreferences._();

  static final AppPreferences instance = AppPreferences._();

  static const responseFormats = ['avatar', 'video', 'landmarks', 'text'];
  static const profiles = ['deaf', 'hearing', 'both'];

  static const _responseKey = 'response_format';
  static const _avatarKey = 'signing_avatar';
  static const _languageKey = 'written_language';
  static const _themeKey = 'theme_preference';
  static const _setupKey = 'preferences_completed';
  static const _onboardingKey = 'onboarding_seen';
  static const _profileKey = 'user_profile';

  String responseFormat = 'avatar';
  String userProfile = 'both';
  String signingAvatar = 'guide';
  String writtenLanguage = 'Français';
  ThemeMode themeMode = ThemeMode.light;
  bool isReady = false;
  bool hasCompletedSetup = false;
  String _scope = 'global';

  bool get isEnglish => writtenLanguage == 'English';

  /// Reçoit les messages des autres en langue des signes.
  bool get receivesSigns => userProfile != 'hearing';

  /// Reçoit les messages en texte et à voix haute.
  bool get receivesSpeech => userProfile != 'deaf';

  /// S'exprime en signant devant la caméra.
  bool get signs => userProfile != 'hearing';

  /// S'exprime au clavier ou à la voix.
  bool get speaks => userProfile != 'deaf';

  Future<void> loadForUser(String identifier) async {
    _scope =
        identifier.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    await load();
  }

  String _key(String name) => '$_scope.$name';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _resetDefaults();
    responseFormat =
        _migrateResponse(prefs.getString(_key(_responseKey))) ?? responseFormat;
    signingAvatar = prefs.getString(_key(_avatarKey)) ?? signingAvatar;
    final profile = prefs.getString(_key(_profileKey));
    if (profiles.contains(profile)) userProfile = profile!;
    // La langue d'interface reste celle de l'appareil tant que le compte
    // n'en a pas choisi une autre.
    writtenLanguage = prefs.getString(_key(_languageKey)) ??
        prefs.getString('global.$_languageKey') ??
        writtenLanguage;
    hasCompletedSetup = prefs.getBool(_key(_setupKey)) ?? false;
    themeMode = prefs.getString(_key(_themeKey)) == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    isReady = true;
    notifyListeners();
  }

  void _resetDefaults() {
    responseFormat = 'avatar';
    userProfile = 'both';
    signingAvatar = 'guide';
    writtenLanguage = 'Français';
    themeMode = ThemeMode.light;
    hasCompletedSetup = false;
  }

  /// Anciennes valeurs (« texte et avatar », etc.) ramenées aux trois modes.
  static String? _migrateResponse(String? value) {
    if (value == null) return null;
    if (responseFormats.contains(value)) return value;
    if (value.contains('avatar')) return 'avatar';
    return 'text';
  }

  Future<void> save({bool completedSetup = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(_responseKey), responseFormat);
    await prefs.setString(_key(_avatarKey), signingAvatar);
    await prefs.setString(_key(_profileKey), userProfile);
    await prefs.setString(_key(_languageKey), writtenLanguage);
    await prefs.setString(
        _key(_themeKey), themeMode == ThemeMode.dark ? 'dark' : 'light');
    if (completedSetup) {
      hasCompletedSetup = true;
      await prefs.setBool(_key(_setupKey), true);
    }
    notifyListeners();
  }

  /// Applique immédiatement un changement (aperçu du thème ou de la langue).
  void preview() => notifyListeners();

  /// Revient aux réglages visibles avant connexion (écran de connexion).
  Future<void> resetToGuest() async {
    _scope = 'global';
    await load();
  }

  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  static Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }

  /// Langue choisie sur l'écran d'accueil, avant toute connexion.
  Future<void> setGuestLanguage(String language) async {
    writtenLanguage = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('global.$_languageKey', language);
    notifyListeners();
  }
}

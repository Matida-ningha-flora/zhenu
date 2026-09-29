import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud.dart';

/// Réglages de l'administration, bibliothèque d'avatars, modèle d'IA et
/// statistiques d'usage.
///
/// En ligne, ces données sont partagées via Firestore (`config/app`,
/// `stats/global`) ; une copie locale permet le fonctionnement hors ligne.
class AdminDataService {
  static const avatarsKey = 'admin_avatar_library_v1';
  static const settingsKey = 'admin_settings_v1';
  static const analyticsKey = 'admin_analytics_v1';
  static const announcementsKey = 'admin_announcements_v1';
  static const modelKey = 'admin_ai_model_v1';

  static const defaultAvatars = <Map<String, dynamic>>[
    {
      'id': 'guide',
      'name': 'Guide inclusif',
      'type': 'photo',
      'source': '',
      'enabled': true
    },
    {
      'id': 'female',
      'name': 'Avatar femme',
      'type': 'photo',
      'source': '',
      'enabled': true
    },
    {
      'id': 'male',
      'name': 'Avatar homme',
      'type': 'photo',
      'source': '',
      'enabled': true
    },
    {
      'id': 'neutral',
      'name': 'Avatar neutre',
      'type': 'photo',
      'source': '',
      'enabled': true
    },
    {
      'id': 'illustrated',
      'name': 'Avatar illustré',
      'type': 'illustration',
      'source': '',
      'enabled': true
    },
  ];

  static const defaultSettings = <String, dynamic>{
    'notificationsEnabled': true,
    'communityModerationRequired': true,
    'localHistoryEnabled': false,
    'offlineAccessEnabled': true,
    'sessionTimeoutMinutes': 30,
  };

  static const defaultModel = <String, dynamic>{
    'endpoint': '',
    'version': '',
    'status': 'not_configured',
    'lastUpdate': '',
  };

  static Future<List<Map<String, dynamic>>>? _avatarCache;

  /// Bibliothèque d'avatars mise en cache pour l'affichage.
  static Future<List<Map<String, dynamic>>> cachedAvatars() =>
      _avatarCache ??= loadAvatars();

  /// Vide le cache (tests, changement de compte).
  static void clearCache() {
    _avatarCache = null;
    _config = null;
    _configAt = null;
  }

  /// Lit un champ du document partagé `config/app` et le garde en cache
  /// local ; renvoie `null` hors ligne.
  static Map<String, dynamic>? _config;
  static DateTime? _configAt;

  static Future<Object?> _cloudConfig(String field, String localKey) async {
    final fresh = _configAt != null &&
        DateTime.now().difference(_configAt!) < const Duration(minutes: 1);
    if (!fresh) {
      final doc = await Cloud.attempt(
          () => Cloud.db.collection('config').doc('app').get());
      if (doc != null) {
        _config = doc.data() ?? {};
        _configAt = DateTime.now();
      }
    }
    final value = Cloud.ready ? (_config ?? const {})[field] : null;
    if (value == null) return null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(localKey, jsonEncode(value));
    return value;
  }

  static Future<void> _saveCloudConfig(String field, Object value) async {
    if (_config != null) _config![field] = value;
    await Cloud.attempt(() => Cloud.db
        .collection('config')
        .doc('app')
        .set({field: value}, SetOptions(merge: true)));
  }

  static Future<List<Map<String, dynamic>>> loadAvatars() async {
    final cloud = await _cloudConfig('avatars', avatarsKey);
    if (cloud is List) {
      return cloud.map((a) => Map<String, dynamic>.from(a as Map)).toList();
    }
    final prefs = await SharedPreferences.getInstance();
    return _decodeList(prefs.getString(avatarsKey), defaultAvatars);
  }

  static Future<void> saveAvatars(List<Map<String, dynamic>> avatars) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(avatarsKey, jsonEncode(avatars));
    await _saveCloudConfig('avatars', avatars);
    _avatarCache = null;
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    final cloud = await _cloudConfig('settings', settingsKey);
    if (cloud is Map) {
      return {...defaultSettings, ...Map<String, dynamic>.from(cloud)};
    }
    final prefs = await SharedPreferences.getInstance();
    return {...defaultSettings, ..._decodeMap(prefs.getString(settingsKey))};
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(settingsKey, jsonEncode(settings));
    await _saveCloudConfig('settings', settings);
  }

  static Future<Map<String, dynamic>> loadModelConfig() async {
    final cloud = await _cloudConfig('model', modelKey);
    if (cloud is Map) {
      return {...defaultModel, ...Map<String, dynamic>.from(cloud)};
    }
    final prefs = await SharedPreferences.getInstance();
    return {...defaultModel, ..._decodeMap(prefs.getString(modelKey))};
  }

  static Future<void> saveModelConfig(Map<String, dynamic> config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(modelKey, jsonEncode(config));
    await _saveCloudConfig('model', config);
  }

  /// Statistiques globales : tous les utilisateurs en ligne (`stats/global`),
  /// ou cet appareil hors ligne.
  static Future<Map<String, dynamic>> loadAnalytics() async {
    final cloud = await Cloud.attempt(
        () => Cloud.db.collection('stats').doc('global').get());
    final data = cloud?.data();
    if (data != null) {
      return {
        'translations': 0,
        'dictionarySearches': 0,
        'searchedTerms': <String, dynamic>{},
        ...data,
      };
    }
    return _loadLocalAnalytics();
  }

  static Future<Map<String, dynamic>> _loadLocalAnalytics() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'translations': 0,
      'dictionarySearches': 0,
      'searchedTerms': <String, dynamic>{},
      ..._decodeMap(prefs.getString(analyticsKey)),
    };
  }

  /// Clé de terme utilisable dans Firestore (sans « . », « / »…).
  static String _termKey(String term) => term
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[./\\\[\]*`~]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static Future<void> _recordCloud(String counter, String? term) async {
    final key = term == null ? '' : _termKey(term);
    await Cloud.attempt(() => Cloud.db.collection('stats').doc('global').set({
          counter: FieldValue.increment(1),
          if (key.isNotEmpty && key.length <= 40)
            'searchedTerms': {key: FieldValue.increment(1)},
        }, SetOptions(merge: true)));
  }

  static Future<void> recordTranslation([String? recognizedSign]) async {
    final analytics = await _loadLocalAnalytics();
    analytics['translations'] = (analytics['translations'] as int? ?? 0) + 1;
    if (recognizedSign != null && recognizedSign.trim().isNotEmpty) {
      _incrementTerm(analytics, recognizedSign);
    }
    await _saveAnalytics(analytics);
    await _recordCloud('translations', recognizedSign);
  }

  static Future<void> recordDictionarySearch(String query) async {
    final normalized = query.trim().toUpperCase();
    if (normalized.length < 2) return;
    final analytics = await _loadLocalAnalytics();
    analytics['dictionarySearches'] =
        (analytics['dictionarySearches'] as int? ?? 0) + 1;
    _incrementTerm(analytics, normalized);
    await _saveAnalytics(analytics);
    await _recordCloud('dictionarySearches', normalized);
  }

  static List<MapEntry<String, int>> topSearches(Map<String, dynamic> analytics,
      {int limit = 5}) {
    final raw =
        Map<String, dynamic>.from(analytics['searchedTerms'] as Map? ?? {});
    final entries = raw.entries
        .map((entry) => MapEntry(entry.key, entry.value as int? ?? 0))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }

  /// Publie une annonce : localement et, si le service en ligne est
  /// disponible, dans Firestore pour une diffusion en temps réel.
  static Future<void> saveAnnouncement(String message,
      {String title = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final announcements =
        _decodeList(prefs.getString(announcementsKey), const []);
    final entry = {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'title': title.trim(),
      'message': message.trim(),
      'createdAt': DateTime.now().toIso8601String(),
    };
    announcements.insert(0, entry);
    await prefs.setString(
        announcementsKey, jsonEncode(announcements.take(20).toList()));
    // Hors ligne, l'annonce reste locale à cet appareil.
    await Cloud.attempt(() => Cloud.db
        .collection('announcements')
        .doc(entry['id'])
        .set({...entry, 'createdAt': FieldValue.serverTimestamp()}));
  }

  static Future<List<Map<String, dynamic>>> loadAnnouncements() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeList(prefs.getString(announcementsKey), const []);
  }

  static const _lastReadAnnouncementKey = 'notifications_last_read_at';

  static Future<int> getUnreadAnnouncementCount() async {
    final announcements = await loadAnnouncements();
    if (announcements.isEmpty) return 0;
    final prefs = await SharedPreferences.getInstance();
    final lastReadIso = prefs.getString(_lastReadAnnouncementKey);
    final lastRead =
        lastReadIso != null ? DateTime.tryParse(lastReadIso) : null;
    if (lastRead == null) return announcements.length;
    return announcements.where((a) {
      final created = DateTime.tryParse(a['createdAt'] as String? ?? '');
      return created == null || created.isAfter(lastRead);
    }).length;
  }

  static Future<void> markAnnouncementsRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _lastReadAnnouncementKey, DateTime.now().toIso8601String());
  }

  static void _incrementTerm(Map<String, dynamic> analytics, String term) {
    final terms =
        Map<String, dynamic>.from(analytics['searchedTerms'] as Map? ?? {});
    final key = term.trim().toUpperCase();
    terms[key] = (terms[key] as int? ?? 0) + 1;
    analytics['searchedTerms'] = terms;
  }

  static Future<void> _saveAnalytics(Map<String, dynamic> analytics) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(analyticsKey, jsonEncode(analytics));
  }

  static Map<String, dynamic> _decodeMap(String? source) {
    if (source == null || source.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(source) as Map);
    } catch (_) {
      return {};
    }
  }

  static List<Map<String, dynamic>> _decodeList(
      String? source, List<Map<String, dynamic>> fallback) {
    if (source == null || source.isEmpty) {
      return fallback.map((item) => Map<String, dynamic>.from(item)).toList();
    }
    try {
      return (jsonDecode(source) as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return fallback.map((item) => Map<String, dynamic>.from(item)).toList();
    }
  }
}

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/lsf_signs.dart';
import 'cloud.dart';

/// Un élément de traduction texte ➔ LSF : un signe du dictionnaire, ou un mot
/// à épeler en dactylologie lorsqu'aucun signe n'existe.
class SignToken {
  final String word;
  final Map<String, dynamic>? sign;

  const SignToken(this.word, this.sign);

  bool get isFingerspelled => sign == null;
  String get fingerspelling => word.toUpperCase().split('').join(' - ');
}

/// Accès unique aux signes LSF (dictionnaire, traduction, administration).
/// Les signes de référence sont embarqués : le dictionnaire reste consultable
/// hors connexion.
class SignRepository {
  static const officialKey = 'dict_official_signs';
  static const communityKey = 'dict_community_suggestions';
  static const favoritesKey = 'dict_favorites';
  static const _cloudSignsKey = 'dict_cloud_signs';

  static const pending = 'En attente';
  static const approved = 'Validé';
  static const rejected = 'Rejeté';

  static const categories = [
    'Salutations',
    'Santé',
    'Nombres',
    'Vie quotidienne',
    'Famille',
    'Émotions',
    'Transport & Lieux',
    'Technologie & Travail',
    'Temps',
    'Culture & Cameroun',
  ];

  static Future<List<Map<String, dynamic>>>? _cache;

  /// Version mise en cache pour la traduction (évite de relire le stockage à
  /// chaque message).
  static Future<List<Map<String, dynamic>>> cachedSigns() =>
      _cache ??= officialSigns();

  /// Vide le cache (tests, changement de compte).
  static void clearCache() => _cache = null;

  /// Signes de référence complétés par les signes validés par
  /// l'administration (Firestore `signs` en ligne, copie locale sinon).
  static Future<List<Map<String, dynamic>>> officialSigns() async {
    final prefs = await SharedPreferences.getInstance();
    final cloud = await Cloud.attempt(() => Cloud.db.collection('signs').get());
    if (cloud != null) {
      final signs = cloud.docs.map((d) => {...d.data(), 'id': d.id}).toList();
      await prefs.setString(_cloudSignsKey, jsonEncode(signs));
    }
    final stored = [
      ..._decode(prefs.getString(officialKey)),
      ..._decode(prefs.getString(_cloudSignsKey)),
    ];
    final byWord = <String, Map<String, dynamic>>{
      for (final sign in defaultOfficialSigns)
        normalize(sign['word'] as String? ?? ''):
            Map<String, dynamic>.from(sign),
    };
    for (final sign in stored) {
      final word = normalize(sign['word'] as String? ?? '');
      if (word.isEmpty) continue;
      byWord[word] = {...?byWord[word], ...sign};
    }
    return byWord.values.toList();
  }

  /// Publie un signe dans le dictionnaire de tous les utilisateurs.
  static Future<void> publishSign(Map<String, dynamic> sign) async {
    final id = (sign['id'] ?? 'sign_${DateTime.now().microsecondsSinceEpoch}')
        .toString();
    final entry = {...sign, 'id': id};
    final saved = await Cloud.attempt(() => Cloud.db
        .collection('signs')
        .doc(id)
        .set({...entry, 'publishedAt': FieldValue.serverTimestamp()}).then(
            (_) => true));
    if (saved != true) {
      final prefs = await SharedPreferences.getInstance();
      final local = _decode(prefs.getString(officialKey))..add(entry);
      await prefs.setString(officialKey, jsonEncode(local));
    }
    _cache = null;
  }

  /// Propositions de la communauté (Firestore `signProposals` en ligne).
  static Future<List<Map<String, dynamic>>> communitySuggestions() async {
    final cloud =
        await Cloud.attempt(() => Cloud.db.collection('signProposals').get());
    if (cloud != null) {
      return cloud.docs
          .map((d) => {...d.data(), 'id': d.id, 'cloud': true})
          .toList();
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(communityKey);
    if (raw == null) {
      return defaultCommunitySuggestions
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return _decode(raw);
  }

  static Future<void> saveCommunitySuggestions(
      List<Map<String, dynamic>> suggestions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(communityKey, jsonEncode(suggestions));
  }

  /// Valide ou rejette une proposition.
  static Future<void> setSuggestionStatus(
      Map<String, dynamic> suggestion, String status) async {
    final update = {
      'status': status,
      'reviewedAt': DateTime.now().toIso8601String(),
    };
    if (suggestion['cloud'] == true) {
      await Cloud.db
          .collection('signProposals')
          .doc(suggestion['id'] as String)
          .update(update);
      return;
    }
    final suggestions = await communitySuggestions();
    await saveCommunitySuggestions([
      for (final s in suggestions)
        if (s['id'] == suggestion['id']) {...s, ...update} else s,
    ]);
  }

  static Future<void> proposeSign(Map<String, dynamic> proposal,
      {String status = pending}) async {
    final user = Cloud.user;
    final entry = {
      'status': status,
      'votes': 0,
      ...proposal,
    };
    if (user != null) {
      final saved =
          await Cloud.attempt(() => Cloud.db.collection('signProposals').add({
                ...entry,
                'authorId': user.uid,
                'createdAt': FieldValue.serverTimestamp(),
              }).then((_) => true));
      if (saved == true) return;
    }
    final suggestions = await communitySuggestions();
    suggestions.insert(0, {
      'id': 'c${DateTime.now().microsecondsSinceEpoch}',
      'createdAt': DateTime.now().toIso8601String(),
      ...entry,
    });
    await saveCommunitySuggestions(suggestions);
  }

  static Future<Set<String>> favorites() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(favoritesKey) ?? const []).toSet();
  }

  static Future<void> saveFavorites(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(favoritesKey, ids.toList());
  }

  /// Minuscule, sans accents ni ponctuation : « Hôpital » == « HOPITAL ».
  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r"[^a-z0-9\s'-]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Mot principal d'une entrée : « KOSSAM (LAIT) » ➔ « kossam ».
  static String headword(Map<String, dynamic> sign) =>
      normalize((sign['word'] as String? ?? '').split('(').first);

  static Map<String, dynamic>? findByWord(
      List<Map<String, dynamic>> signs, String word) {
    final target = normalize(word);
    if (target.isEmpty) return null;
    for (final sign in signs) {
      if (headword(sign) == target ||
          normalize(sign['word'] as String? ?? '') == target) {
        return sign;
      }
    }
    return null;
  }

  static const _stopWords = {
    'le',
    'la',
    'les',
    'l',
    'un',
    'une',
    'des',
    'de',
    'du',
    'd',
    'et',
    'a',
    'au',
    'aux',
    'en',
    'the',
    'an',
    'of',
    'to',
    'and',
  };

  /// Découpe une phrase en signes LSF. Les expressions de plusieurs mots
  /// présentes dans le dictionnaire sont reconnues avant les mots isolés.
  /// [animated] : signes animés disponibles sur le serveur (clés
  /// normalisées « AU_REVOIR »), reconnus même s'ils sont absents du
  /// dictionnaire embarqué.
  static List<SignToken> translateText(
      String text, List<Map<String, dynamic>> signs,
      {Set<String> animated = const {}}) {
    String key(String phrase) => phrase.toUpperCase().replaceAll(' ', '_');
    final words = normalize(text.replaceAll("'", ' '))
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    final tokens = <SignToken>[];
    var i = 0;
    while (i < words.length) {
      Map<String, dynamic>? match;
      var span = 1;
      for (var size = 3; size >= 1 && match == null; size--) {
        if (i + size > words.length) continue;
        final phrase = words.sublist(i, i + size).join(' ');
        match = findByWord(signs, phrase) ??
            (animated.contains(key(phrase))
                ? {'word': phrase.toUpperCase(), 'animatedOnly': true}
                : null);
        if (match != null) span = size;
      }
      final word = words.sublist(i, i + span).join(' ');
      if (match != null) {
        tokens.add(SignToken(word, match));
      } else if (!_stopWords.contains(word)) {
        tokens.add(SignToken(word, null));
      }
      i += span;
    }
    return tokens;
  }

  static List<Map<String, dynamic>> _decode(String? source) {
    if (source == null || source.isEmpty) return [];
    try {
      return (jsonDecode(source) as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

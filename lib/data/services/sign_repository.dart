import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/lsf_signs.dart';
import 'cloud.dart';
import 'lsf_grammar.dart';

/// Un élément de traduction texte ➔ LSF : un signe du dictionnaire, un
/// pointage (pronom), ou un mot à épeler en dactylologie lorsqu'aucun signe
/// n'existe.
class SignToken {
  final String word;
  final Map<String, dynamic>? sign;

  /// Pronom signé par un pointage (vers soi, vers l'autre…).
  final PointTarget? point;

  /// Expression du visage de la phrase (question, négation).
  final LsfExpression expression;

  /// Phrase niée : la tête fait « non » pendant le signe.
  final bool negated;

  const SignToken(this.word, this.sign,
      {this.point,
      this.expression = LsfExpression.neutral,
      this.negated = false});

  bool get isFingerspelled => sign == null;
  bool get isPointing => sign?['pointing'] == true;
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

  /// Signes de remplacement pour les marqueurs grammaticaux.
  static const _alternatives = {
    'fini': ['fini', 'finir', 'terminer', 'fin'],
    'futur': ['futur', 'plus tard', 'bientot'],
    'pas': ['pas', 'non'],
    'plus': ['plus jamais', 'jamais', 'pas'],
    'aucun': ['aucun', 'rien', 'pas'],
  };

  static const _pointDescriptions = {
    PointTarget.me: 'Index pointé vers sa propre poitrine.',
    PointTarget.you: 'Index pointé vers la personne à qui l’on parle.',
    PointTarget.other:
        'Index pointé sur le côté, vers la personne dont on parle.',
    PointTarget.we: 'Index qui décrit un arc entre soi et l’autre.',
    PointTarget.youPlural: 'Index qui balaie les personnes en face.',
    PointTarget.them:
        'Index qui balaie le côté, vers les personnes dont on parle.',
  };

  /// Traduit un texte français en LSF : ordre de la LSF (temps, lieu,
  /// personnes, action), sans mots grammaticaux du français, pronoms
  /// pointés et expressions du visage (voir [LsfGrammar]).
  /// [animated] : signes animés disponibles sur le serveur (clés
  /// normalisées « AU_REVOIR »), reconnus même s'ils sont absents du
  /// dictionnaire embarqué.
  static List<SignToken> translateText(
      String text, List<Map<String, dynamic>> signs,
      {Set<String> animated = const {}}) {
    String key(String phrase) =>
        normalize(phrase).toUpperCase().replaceAll(RegExp(r"[\s'-]+"), '_');
    Map<String, dynamic>? lookup(String phrase) =>
        findByWord(signs, phrase) ??
        (animated.contains(key(phrase))
            ? {'word': phrase.toUpperCase(), 'animatedOnly': true}
            : null);
    bool known(String phrase) => lookup(phrase) != null;

    final tokens = <SignToken>[];
    for (final unit in LsfGrammar.translate(text, known)) {
      final options = _alternatives[unit.gloss] ?? [unit.gloss];
      String word = unit.gloss;
      Map<String, dynamic>? sign;
      for (final option in options) {
        sign = lookup(option);
        if (sign != null) {
          word = option;
          break;
        }
      }
      final point = unit.point;
      if (sign == null && point != null) {
        sign = {
          'word': unit.gloss.toUpperCase(),
          'pointing': true,
          'gestureSummary': _pointDescriptions[point],
        };
      }
      if (sign == null && _stopWords.contains(word)) continue;
      tokens.add(SignToken(word, sign,
          point: point, expression: unit.expression, negated: unit.negated));
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

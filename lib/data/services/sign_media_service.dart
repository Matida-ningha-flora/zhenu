import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sign_motion.dart';
import 'echosign_api_client.dart';
import 'sign_recognition_service.dart';

/// Animations GIF des signes servies par le serveur EchoSign
/// (`GET /media/index`, `GET /media/gif/{signe}`).
///
/// La liste des signes animés est gardée en cache sur l'appareil : on sait
/// hors ligne quels mots ont une animation, et on évite les requêtes inutiles.
class SignMediaService {
  SignMediaService._();
  static final SignMediaService instance = SignMediaService._();

  static const _cacheKey = 'sign_media_index_v1';

  String _base = '';
  Set<String> _keys = {};
  Future<void>? _loading;
  DateTime? _loadedAt;

  Set<String> get keys => _keys;

  /// Même normalisation que le serveur : « À bientôt » ➜ « A_BIENTOT ».
  static String normalize(String value) {
    const accents = {
      'À': 'A',
      'Â': 'A',
      'Ä': 'A',
      'Á': 'A',
      'Ç': 'C',
      'É': 'E',
      'È': 'E',
      'Ê': 'E',
      'Ë': 'E',
      'Î': 'I',
      'Ï': 'I',
      'Í': 'I',
      'Ô': 'O',
      'Ö': 'O',
      'Ó': 'O',
      'Ù': 'U',
      'Û': 'U',
      'Ü': 'U',
      'Ú': 'U',
      'Ÿ': 'Y',
      'Œ': 'OE',
      'Æ': 'AE',
    };
    final upper = value.toUpperCase();
    final buffer = StringBuffer();
    for (final rune in upper.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(accents[char] ?? char);
    }
    return buffer
        .toString()
        .replaceAll(RegExp(r"[\s._\-'’]+"), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  bool has(String word) => _keys.contains(normalize(word));

  /// URL de l'animation d'un signe, ou `null` s'il n'en existe pas.
  Uri? gifUrl(String word) {
    final key = normalize(word);
    if (_base.isEmpty || !_keys.contains(key)) return null;
    return Uri.parse('$_base/media/gif/${Uri.encodeComponent(key)}');
  }

  /// Charge la liste (au plus une requête toutes les 10 minutes).
  Future<void> ensureLoaded() {
    final fresh = _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < const Duration(minutes: 10);
    if (fresh) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    final address = await SignRecognitionService.serverAddress();
    final urls = EchoSignApiClient.resolve(address);
    final prefs = await SharedPreferences.getInstance();
    if (urls == null) {
      _base = '';
      _keys = {};
      return;
    }
    _base =
        urls.health.replace(path: '').toString().replaceAll(RegExp(r'/$'), '');
    // Cache local d'abord : l'affichage n'attend pas le réseau.
    final cached = prefs.getString('$_cacheKey.$_base');
    if (cached != null && _keys.isEmpty) {
      try {
        _keys = (jsonDecode(cached) as List).cast<String>().toSet();
      } catch (_) {}
    }
    try {
      final response = await http
          .get(Uri.parse('$_base/media/index'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _keys = ((json['signs'] as List?) ?? const []).cast<String>().toSet();
        await prefs.setString('$_cacheKey.$_base', jsonEncode(_keys.toList()));
      }
      _loadedAt = DateTime.now();
    } catch (e) {
      // Serveur injoignable : nouvelle tentative dans 30 secondes au plus tôt.
      _loadedAt =
          DateTime.now().subtract(const Duration(minutes: 9, seconds: 30));
      debugPrint('Animations des signes indisponibles : $e');
    }
  }

  final Map<String, SignMotion> _motions = {};
  final Map<String, Future<SignMotion?>> _pendingMotions = {};

  /// Mouvements d'un signe pour l'avatar animé (`/media/landmarks/{signe}`).
  /// Le premier appel pour un signe peut prendre une dizaine de secondes
  /// (extraction côté serveur), les suivants sont immédiats.
  Future<SignMotion?> motion(String word) {
    final key = normalize(word);
    if (_base.isEmpty || !_keys.contains(key)) return Future.value(null);
    final cached = _motions[key];
    if (cached != null) return Future.value(cached);
    return _pendingMotions[key] ??=
        _fetchMotion(key).whenComplete(() => _pendingMotions.remove(key));
  }

  SignMotion? cachedMotion(String word) => _motions[normalize(word)];

  Future<SignMotion?> _fetchMotion(String key) async {
    try {
      final response = await http
          .get(Uri.parse('$_base/media/landmarks/${Uri.encodeComponent(key)}'))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
      final motion = SignMotion.fromJson(
          Map<String, dynamic>.from(jsonDecode(response.body) as Map));
      if (motion.frames.isEmpty) return null;
      if (_motions.length > 60) _motions.remove(_motions.keys.first);
      return _motions[key] = motion;
    } catch (e) {
      debugPrint('Mouvement indisponible pour $key : $e');
      return null;
    }
  }

  @visibleForTesting
  void setMotionForTesting(String word, SignMotion motion) =>
      _motions[normalize(word)] = motion;

  @visibleForTesting
  void setForTesting(String base, Set<String> keys) {
    _base = base;
    _keys = keys;
    _loadedAt = DateTime.now();
  }
}

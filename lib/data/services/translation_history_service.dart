import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Historique des traductions et conversations, stocké sur l'appareil et
/// propre à chaque compte.
class TranslationHistoryService {
  static const _baseKey = 'zhenu_translation_history_v1';
  static const _maxEntries = 200;
  static String _scope = '';

  /// Incrémenté à chaque modification : les écrans l'écoutent pour se mettre
  /// à jour sans rechargement manuel.
  static final ValueNotifier<int> changes = ValueNotifier(0);

  static String get _historyKey =>
      _scope.isEmpty ? _baseKey : '$_baseKey.$_scope';

  static void useAccount(String email) {
    _scope = email.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    changes.value++;
  }

  static Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_historyKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addEntry({
    required String type, // 'sign_to_text', 'text_to_sign', 'conversation'
    required String input,
    required String output,
    List<Map<String, dynamic>>? messages,
    String? id,
  }) async {
    if (input.trim().isEmpty && output.trim().isEmpty) return;
    final history = await getHistory();
    // Un identifiant fixe (salon de conversation) remplace l'entrée existante.
    if (id != null) history.removeWhere((e) => e['id'] == id);
    history.insert(0, {
      'id': id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      'type': type,
      'input': input.trim(),
      'output': output.trim(),
      'timestamp': DateTime.now().toIso8601String(),
      if (messages != null) 'messages': messages,
    });
    await _save(history.take(_maxEntries).toList());
  }

  static Future<void> deleteEntry(String id) async {
    final history = await getHistory();
    history.removeWhere((e) => e['id'] == id);
    await _save(history);
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    changes.value++;
  }

  static Future<void> _save(List<Map<String, dynamic>> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(history));
    changes.value++;
  }
}

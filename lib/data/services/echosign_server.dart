import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_data_service.dart';
import 'echosign_api_client.dart';

/// Localisation du serveur EchoSign.
///
/// Le serveur tourne sur un PC du réseau local : son adresse change avec le
/// réseau (box, partage de connexion…). L'application essaie, dans l'ordre :
/// 1. l'adresse saisie par l'utilisateur dans les préférences ;
/// 2. la dernière adresse qui a fonctionné ;
/// 3. l'adresse de l'administration, puis celle fournie à la compilation ;
/// 4. une recherche automatique sur le réseau Wi-Fi du téléphone (port 8000).
class EchoSignServer {
  EchoSignServer._();

  static const manualKey = 'echosign_server_manual';
  static const _lastKey = 'echosign_server_last';
  static const defaultPort = 8000;

  /// Adresse de repli (PC de développement).
  static const fallback = 'http://192.168.100.132:8000';

  static String? _found;
  static Future<String?>? _locating;

  /// Adresse connue qui fonctionne, sans requête réseau.
  static String? get current => _found;

  /// Adresse à utiliser tout de suite (sans vérification).
  static Future<String> preferred() async {
    if (_found != null) return _found!;
    final candidates = await _candidates();
    return candidates.isEmpty ? fallback : candidates.first;
  }

  /// Adresse saisie par l'utilisateur (vide : automatique).
  static Future<String> manual() async =>
      (await SharedPreferences.getInstance()).getString(manualKey) ?? '';

  static Future<void> setManual(String address) async {
    final prefs = await SharedPreferences.getInstance();
    final value = address.trim();
    if (value.isEmpty) {
      await prefs.remove(manualKey);
    } else {
      await prefs.setString(manualKey, value);
    }
    _found = null;
  }

  /// Oublie l'adresse trouvée (le serveur ne répond plus).
  static void invalidate() => _found = null;

  @visibleForTesting
  static void setForTesting(String? address) => _found = address;

  static Future<List<String>> _candidates() async {
    final prefs = await SharedPreferences.getInstance();
    final config = await AdminDataService.loadModelConfig();
    const fromBuild = String.fromEnvironment('ECHOSIGN_URL');
    final list = [
      prefs.getString(manualKey) ?? '',
      prefs.getString(_lastKey) ?? '',
      (config['endpoint'] as String? ?? '').trim(),
      fromBuild,
      fallback,
    ];
    final seen = <String>{};
    return [
      for (final a in list)
        if (a.trim().isNotEmpty && seen.add(a.trim())) a.trim()
    ];
  }

  /// Trouve un serveur qui répond ; `null` si aucun n'est joignable.
  /// Les appels simultanés partagent la même recherche.
  static Future<String?> locate({bool force = false}) {
    if (!force && _found != null) return Future.value(_found);
    return _locating ??= _locate().whenComplete(() => _locating = null);
  }

  static Future<String?> _locate() async {
    final candidates = await _candidates();
    // Adresses connues, testées en parallèle.
    final checks = await Future.wait(candidates.map((a) async =>
        await EchoSignApiClient.checkHealth(a,
                    timeout: const Duration(seconds: 2)) !=
                null
            ? a
            : null));
    final known = checks.whereType<String>().toList();
    if (known.isNotEmpty) return _remember(known.first);
    // Pas de recherche sur le web ni pendant les tests automatiques.
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }
    final scanned = await _scan();
    return scanned == null ? null : _remember(scanned);
  }

  static Future<String> _remember(String address) async {
    _found = address;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastKey, address);
    return address;
  }

  /// Recherche sur le(s) réseau(x) local(aux) du téléphone : une machine
  /// dont le port 8000 est ouvert et qui répond à `/health`.
  static Future<String?> _scan() async {
    final prefixes = <String>{};
    try {
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final parts = address.address.split('.');
          if (parts.length != 4) continue;
          final first = int.tryParse(parts[0]) ?? 0;
          final second = int.tryParse(parts[1]) ?? 0;
          final private = first == 10 ||
              (first == 192 && second == 168) ||
              (first == 172 && second >= 16 && second <= 31);
          if (private) prefixes.add('${parts[0]}.${parts[1]}.${parts[2]}');
        }
      }
    } catch (e) {
      debugPrint('Interfaces réseau illisibles : $e');
      return null;
    }
    for (final prefix in prefixes) {
      final hosts = [for (var i = 1; i < 255; i++) '$prefix.$i'];
      // Par paquets : ouverture du port, puis vérification /health.
      for (var start = 0; start < hosts.length; start += 64) {
        final batch = hosts.sublist(start, min(start + 64, hosts.length));
        final open = await Future.wait(batch.map(_portOpen));
        for (var i = 0; i < batch.length; i++) {
          if (!open[i]) continue;
          final address = 'http://${batch[i]}:$defaultPort';
          if (await EchoSignApiClient.checkHealth(address,
                  timeout: const Duration(seconds: 2)) !=
              null) {
            return address;
          }
        }
      }
    }
    return null;
  }

  static int min(int a, int b) => a < b ? a : b;

  /// Adresses du téléphone sur le réseau local (diagnostic : le PC doit
  /// avoir une adresse qui commence pareil).
  static Future<List<String>> deviceAddresses() async {
    if (kIsWeb) return const [];
    try {
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      return [
        for (final i in interfaces)
          for (final a in i.addresses) a.address
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> _portOpen(String host) async {
    try {
      final socket = await Socket.connect(host, defaultPort,
          timeout: const Duration(milliseconds: 450));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}

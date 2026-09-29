import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../firebase_options.dart';
import '../constants/demo_accounts.dart';
import 'firebase_auth_service.dart';

/// Gestion des comptes (utilisateurs et administrateurs) par l'administration.
///
/// En ligne : collection Firestore `users`. Hors ligne : comptes locaux.
/// Les règles de sécurité Firestore doivent réserver l'écriture des champs
/// `role` et `suspended` aux administrateurs.
class AdminUserService {
  static const _localKey = 'mock_users';

  static bool get _online => FirebaseAuthService().isFirebaseConfigured;

  static Future<List<Map<String, dynamic>>> listUsers() async {
    final users = <String, Map<String, dynamic>>{};
    for (final entry in demoAccounts.entries) {
      users[entry.key] = Map<String, dynamic>.from(entry.value);
    }
    for (final entry in (await _localUsers()).entries) {
      users[entry.key] = Map<String, dynamic>.from(entry.value as Map);
    }
    if (_online) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .get()
            .timeout(const Duration(seconds: 8));
        for (final doc in snapshot.docs) {
          final data = {...doc.data(), 'uid': doc.id, 'source': 'online'};
          final email = (data['email'] as String? ?? doc.id).toLowerCase();
          users[email] = data;
        }
      } catch (_) {
        // Hors ligne ou règles restrictives : liste locale uniquement.
      }
    }
    final list = users.values
        .where((u) => u['deleted'] != true)
        .map((u) => {
              ...u,
              'role': FirebaseAuthService.normalizeRole(u['role']),
            }
              ..remove('password')
              ..remove('passwordHash'))
        .toList()
      ..sort((a, b) => (a['name'] as String? ?? '')
          .toLowerCase()
          .compareTo((b['name'] as String? ?? '').toLowerCase()));
    return list;
  }

  static Future<Map<String, dynamic>> _localUsers() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final decoded = jsonDecode(prefs.getString(_localKey) ?? '{}') as Map;
      return decoded.map(
          (k, v) => MapEntry(k as String, Map<String, dynamic>.from(v as Map)));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveLocal(Map<String, dynamic> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localKey, jsonEncode(users));
  }

  /// Modifie le rôle ou la suspension d'un compte.
  static Future<void> update(
      Map<String, dynamic> user, Map<String, dynamic> changes) async {
    final email = (user['email'] as String? ?? '').toLowerCase();
    if (user['source'] == 'online') {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user['uid'] as String)
          .set(changes, SetOptions(merge: true));
      return;
    }
    final users = await _localUsers();
    final base =
        users[email] ?? Map<String, dynamic>.from(demoAccounts[email] ?? user);
    users[email] = {...base, ...changes};
    await _saveLocal(users);
  }

  static Future<void> delete(Map<String, dynamic> user) async {
    final email = (user['email'] as String? ?? '').toLowerCase();
    if (user['source'] == 'online') {
      // Le compte d'authentification ne peut être supprimé que côté serveur :
      // le profil est supprimé et l'accès bloqué.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user['uid'] as String)
          .set({'suspended': true, 'deleted': true}, SetOptions(merge: true));
      return;
    }
    final users = await _localUsers();
    users.remove(email);
    await _saveLocal(users);
  }

  /// Crée un compte (utilisateur ou administrateur) sans déconnecter
  /// l'administrateur courant.
  static Future<void> create({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final profile = {
      'name': name.trim(),
      'email': cleanEmail,
      'role': FirebaseAuthService.normalizeRole(role),
      'level': 1,
      'xp': 0,
      'suspended': false,
    };
    if (_online) {
      final app = await Firebase.initializeApp(
        name: 'admin-account-creation',
        options: DefaultFirebaseOptions.currentPlatform,
      ).catchError((_) => Firebase.app('admin-account-creation'));
      final auth = FirebaseAuth.instanceFor(app: app);
      try {
        final credential = await auth.createUserWithEmailAndPassword(
            email: cleanEmail, password: password);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set({
          ...profile,
          'uid': credential.user!.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await auth.signOut();
        return;
      } on FirebaseAuthException catch (e) {
        throw Exception(e.code == 'email-already-in-use'
            ? 'Cette adresse e-mail est déjà utilisée.'
            : e.message ?? 'Création impossible.');
      }
    }
    final users = await _localUsers();
    if (users.containsKey(cleanEmail) || demoAccounts.containsKey(cleanEmail)) {
      throw Exception('Cette adresse e-mail est déjà utilisée.');
    }
    users[cleanEmail] = {
      ...profile,
      'uid': 'local_${DateTime.now().millisecondsSinceEpoch}',
      'passwordHash': FirebaseAuthService.hashPassword(cleanEmail, password),
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _saveLocal(users);
  }
}

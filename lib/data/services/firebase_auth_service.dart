import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../firebase_options.dart';
import '../constants/demo_accounts.dart';

/// Authentification NeuroSigne.
///
/// Deux rôles seulement : `user` (profil unique pour tous les utilisateurs de
/// l'application mobile) et `admin`. Un compte administrateur ne peut jamais
/// être obtenu par inscription publique : il est créé ou promu par un autre
/// administrateur.
class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  static const roleUser = 'user';
  static const roleAdmin = 'admin';
  static const _localUsersKey = 'mock_users';
  static const _localSessionKey = 'current_mock_user';

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Anciennes valeurs (`normal`, `sourd`, `trainer`) ramenées au profil unique.
  static String normalizeRole(Object? role) =>
      role == roleAdmin ? roleAdmin : roleUser;

  /// Firebase initialisé avec de vraies clés de projet.
  bool get isFirebaseConfigured {
    try {
      Firebase.app();
      const options = DefaultFirebaseOptions.web;
      return options.apiKey != 'YOUR_API_KEY_HERE' &&
          options.projectId != 'YOUR_PROJECT_ID_HERE';
    } catch (_) {
      return false;
    }
  }

  /// Les comptes de démonstration ne sont acceptés qu'en développement ou
  /// lorsque Firebase est indisponible — jamais dans une version publiée
  /// reliée à Firebase.
  bool get demoAccountsEnabled => kDebugMode || !isFirebaseConfigured;

  static String hashPassword(String email, String password) => sha256
      .convert(
          utf8.encode('neurosigne:${email.trim().toLowerCase()}:$password'))
      .toString();

  Map<String, dynamic> _publicProfile(Map<String, dynamic> data) {
    final profile = Map<String, dynamic>.from(data)
      ..remove('password')
      ..remove('passwordHash');
    profile['role'] = normalizeRole(profile['role']);
    return profile;
  }

  Future<Map<String, dynamic>> _localUsers() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      return Map<String, dynamic>.from(
          jsonDecode(prefs.getString(_localUsersKey) ?? '{}') as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveLocalSession(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localSessionKey, jsonEncode(profile));
  }

  /// Inscription publique : toujours un compte utilisateur.
  Future<Map<String, dynamic>?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final profile = <String, dynamic>{
      'name': name.trim(),
      'email': cleanEmail,
      'role': roleUser,
      'level': 1,
      'xp': 0,
      'suspended': false,
    };

    if (isFirebaseConfigured) {
      try {
        final credential = await _auth.createUserWithEmailAndPassword(
            email: cleanEmail, password: password);
        final user = credential.user;
        if (user == null) return null;
        await user.updateDisplayName(profile['name'] as String);
        final data = {
          ...profile,
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        };
        await _firestore.collection('users').doc(user.uid).set(data);
        return _publicProfile({...profile, 'uid': user.uid});
      } on FirebaseAuthException catch (e) {
        throw _handleAuthException(e);
      } on FirebaseException catch (e) {
        throw Exception(_firestoreMessage(e));
      }
    }

    final users = await _localUsers();
    if (users.containsKey(cleanEmail) || demoAccounts.containsKey(cleanEmail)) {
      throw Exception('Cette adresse e-mail est déjà utilisée.');
    }
    final data = {
      ...profile,
      'uid': 'local_${DateTime.now().millisecondsSinceEpoch}',
      'passwordHash': hashPassword(cleanEmail, password),
      'createdAt': DateTime.now().toIso8601String(),
    };
    users[cleanEmail] = data;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localUsersKey, jsonEncode(users));
    final publicProfile = _publicProfile(data);
    await _saveLocalSession(publicProfile);
    return publicProfile;
  }

  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (demoAccountsEnabled && demoAccounts.containsKey(cleanEmail)) {
      return _localLogin(cleanEmail, password);
    }

    if (isFirebaseConfigured) {
      try {
        final credential = await _auth.signInWithEmailAndPassword(
            email: cleanEmail, password: password);
        final user = credential.user;
        if (user == null) return null;
        final ref = _firestore.collection('users').doc(user.uid);
        final doc = await ref.get();
        Map<String, dynamic> data;
        if (doc.exists) {
          data = doc.data()!;
        } else {
          // Profil absent (compte créé depuis la console) : utilisateur simple.
          data = {
            'uid': user.uid,
            'name': user.displayName ?? cleanEmail.split('@').first,
            'email': cleanEmail,
            'role': roleUser,
            'level': 1,
            'xp': 0,
          };
          await ref.set(data);
        }
        if (data['suspended'] == true) {
          await _auth.signOut();
          throw Exception(
              'Ce compte est suspendu. Contactez un administrateur.');
        }
        await ref.set({'lastLoginAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
        return _publicProfile(data);
      } on FirebaseAuthException catch (e) {
        throw _handleAuthException(e);
      } on FirebaseException catch (e) {
        throw Exception(_firestoreMessage(e));
      }
    }

    return _localLogin(cleanEmail, password);
  }

  Future<Map<String, dynamic>> _localLogin(
      String cleanEmail, String password) async {
    final users = {...demoAccounts, ...await _localUsers()};
    final data = users[cleanEmail] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Aucun compte trouvé avec cet e-mail.');
    }
    if (data['suspended'] == true) {
      throw Exception('Ce compte est suspendu. Contactez un administrateur.');
    }
    final hash = data['passwordHash'] as String?;
    final valid = hash != null
        ? hash == hashPassword(cleanEmail, password)
        : data['password'] == password;
    if (!valid) throw Exception('E-mail ou mot de passe incorrect.');
    final profile = _publicProfile(data);
    await _saveLocalSession(profile);
    return profile;
  }

  Future<void> sendPasswordReset(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (isFirebaseConfigured && !demoAccounts.containsKey(cleanEmail)) {
      try {
        await _auth.sendPasswordResetEmail(email: cleanEmail);
        return;
      } on FirebaseAuthException catch (e) {
        throw _handleAuthException(e);
      }
    }
    throw Exception(
        'La réinitialisation par e-mail nécessite une connexion au service en ligne.');
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localSessionKey);
    if (isFirebaseConfigured) {
      try {
        await _auth.signOut();
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getString(_localSessionKey);
    if (local != null) {
      try {
        return _publicProfile(
            Map<String, dynamic>.from(jsonDecode(local) as Map));
      } catch (_) {
        await prefs.remove(_localSessionKey);
      }
    }
    if (!isFirebaseConfigured) return null;
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists || doc.data()?['suspended'] == true) return null;
      return _publicProfile(doc.data()!);
    } catch (e) {
      debugPrint('Session Firebase indisponible : $e');
      return null;
    }
  }

  /// Met à jour le nom affiché de l'utilisateur connecté.
  Future<void> updateName(String email, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getString(_localSessionKey);
    if (local != null) {
      final profile = Map<String, dynamic>.from(jsonDecode(local) as Map);
      profile['name'] = clean;
      await _saveLocalSession(profile);
      final users = await _localUsers();
      final key = email.trim().toLowerCase();
      if (users[key] is Map) {
        users[key] = {
          ...Map<String, dynamic>.from(users[key] as Map),
          'name': clean
        };
        await prefs.setString(_localUsersKey, jsonEncode(users));
      }
      return;
    }
    if (isFirebaseConfigured && _auth.currentUser != null) {
      final user = _auth.currentUser!;
      await user.updateDisplayName(clean);
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({'name': clean}, SetOptions(merge: true));
    }
  }

  String _firestoreMessage(FirebaseException e) => e.code == 'unavailable'
      ? 'Service indisponible. Vérifiez votre connexion internet.'
      : 'Erreur du service (${e.code}). Réessayez.';

  Exception _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return Exception('E-mail ou mot de passe incorrect.');
      case 'email-already-in-use':
        return Exception('Cette adresse e-mail est déjà utilisée.');
      case 'invalid-email':
        return Exception("L'adresse e-mail n'est pas valide.");
      case 'weak-password':
        return Exception('Mot de passe trop faible (8 caractères minimum).');
      case 'too-many-requests':
        return Exception(
            'Trop de tentatives. Réessayez dans quelques minutes.');
      case 'network-request-failed':
        return Exception('Pas de connexion internet.');
      case 'user-disabled':
        return Exception('Ce compte a été désactivé.');
      default:
        return Exception(e.message ?? "Erreur d'authentification.");
    }
  }
}

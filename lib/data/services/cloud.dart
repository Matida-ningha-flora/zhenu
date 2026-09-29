import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firebase_auth_service.dart';

/// Accès à Firestore lorsqu'un compte Firebase est connecté.
///
/// Sans Firebase (hors ligne, comptes de démonstration, tests), [ready] est
/// faux et les services utilisent leur stockage local.
class Cloud {
  static FirebaseFirestore? _testDb;
  static FirebaseAuth? _testAuth;

  /// Branche une base et une authentification de test.
  @visibleForTesting
  static void useForTesting(FirebaseFirestore? db, [FirebaseAuth? auth]) {
    _testDb = db;
    _testAuth = auth;
  }

  static FirebaseFirestore get db => _testDb ?? FirebaseFirestore.instance;

  static FirebaseAuth get auth => _testAuth ?? FirebaseAuth.instance;

  static bool get ready {
    if (_testDb != null) return _testAuth?.currentUser != null;
    if (!FirebaseAuthService().isFirebaseConfigured) return false;
    try {
      return FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  static User? get user => ready ? auth.currentUser : null;

  /// Exécute une opération Firestore ; renvoie `null` si elle échoue ou
  /// dépasse le délai (réseau absent, règles refusées…).
  static Future<T?> attempt<T>(Future<T> Function() action,
      {Duration timeout = const Duration(seconds: 6)}) async {
    if (!ready) return null;
    try {
      return await action().timeout(timeout);
    } catch (e) {
      debugPrint('Firestore : $e');
      return null;
    }
  }
}

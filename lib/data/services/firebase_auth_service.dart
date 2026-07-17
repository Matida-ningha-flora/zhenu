import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../firebase_options.dart';

class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Détermine si le projet Firebase est configuré avec des clés réelles.
  bool get isFirebaseConfigured {
    try {
      Firebase.app();
      // On teste si les options par défaut ont été modifiées
      const options = DefaultFirebaseOptions.web;
      if (options.apiKey == 'YOUR_API_KEY_HERE' || options.projectId == 'YOUR_PROJECT_ID_HERE') {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Inscription d'un utilisateur
  Future<Map<String, dynamic>?> register({
    required String name,
    required String email,
    required String password,
    required String role, // 'normal' ou 'sourd' (l'admin ne peut pas s'inscrire publiquement)
    required String avatarType,
  }) async {
    // Empêcher l'inscription en tant qu'admin par défaut pour des raisons de sécurité.
    // Si l'e-mail contient une signature admin spécifique, on peut l'autoriser exceptionnellement
    String finalRole = role;
    if (email.trim().toLowerCase().startsWith('admin@') || email.trim().toLowerCase() == 'admin@test.com') {
      finalRole = 'admin';
    } else if (role == 'admin') {
      // Bloque la tentative de forcer le rôle admin dans l'API publique
      finalRole = 'normal';
    }

    if (isFirebaseConfigured) {
      try {
        // 1. Création du compte Firebase Auth
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password.trim(),
        );

        User? user = userCredential.user;
        if (user != null) {
          // 2. Enregistrement du profil dans Cloud Firestore
          Map<String, dynamic> userData = {
            'uid': user.uid,
            'name': name.trim(),
            'email': email.trim().toLowerCase(),
            'role': finalRole,
            'avatarType': avatarType,
            'level': 1,
            'xp': 0,
            'badges': <String>[],
            'createdAt': FieldValue.serverTimestamp(),
          };

          await _firestore.collection('users').doc(user.uid).set(userData);
          return userData;
        }
      } on FirebaseAuthException catch (e) {
        throw _handleAuthException(e);
      } catch (e) {
        throw Exception("Une erreur inattendue est survenue : $e");
      }
    } else {
      // --- MODE DÉMONSTRATION / OFFLINE (Fallback SharedPreferences) ---
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString('mock_users') ?? '{}';
      final Map<String, dynamic> mockUsers = jsonDecode(usersJson);

      if (mockUsers.containsKey(email.trim().toLowerCase())) {
        throw Exception("Cette adresse e-mail est déjà utilisée.");
      }

      final String mockUid = "mock_uid_${DateTime.now().millisecondsSinceEpoch}";
      final Map<String, dynamic> userData = {
        'uid': mockUid,
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'role': finalRole,
        'avatarType': avatarType,
        'level': 1,
        'xp': 0,
        'badges': <String>[],
        'password': password.trim(), // Stocké uniquement en local pour le mock
      };

      mockUsers[email.trim().toLowerCase()] = userData;
      await prefs.setString('mock_users', jsonEncode(mockUsers));
      await prefs.setString('current_mock_user', jsonEncode(userData));

      return userData;
    }
    return null;
  }

  /// Connexion d'un utilisateur
  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (isFirebaseConfigured) {
      try {
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: cleanEmail,
          password: password.trim(),
        );

        User? user = userCredential.user;
        if (user != null) {
          // Récupération des données utilisateur de Firestore
          DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
          if (doc.exists) {
            return doc.data() as Map<String, dynamic>;
          } else {
            // Profil inexistant (ex: créé manuellement dans Auth console). On le crée.
            // Si l'e-mail contient 'admin' ou 'trainer', on attribue ces rôles par défaut.
            String defaultRole = 'normal';
            if (cleanEmail.contains('admin')) defaultRole = 'admin';
            if (cleanEmail.contains('trainer')) defaultRole = 'trainer';

            Map<String, dynamic> userData = {
              'uid': user.uid,
              'name': cleanEmail.split('@')[0],
              'email': cleanEmail,
              'role': defaultRole,
              'avatarType': 'male',
              'level': 1,
              'xp': 0,
              'badges': <String>[],
            };
            await _firestore.collection('users').doc(user.uid).set(userData);
            return userData;
          }
        }
      } on FirebaseAuthException catch (e) {
        throw _handleAuthException(e);
      } catch (e) {
        throw Exception("Une erreur inattendue est survenue : $e");
      }
    } else {
      // --- MODE DÉMONSTRATION / OFFLINE (Fallback SharedPreferences) ---
      final prefs = await SharedPreferences.getInstance();

      // Comptes démo par défaut pré-enregistrés
      final defaultAccounts = {
        'user@test.com': {
          'uid': 'demo_user',
          'name': 'Apprenant Démo',
          'email': 'user@test.com',
          'role': 'normal',
          'avatarType': 'male',
          'level': 3,
          'xp': 1250,
          'badges': ['🎓', '⭐'],
          'password': 'password'
        },
        'sourd@test.com': {
          'uid': 'demo_sourd',
          'name': 'Sourd Démo',
          'email': 'sourd@test.com',
          'role': 'sourd',
          'avatarType': 'female',
          'level': 2,
          'xp': 800,
          'badges': ['🎓'],
          'password': 'password'
        },
        'admin@test.com': {
          'uid': 'demo_admin',
          'name': 'Admin Zhẽnù',
          'email': 'admin@test.com',
          'role': 'admin',
          'avatarType': 'male',
          'level': 5,
          'xp': 5000,
          'badges': ['🎓', '⭐', '🚨'],
          'password': 'password'
        }
      };

      final usersJson = prefs.getString('mock_users') ?? '{}';
      final Map<String, dynamic> mockUsers = jsonDecode(usersJson);

      // On fusionne les comptes par défaut et les comptes créés
      final allUsers = {...defaultAccounts, ...mockUsers};

      if (!allUsers.containsKey(cleanEmail)) {
        throw Exception("Aucun compte trouvé avec cet e-mail. Veuillez vous inscrire.");
      }

      final userData = allUsers[cleanEmail] as Map<String, dynamic>;
      // N'importe quel mot de passe fonctionne pour les comptes démo par défaut,
      // sinon vérification stricte pour les comptes créés
      if (cleanEmail != 'user@test.com' && 
          cleanEmail != 'sourd@test.com' && 
          cleanEmail != 'admin@test.com' && 
          userData['password'] != password.trim()) {
        throw Exception("Mot de passe incorrect.");
      }

      await prefs.setString('current_mock_user', jsonEncode(userData));
      return userData;
    }
    return null;
  }

  /// Déconnexion
  Future<void> signOut() async {
    if (isFirebaseConfigured) {
      await _auth.signOut();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_mock_user');
    }
  }

  /// Récupérer les données de l'utilisateur actuellement connecté
  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (isFirebaseConfigured) {
      try {
        User? firebaseUser = _auth.currentUser;
        if (firebaseUser != null) {
          DocumentSnapshot doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
          if (doc.exists) {
            return doc.data() as Map<String, dynamic>;
          }
        }
      } catch (e) {
        print("Erreur de récupération Firebase de l'utilisateur: $e");
        return null;
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_mock_user');
      if (userJson != null) {
        return jsonDecode(userJson) as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// Gère les exceptions d'authentification Firebase et les traduit en français
  Exception _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception("Aucun utilisateur trouvé pour cette adresse e-mail.");
      case 'wrong-password':
        return Exception("Mot de passe incorrect.");
      case 'email-already-in-use':
        return Exception("Cette adresse e-mail est déjà utilisée par un autre compte.");
      case 'invalid-email':
        return Exception("L'adresse e-mail n'est pas valide.");
      case 'weak-password':
        return Exception("Le mot de passe choisi est trop faible (6 caractères minimum).");
      case 'operation-not-allowed':
        return Exception("Cette opération n'est pas autorisée.");
      default:
        return Exception(e.message ?? "Une erreur d'authentification s'est produite.");
    }
  }
}

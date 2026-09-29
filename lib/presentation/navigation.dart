import 'package:flutter/material.dart';

import '../core/preferences/app_preferences.dart';
import '../data/services/firebase_auth_service.dart';
import 'screens/admin_dashboard.dart';
import 'screens/login_screen.dart';
import 'screens/user_dashboard.dart';

Route<void> fadeRoute(Widget page) => PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 350),
    );

/// Ouvre l'espace correspondant au rôle et vide la pile de navigation.
void openHomeFor(BuildContext context, Map<String, dynamic> user) {
  final email = user['email'] as String? ?? '';
  final name = user['name'] as String? ?? '';
  final page = FirebaseAuthService.normalizeRole(user['role']) ==
          FirebaseAuthService.roleAdmin
      ? AdminDashboard(email: email)
      : UserDashboard(email: email, name: name);
  Navigator.of(context).pushAndRemoveUntil(fadeRoute(page), (_) => false);
}

Future<void> signOutAndReturnToLogin(BuildContext context) async {
  final navigator = Navigator.of(context);
  await FirebaseAuthService().signOut();
  await AppPreferences.instance.resetToGuest();
  navigator.pushAndRemoveUntil(fadeRoute(const LoginScreen()), (_) => false);
}

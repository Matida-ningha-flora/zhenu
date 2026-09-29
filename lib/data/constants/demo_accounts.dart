/// Comptes de démonstration (mot de passe : `password`), utilisés uniquement
/// en développement ou sans Firebase — voir
/// `FirebaseAuthService.demoAccountsEnabled`. Partagés avec l'espace
/// administrateur pour que les deux affichent les mêmes informations.
const Map<String, Map<String, dynamic>> demoAccounts = {
  'user@test.com': {
    'uid': 'demo_user',
    'name': 'Utilisateur Démo',
    'email': 'user@test.com',
    'role': 'user',
    'level': 1,
    'xp': 0,
    'password': 'password',
  },
  'admin@test.com': {
    'uid': 'demo_admin',
    'name': 'Administrateur Démo',
    'email': 'admin@test.com',
    'role': 'admin',
    'level': 1,
    'xp': 0,
    'password': 'password',
  },
};

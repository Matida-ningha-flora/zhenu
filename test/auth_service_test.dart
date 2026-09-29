import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhendu_app/data/services/firebase_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final auth = FirebaseAuthService();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('l’inscription publique ne donne jamais le rôle administrateur',
      () async {
    final user = await auth.register(
        name: 'Test', email: 'admin@exemple.com', password: 'motdepasse1');
    expect(user!['role'], 'user');
  });

  test('le mot de passe local est haché et vérifié', () async {
    await auth.register(
        name: 'Awa', email: 'awa@exemple.com', password: 'secret123');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mock_users'), isNot(contains('secret123')));

    await expectLater(auth.login(email: 'awa@exemple.com', password: 'mauvais'),
        throwsException);
    final user =
        await auth.login(email: 'awa@exemple.com', password: 'secret123');
    expect(user!['name'], 'Awa');
    expect(user.containsKey('passwordHash'), isFalse);
  });

  test('les anciens rôles sont ramenés au profil unique', () {
    expect(FirebaseAuthService.normalizeRole('sourd'), 'user');
    expect(FirebaseAuthService.normalizeRole('trainer'), 'user');
    expect(FirebaseAuthService.normalizeRole('admin'), 'admin');
  });
}

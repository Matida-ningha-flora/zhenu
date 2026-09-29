import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhendu_app/data/services/sign_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('traduit une phrase en signes et épelle les mots inconnus', () async {
    final signs = await SignRepository.officialSigns();
    final tokens = SignRepository.translateText('Bonjour, merci Zoé !', signs);

    expect(tokens.map((t) => t.word), ['bonjour', 'merci', 'zoe']);
    expect(tokens[0].isFingerspelled, isFalse);
    expect(tokens[1].isFingerspelled, isFalse);
    expect(tokens[2].isFingerspelled, isTrue);
    expect(tokens[2].fingerspelling, 'Z - O - E');
  });

  test('la recherche ignore les accents', () async {
    final signs = await SignRepository.officialSigns();
    expect(SignRepository.findByWord(signs, 'hopital'), isNotNull);
  });

  test('un ancien stockage partiel ne masque pas les signes de référence',
      () async {
    SharedPreferences.setMockInitialValues({
      SignRepository.officialKey: '[{"id":"1","word":"BONJOUR"}]',
    });
    final signs = await SignRepository.officialSigns();
    expect(signs.length, greaterThan(20));
  });
}

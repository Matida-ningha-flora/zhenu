import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zhendu_app/presentation/widgets/motion.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhendu_app/core/preferences/app_preferences.dart';
import 'package:zhendu_app/data/models/sign_motion.dart';
import 'package:zhendu_app/data/services/admin_data_service.dart';
import 'package:zhendu_app/data/services/sign_media_service.dart';
import 'package:zhendu_app/data/services/sign_repository.dart';
import 'package:zhendu_app/presentation/widgets/lsf_renderer.dart';
import 'package:zhendu_app/presentation/widgets/sign_avatar.dart';
import 'package:zhendu_app/presentation/widgets/sign_translation_gif.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    Motion.ambient = false;
    SharedPreferences.setMockInitialValues({});
    SignRepository.clearCache();
    AdminDataService.clearCache();
    SignMediaService.instance.setForTesting('http://192.168.100.132:8000',
        {'MERCI', 'AU_REVOIR', 'ABEILLE', 'A_BIENTOT'});
  });

  test('même normalisation que le serveur', () {
    expect(SignMediaService.normalize('À bientôt'), 'A_BIENTOT');
    expect(SignMediaService.normalize('ABOYER.GUEULE'), 'ABOYER_GUEULE');
    expect(SignMediaService.normalize("l'abeille"), 'L_ABEILLE');
    expect(SignMediaService.normalize(' a-côté '), 'A_COTE');
  });

  test('URL de l’animation seulement si le GIF existe', () {
    final media = SignMediaService.instance;
    expect(media.gifUrl('merci').toString(),
        'http://192.168.100.132:8000/media/gif/MERCI');
    expect(media.gifUrl('à bientôt').toString(),
        'http://192.168.100.132:8000/media/gif/A_BIENTOT');
    expect(media.gifUrl('bonjour'), isNull);
  });

  test('les signes animés du serveur complètent le dictionnaire', () async {
    final signs = await SignRepository.officialSigns();
    final tokens = SignRepository.translateText(
        'Merci, au revoir l’abeille', signs,
        animated: SignMediaService.instance.keys);
    expect(tokens.map((t) => t.word), ['merci', 'au revoir', 'abeille']);
    expect(tokens.every((t) => !t.isFingerspelled), isTrue);
    expect(tokens[2].sign!['animatedOnly'], isTrue);
  });

  testWidgets('mode vidéo : un seul cadre, le signe est chargé',
      (tester) async {
    AppPreferences.instance.responseFormat = 'video';
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: LsfRenderer(text: 'merci', autoplay: false))));
    await tester.pumpAndSettle();
    // Serveur de test injoignable : le cadre vidéo explique l'absence.
    expect(find.text('MERCI'), findsWidgets);
    expect(find.byType(SignGifView), findsNothing);
  });

  for (final (format, style) in [
    ('avatar', MotionStyle.avatar),
    ('landmarks', MotionStyle.skeleton),
  ]) {
    testWidgets('mode $format : le signe est rejoué en mouvement',
        (tester) async {
      SignMediaService.instance.setMotionForTesting(
          'merci',
          SignMotion.fromJson(jsonDecode(
                  File('test/fixtures/landmarks_merci.json').readAsStringSync())
              as Map<String, dynamic>));
      AppPreferences.instance.responseFormat = format;
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: LsfRenderer(text: 'merci', autoplay: false))));
      // Animation en boucle : pas de pumpAndSettle.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final player =
          tester.widget<SignMotionPlayer>(find.byType(SignMotionPlayer));
      expect(player.style, style);
      expect(find.byType(SignGifView), findsNothing);
    });
  }

  testWidgets('sans animation : avatar et description du geste',
      (tester) async {
    AppPreferences.instance.responseFormat = 'avatar';
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: LsfRenderer(text: 'bonjour', autoplay: false))));
    await tester.pumpAndSettle();
    expect(find.byType(SignGifView), findsNothing);
    expect(find.text('BONJOUR'), findsWidgets);
  });
}

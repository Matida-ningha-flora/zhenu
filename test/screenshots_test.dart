// Génère des captures d'écran de revue visuelle (non exécuté par défaut).
// flutter test test/screenshots_test.dart --dart-define=SCREENSHOTS=true
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zhendu_app/presentation/widgets/motion.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhendu_app/core/preferences/app_preferences.dart';
import 'package:zhendu_app/core/themes/app_theme.dart';
import 'package:zhendu_app/data/services/admin_data_service.dart';
import 'package:zhendu_app/data/services/cloud.dart';
import 'package:zhendu_app/data/services/sign_media_service.dart';
import 'package:zhendu_app/data/services/sign_repository.dart';
import 'package:zhendu_app/presentation/screens/admin_dashboard.dart';
import 'package:zhendu_app/presentation/screens/conversations/group_conversations.dart';
import 'package:zhendu_app/presentation/screens/conversations/remote_room_screen.dart';
import 'package:zhendu_app/presentation/screens/login_screen.dart';
import 'package:zhendu_app/presentation/screens/onboarding_screen.dart';
import 'package:zhendu_app/presentation/screens/preferences_screen.dart';
import 'package:zhendu_app/presentation/widgets/lsf_renderer.dart';
import 'package:zhendu_app/presentation/screens/user_dashboard.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');
const _out =
    String.fromEnvironment('SCREENSHOT_DIR', defaultValue: 'build/screenshots');

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    if (!_enabled) return;
    GoogleFonts.config.allowRuntimeFetching = false;
    Motion.ambient = false;
    await _loadFont('MaterialIcons', [
      'C:/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf'
    ]);
    await _loadFont('Emoji', ['C:/Windows/Fonts/seguiemj.ttf']);
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      await _loadFont('Inter', ['assets/google_fonts/Inter-$w.ttf']);
    }
  });

  setUp(() {
    SignRepository.clearCache();
    AdminDataService.clearCache();
  });

  Future<void> shot(WidgetTester tester, String name, Widget home,
      {bool dark = false,
      Map<String, Object> prefs = const {},
      Future<void> Function(WidgetTester)? act}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'user_test_com.preferences_completed': true,
      'user_test_com.theme_preference': dark ? 'dark' : 'light',
      ...prefs,
    });
    await AppPreferences.instance.loadForUser('user@test.com');
    ThemeData withFallback(ThemeData t) => t.copyWith(
        textTheme: t.textTheme.apply(fontFamilyFallback: const ['Emoji']));
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: ListenableBuilder(
        listenable: AppPreferences.instance,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: withFallback(AppTheme.lightTheme),
          darkTheme: withFallback(AppTheme.darkTheme),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: home,
        ),
      ),
    ));
    await tester
        .runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    final before = tester.takeException();
    if (before != null) debugPrint('SHOT $name (avant) : $before');
    if (act != null) await act(tester);
    await tester
        .runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    final after = tester.takeException();
    if (after != null) debugPrint('SHOT $name : $after');
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(_out).createSync(recursive: true);
      File('$_out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  const user = UserDashboard(email: 'user@test.com', name: 'Awa Ndiaye');

  testWidgets('captures', (tester) async {
    await shot(tester, '01_accueil_presentation', const OnboardingScreen());
    await shot(tester, '02_connexion', const LoginScreen());
    await shot(tester, '03_tableau_de_bord', user);
    await shot(tester, '04_je_parle', user, act: (t) async {
      await t.tap(find.text('Je parle'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'Bonjour merci');
      await t.pump();
      await t.tap(find.text('Traduire en LSF'));
      await t.pump(const Duration(milliseconds: 300));
    });
    await shot(tester, '05_je_signe', user, act: (t) async {
      await t.tap(find.text('Je signe'));
      await t.pumpAndSettle();
    });
    await shot(tester, '06_conversation', user, act: (t) async {
      await t.tap(find.text('Traduire').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Groupe'));
      await t.pumpAndSettle();
      for (final name in ['Paul', 'Mariam']) {
        await t.enterText(find.byType(TextField).first, name);
        await t.tap(find.byTooltip('Ajouter'));
        await t.pumpAndSettle();
      }
      await t.tap(find.textContaining('Démarrer'));
      await t.pumpAndSettle();
      await t.tap(find.text('Paul').last);
      await t.enterText(
          find.byType(TextField).last, 'Bonjour, comment ça va ?');
      await t.pump();
      await t.tap(find.byTooltip('Envoyer'));
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
      await t.tap(find.text('Moi'));
      await t.enterText(find.byType(TextField).last, 'Très bien, merci !');
      await t.pump();
      await t.tap(find.byTooltip('Envoyer'));
      await t.pump(const Duration(milliseconds: 300));
    });
    await shot(tester, '07_dictionnaire', user, act: (t) async {
      await t.tap(find.text('Dictionnaire'));
    });
    await shot(tester, '09_profil', user, act: (t) async {
      await t.tap(find.text('Profil'));
    });
    await shot(tester, '10_preferences', const PreferencesScreen());
    await shot(tester, '11_tableau_de_bord_sombre', user, dark: true);
    await shot(
        tester, '12_admin', const AdminDashboard(email: 'admin@test.com'));
  }, skip: !_enabled);

  testWidgets('captures conversations à distance', (tester) async {
    final db = FakeFirebaseFirestore();
    final now = DateTime.now();
    Map<String, Object> room(String id, String title, List<String> people,
            {List<String> invited = const [],
            String last = '',
            String by = ''}) =>
        {
          'title': title,
          'code': 'K7M4Q2',
          'createdBy': people.first,
          'participants': people,
          'participantNames': {
            'awa': 'Awa Ndiaye',
            'paul': 'Paul Mbarga',
            'mariam': 'Mariam',
            'jean': 'Jean'
          },
          'invitedEmails': invited,
          'active': true,
          'lastMessage': last,
          'lastSenderName': by,
          'createdAt': now.subtract(const Duration(hours: 3)),
          'lastMessageAt': now.subtract(const Duration(minutes: 4)),
          'lastRead': {'awa': now.subtract(const Duration(hours: 1))},
          'presence': {'awa': now, 'paul': now},
        };
    await db.collection('conversations').doc('r1').set(room(
        'r1', 'Famille', ['awa', 'paul', 'mariam'],
        last: 'On se retrouve à 18 h ?', by: 'Paul Mbarga'));
    await db.collection('conversations').doc('r2').set(room(
        'r2', '', ['awa', 'jean'],
        last: 'Merci beaucoup', by: 'Awa Ndiaye')
      ..['lastRead'] = {'awa': now});
    await db.collection('conversations').doc('r3').set(
        room('r3', 'Réunion association', ['jean'], invited: ['awa@test.com']));
    final messages = db.collection('conversations/r1/messages');
    var t = now.subtract(const Duration(minutes: 12));
    for (final m in [
      ['paul', 'Paul Mbarga', 'Bonjour à tous !', false],
      ['awa', 'Awa Ndiaye', 'Bonjour Paul, comment ça va ?', true],
      ['mariam', 'Mariam', 'Très bien merci', false],
      ['paul', 'Paul Mbarga', 'On se retrouve à 18 h ?', false],
    ]) {
      t = t.add(const Duration(minutes: 2));
      await messages.add({
        'senderId': m[0],
        'senderName': m[1],
        'text': m[2],
        'signed': m[3],
        'createdAt': t,
      });
    }
    Cloud.useForTesting(
        db,
        MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'awa', email: 'awa@test.com')));
    addTearDown(() => Cloud.useForTesting(null));
    await shot(tester, '13_salons_a_distance',
        const Scaffold(body: SafeArea(child: GroupConversationsTab())));
    await shot(tester, '14_salon',
        const RemoteRoomScreen(roomId: 'r1', myName: 'Awa Ndiaye'));
  }, skip: !_enabled);

  // Animation réelle depuis le serveur EchoSign (SCREENSHOT_SERVER).
  testWidgets('capture traduction avec GIF du serveur', (tester) async {
    const server = String.fromEnvironment('SCREENSHOT_SERVER');
    HttpOverrides.global = null; // accès réseau réel pour ce test
    final keys = await tester.runAsync(() async {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('$server/media/index'));
      final body = await (await request.close()).transform(utf8.decoder).join();
      client.close();
      return ((jsonDecode(body) as Map)['signs'] as List)
          .cast<String>()
          .toSet();
    });
    SignMediaService.instance.setForTesting(server, keys!);
    for (final format in ['avatar', 'video']) {
      await shot(
          tester,
          '15_texte_vers_signe_$format',
          const Scaffold(
              body: SafeArea(
                  child: Padding(
            padding: EdgeInsets.all(16),
            child: LsfRenderer(text: 'Merci, au revoir', autoplay: false),
          ))),
          prefs: {'user_test_com.response_format': format}, act: (t) async {
        await t.runAsync(() => Future.delayed(const Duration(seconds: 4)));
        await t.pump();
      });
    }
  },
      skip: !_enabled ||
          const String.fromEnvironment('SCREENSHOT_SERVER').isEmpty);
}

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zhendu_app/presentation/widgets/motion.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhendu_app/data/services/admin_data_service.dart';
import 'package:zhendu_app/data/services/cloud.dart';
import 'package:zhendu_app/data/services/conversation_service.dart';
import 'package:zhendu_app/data/services/sign_repository.dart';
import 'package:zhendu_app/presentation/screens/conversations/group_conversations.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    Motion.ambient = false;
    SharedPreferences.setMockInitialValues({});
    SignRepository.clearCache();
    AdminDataService.clearCache();
    db = FakeFirebaseFirestore();
  });
  tearDown(() => Cloud.useForTesting(null));

  Future<void> pumpTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GroupConversationsTab())));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Sans compte en ligne : un compte est demandé (pas de mode local)',
      (tester) async {
    await pumpTab(tester);
    expect(find.text('Compte en ligne requis'), findsOneWidget);
    expect(find.text('Face à face'), findsNothing);
    expect(find.text('Créer'), findsNothing);
  });

  testWidgets('Créer un salon, voir son code et envoyer un message',
      (tester) async {
    Cloud.useForTesting(
        db,
        MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'awa', email: 'awa@test.com')));
    await pumpTab(tester);
    expect(find.text('Conversations à distance'), findsOneWidget);

    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Famille');
    await tester.tap(find.text('Créer le salon'));
    await tester.pumpAndSettle();

    // Le code du salon est affiché pour être partagé.
    final room =
        Room.fromDoc((await db.collection('conversations').get()).docs.single);
    expect(find.text(room.code), findsWidgets);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('Famille'), findsWidgets);
    await tester.enterText(find.byType(TextField).last, 'Bonjour à tous');
    await tester.pump();
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pumpAndSettle();

    final messages =
        await db.collection('conversations/${room.id}/messages').get();
    expect(messages.docs.single.data()['text'], 'Bonjour à tous');
    expect(find.text('Bonjour à tous'), findsOneWidget);
  });

  testWidgets('Une invitation reçue peut être acceptée', (tester) async {
    await db.collection('conversations').doc('r1').set({
      'title': 'Réunion',
      'code': 'XYZ234',
      'createdBy': 'awa',
      'participants': ['awa'],
      'participantNames': {'awa': 'Awa'},
      'invitedEmails': ['paul@test.com'],
      'active': true,
      'lastMessage': '',
      'lastSenderName': '',
    });
    Cloud.useForTesting(
        db,
        MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'paul', email: 'paul@test.com')));
    await pumpTab(tester);

    expect(find.text('Awa vous invite dans « Réunion »'), findsOneWidget);
    await tester.tap(find.text('Rejoindre').last);
    await tester.pumpAndSettle();

    final room = await db.collection('conversations').doc('r1').get();
    expect(room.data()!['participants'], ['awa', 'paul']);
  });
}

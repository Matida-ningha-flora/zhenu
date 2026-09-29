import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhendu_app/data/services/conversation_service.dart';
import 'package:zhendu_app/presentation/screens/register_screen.dart';
import 'package:zhendu_app/presentation/widgets/motion.dart';
import 'package:zhendu_app/presentation/widgets/user_type_selector.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    Motion.ambient = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('inscription : le profil (sourd, entendant) est obligatoire',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(UserTypeSelector), findsOneWidget);
    await tester.ensureVisible(find.text('Créer mon compte'));
    await tester.tap(find.text('Créer mon compte'));
    await tester.pumpAndSettle();
    expect(find.text('Choisissez votre profil.'), findsOneWidget);

    await tester.ensureVisible(find.text('Sourd ou malentendant'));
    await tester.tap(find.text('Sourd ou malentendant'));
    await tester.pumpAndSettle();
    expect(find.text('Choisissez votre profil.'), findsNothing);
  });

  test('le profil de chaque participant est lu depuis le salon', () {
    expect(UserType.of('deaf')!.emoji, '🤟');
    expect(UserType.of('hearing')!.emoji, '🗣️');
    expect(UserType.of('inconnu'), isNull);
    expect(const Room(
      id: 'r',
      title: '',
      code: 'ABC234',
      createdBy: 'a',
      participants: ['a'],
      names: {'a': 'Awa'},
      invitedEmails: [],
      active: true,
      lastMessage: '',
      lastSenderName: '',
      lastMessageAt: null,
      createdAt: null,
      lastRead: {},
      presence: {},
      userTypes: {'a': 'deaf'},
    ).userTypes['a'], 'deaf');
  });
}

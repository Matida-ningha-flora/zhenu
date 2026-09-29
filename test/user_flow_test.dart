import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zhendu_app/presentation/widgets/motion.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhendu_app/core/preferences/app_preferences.dart';
import 'package:zhendu_app/core/themes/app_theme.dart';
import 'package:zhendu_app/data/services/admin_data_service.dart';
import 'package:zhendu_app/data/services/sign_repository.dart';
import 'package:zhendu_app/presentation/screens/dictionary_screen.dart';
import 'package:zhendu_app/presentation/screens/user_dashboard.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    Motion.ambient = false;
    SignRepository.clearCache();
    AdminDataService.clearCache();
  });

  Future<void> pumpDashboard(WidgetTester tester, {bool dark = false}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'user_test_com.preferences_completed': true,
      'user_test_com.theme_preference': dark ? 'dark' : 'light',
    });
    await tester.pumpWidget(ListenableBuilder(
      listenable: AppPreferences.instance,
      builder: (context, _) => MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: AppPreferences.instance.themeMode,
        home: const UserDashboard(email: 'user@test.com', name: 'Awa Ndiaye'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets('Parcours utilisateur complet (${dark ? 'sombre' : 'clair'})',
        (tester) async {
      await pumpDashboard(tester, dark: dark);
      expect(find.textContaining('Awa'), findsWidgets);
      expect(find.text('Je signe'), findsOneWidget);

      // Accueil ➜ traduction « Je parle ».
      await tester.tap(find.text('Je parle'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Bonjour merci');
      await tester.pump();
      await tester.tap(find.text('Traduire en LSF'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle(const Duration(seconds: 6));
      expect(find.text('En LSF'), findsOneWidget);

      // Conversations : deux téléphones, un compte en ligne est requis.
      await tester.tap(find.text('Groupe'));
      await tester.pumpAndSettle();
      expect(find.text('Compte en ligne requis'), findsOneWidget);

      // Dictionnaire ➜ fiche.
      await tester.tap(find.text('Dictionnaire'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'merci');
      await tester.pumpAndSettle();
      await tester.tap(find.text('MERCI').first);
      await tester.pumpAndSettle();
      expect(find.byType(SignDetailScreen), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Paramètres du geste'), 300,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('Paramètres du geste'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Profil ➜ préférences, historique, notifications.
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Préférences'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Texte affiché'));
      await tester.pumpAndSettle();
      expect(AppPreferences.instance.responseFormat, 'text');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Historique'));
      await tester.pumpAndSettle();
      expect(find.text('Bonjour merci'), findsOneWidget);
    });
  }

  testWidgets('L’interface en anglais s’affiche sans débordement',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'user_test_com.preferences_completed': true,
      'user_test_com.written_language': 'English',
    });
    await tester.pumpWidget(const MaterialApp(
        home: UserDashboard(email: 'user@test.com', name: 'Jean')));
    await tester.pumpAndSettle();
    expect(find.text('I sign'), findsOneWidget);
    for (final tab in ['Translate', 'Dictionary', 'Profile', 'Home']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Translate').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Group'));
    await tester.pumpAndSettle();
    expect(find.text('Online account required'), findsOneWidget);
  });
}

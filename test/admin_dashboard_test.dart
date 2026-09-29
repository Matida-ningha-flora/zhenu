import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhendu_app/data/services/sign_repository.dart';
import 'package:zhendu_app/presentation/screens/admin_dashboard.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpAdmin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        const MaterialApp(home: AdminDashboard(email: 'admin@test.com')));
    await tester.pumpAndSettle();
  }

  testWidgets('Valider une proposition la publie dans le dictionnaire',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      SignRepository.communityKey: jsonEncode([
        {
          'id': 'p1',
          'word': 'MOTOTAXI',
          'category': 'Transport & Lieux',
          'description': 'Poings sur le guidon.',
          'status': 'En attente',
        }
      ]),
    });
    await pumpAdmin(tester);

    await tester.tap(find.text('Signes').first);
    await tester.pumpAndSettle();
    expect(find.text('MOTOTAXI'), findsOneWidget);
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    final official = await SignRepository.officialSigns();
    expect(SignRepository.findByWord(official, 'mototaxi'), isNotNull);
    expect(find.text('Tout est traité'), findsOneWidget);
  });

  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets(
        'Toutes les sections admin s’affichent (${size.width.toInt()} px)',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
          const MaterialApp(home: AdminDashboard(email: 'admin@test.com')));
      await tester.pumpAndSettle();
      for (final section in [
        'Signes',
        'Comptes',
        'Avatars',
        'Système',
        'Aperçu'
      ]) {
        await tester.tap(find.text(section).last);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Avatars').last);
      await tester.pumpAndSettle();
      expect(find.text('Nouvel avatar'), findsOneWidget);
      await tester.tap(find.text('Comptes').last);
      await tester.pumpAndSettle();
      expect(find.text('Administrateur Démo (vous)'), findsOneWidget);
    });
  }
}

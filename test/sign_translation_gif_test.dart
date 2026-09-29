import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhendu_app/presentation/widgets/sign_translation_gif.dart';

void main() {
  testWidgets('Un signe absent ne montre pas de média sans rapport',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SignTranslationGif(text: 'bonjour', variant: 'guide'),
      ),
    ));
    expect(find.text('Aucune animation disponible pour « bonjour ».'),
        findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SignTranslationGif(text: '', variant: 'female'),
      ),
    ));
    expect(find.text('En attente d’un signe'), findsOneWidget);
    expect(find.text('Aucune animation disponible pour « bonjour ».'),
        findsNothing);
  });
}

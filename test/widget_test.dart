import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zhendu_app/presentation/widgets/motion.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhendu_app/main.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    Motion.ambient = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Le démarrage mène à la page d’accueil sans mode urgence',
      (tester) async {
    await tester.pumpWidget(const NeuroSigneApp());
    expect(find.text('NeuroSigne'), findsOneWidget);
    expect(find.text('LA LANGUE DES SIGNES, POUR TOUS'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Signez, on vous entend'), findsOneWidget);
    expect(find.textContaining('rgence'), findsNothing);
  });
}

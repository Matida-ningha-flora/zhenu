// Rendu de l'avatar animé à partir de mouvements réels (fixtures extraites
// du serveur). Captures : --dart-define=SCREENSHOTS=true
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhendu_app/data/models/lsf_motion_synthesis.dart';
import 'package:zhendu_app/data/models/sign_motion.dart';
import 'package:zhendu_app/data/services/lsf_grammar.dart';
import 'package:zhendu_app/presentation/widgets/motion.dart';
import 'package:zhendu_app/presentation/widgets/sign_avatar.dart';

const _shots = bool.fromEnvironment('SCREENSHOTS');

SignMotion _load(String name) => SignMotion.fromJson(
    jsonDecode(File('test/fixtures/landmarks_$name.json').readAsStringSync())
        as Map<String, dynamic>);

void main() {
  setUp(() => Motion.ambient = false);

  test('les mains manquantes sont complétées et l’animation est continue', () {
    final motion = _load('merci');
    expect(motion.frames, isNotEmpty);
    expect(motion.frames.every((f) => f.pose != null), isTrue);
    expect(motion.frames.every((f) => f.face != null), isTrue);
    final mid = motion.frameAt(0.37);
    expect(mid.pose, hasLength(33));
    expect(motion.duration.inMilliseconds, greaterThan(1000));
  });

  for (final style in MotionStyle.values) {
    for (final sign in ['abeille', 'merci']) {
      testWidgets('rendu $style $sign', (tester) async {
        tester.view.physicalSize = const Size(900, 900);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetPhysicalSize);
        final key = GlobalKey();
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 300,
                  child: SignMotionPlayer(
                    motion: _load(sign),
                    style: style,
                    avatar: sign == 'merci' ? 'female' : 'guide',
                    height: 300,
                    playing: false,
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        if (!_shots) return;
        for (final t in [0.3, 0.6]) {
          final state = tester.state(find.byType(SignMotionPlayer));
          // ignore: invalid_use_of_protected_member
          (state as dynamic).setPositionForTesting(t);
          await tester.pump();
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            Directory('build/screenshots').createSync(recursive: true);
            File('build/screenshots/avatar_${style.name}_${sign}_$t.png')
                .writeAsBytesSync(data!.buffer.asUint8List());
          });
        }
      });
    }
  }

  // Pointages (pronoms) et expressions du visage construits par l'application.
  SignMotion neutralBased(String name) {
    final neutral = SignMotion.fromJson(
        jsonDecode(File('assets/lsf/neutral_frame.json').readAsStringSync())
            as Map<String, dynamic>);
    final base = neutral.frames.first;
    return switch (name) {
      'moi' => LsfMotionSynthesis.pointing(PointTarget.me, base),
      'toi' => LsfMotionSynthesis.pointing(PointTarget.you, base),
      'lui' => LsfMotionSynthesis.pointing(PointTarget.other, base),
      'question_oui_non' => LsfMotionSynthesis.express(
          LsfMotionSynthesis.pointing(PointTarget.you, base),
          LsfExpression.questionYesNo,
          false),
      'question_ou' => LsfMotionSynthesis.express(
          _load('merci'), LsfExpression.questionWh, false),
      _ => LsfMotionSynthesis.express(
          _load('merci'), LsfExpression.negation, true),
    };
  }

  for (final name in [
    'moi',
    'toi',
    'lui',
    'question_oui_non',
    'question_ou',
    'negation'
  ]) {
    testWidgets('synthèse $name', (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      final key = GlobalKey();
      final motion = neutralBased(name);
      expect(motion.frames.length, greaterThan(10));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 300,
                child: SignMotionPlayer(
                    motion: motion, height: 300, playing: false),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      if (!_shots) return;
      for (final t in [0.2, 0.5]) {
        final state = tester.state(find.byType(SignMotionPlayer));
        (state as dynamic).setPositionForTesting(t);
        await tester.pump();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory('build/screenshots').createSync(recursive: true);
          File('build/screenshots/synth_${name}_$t.png')
              .writeAsBytesSync(data!.buffer.asUint8List());
        });
      }
    });
  }
}

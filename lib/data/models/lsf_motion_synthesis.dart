import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../services/lsf_grammar.dart';
import 'sign_motion.dart';

/// Mouvements construits par l'application, en plus de ceux des vidéos :
/// - les pointages (pronoms MOI, TOI, LUI…), faits avec tout le bras ;
/// - les expressions du visage qui portent la grammaire de la phrase :
///   sourcils levés (question fermée), froncés (question ouverte),
///   tête qui fait « non » (négation).
class LsfMotionSynthesis {
  LsfMotionSynthesis._();

  static MotionFrame? _neutral;

  /// Posture de repos (bras le long du corps), tirée d'une vidéo réelle.
  static Future<MotionFrame> neutral() async {
    if (_neutral != null) return _neutral!;
    final raw = await rootBundle.loadString('assets/lsf/neutral_frame.json');
    return _neutral =
        SignMotion.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map))
            .frames
            .first;
  }

  static void setNeutralForTesting(MotionFrame frame) => _neutral = frame;

  // Indices MediaPipe du bras droit du signeur (à gauche de l'image).
  static const _elbow = 14;
  static const _wrist = 16;
  static const _pinky = 18;
  static const _index = 20;
  static const _thumb = 22;

  /// Pointage vers une personne : le bras monte, l'index désigne, puis le
  /// bras redescend. Les pluriels balaient l'espace.
  static SignMotion pointing(PointTarget target, MotionFrame base) {
    final pose = base.pose!;
    final shoulder = pose[12];
    final otherShoulder = pose[11];
    final width = (otherShoulder - shoulder).distance;
    final chest = Offset(
        (shoulder.dx + otherShoulder.dx) / 2, shoulder.dy + width * 0.35);

    // Positions clés (poignet, direction de l'index) exprimées par rapport
    // aux épaules, pour s'adapter à la taille du personnage.
    Offset at(double x, double y) =>
        Offset(shoulder.dx + x * width, shoulder.dy + y * width);
    final (List<Offset> wrists, List<Offset> directions) = switch (target) {
      PointTarget.me => (
          [chest + Offset(-width * 0.34, width * 0.14)],
          [const Offset(1, -0.35)]
        ),
      PointTarget.you => ([at(0.12, 0.45)], [const Offset(0.25, -1)]),
      PointTarget.other => ([at(-0.42, 0.42)], [const Offset(-1, -0.2)]),
      PointTarget.we => (
          [at(0.1, 0.42), at(0.3, 0.62)],
          [const Offset(0.2, -1), (chest - at(0.3, 0.62))]
        ),
      PointTarget.youPlural => (
          [at(-0.05, 0.45), at(0.55, 0.42)],
          [const Offset(-0.3, -1), const Offset(0.4, -1)]
        ),
      PointTarget.them => (
          [at(-0.35, 0.35), at(-0.45, 0.6)],
          [const Offset(-1, -0.35), const Offset(-1, 0.2)]
        ),
    };

    const frames = 20; // 12 images/s : environ 1,7 s
    const rise = 5;
    const fall = 5;
    final restWrist = pose[_wrist];
    final restElbow = pose[_elbow];
    final out = <MotionFrame>[];
    for (var f = 0; f < frames; f++) {
      // Montée, maintien (avec balayage pour les pluriels), descente.
      final double lift;
      if (f < rise) {
        lift = _ease(f / rise);
      } else if (f >= frames - fall) {
        lift = _ease((frames - 1 - f) / fall);
      } else {
        lift = 1;
      }
      final hold = ((f - rise) / (frames - rise - fall - 1)).clamp(0.0, 1.0);
      final sweep = wrists.length == 1 ? 0.0 : _ease(hold);
      final targetWrist = wrists.length == 1
          ? wrists.first
          : Offset.lerp(wrists.first, wrists.last, sweep)!;
      final targetDir = _unit(directions.length == 1
          ? directions.first
          : Offset.lerp(
              _unit(directions.first), _unit(directions.last), sweep)!);

      final wrist = Offset.lerp(restWrist, targetWrist, lift)!;
      // Coude : entre l'épaule et le poignet, un peu vers l'extérieur.
      final elbowTarget = Offset(
          (shoulder.dx + targetWrist.dx) / 2 - width * 0.16,
          max(shoulder.dy + width * 0.55, targetWrist.dy + width * 0.2));
      final elbow = Offset.lerp(restElbow, elbowTarget, lift)!;
      final dir = _unit(Offset.lerp(const Offset(0, 1), targetDir, lift)!);
      final hand = _pointingHand(wrist, dir, width * 0.34);

      final newPose = List<Offset>.of(pose);
      newPose[_elbow] = elbow;
      newPose[_wrist] = wrist;
      newPose[_index] = hand[6];
      newPose[_pinky] = hand[17];
      newPose[_thumb] = hand[3];
      out.add(MotionFrame(
        pose: newPose,
        face: base.face,
        left: null,
        right: hand,
      ));
    }
    return SignMotion(
        sign: LsfGrammar.pointGloss[target]!.toUpperCase(),
        fps: 12,
        frames: out);
  }

  /// Posture d'attente : l'avatar respire, corps entier visible.
  static SignMotion idle(MotionFrame base) {
    const count = 36; // 3 s à 12 images/s
    final frames = <MotionFrame>[];
    for (var f = 0; f < count; f++) {
      final phase = sin(f / count * 2 * pi);
      final breath = Offset(0, phase * 0.004);
      final sway = Offset(sin(f / count * 2 * pi + 1) * 0.003, 0);
      final pose = base.pose!;
      frames.add(MotionFrame(
        pose: [
          for (var k = 0; k < pose.length; k++)
            k <= 12 ? pose[k] + breath + sway : pose[k] + breath * 0.5
        ],
        face: base.face?.map((key, points) =>
            MapEntry(key, [for (final p in points) p + breath + sway])),
      ));
    }
    return SignMotion(sign: 'ATTENTE', fps: 12, frames: frames);
  }

  static double _ease(double t) {
    final x = t.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  static Offset _unit(Offset v) {
    final d = v.distance;
    return d == 0 ? const Offset(0, 1) : v / d;
  }

  /// Main fermée, index tendu dans la direction [d] (21 points MediaPipe).
  static List<Offset> _pointingHand(Offset w, Offset d, double length) {
    final n = Offset(-d.dy, d.dx); // travers de la main
    Offset p(double along, double across) =>
        w + d * (along * length) + n * (across * length);
    return [
      w, // 0 poignet
      // Pouce replié sur les doigts.
      p(0.15, 0.2), p(0.3, 0.3), p(0.42, 0.26), p(0.5, 0.14),
      // Index tendu.
      p(0.45, 0.1), p(0.7, 0.1), p(0.88, 0.1), p(1.05, 0.1),
      // Majeur, annulaire, auriculaire repliés.
      p(0.45, -0.04), p(0.58, -0.02), p(0.5, 0.02), p(0.4, 0.02),
      p(0.42, -0.16), p(0.54, -0.14), p(0.47, -0.1), p(0.38, -0.09),
      p(0.37, -0.27), p(0.47, -0.25), p(0.42, -0.21), p(0.34, -0.19),
    ];
  }

  /// Ajoute l'expression de la phrase au mouvement d'un signe.
  static SignMotion express(
      SignMotion motion, LsfExpression expression, bool negated) {
    if (expression == LsfExpression.neutral && !negated) return motion;
    final count = motion.frames.length;
    final frames = <MotionFrame>[];
    for (var i = 0; i < count; i++) {
      final frame = motion.frames[i];
      final face = frame.face;
      final oval = face?['oval'];
      if (face == null || oval == null || oval.length < 19) {
        frames.add(frame);
        continue;
      }
      final t = count <= 1 ? 0.0 : i / (count - 1);
      final faceHeight = (oval[0] - oval[18]).distance;
      final center = oval.reduce((a, b) => a + b) / oval.length.toDouble();
      // Mise en place de l'expression au début du signe.
      final strength = _ease(t * 5);

      Offset brow(Offset point) => switch (expression) {
            LsfExpression.questionYesNo =>
              point + Offset(0, -faceHeight * 0.14 * strength),
            LsfExpression.questionWh => Offset(
                point.dx + (center.dx - point.dx) * 0.14 * strength,
                point.dy + faceHeight * 0.045 * strength),
            _ => point,
          };
      // « Non » de la tête : deux allers-retours et demi par signe.
      final shake = negated
          ? Offset(sin(t * pi * 2 * 2.5) * faceHeight * 0.1 * strength, 0)
          : Offset.zero;

      final newFace = <String, List<Offset>>{
        for (final entry in face.entries)
          entry.key: [
            for (final point in entry.value)
              (entry.key.endsWith('Brow') ? brow(point) : point) + shake
          ]
      };
      final pose = frame.pose;
      frames.add(frame.copyWith(
        face: newFace,
        pose: pose == null || shake == Offset.zero
            ? pose
            : [
                for (var k = 0; k < pose.length; k++)
                  k <= 10 ? pose[k] + shake : pose[k]
              ],
      ));
    }
    return SignMotion(sign: motion.sign, fps: motion.fps, frames: frames);
  }
}

import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/sign_motion.dart';
import 'motion.dart';

/// Apparence de l'avatar signant, selon le style choisi dans les préférences.
class AvatarLook {
  final Color skin;
  final Color skinShade;
  final Color outfit;
  final Color outfitShade;
  final Color hair;
  final Color lips;
  final bool longHair;
  final Color background;

  const AvatarLook({
    required this.skin,
    required this.skinShade,
    required this.outfit,
    required this.outfitShade,
    required this.hair,
    required this.lips,
    this.longHair = false,
    this.background = const Color(0xFFF3E6D8),
  });

  static const _looks = {
    'guide': AvatarLook(
      skin: Color(0xFF8D5A3B),
      skinShade: Color(0xFF6B4029),
      outfit: Color(0xFF2B2F3A),
      outfitShade: Color(0xFF1C1F27),
      hair: Color(0xFF1A1411),
      lips: Color(0xFF7A3E34),
    ),
    'female': AvatarLook(
      skin: Color(0xFF9C6644),
      skinShade: Color(0xFF7A4B30),
      outfit: Color(0xFF8C2F39),
      outfitShade: Color(0xFF6B2029),
      hair: Color(0xFF221610),
      lips: Color(0xFF9E3D46),
      longHair: true,
    ),
    'male': AvatarLook(
      skin: Color(0xFF6B4226),
      skinShade: Color(0xFF4F2F1A),
      outfit: Color(0xFF1F2A44),
      outfitShade: Color(0xFF151D30),
      hair: Color(0xFF111111),
      lips: Color(0xFF5E3024),
    ),
    'neutral': AvatarLook(
      skin: Color(0xFFC68642),
      skinShade: Color(0xFFA06A30),
      outfit: Color(0xFF3D5A5B),
      outfitShade: Color(0xFF2A4041),
      hair: Color(0xFF3B2A20),
      lips: Color(0xFF9A5A45),
    ),
    'illustrated': AvatarLook(
      skin: Color(0xFFE0AC69),
      skinShade: Color(0xFFBF8A4E),
      outfit: AppColors.primary,
      outfitShade: AppColors.primaryDeep,
      hair: Color(0xFF4A2E1A),
      lips: Color(0xFFB0574A),
      longHair: true,
    ),
  };

  static AvatarLook of(String id) => _looks[id] ?? _looks['guide']!;
}

enum MotionStyle { avatar, skeleton }

/// Rejoue le mouvement d'un signe en boucle.
class SignMotionPlayer extends StatefulWidget {
  final SignMotion motion;
  final MotionStyle style;
  final String avatar;
  final double height;
  final bool playing;

  /// Appelé à la fin de chaque répétition (enchaînement des signes).
  final VoidCallback? onCycle;

  const SignMotionPlayer({
    super.key,
    required this.motion,
    this.style = MotionStyle.avatar,
    this.avatar = 'guide',
    this.height = 240,
    this.playing = true,
    this.onCycle,
  });

  @override
  State<SignMotionPlayer> createState() => _SignMotionPlayerState();
}

class _SignMotionPlayerState extends State<SignMotionPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  )..addStatusListener(_onStatus);

  Duration get _duration {
    final d = widget.motion.duration;
    return d < const Duration(milliseconds: 600)
        ? const Duration(milliseconds: 600)
        : d;
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    widget.onCycle?.call();
    if (mounted && widget.playing && Motion.ambient) {
      _controller.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant SignMotionPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.motion != widget.motion) {
      _controller.duration = _duration;
      _controller.forward(from: 0);
    }
    _sync();
  }

  void _sync() {
    if (Motion.reduced(context)) {
      _controller.value = 0.5; // image fixe au milieu du geste
      return;
    }
    if (widget.playing && !_controller.isAnimating) {
      _controller.forward(from: _controller.value >= 1 ? 0 : _controller.value);
    } else if (!widget.playing) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Position de l'animation (0 à 1), pour les tests et captures.
  @visibleForTesting
  void setPositionForTesting(double t) => _controller.value = t;

  @override
  Widget build(BuildContext context) {
    final look = AvatarLook.of(widget.avatar);
    final skeleton = widget.style == MotionStyle.skeleton;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: skeleton
              ? const LinearGradient(
                  colors: [Color(0xFF1A1310), Color(0xFF2C221F)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter)
              : LinearGradient(colors: [
                  look.background,
                  Color.lerp(look.background, AppColors.secondarySoft, 0.6)!
                ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: skeleton
                ? _SkeletonPainter(widget.motion.frameAt(_controller.value))
                : _AvatarPainter(
                    widget.motion.frameAt(_controller.value), look),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

/// Transforme les coordonnées normalisées (carré 0–1) vers la zone de dessin.
class _Space {
  final Rect box;
  _Space(Size size)
      : box = Rect.fromCenter(
          center: size.center(Offset.zero),
          width: min(size.width, size.height * 1.05),
          height: min(size.width, size.height * 1.05),
        );

  Offset map(Offset p) =>
      Offset(box.left + p.dx * box.width, box.top + p.dy * box.height);

  double scale(double v) => v * box.width;
}

// Connexions MediaPipe.
const _handBones = [
  [0, 1, 2, 3, 4],
  [0, 5, 6, 7, 8],
  [5, 9, 10, 11, 12],
  [9, 13, 14, 15, 16],
  [13, 17, 18, 19, 20],
  [0, 17],
];
const _poseBones = [
  [11, 12],
  [11, 13],
  [13, 15],
  [12, 14],
  [14, 16],
  [11, 23],
  [12, 24],
  [23, 24],
  [15, 17],
  [15, 19],
  [15, 21],
  [16, 18],
  [16, 20],
  [16, 22],
];

/// Associe chaque main détectée au poignet le plus proche (le libellé
/// gauche/droite de MediaPipe dépend du sens de l'image).
({List<Offset>? a, List<Offset>? b}) _handsByWrist(MotionFrame f) {
  final pose = f.pose;
  if (pose == null) return (a: f.left, b: f.right);
  final wristA = pose[15];
  final wristB = pose[16];
  List<Offset>? forA;
  List<Offset>? forB;
  for (final hand in [f.left, f.right]) {
    if (hand == null) continue;
    final dA = (hand[0] - wristA).distance;
    final dB = (hand[0] - wristB).distance;
    if (dA <= dB && forA == null) {
      forA = hand;
    } else if (forB == null) {
      forB = hand;
    } else {
      forA ??= hand;
    }
  }
  return (a: forA, b: forB);
}

class _AvatarPainter extends CustomPainter {
  final MotionFrame frame;
  final AvatarLook look;

  _AvatarPainter(this.frame, this.look);

  @override
  void paint(Canvas canvas, Size size) {
    final pose = frame.pose;
    if (pose == null) return;
    final s = _Space(size);
    Offset p(int i) => s.map(pose[i]);

    final ls = p(11);
    final rs = p(12);
    final shoulderWidth = (ls - rs).distance;
    final unit = max(shoulderWidth, s.scale(0.18));
    final fill = Paint()..isAntiAlias = true;
    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final face = frame.face;
    final oval = face?['oval'];
    final faceCenter = oval != null && oval.isNotEmpty
        ? s.map(oval.reduce((a, b) => a + b) / oval.length.toDouble())
        : p(0);
    final faceHeight = oval != null && oval.length > 18
        ? (s.map(oval[0]) - s.map(oval[18])).distance
        : unit * 0.62;

    // Cheveux longs (derrière la tête et les épaules).
    if (look.longHair) {
      final rect = Rect.fromCenter(
          center: faceCenter + Offset(0, faceHeight * 0.35),
          width: faceHeight * 1.05,
          height: faceHeight * 1.5);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(faceHeight * 0.45)),
          fill..color = look.hair);
    }

    // Buste : épaules arrondies qui montent jusqu'à la base du cou.
    final bottom = size.height + 4;
    final mid = (ls + rs) / 2;
    final neckBase = mid.dy - unit * 0.2;
    final torso = Path()
      ..moveTo(rs.dx - unit * 0.1, rs.dy + unit * 0.1)
      ..quadraticBezierTo(rs.dx - unit * 0.06, rs.dy - unit * 0.14,
          mid.dx - unit * 0.24, neckBase + unit * 0.02)
      ..lineTo(mid.dx + unit * 0.24, neckBase + unit * 0.02)
      ..quadraticBezierTo(ls.dx + unit * 0.06, ls.dy - unit * 0.14,
          ls.dx + unit * 0.1, ls.dy + unit * 0.1)
      ..lineTo(ls.dx + unit * 0.16, bottom)
      ..lineTo(rs.dx - unit * 0.16, bottom)
      ..close();
    // Cou.
    final chin = oval != null && oval.length > 18 ? s.map(oval[18]) : p(0);
    final neckWidth = unit * 0.28;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(mid.dx - neckWidth / 2, chin.dy - faceHeight * 0.12,
                mid.dx + neckWidth / 2, neckBase + unit * 0.12),
            Radius.circular(neckWidth * 0.3)),
        fill..color = look.skinShade);
    canvas.drawPath(torso, fill..color = look.outfit);
    // Col en V.
    canvas.drawPath(
        Path()
          ..moveTo(mid.dx - neckWidth * 0.5, neckBase)
          ..lineTo(mid.dx, neckBase + unit * 0.24)
          ..lineTo(mid.dx + neckWidth * 0.5, neckBase)
          ..close(),
        fill..color = look.skinShade);

    // Tête.
    if (oval != null && oval.length > 2) {
      final head = Path()..addPolygon(oval.map(s.map).toList(), true);
      // Cheveux : calotte au-dessus du front.
      final top = s.map(oval[0]);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(faceCenter.dx, top.dy + faceHeight * 0.16),
              width: faceHeight * 0.98,
              height: faceHeight * 0.62),
          fill..color = look.hair);
      canvas.drawPath(head, fill..color = look.skin);
      // Oreilles.
      final leftEar = s.map(oval[9]);
      final rightEar = s.map(oval[27]);
      for (final ear in [leftEar, rightEar]) {
        canvas.drawOval(
            Rect.fromCenter(
                center: ear,
                width: faceHeight * 0.1,
                height: faceHeight * 0.18),
            fill..color = look.skinShade);
      }
      // Traits du visage (les expressions font partie de la LSF).
      for (final brow in ['leftBrow', 'rightBrow']) {
        final pts = face![brow];
        if (pts != null && pts.length >= 5) {
          final path = Path()..moveTo(s.map(pts[0]).dx, s.map(pts[0]).dy);
          for (final q in pts.sublist(1, 5)) {
            final m = s.map(q);
            path.lineTo(m.dx, m.dy);
          }
          canvas.drawPath(path, stroke(look.hair, faceHeight * 0.045));
        }
      }
      for (final eye in ['leftEye', 'rightEye']) {
        final pts = face![eye];
        if (pts != null && pts.length > 3) {
          final path = Path()..addPolygon(pts.map(s.map).toList(), true);
          canvas.drawPath(path, fill..color = Colors.white);
          final c = s.map(pts.reduce((a, b) => a + b) / pts.length.toDouble());
          final bounds = path.getBounds();
          canvas.save();
          canvas.clipPath(path);
          canvas.drawCircle(c, max(bounds.height * 0.62, faceHeight * 0.03),
              fill..color = const Color(0xFF2B1A12));
          canvas.restore();
          canvas.drawPath(path, stroke(look.skinShade, faceHeight * 0.012));
        }
      }
      final lipsOuter = face!['lipsOuter'];
      final lipsInner = face['lipsInner'];
      if (lipsOuter != null && lipsOuter.length > 3) {
        canvas.drawPath(Path()..addPolygon(lipsOuter.map(s.map).toList(), true),
            fill..color = look.lips);
      }
      if (lipsInner != null && lipsInner.length > 3) {
        canvas.drawPath(Path()..addPolygon(lipsInner.map(s.map).toList(), true),
            fill..color = const Color(0xFF3B1A12));
      }
    } else {
      canvas.drawCircle(p(0), unit * 0.28, fill..color = look.skin);
    }

    // Bras (manches), puis mains par-dessus.
    final hands = _handsByWrist(frame);
    final sleeve = unit * 0.17;
    for (final side in [
      (
        shoulder: 11,
        elbow: 13,
        wrist: 15,
        hand: hands.a,
        index: 19,
        pinky: 17,
        thumb: 21
      ),
      (
        shoulder: 12,
        elbow: 14,
        wrist: 16,
        hand: hands.b,
        index: 20,
        pinky: 18,
        thumb: 22
      ),
    ]) {
      final arm = Path()
        ..moveTo(p(side.shoulder).dx, p(side.shoulder).dy)
        ..lineTo(p(side.elbow).dx, p(side.elbow).dy)
        ..lineTo(p(side.wrist).dx, p(side.wrist).dy);
      canvas.drawPath(arm, stroke(look.outfitShade, sleeve * 1.12));
      canvas.drawPath(arm, stroke(look.outfit, sleeve));
      // Poignet de chemise.
      canvas.drawCircle(p(side.wrist), sleeve * 0.34,
          fill..color = Colors.white.withValues(alpha: 0.9));

      final hand = side.hand;
      if (hand != null && hand.length == 21) {
        _drawHand(canvas, hand.map(s.map).toList(), look);
      } else {
        // Main reconstruite à partir des repères du corps.
        final w = p(side.wrist);
        final i = p(side.index);
        final k = p(side.pinky);
        final t = p(side.thumb);
        final palm = Path()..addPolygon([w, i, k], true);
        final size = max((i - w).distance, unit * 0.12);
        canvas.drawPath(palm, stroke(look.skinShade, size * 0.55));
        canvas.drawPath(palm, fill..color = look.skin);
        canvas.drawPath(palm, stroke(look.skin, size * 0.45));
        canvas.drawLine(w, t, stroke(look.skin, size * 0.3));
      }
    }
  }

  void _drawHand(Canvas canvas, List<Offset> h, AvatarLook look) {
    final handSize = max((h[0] - h[9]).distance, 6.0);
    final width = handSize * 0.26;
    final palm = Path()
      ..addPolygon([h[0], h[1], h[5], h[9], h[13], h[17]], true);
    final outline = Paint()
      ..color = look.skinShade
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 1.25
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final skin = Paint()
      ..color = look.skin
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Path chain(List<int> ids) {
      final path = Path()..moveTo(h[ids.first].dx, h[ids.first].dy);
      for (final id in ids.skip(1)) {
        path.lineTo(h[id].dx, h[id].dy);
      }
      return path;
    }

    canvas.drawPath(palm, outline);
    for (final bone in _handBones) {
      canvas.drawPath(chain(bone), outline);
    }
    canvas.drawPath(palm, Paint()..color = look.skin);
    canvas.drawPath(palm, skin);
    for (final bone in _handBones) {
      canvas.drawPath(chain(bone), skin);
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter old) =>
      old.frame != frame || old.look != look;
}

class _SkeletonPainter extends CustomPainter {
  final MotionFrame frame;
  _SkeletonPainter(this.frame);

  @override
  void paint(Canvas canvas, Size size) {
    final s = _Space(size);
    final bone = Paint()
      ..color = AppColors.primary
      ..strokeWidth = s.scale(0.012)
      ..strokeCap = StrokeCap.round;
    final joint = Paint()..color = AppColors.secondary;
    final pose = frame.pose;
    if (pose != null) {
      for (final b in _poseBones) {
        canvas.drawLine(s.map(pose[b[0]]), s.map(pose[b[1]]), bone);
      }
      for (final i in [11, 12, 13, 14, 15, 16, 23, 24]) {
        canvas.drawCircle(s.map(pose[i]), s.scale(0.012), joint);
      }
    }
    final face = frame.face;
    if (face != null) {
      final line = Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.scale(0.005);
      for (final part in face.values) {
        if (part.length > 2) {
          canvas.drawPath(
              Path()..addPolygon(part.map(s.map).toList(), true), line);
        }
      }
    }
    final handBone = Paint()
      ..color = AppColors.secondary
      ..strokeWidth = s.scale(0.007)
      ..strokeCap = StrokeCap.round;
    final tip = Paint()..color = Colors.white;
    for (final hand in [frame.left, frame.right]) {
      if (hand == null || hand.length != 21) continue;
      for (final chain in _handBones) {
        for (var i = 0; i < chain.length - 1; i++) {
          canvas.drawLine(
              s.map(hand[chain[i]]), s.map(hand[chain[i + 1]]), handBone);
        }
      }
      for (final pt in hand) {
        canvas.drawCircle(s.map(pt), s.scale(0.006), tip);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SkeletonPainter old) => old.frame != frame;
}

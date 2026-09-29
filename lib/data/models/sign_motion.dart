import 'dart:ui';

/// Une image d'un signe : positions normalisées (0 à 1) du corps, du visage
/// et des mains, extraites par MediaPipe (`GET /media/landmarks/{signe}`).
class MotionFrame {
  final List<Offset>? pose; // 33 points
  final Map<String, List<Offset>>? face; // contours (ovale, yeux, bouche…)
  final List<Offset>? left; // 21 points
  final List<Offset>? right; // 21 points

  const MotionFrame({this.pose, this.face, this.left, this.right});

  static List<Offset>? _points(Object? raw) => raw is List
      ? raw
          .map((p) => Offset(
              ((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()))
          .toList()
      : null;

  factory MotionFrame.fromJson(Map<String, dynamic> json) => MotionFrame(
        pose: _points(json['pose']),
        face: json['face'] is Map
            ? (json['face'] as Map).map((k, v) =>
                MapEntry(k.toString(), _points(v) ?? const <Offset>[]))
            : null,
        left: _points(json['left']),
        right: _points(json['right']),
      );

  MotionFrame copyWith({
    List<Offset>? pose,
    Map<String, List<Offset>>? face,
    List<Offset>? left,
    List<Offset>? right,
  }) =>
      MotionFrame(
        pose: pose ?? this.pose,
        face: face ?? this.face,
        left: left ?? this.left,
        right: right ?? this.right,
      );
}

/// Mouvement complet d'un signe, prêt à être rejoué par l'avatar.
class SignMotion {
  final String sign;
  final double fps;
  final List<MotionFrame> frames;

  SignMotion({required this.sign, required this.fps, required this.frames});

  Duration get duration => Duration(
      milliseconds: (frames.length / (fps <= 0 ? 12 : fps) * 1000).round());

  factory SignMotion.fromJson(Map<String, dynamic> json) {
    final frames = ((json['frames'] as List?) ?? const [])
        .map((f) => MotionFrame.fromJson(Map<String, dynamic>.from(f as Map)))
        .toList();
    return SignMotion(
      sign: json['sign'] as String? ?? '',
      fps: (json['fps'] as num?)?.toDouble() ?? 12,
      frames: _fillGaps(frames),
    );
  }

  /// Complète les images où une partie n'a pas été détectée :
  /// - mains : interpolation entre deux images proches, sinon laissée vide
  ///   (l'avatar la reconstruit alors à partir du bras) ;
  /// - corps et visage : image connue la plus proche.
  static List<MotionFrame> _fillGaps(List<MotionFrame> frames) {
    if (frames.isEmpty) return frames;
    final out = List<MotionFrame>.of(frames);

    List<Offset>? nearest(List<Offset>? Function(MotionFrame) get, int i) {
      for (var d = 1; d < out.length; d++) {
        if (i - d >= 0 && get(frames[i - d]) != null) return get(frames[i - d]);
        if (i + d < out.length && get(frames[i + d]) != null) {
          return get(frames[i + d]);
        }
      }
      return null;
    }

    Map<String, List<Offset>>? nearestFace(int i) {
      for (var d = 1; d < out.length; d++) {
        if (i - d >= 0 && frames[i - d].face != null) return frames[i - d].face;
        if (i + d < out.length && frames[i + d].face != null) {
          return frames[i + d].face;
        }
      }
      return null;
    }

    List<Offset>? bridge(List<Offset>? Function(MotionFrame) get, int i) {
      int? before;
      int? after;
      for (var j = i - 1; j >= 0 && i - j <= 8; j--) {
        if (get(frames[j]) != null) {
          before = j;
          break;
        }
      }
      for (var j = i + 1; j < frames.length && j - i <= 8; j++) {
        if (get(frames[j]) != null) {
          after = j;
          break;
        }
      }
      if (before == null || after == null) return null;
      final t = (i - before) / (after - before);
      final a = get(frames[before])!;
      final b = get(frames[after])!;
      return [for (var k = 0; k < a.length; k++) Offset.lerp(a[k], b[k], t)!];
    }

    for (var i = 0; i < out.length; i++) {
      final f = frames[i];
      out[i] = MotionFrame(
        pose: f.pose ?? nearest((x) => x.pose, i),
        face: f.face ?? nearestFace(i),
        left: f.left ?? bridge((x) => x.left, i),
        right: f.right ?? bridge((x) => x.right, i),
      );
    }
    return out;
  }

  /// Image à la position [t] (0 à 1), interpolée entre deux images
  /// successives pour une animation fluide.
  MotionFrame frameAt(double t) {
    if (frames.length == 1) return frames.first;
    final position = (t.clamp(0.0, 1.0)) * (frames.length - 1);
    final i = position.floor().clamp(0, frames.length - 1);
    final j = (i + 1).clamp(0, frames.length - 1);
    final k = position - i;
    final a = frames[i];
    final b = frames[j];

    List<Offset>? mix(List<Offset>? p, List<Offset>? q) {
      if (p == null) return q == null ? null : (k > 0.5 ? q : null);
      if (q == null || q.length != p.length) return k < 0.5 ? p : q;
      return [for (var n = 0; n < p.length; n++) Offset.lerp(p[n], q[n], k)!];
    }

    Map<String, List<Offset>>? mixFace() {
      final p = a.face;
      final q = b.face;
      if (p == null || q == null) return p ?? q;
      return {
        for (final key in p.keys)
          key: mix(p[key], q[key]) ?? p[key] ?? const [],
      };
    }

    return MotionFrame(
      pose: mix(a.pose, b.pose),
      face: mixFace(),
      left: mix(a.left, b.left),
      right: mix(a.right, b.right),
    );
  }
}

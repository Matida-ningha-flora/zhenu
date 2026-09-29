import 'dart:math';

import 'package:flutter/material.dart';

/// Animations de l'interface NeuroSigne.
///
/// Toutes respectent le réglage système « réduire les animations »
/// (MediaQuery.disableAnimations). Les animations continues (respiration,
/// flottement, fond animé) peuvent aussi être coupées via [Motion.ambient],
/// par exemple pour les tests.
class Motion {
  static bool ambient = true;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static bool continuous(BuildContext context) => ambient && !reduced(context);
}

/// Apparition en fondu avec léger glissement vers le haut, après [delay].
/// Utilisé en cascade pour faire entrer les éléments d'un écran.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
    this.offset = 18,
  });

  /// Délai d'un élément dans une cascade.
  static Duration stagger(int index, {int stepMs = 70, int startMs = 0}) =>
      Duration(milliseconds: startMs + index * stepMs);

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  // Le délai fait partie de l'animation (intervalle de départ) : pas de
  // minuterie séparée qui survivrait à l'écran.
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: widget.delay + widget.duration);
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.inMicroseconds /
          (widget.delay + widget.duration).inMicroseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _curve,
        child: widget.child,
        builder: (context, child) => Opacity(
          opacity: _curve.value,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - _curve.value)),
            child: child,
          ),
        ),
      );
}

/// Pulsation douce et continue (logo « qui respire »).
class Breathing extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration period;

  const Breathing({
    super.key,
    required this.child,
    this.amplitude = 0.05,
    this.period = const Duration(seconds: 2),
  });

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.continuous(context)) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: Tween(begin: 1 - widget.amplitude, end: 1 + widget.amplitude)
            .animate(
                CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
        child: widget.child,
      );
}

/// Flottement vertical lent (illustrations).
class Floating extends StatefulWidget {
  final Widget child;
  final double distance;
  final Duration period;

  const Floating({
    super.key,
    required this.child,
    this.distance = 8,
    this.period = const Duration(milliseconds: 3200),
  });

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.continuous(context)) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0,
              -widget.distance * Curves.easeInOut.transform(_controller.value)),
          child: child,
        ),
      );
}

/// Léger enfoncement au toucher, pour les cartes et boutons cliquables.
class PressableScale extends StatefulWidget {
  final Widget child;
  final double pressedScale;

  const PressableScale(
      {super.key, required this.child, this.pressedScale = 0.97});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedScale(
          scale: _pressed && !Motion.reduced(context) ? widget.pressedScale : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

/// Taches de couleur floues qui dérivent lentement en arrière-plan
/// (écran de lancement, page d'accueil, connexion).
class AmbientBlobs extends StatefulWidget {
  final List<Color> colors;

  /// Décalage des taches (change à chaque page de l'accueil).
  final int phase;
  final double opacity;

  const AmbientBlobs({
    super.key,
    required this.colors,
    this.phase = 0,
    this.opacity = 0.35,
  });

  @override
  State<AmbientBlobs> createState() => _AmbientBlobsState();
}

class _AmbientBlobsState extends State<AmbientBlobs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift =
      AnimationController(vsync: this, duration: const Duration(seconds: 14));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.continuous(context)) {
      if (!_drift.isAnimating) _drift.repeat();
    } else {
      _drift.stop();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  // Positions de base (fractions de l'écran) selon la page affichée.
  static const _anchors = [
    [Offset(0.95, 0.02), Offset(0.02, 0.92), Offset(0.15, 0.30)],
    [Offset(0.10, 0.05), Offset(0.95, 0.80), Offset(0.80, 0.35)],
    [Offset(0.85, 0.20), Offset(0.10, 0.70), Offset(0.50, 0.02)],
    [Offset(0.30, 0.00), Offset(0.90, 0.95), Offset(0.00, 0.50)],
  ];

  @override
  Widget build(BuildContext context) {
    final anchors = _anchors[widget.phase % _anchors.length];
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      final diameter = size.shortestSide * 0.95;
      return AnimatedBuilder(
        animation: _drift,
        builder: (context, _) => Stack(children: [
          for (var i = 0; i < widget.colors.length && i < anchors.length; i++)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOutCubic,
              left: anchors[i].dx * size.width -
                  diameter / 2 +
                  sin(_drift.value * 2 * pi + i * 2.1) * 24,
              top: anchors[i].dy * size.height -
                  diameter / 2 +
                  cos(_drift.value * 2 * pi + i * 1.3) * 24,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 900),
                  width: diameter,
                  height: diameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      widget.colors[i].withValues(alpha: widget.opacity),
                      widget.colors[i].withValues(alpha: 0),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      );
    });
  }
}

/// Onde sonore animée pendant l'écoute du micro.
class SoundWave extends StatefulWidget {
  final bool active;
  final Color color;
  final double height;

  /// Niveau sonore (0 à 1) : amplifie l'onde quand l'utilisateur parle.
  final double level;

  const SoundWave({
    super.key,
    required this.active,
    required this.color,
    this.height = 36,
    this.level = 0.5,
  });

  @override
  State<SoundWave> createState() => _SoundWaveState();
}

class _SoundWaveState extends State<SoundWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  void _sync() {
    if (widget.active && !Motion.reduced(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant SoundWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: widget.height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _WavePainter(
              t: _controller.value,
              color: widget.color,
              level: widget.active ? widget.level.clamp(0.25, 1.0) : 0.08,
            ),
          ),
        ),
      );
}

class _WavePainter extends CustomPainter {
  final double t;
  final Color color;
  final double level;

  _WavePainter({required this.t, required this.color, required this.level});

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 23;
    final gap = size.width / bars;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = min(4.0, gap * 0.55);
    for (var i = 0; i < bars; i++) {
      final center = 1 - (i - bars / 2).abs() / (bars / 2);
      final wave = (sin((t * 2 * pi) + i * 0.7) + 1) / 2;
      final h = max(3.0,
          size.height * level * (0.25 + 0.75 * wave) * (0.4 + 0.6 * center));
      final x = gap * (i + 0.5);
      canvas.drawLine(Offset(x, size.height / 2 - h / 2),
          Offset(x, size.height / 2 + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.t != t || old.level != level || old.color != color;
}

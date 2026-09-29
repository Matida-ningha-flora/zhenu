import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

import '../../core/l10n/tr.dart';
import '../../core/preferences/app_preferences.dart';
import '../../data/services/sign_media_service.dart';
import '../../data/services/sign_repository.dart';
import '../../data/models/lsf_motion_synthesis.dart';
import '../../data/models/sign_motion.dart';
import '../../data/services/lsf_grammar.dart';
import 'sign_avatar.dart';

/// Affiche un texte en LSF, signe par signe, dans le mode de réception choisi
/// par l'utilisateur : avatar animé, vidéo (GIF d'interprète), landmarks ou
/// texte descriptif.
class LsfRenderer extends StatefulWidget {
  final String text;

  /// `avatar`, `video`, `landmarks` ou `text`. Par défaut : la préférence
  /// de l'utilisateur.
  final String? format;
  final bool autoplay;
  final double stageHeight;

  /// Version réduite (conversation) : sans la liste des signes.
  final bool compact;

  const LsfRenderer({
    super.key,
    required this.text,
    this.format,
    this.autoplay = true,
    this.stageHeight = 240,
    this.compact = false,
  });

  @override
  State<LsfRenderer> createState() => _LsfRendererState();
}

class _LsfRendererState extends State<LsfRenderer> {
  List<SignToken> _tokens = const [];
  bool _loading = true;
  int _index = 0;
  bool _playing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LsfRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _load();
  }

  Future<void> _load() async {
    final media = SignMediaService.instance;
    // Liste des animations : attendue au premier affichage, puis
    // rafraîchie en arrière-plan.
    if (media.keys.isEmpty) {
      await media.ensureLoaded();
    } else {
      media.ensureLoaded();
    }
    final signs = await SignRepository.cachedSigns();
    if (!mounted) return;
    setState(() {
      _tokens = SignRepository.translateText(widget.text, signs,
          animated: media.keys);
      _index = 0;
      _loading = false;
    });
    if (widget.autoplay && _tokens.length > 1) _play();
  }

  /// Enchaînement : un signe animé passe au suivant à la fin de son
  /// mouvement ; les autres après un délai fixe.
  void _play() {
    if (_index >= _tokens.length - 1) _index = 0;
    setState(() => _playing = true);
    _armTimer();
  }

  bool get _currentIsAnimated {
    final format = widget.format ?? AppPreferences.instance.responseFormat;
    final token = _tokens[_index];
    return (format == 'avatar' ||
            format == 'landmarks' ||
            format == 'video' ||
            token.isPointing) &&
        (token.isPointing ||
            !token.isFingerspelled &&
                SignMediaService.instance.has(token.word));
  }

  void _armTimer() {
    _timer?.cancel();
    if (!_playing) return;
    // Filet de sécurité si l'animation ne se charge pas.
    _timer = Timer(
        _currentIsAnimated
            ? const Duration(seconds: 14)
            : const Duration(milliseconds: 2600),
        _advance);
  }

  void _advance() {
    if (!mounted || !_playing) return;
    if (_index >= _tokens.length - 1) {
      _timer?.cancel();
      setState(() => _playing = false);
    } else {
      setState(() => _index++);
      _armTimer();
    }
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _playing = false);
  }

  void _goTo(int index) {
    _timer?.cancel();
    setState(() {
      _playing = false;
      _index = index.clamp(0, _tokens.length - 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return SizedBox(
          height: widget.stageHeight,
          child: const Center(child: CircularProgressIndicator()));
    }
    if (_tokens.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(tr('Aucun mot à traduire.', 'Nothing to translate.'),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      );
    }
    final token = _tokens[_index];
    final format = widget.format ?? AppPreferences.instance.responseFormat;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GlossLine(tokens: _tokens, index: _index, onTap: _goTo),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: format == 'video'
              ? Duration.zero
              : const Duration(milliseconds: 250),
          child: KeyedSubtree(
            key: ValueKey('$format/$_index/${token.word}'),
            child: switch (format) {
              'text' => _TextStage(token: token),
              'video' => token.isPointing
                  ? _MotionStage(
                      token: token,
                      height: widget.stageHeight,
                      style: MotionStyle.avatar,
                      onCycle: _advance)
                  : _VideoStage(
                      token: token,
                      height: widget.stageHeight,
                      onCycle: _advance),
              'landmarks' => _MotionStage(
                  token: token,
                  height: widget.stageHeight,
                  style: MotionStyle.skeleton,
                  onCycle: _advance),
              _ => _MotionStage(
                  token: token,
                  height: widget.stageHeight,
                  style: MotionStyle.avatar,
                  onCycle: _advance),
            },
          ),
        ),
        if (_tokens.length > 1) ...[
          const SizedBox(height: 12),
          Row(children: [
            IconButton(
              tooltip: tr('Signe précédent', 'Previous sign'),
              onPressed: _index == 0 ? null : () => _goTo(_index - 1),
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            IconButton.filledTonal(
              tooltip: _playing ? tr('Pause', 'Pause') : tr('Lire', 'Play'),
              onPressed: _playing ? _pause : _play,
              icon: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
            ),
            IconButton(
              tooltip: tr('Signe suivant', 'Next sign'),
              onPressed:
                  _index >= _tokens.length - 1 ? null : () => _goTo(_index + 1),
              icon: const Icon(Icons.skip_next_rounded),
            ),
            const Spacer(),
            if (widget.compact && token.isFingerspelled)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.abc_rounded,
                    size: 20, color: theme.colorScheme.onSurfaceVariant),
              ),
            Text('${_index + 1} / ${_tokens.length}',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ],
        if (!widget.compact) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < _tokens.length; i++)
                ChoiceChip(
                  label: Text(_tokens[i].word.toUpperCase()),
                  selected: i == _index,
                  showCheckmark: false,
                  avatar: _tokens[i].isFingerspelled
                      ? const Icon(Icons.abc_rounded, size: 18)
                      : null,
                  onSelected: (_) => _goTo(i),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (_tokens.any((t) => t.isFingerspelled)) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.abc_rounded,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tr('Mot épelé en dactylologie (absent du dictionnaire).',
                      'Fingerspelled word (not in the dictionary).'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ]),
          ],
        ],
      ],
    );
  }
}

String _summary(SignToken token) => token.isFingerspelled
    ? token.fingerspelling
    : (token.sign!['gestureSummary'] as String? ??
        token.sign!['description'] as String? ??
        '');

/// Vidéo d'interprète : chaque signe est joué une fois en entier, puis la
/// phrase continue avec le signe suivant, dans le même cadre.
class _VideoStage extends StatefulWidget {
  final SignToken token;
  final double height;
  final VoidCallback onCycle;
  const _VideoStage(
      {required this.token, required this.height, required this.onCycle});

  @override
  State<_VideoStage> createState() => _VideoStageState();
}

class _VideoStageState extends State<_VideoStage> {
  late final Future<({Uint8List bytes, Duration duration})?> _clip =
      widget.token.isFingerspelled
          ? Future.value(null)
          : SignMediaService.instance.gifClip(widget.token.word);
  Timer? _end;

  @override
  void dispose() {
    _end?.cancel();
    super.dispose();
  }

  Widget _placeholder(BuildContext context, {bool loading = false}) {
    final theme = Theme.of(context);
    final token = widget.token;
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.stage,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const SizedBox.square(
                dimension: 32,
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: Colors.white))
          else
            Icon(Icons.videocam_off_outlined,
                size: 36, color: Colors.white.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(token.word.toUpperCase(),
              style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Text(
              loading
                  ? tr('Chargement de la vidéo…', 'Loading the video…')
                  : _summary(token),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.75))),
          if (!loading) ...[
            const SizedBox(height: 8),
            Text(
                token.isFingerspelled
                    ? tr('Épelé en dactylologie', 'Fingerspelled')
                    : tr('Vidéo d’interprète non disponible pour ce signe',
                        'Interpreter video not available for this sign'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white.withValues(alpha: 0.6))),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({Uint8List bytes, Duration duration})?>(
      future: _clip,
      builder: (context, snapshot) {
        final clip = snapshot.data;
        if (clip == null) {
          return _placeholder(context,
              loading: snapshot.connectionState != ConnectionState.done);
        }
        // Signe suivant à la fin de la vidéo (une seule lecture).
        _end ??= Timer(clip.duration, widget.onCycle);
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: widget.height,
            width: double.infinity,
            color: AppColors.stage,
            child: Stack(fit: StackFit.expand, children: [
              Image.memory(clip.bytes,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  semanticLabel: 'Signe LSF : ${widget.token.word}'),
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(widget.token.word.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _TextStage extends StatelessWidget {
  final SignToken token;
  const _TextStage({required this.token});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sign = token.sign;
    final steps = sign == null
        ? <String>[]
        : [
            for (final key in ['step1', 'step2', 'step3'])
              if ((sign[key] as String? ?? '').isNotEmpty) sign[key] as String,
          ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(token.word.toUpperCase(), style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          if (sign == null)
            Text(
              '${tr('Dactylologie', 'Fingerspelling')} : ${token.fingerspelling}',
              style: theme.textTheme.bodyMedium,
            )
          else ...[
            Text(
                sign['animatedOnly'] == true
                    ? tr('Animation disponible en mode Vidéo ou Avatar.',
                        'Animation available in Video or Avatar mode.')
                    : sign['description'] as String? ??
                        sign['gestureSummary'] as String? ??
                        '',
                style: theme.textTheme.bodyMedium),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onPrimaryContainer)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child:
                            Text(steps[i], style: theme.textTheme.bodySmall)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Signe rejoué par l'avatar animé ou en landmarks, à partir des mouvements
/// réels fournis par le serveur. Sans mouvement disponible (mot épelé, signe
/// absent, serveur injoignable) : avatar et description du geste.
class _MotionStage extends StatefulWidget {
  final SignToken token;
  final double height;
  final MotionStyle style;
  final VoidCallback onCycle;

  const _MotionStage({
    required this.token,
    required this.height,
    required this.style,
    required this.onCycle,
  });

  @override
  State<_MotionStage> createState() => _MotionStageState();
}

class _MotionStageState extends State<_MotionStage> {
  late Future<SignMotion?> _motion = _load();

  Future<SignMotion?> _load() async {
    final token = widget.token;
    SignMotion? motion;
    if (token.isPointing && token.point != null) {
      motion = LsfMotionSynthesis.pointing(
          token.point!, await LsfMotionSynthesis.neutral());
    } else if (!token.isFingerspelled) {
      motion = await SignMediaService.instance.motion(token.word);
    }
    if (motion == null) return null;
    // Expression du visage de la phrase (question, négation).
    return LsfMotionSynthesis.express(motion, token.expression, token.negated);
  }

  @override
  void didUpdateWidget(covariant _MotionStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token.word != widget.token.word) _motion = _load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SignMotion?>(
      future: _motion,
      builder: (context, snapshot) {
        final motion = snapshot.data;
        if (motion != null) {
          return SignMotionPlayer(
            key: ValueKey(motion.sign),
            motion: motion,
            style: widget.style,
            avatar: AppPreferences.instance.signingAvatar,
            height: widget.height,
            onCycle: widget.onCycle,
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return _Preparing(height: widget.height, word: widget.token.word);
        }
        return _BodyFallback(
            token: widget.token, height: widget.height, style: widget.style);
      },
    );
  }
}

class _Preparing extends StatelessWidget {
  final double height;
  final String word;
  const _Preparing({required this.height, required this.word});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox.square(
              dimension: 30, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: 12),
          Text(word.toUpperCase(), style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(tr('Préparation du signe…', 'Preparing the sign…'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

/// Phrase telle qu'elle est signée en LSF (ordre et expression du visage).
class _GlossLine extends StatelessWidget {
  final List<SignToken> tokens;
  final int index;
  final ValueChanged<int> onTap;

  const _GlossLine(
      {required this.tokens, required this.index, required this.onTap});

  static String? _expressionLabel(SignToken token) =>
      switch (token.expression) {
        LsfExpression.questionYesNo =>
          tr('Question : sourcils levés', 'Question: raised eyebrows'),
        LsfExpression.questionWh =>
          tr('Question : sourcils froncés', 'Question: furrowed brows'),
        LsfExpression.negation =>
          tr('Négation : la tête fait « non »', 'Negation: head shake'),
        LsfExpression.neutral => null,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = tokens[index];
    final expression = _expressionLabel(current);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(
                text: '${tr('En LSF', 'In LSF')} : ',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            for (var i = 0; i < tokens.length; i++) ...[
              if (i > 0) const TextSpan(text: ' '),
              TextSpan(
                text: tokens[i].isPointing
                    ? '👉${tokens[i].word.toUpperCase()}'
                    : tokens[i].word.toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: i == index
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  fontWeight: i == index ? FontWeight.w800 : FontWeight.w500,
                  decoration: i == index ? TextDecoration.underline : null,
                ),
              ),
            ],
          ]),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        if (expression != null) ...[
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.face_retouching_natural_rounded,
                size: 16, color: theme.colorScheme.secondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(expression,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.secondary)),
            ),
          ]),
        ],
      ],
    );
  }
}

/// Signe sans mouvement disponible (mot épelé, absent du serveur, serveur
/// injoignable) : l'avatar reste affiché en entier, avec le geste décrit.
class _BodyFallback extends StatelessWidget {
  final SignToken token;
  final double height;
  final MotionStyle style;

  const _BodyFallback(
      {required this.token, required this.height, required this.style});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = SignMediaService.instance;
    final reason = token.isFingerspelled
        ? tr('Épelé en dactylologie', 'Fingerspelled')
        : media.keys.isEmpty
            ? tr('Serveur non joint : mouvement indisponible',
                'Server not reached: movement unavailable')
            : tr('Pas encore de vidéo pour ce signe',
                'No video for this sign yet');
    return FutureBuilder<MotionFrame>(
      future: LsfMotionSynthesis.neutral(),
      builder: (context, snapshot) {
        final base = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (base == null)
              SizedBox(height: height)
            else
              SignMotionPlayer(
                motion: LsfMotionSynthesis.idle(base),
                style: style,
                avatar: AppPreferences.instance.signingAvatar,
                height: height,
              ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: token.word.toUpperCase(),
                    style: theme.textTheme.titleSmall),
                if (_summary(token).isNotEmpty)
                  TextSpan(
                      text: ' — ${_summary(token)}',
                      style: theme.textTheme.bodySmall),
              ]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(reason,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        );
      },
    );
  }
}

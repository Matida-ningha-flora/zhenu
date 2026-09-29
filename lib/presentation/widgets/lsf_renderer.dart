import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

import '../../core/l10n/tr.dart';
import '../../core/preferences/app_preferences.dart';
import '../../data/services/sign_media_service.dart';
import '../../data/services/sign_repository.dart';
import '../../data/models/sign_motion.dart';
import 'avatar_portrait.dart';
import 'sign_avatar.dart';
import 'sign_translation_gif.dart';

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
    return (format == 'avatar' || format == 'landmarks') &&
        !token.isFingerspelled &&
        SignMediaService.instance.has(token.word);
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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(
            key: ValueKey('$format/$_index/${token.word}'),
            child: switch (format) {
              'text' => _TextStage(token: token),
              'video' => _VideoStage(token: token, height: widget.stageHeight),
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

class _AvatarStage extends StatelessWidget {
  final SignToken token;
  final double height;
  const _AvatarStage({required this.token, required this.height});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatar = AppPreferences.instance.signingAvatar;
    final composite = Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          SizedBox.square(
              dimension: height * 0.5, child: AvatarPortrait(variant: avatar)),
          Positioned(
            right: -6,
            bottom: -6,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Color(0x22000000), blurRadius: 8)
                ],
              ),
              child: Text(
                token.isFingerspelled
                    ? '🤟'
                    : token.sign!['gestureEmoji'] as String? ?? '🤟',
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
        ]),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(token.word.toUpperCase(),
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
              const SizedBox(height: 8),
              Text(_summary(token),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
            ],
          ),
        ),
      ]),
    );
    final gif = SignMediaService.instance.gifUrl(token.word);
    if (gif != null) {
      return SignGifView(
          url: gif,
          height: height,
          label: token.word,
          fallback: composite,
          avatar: avatar);
    }
    return SignTranslationGif(
        text: token.word,
        variant: avatar,
        size: height / 1.4,
        fallback: composite);
  }
}

class _VideoStage extends StatelessWidget {
  final SignToken token;
  final double height;
  const _VideoStage({required this.token, required this.height});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.stage,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            token.isFingerspelled
                ? '🤟'
                : token.sign!['gestureEmoji'] as String? ?? '🤟',
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 12),
          Text(token.word.toUpperCase(),
              style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Text(_summary(token),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.75))),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.videocam_off_outlined,
                size: 16, color: Colors.white.withValues(alpha: 0.6)),
            const SizedBox(width: 6),
            Text(
                tr('Vidéo d’interprète non disponible pour ce signe',
                    'Interpreter video not available for this sign'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white.withValues(alpha: 0.6))),
          ]),
        ],
      ),
    );
    final gif = SignMediaService.instance.gifUrl(token.word);
    if (gif != null) {
      return SignGifView(
          url: gif, height: height, label: token.word, fallback: placeholder);
    }
    return SignTranslationGif(
        text: token.word,
        variant: 'video',
        size: height / 1.4,
        fallback: placeholder);
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
                    : sign['description'] as String? ?? '',
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

  Future<SignMotion?> _load() => widget.token.isFingerspelled
      ? Future.value(null)
      : SignMediaService.instance.motion(widget.token.word);

  @override
  void didUpdateWidget(covariant _MotionStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token.word != widget.token.word) _motion = _load();
  }

  @override
  Widget build(BuildContext context) {
    final cached = SignMediaService.instance.cachedMotion(widget.token.word);
    return FutureBuilder<SignMotion?>(
      future: _motion,
      initialData: cached,
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
        return _AvatarStage(token: widget.token, height: widget.height);
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

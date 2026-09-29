import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/l10n/tr.dart';
import '../../core/preferences/app_preferences.dart';
import '../../data/services/admin_data_service.dart';
import '../../data/services/sign_recognition_service.dart';
import '../../data/services/translation_history_service.dart';
import '../../data/services/voice_services.dart';
import '../widgets/lsf_explain_button.dart';
import '../widgets/lsf_renderer.dart';
import '../widgets/motion.dart';
import '../widgets/reception_modes.dart';
import '../widgets/ui_kit.dart';
import 'conversations/group_conversations.dart';

enum TranslatorMode { sign, speech, conversation }

/// Traduction dans les deux sens et conversation à plusieurs.
class TranslatorScreen extends StatefulWidget {
  final ValueNotifier<TranslatorMode> mode;

  const TranslatorScreen({super.key, required this.mode});

  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen> {
  final _recognizer = SignRecognitionService();

  @override
  void initState() {
    super.initState();
    widget.mode.addListener(_onModeChanged);
  }

  void _onModeChanged() {
    // La caméra n'est utilisée qu'en mode « Je signe ».
    if (widget.mode.value != TranslatorMode.sign) _recognizer.stopCamera();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.mode.removeListener(_onModeChanged);
    _recognizer.dispose();
    SpeechInput.instance.stop();
    SpeechOutput.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Traduire', 'Translate')),
        actions: [
          LsfExplainButton(
            text: tr(
                'Je signe : la caméra traduit vos signes en texte et en voix. Je parle : votre voix ou votre texte est traduit en LSF. Conversation : échangez avec plusieurs personnes.',
                'I sign: the camera translates your signs into text and speech. I speak: your voice or text is translated into LSF. Conversation: talk with several people.'),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<TranslatorMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: TranslatorMode.sign,
                    icon: const Icon(Icons.front_hand_outlined, size: 18),
                    label: Text(tr('Je signe', 'I sign')),
                  ),
                  ButtonSegment(
                    value: TranslatorMode.speech,
                    icon: const Icon(Icons.mic_none_rounded, size: 18),
                    label: Text(tr('Je parle', 'I speak')),
                  ),
                  ButtonSegment(
                    value: TranslatorMode.conversation,
                    icon: const Icon(Icons.groups_outlined, size: 18),
                    label: Text(tr('Groupe', 'Group')),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (value) => widget.mode.value = value.first,
              ),
            ),
          ),
        ),
      ),
      body: switch (mode) {
        TranslatorMode.sign => _SignView(recognizer: _recognizer),
        TranslatorMode.speech => const _SpeechView(),
        TranslatorMode.conversation => const GroupConversationsTab(),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Caméra
// ---------------------------------------------------------------------------

/// Zone caméra avec l'état de la reconnaissance en surimpression.
class CameraStage extends StatefulWidget {
  final SignRecognitionService recognizer;
  final double height;

  const CameraStage({super.key, required this.recognizer, this.height = 340});

  @override
  State<CameraStage> createState() => _CameraStageState();
}

class _CameraStageState extends State<CameraStage> {
  String? _problemMessage(SignRecognitionService r) => switch (r.problem) {
        RecognitionProblem.server => tr(
            'Serveur de reconnaissance injoignable. Vérifiez que le serveur tourne et que le téléphone est sur le même Wi-Fi.',
            'Recognition server unreachable. Check that the server is running and that the phone is on the same Wi-Fi.'),
        RecognitionProblem.unsupported => tr(
            'La reconnaissance des signes fonctionne dans l’application Android.',
            'Sign recognition works in the Android app.'),
        RecognitionProblem.camera => tr(
            'Caméra inaccessible. Autorisez l’accès à la caméra dans les réglages.',
            'Camera unavailable. Allow camera access in the settings.'),
        RecognitionProblem.none => null,
      };

  @override
  Widget build(BuildContext context) {
    final r = widget.recognizer;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: r,
      builder: (context, _) {
        final problem = _problemMessage(r);
        final recognized = r.status == RecognitionStatus.recognized;
        final (pillColor, pillLabel, pillDot) = switch (r.status) {
          RecognitionStatus.starting => (
              Colors.white.withValues(alpha: 0.25),
              tr('Connexion…', 'Connecting…'),
              false
            ),
          RecognitionStatus.analysing || RecognitionStatus.recognized => r
                  .handsVisible
              ? (const Color(0xFFDC2626), tr('Signe en cours', 'Signing'), true)
              : (
                  Colors.black.withValues(alpha: 0.45),
                  tr('Montrez vos mains', 'Show your hands'),
                  false
                ),
          _ => (
              Colors.black.withValues(alpha: 0.45),
              tr('Prêt', 'Ready'),
              false
            ),
        };
        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: widget.height,
            color: AppColors.stage,
            child: Stack(fit: StackFit.expand, children: [
              if (r.camera != null && r.camera!.value.isInitialized)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: r.camera!.value.previewSize?.height ?? 480,
                    height: r.camera!.value.previewSize?.width ?? 640,
                    child: CameraPreview(r.camera!),
                  ),
                ),
              if (!r.cameraOn)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.videocam_outlined,
                          color: Colors.white.withValues(alpha: 0.7), size: 44),
                      const SizedBox(height: 12),
                      Text(
                        r.status == RecognitionStatus.starting
                            ? tr('Activation de la caméra…', 'Starting camera…')
                            : tr('Caméra désactivée', 'Camera is off'),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      if (r.status != RecognitionStatus.starting)
                        FilledButton.tonalIcon(
                          onPressed: r.startCamera,
                          icon: const Icon(Icons.videocam_rounded),
                          label:
                              Text(tr('Activer la caméra', 'Turn on camera')),
                        ),
                    ]),
                  ),
                ),
              if (r.cameraOn) ...[
                // Cadre de positionnement : doré quand des mains sont vues,
                // vert quand un signe vient d'être reconnu.
                Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.82,
                    heightFactor: 0.82,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: recognized
                              ? const Color(0xFF34D399)
                              : r.handsVisible
                                  ? AppColors.secondary
                                  : Colors.white.withValues(alpha: 0.4),
                          width: r.handsVisible || recognized ? 3 : 2,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _OverlayPill(
                      color: pillColor, label: pillLabel, dot: pillDot),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Row(children: [
                    if (r.online)
                      _OverlayPill(
                          color: const Color(0xFF059669),
                          label: tr('Modèle IA', 'AI model')),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: tr('Éteindre la caméra', 'Turn off camera'),
                        onPressed: r.stopCamera,
                        icon: const Icon(Icons.videocam_off_outlined,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ]),
                ),
                if (r.lastLabel != null && problem == null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          key: ValueKey(
                              r.lastLabel! + (r.latency?.toString() ?? '')),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(r.lastLabel!,
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
              ],
              if (problem != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFFCA5A5), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(problem,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.white)),
                      ),
                    ]),
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }
}

class _OverlayPill extends StatelessWidget {
  final Color color;
  final String label;
  final bool dot;

  const _OverlayPill(
      {required this.color, required this.label, this.dot = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

// ---------------------------------------------------------------------------
// Je signe : LSF → texte et voix
// ---------------------------------------------------------------------------

class _SignView extends StatefulWidget {
  final SignRecognitionService recognizer;
  const _SignView({required this.recognizer});

  @override
  State<_SignView> createState() => _SignViewState();
}

class _SignViewState extends State<_SignView> {
  final List<String> _words = [];
  bool _autoSpeak = true;
  StreamSubscription<String>? _results;

  String get _sentence => _words.join(' ');

  @override
  void initState() {
    super.initState();
    _results = widget.recognizer.results.listen((word) {
      if (!mounted) return;
      setState(() => _words.add(word));
      if (_autoSpeak) SpeechOutput.instance.speak(word);
    });
  }

  @override
  void dispose() {
    _results?.cancel();
    super.dispose();
  }

  Future<void> _toggleAnalysis() async {
    final r = widget.recognizer;
    if (r.analysing || r.status == RecognitionStatus.recognized) {
      await r.stopAnalysis();
      _saveSentence();
    } else {
      await r.startAnalysis();
    }
  }

  void _saveSentence() {
    if (_words.isEmpty) return;
    TranslationHistoryService.addEntry(
      type: 'sign_to_text',
      input: _sentence,
      output: tr('Signé devant la caméra', 'Signed in front of the camera'),
    );
  }

  void _clear() {
    _saveSentence();
    setState(_words.clear);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.recognizer;
    return ListenableBuilder(
      listenable: r,
      builder: (context, _) {
        final running = r.analysing || r.status == RecognitionStatus.recognized;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            CameraStage(recognizer: r),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.info_outline_rounded,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('Placez vos mains et votre visage dans le cadre, avec un bon éclairage.',
                      'Keep your hands and face inside the frame, in good lighting.'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: running
                  ? FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error)
                  : null,
              onPressed: r.status == RecognitionStatus.starting
                  ? null
                  : _toggleAnalysis,
              icon:
                  Icon(running ? Icons.stop_rounded : Icons.play_arrow_rounded),
              label: Text(running
                  ? tr('Arrêter la traduction', 'Stop translating')
                  : tr('Démarrer la traduction', 'Start translating')),
            ),
            if (r.uncertain != null && running) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Icon(Icons.help_outline_rounded,
                      size: 20, color: theme.colorScheme.onSecondaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${tr('Signe incertain', 'Uncertain sign')} : ${r.uncertain!.label} (${(r.uncertain!.score * 100).round()} %)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer),
                    ),
                  ),
                  TextButton(
                    onPressed: r.acceptUncertain,
                    child: Text(tr('Valider', 'Accept')),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(tr('Traduction', 'Translation'),
                        style: theme.textTheme.titleSmall),
                    const Spacer(),
                    if (r.latency != null)
                      StatusPill(
                        label:
                            '${(r.latency!.inMilliseconds / 1000).toStringAsFixed(1)} s',
                        color: r.latency!.inMilliseconds < 2000
                            ? AppColors.success
                            : AppColors.warning,
                        icon: Icons.speed_rounded,
                      ),
                  ]),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: _words.isEmpty
                        ? Text(
                            tr('Les signes reconnus s’afficheront ici et seront lus à voix haute.',
                                'Recognised signs will appear here and be read aloud.'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          )
                        : Text(_sentence, style: theme.textTheme.headlineSmall),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  Row(children: [
                    Expanded(
                      child: SwitchListTile.adaptive(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(tr('Lecture vocale automatique',
                            'Read aloud automatically')),
                        value: _autoSpeak,
                        onChanged: (v) => setState(() => _autoSpeak = v),
                      ),
                    ),
                  ]),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42)),
                      onPressed: _words.isEmpty
                          ? null
                          : () => SpeechOutput.instance.speak(_sentence),
                      icon: const Icon(Icons.volume_up_outlined, size: 20),
                      label: Text(tr('Écouter', 'Play')),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42)),
                      onPressed: _words.isEmpty
                          ? null
                          : () {
                              Clipboard.setData(ClipboardData(text: _sentence));
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          tr('Texte copié.', 'Text copied.'))));
                            },
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      label: Text(tr('Copier', 'Copy')),
                    ),
                    TextButton.icon(
                      style:
                          TextButton.styleFrom(minimumSize: const Size(0, 42)),
                      onPressed: _words.isEmpty ? null : _clear,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: Text(tr('Nouvelle phrase', 'New sentence')),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Je parle : voix ou texte → LSF
// ---------------------------------------------------------------------------

class _SpeechView extends StatefulWidget {
  const _SpeechView();

  @override
  State<_SpeechView> createState() => _SpeechViewState();
}

class _SpeechViewState extends State<_SpeechView> {
  final _input = TextEditingController();
  String? _translated;

  List<String> get _suggestions => AppPreferences.instance.isEnglish
      ? const ['Bonjour', 'Merci', 'Comment ça va ?', 'Au revoir']
      : const ['Bonjour', 'Merci beaucoup', 'Comment ça va ?', 'Au revoir'];

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    SpeechInput.instance.stop();
    _input.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    final speech = SpeechInput.instance;
    if (speech.listening) {
      await speech.stop();
      return;
    }
    final started = await speech.listen((text, isFinal) {
      if (!mounted) return;
      _input.value = TextEditingValue(
          text: text, selection: TextSelection.collapsed(offset: text.length));
      if (isFinal && text.trim().isNotEmpty) _translate();
    });
    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(
            'Micro ou reconnaissance vocale indisponible. Vous pouvez saisir le texte.',
            'Microphone or speech recognition unavailable. You can type the text instead.')),
      ));
    }
  }

  void _translate() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    SpeechInput.instance.stop();
    setState(() => _translated = text);
    AdminDataService.recordTranslation(text);
    TranslationHistoryService.addEntry(
      type: 'text_to_sign',
      input: text,
      output: tr('Traduit en LSF', 'Translated into LSF'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListenableBuilder(
                listenable: SpeechInput.instance,
                builder: (context, _) => TextField(
                  controller: _input,
                  minLines: 3,
                  maxLines: 6,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _translate(),
                  style: theme.textTheme.titleMedium,
                  decoration: InputDecoration(
                    hintText: SpeechInput.instance.listening
                        ? tr('À l’écoute… parlez maintenant',
                            'Listening… speak now')
                        : tr('Parlez ou écrivez votre message…',
                            'Speak or type your message…'),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    suffixIcon: _input.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: tr('Effacer', 'Clear'),
                            onPressed: () {
                              _input.clear();
                              setState(() => _translated = null);
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
              // Onde sonore animée pendant l'écoute du micro.
              ListenableBuilder(
                listenable: SpeechInput.instance,
                builder: (context, _) => AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: SpeechInput.instance.listening
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
                          child: SoundWave(
                            active: true,
                            color: theme.colorScheme.primary,
                            level: (SpeechInput.instance.level + 2) / 12,
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                ListenableBuilder(
                  listenable: SpeechInput.instance,
                  builder: (context, _) {
                    final listening = SpeechInput.instance.listening;
                    return IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: listening
                            ? theme.colorScheme.error
                            : theme.colorScheme.primaryContainer,
                        foregroundColor: listening
                            ? Colors.white
                            : theme.colorScheme.onPrimaryContainer,
                        minimumSize: const Size(48, 48),
                      ),
                      tooltip: listening
                          ? tr('Arrêter l’écoute', 'Stop listening')
                          : tr('Dicter', 'Dictate'),
                      onPressed: _toggleMic,
                      icon: Icon(
                          listening ? Icons.stop_rounded : Icons.mic_rounded),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style:
                        FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: _input.text.trim().isEmpty ? null : _translate,
                    icon: const Icon(Icons.sign_language_rounded, size: 20),
                    label: Text(tr('Traduire en LSF', 'Translate to LSF')),
                  ),
                ),
              ]),
            ],
          ),
        ),
        if (_translated == null) ...[
          const SizedBox(height: 20),
          Text(tr('Suggestions', 'Suggestions'),
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in _suggestions)
              ActionChip(
                label: Text(s),
                onPressed: () {
                  _input.text = s;
                  _translate();
                },
              ),
          ]),
        ] else ...[
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(tr('En LSF', 'In LSF'),
                        style: theme.textTheme.titleSmall),
                  ),
                  const ReceptionModeButton(),
                ]),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: AppPreferences.instance,
                  builder: (context, _) => LsfRenderer(
                    key: ValueKey(
                        '$_translated/${AppPreferences.instance.responseFormat}'),
                    text: _translated!,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Conversation à plusieurs
// ---------------------------------------------------------------------------

class SignCaptureSheet extends StatefulWidget {
  const SignCaptureSheet({super.key});

  @override
  State<SignCaptureSheet> createState() => SignCaptureSheetState();
}

class SignCaptureSheetState extends State<SignCaptureSheet> {
  final _recognizer = SignRecognitionService();
  final List<String> _words = [];
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _recognizer.results.listen((word) {
      if (mounted) setState(() => _words.add(word));
    });
    _recognizer.startAnalysis();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Signez votre message', 'Sign your message'),
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            CameraStage(recognizer: _recognizer, height: 280),
            const SizedBox(height: 12),
            Text(
              _words.isEmpty
                  ? tr('Aucun signe reconnu pour l’instant.',
                      'No sign recognised yet.')
                  : _words.join(' '),
              style: _words.isEmpty
                  ? theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
                  : theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: ListenableBuilder(
                  listenable: _recognizer,
                  builder: (context, _) {
                    final running = _recognizer.analysing ||
                        _recognizer.status == RecognitionStatus.recognized;
                    return OutlinedButton(
                      onPressed: running
                          ? _recognizer.stopAnalysis
                          : _recognizer.startAnalysis,
                      child: Text(running
                          ? tr('Pause', 'Pause')
                          : tr('Reprendre', 'Resume')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _words.isEmpty
                      ? null
                      : () => Navigator.pop(context, _words.join(' ')),
                  child: Text(tr('Envoyer', 'Send')),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

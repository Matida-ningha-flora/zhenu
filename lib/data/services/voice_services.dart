import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/preferences/app_preferences.dart';

/// Lecture à voix haute des traductions (synthèse vocale de l'appareil).
class SpeechOutput {
  SpeechOutput._();
  static final SpeechOutput instance = SpeechOutput._();

  final FlutterTts _tts = FlutterTts();

  Future<bool> speak(String text) async {
    if (text.trim().isEmpty) return false;
    try {
      await _tts.stop();
      await _tts
          .setLanguage(AppPreferences.instance.isEnglish ? 'en-US' : 'fr-FR');
      await _tts.setSpeechRate(0.48);
      final result = await _tts.speak(text);
      return result == 1;
    } catch (e) {
      debugPrint('Synthèse vocale indisponible : $e');
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// Reconnaissance vocale (parole → texte) du système.
class SpeechInput extends ChangeNotifier {
  SpeechInput._();
  static final SpeechInput instance = SpeechInput._();

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  bool available = false;
  bool listening = false;
  double level = 0;

  Future<bool> _ensureInitialized() async {
    if (_initialized) return available;
    _initialized = true;
    try {
      available = await _speech.initialize(
        onStatus: (status) {
          final active = status == SpeechToText.listeningStatus;
          if (active != listening) {
            listening = active;
            notifyListeners();
          }
        },
        onError: (_) {
          listening = false;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Reconnaissance vocale indisponible : $e');
      available = false;
    }
    return available;
  }

  /// Écoute l'utilisateur. [onText] reçoit la transcription au fil de l'eau ;
  /// `isFinal` est vrai à la fin de la phrase.
  Future<bool> listen(void Function(String text, bool isFinal) onText) async {
    if (!await _ensureInitialized()) return false;
    try {
      await _speech.listen(
        onResult: (result) =>
            onText(result.recognizedWords, result.finalResult),
        onSoundLevelChange: (value) {
          level = value;
          notifyListeners();
        },
        listenOptions: SpeechListenOptions(
          localeId: AppPreferences.instance.isEnglish ? 'en_US' : 'fr_FR',
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
      );
      listening = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Écoute impossible : $e');
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
    listening = false;
    notifyListeners();
  }
}

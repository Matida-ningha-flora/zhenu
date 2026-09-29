import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'admin_data_service.dart';
import 'echosign_api_client.dart';
import 'echosign_server.dart';

enum RecognitionStatus { idle, starting, ready, analysing, recognized, error }

/// Raison pour laquelle la reconnaissance ne peut pas fonctionner.
enum RecognitionProblem { none, camera, server, unsupported, landmarks }

/// Une image analysée : instant de capture et points clés (1692 valeurs).
class _Sample {
  final int ms;
  final List<double> keypoints;
  _Sample(this.ms, this.keypoints);
}

/// Reconnaissance des signes LSF depuis la caméra.
///
/// Le modèle EchoSign a appris sur des séquences de 30 images à environ
/// 12,5 images/s (≈ 2,4 s de geste). Un téléphone n'analyse que quelques
/// images par seconde (corps, visage et mains) : envoyer les images une à une
/// ne remplirait jamais les 30 images avant la fin du geste.
///
/// Le geste est donc enregistré en entier, de l'apparition des mains à leur
/// disparition, remis au rythme d'apprentissage (12,5 images/s par
/// interpolation), puis envoyé d'un bloc à `POST /predict/sequence`.
/// Le résultat arrive juste après chaque signe.
class SignRecognitionService extends ChangeNotifier {
  static const _landmarkChannel = MethodChannel('zhenu/mediapipe');

  /// Rythme et longueur des séquences d'apprentissage.
  static const _trainingFps = 12.5;
  static const _sequenceLength = 30;

  /// Fin du geste : mains absentes pendant cette durée.
  static const _handsLostAfter = Duration(milliseconds: 700);

  /// Un geste plus long est analysé sans attendre la fin.
  static const _maxSegment = Duration(milliseconds: 4000);

  /// Nombre minimal d'images avec les mains pour tenter une prédiction.
  static const _minHandFrames = 3;

  /// Seuil de confiance du modèle (identique au serveur).
  static const _threshold = 0.65;

  CameraController? camera;
  RecognitionStatus status = RecognitionStatus.idle;
  RecognitionProblem problem = RecognitionProblem.none;
  bool cameraOn = false;
  bool online = false;

  /// Des mains sont visibles : un signe est en cours.
  bool handsVisible = false;

  /// Un geste terminé est en cours d'analyse par le modèle.
  bool predicting = false;
  String? lastLabel;
  double? confidence;
  Duration? latency;

  /// Diagnostic affiché sous la caméra.
  int framesAnalysed = 0;
  int handFrames = 0;
  String? lastError;
  double framesPerSecond = 0;

  /// Meilleure hypothèse lorsque le modèle n'est pas assez sûr de lui.
  ({String label, double score})? uncertain;

  /// Recherche du serveur sur le réseau en cours.
  bool searching = false;

  /// Étape en cours du démarrage, affichée à l'utilisateur.
  String? phase;

  final _results = StreamController<String>.broadcast();
  Stream<String> get results => _results.stream;

  String? _server;
  bool _streaming = false;
  bool _pictureMode = false;
  Timer? _pictureTimer;
  bool _extracting = false;
  int _failures = 0;
  final _clock = Stopwatch()..start();
  final List<_Sample> _segment = [];
  int? _lastHandsMs;
  final List<int> _recentFrames = [];
  bool _disposed = false;

  bool get analysing =>
      status == RecognitionStatus.analysing ||
      status == RecognitionStatus.recognized;

  /// La reconnaissance réelle n'existe que sur Android (MediaPipe natif).
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Serveur EchoSign de repli (PC de développement sur le Wi-Fi local).
  static const defaultServer = EchoSignServer.fallback;

  /// Adresse du serveur : celle qui a été trouvée, sinon la plus probable
  /// (voir [EchoSignServer]).
  static Future<String> serverAddress() => EchoSignServer.preferred();

  static Future<String> endpoint() async =>
      EchoSignApiClient.resolve(await serverAddress())?.websocket.toString() ??
      '';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> startCamera() async {
    if (cameraOn) return;
    status = RecognitionStatus.starting;
    problem = RecognitionProblem.none;
    _notify();
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('no camera');
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        // YUV 4:2:0 standard : conversion en NV21 maîtrisée côté Dart
        // (lignes et pas des plans pris en compte).
        imageFormatGroup:
            supported ? ImageFormatGroup.yuv420 : ImageFormatGroup.unknown,
      );
      await controller.initialize();
      camera = controller;
      cameraOn = true;
      status = RecognitionStatus.ready;
      // Prépare les détecteurs pendant que l'utilisateur se place.
      if (supported) {
        unawaited(_landmarkChannel.invokeMethod<bool>('warmup').then((ready) {
          if (ready == false) {
            lastError = 'MediaPipe indisponible sur ce téléphone';
            _notify();
          }
          return ready;
        }).catchError((Object _) => false));
      }
    } catch (e) {
      debugPrint('Caméra indisponible : $e');
      camera = null;
      cameraOn = false;
      problem = RecognitionProblem.camera;
      status = RecognitionStatus.error;
    }
    _notify();
  }

  Future<void> stopCamera() async {
    await stopAnalysis();
    final controller = camera;
    camera = null;
    cameraOn = false;
    status = RecognitionStatus.idle;
    _notify();
    await controller?.dispose();
  }

  Future<void> startAnalysis() async {
    if (!supported) {
      problem = RecognitionProblem.unsupported;
      status = RecognitionStatus.error;
      _notify();
      return;
    }
    if (!cameraOn) await startCamera();
    final controller = camera;
    if (controller == null) return;
    status = RecognitionStatus.starting;
    problem = RecognitionProblem.none;
    try {
      // Chaque étape a une durée limite : le démarrage ne reste jamais
      // bloqué.
      phase = 'server';
      searching = true;
      _notify();
      _server = await EchoSignServer.locate()
          .timeout(const Duration(seconds: 25), onTimeout: () => null);
      searching = false;
      online = _server != null;
      if (!online) {
        problem = RecognitionProblem.server;
        status = RecognitionStatus.error;
        return;
      }
      _resetSign();
      lastLabel = null;
      uncertain = null;
      framesAnalysed = 0;
      handFrames = 0;
      lastError = null;
      _failures = 0;
      phase = 'camera';
      _notify();
      status = RecognitionStatus.analysing;
      await _startFrames(controller);
    } catch (e) {
      debugPrint('Démarrage de l’analyse impossible : $e');
      if (status == RecognitionStatus.starting) {
        problem =
            online ? RecognitionProblem.camera : RecognitionProblem.server;
        status = RecognitionStatus.error;
      }
    } finally {
      phase = null;
      searching = false;
      _notify();
    }
  }

  /// Flux vidéo de la caméra ; s'il ne démarre pas sur ce téléphone, photos
  /// successives (plus lent mais fonctionne partout).
  Future<void> _startFrames(CameraController controller) async {
    if (_streaming || _pictureMode) return;
    try {
      await controller
          .startImageStream(_onFrame)
          .timeout(const Duration(seconds: 5));
      _streaming = true;
      return;
    } catch (e) {
      debugPrint('Flux vidéo indisponible, passage aux photos : $e');
      try {
        await controller.stopImageStream();
      } catch (_) {}
    }
    _pictureMode = true;
    _pictureTimer?.cancel();
    _pictureTimer = Timer.periodic(
        const Duration(milliseconds: 150), (_) => _onPicture(controller));
  }

  Future<void> stopAnalysis() async {
    final controller = camera;
    if (_streaming && controller != null) {
      try {
        await controller.stopImageStream();
      } catch (_) {}
    }
    _streaming = false;
    _pictureTimer?.cancel();
    _pictureTimer = null;
    _pictureMode = false;
    _resetSign();
    uncertain = null;
    if (analysing) status = RecognitionStatus.ready;
    _notify();
  }

  // --- Images ------------------------------------------------------------

  Future<void> _onFrame(CameraImage image) async {
    final controller = camera;
    if (_disposed || !analysing || controller == null || _extracting) return;
    _extracting = true;
    try {
      final keypoints = await _landmarkChannel.invokeMethod<List<dynamic>>(
        'extractKeypointsFromNv21',
        {
          'nv21': _toNv21(image),
          'width': image.width,
          'height': image.height,
          'rotation': controller.description.sensorOrientation,
        },
      );
      _onKeypoints(keypoints);
    } on MissingPluginException {
      problem = RecognitionProblem.unsupported;
      status = RecognitionStatus.error;
      await stopAnalysis();
    } catch (e) {
      _onExtractionError(e);
    } finally {
      _extracting = false;
    }
  }

  Future<void> _onPicture(CameraController controller) async {
    if (_disposed ||
        !analysing ||
        _extracting ||
        controller.value.isTakingPicture) {
      return;
    }
    _extracting = true;
    try {
      final picture = await controller.takePicture();
      final bytes = await picture.readAsBytes();
      final keypoints = await _landmarkChannel.invokeMethod<List<dynamic>>(
        'extractKeypointsFromJpeg',
        {
          'jpeg': bytes,
          'width': 0,
          'height': 0,
          'rotation': controller.description.sensorOrientation,
        },
      );
      _onKeypoints(keypoints);
    } catch (e) {
      _onExtractionError(e);
    } finally {
      _extracting = false;
    }
  }

  void _onExtractionError(Object e) {
    debugPrint('Image ignorée : $e');
    lastError = e is PlatformException ? (e.message ?? e.code) : '$e';
    // Échecs répétés : l'analyse d'image ne fonctionne pas sur ce téléphone.
    if (++_failures >= 8 && framesAnalysed == 0) {
      problem = RecognitionProblem.landmarks;
      status = RecognitionStatus.error;
      unawaited(stopAnalysis());
    }
    _notify();
  }

  void _onKeypoints(List<dynamic>? raw) {
    if (raw == null || raw.length != EchoSignApiClient.frameSize) return;
    final now = _clock.elapsedMilliseconds;
    framesAnalysed++;
    _failures = 0;
    _recentFrames.add(now);
    _recentFrames.removeWhere((t) => now - t > 3000);
    framesPerSecond = _recentFrames.length / 3;
    final values = [for (final v in raw) (v as num).toDouble()];

    if (_hasHands(values)) {
      handFrames++;
      _lastHandsMs = now;
      if (!handsVisible) {
        handsVisible = true;
        uncertain = null;
        _segment.clear();
      }
      _segment.add(_Sample(now, values));
      // Geste très long : analysé sans attendre que les mains retombent.
      if (now - _segment.first.ms >= _maxSegment.inMilliseconds) {
        _finishSign();
      }
    } else if (handsVisible &&
        _lastHandsMs != null &&
        now - _lastHandsMs! >= _handsLostAfter.inMilliseconds) {
      _finishSign();
    }
    _notify();
  }

  /// Les 126 dernières valeurs sont les deux mains (21 points × 3 chacune).
  static bool _hasHands(List<double> keypoints) {
    for (var i = keypoints.length - 126; i < keypoints.length; i++) {
      if (keypoints[i] != 0) return true;
    }
    return false;
  }

  void _resetSign() {
    handsVisible = false;
    _segment.clear();
    _lastHandsMs = null;
  }

  // --- Prédiction ----------------------------------------------------------

  void _finishSign() {
    final samples = List<_Sample>.of(_segment);
    _resetSign();
    if (samples.length < _minHandFrames) return;
    final started = DateTime.now();
    unawaited(_predict(samples, started));
  }

  Future<void> _predict(List<_Sample> samples, DateTime started) async {
    final server = _server;
    final urls = server == null ? null : EchoSignApiClient.resolve(server);
    if (urls == null) return;
    predicting = true;
    _notify();
    try {
      final uri = urls.health.replace(path: '/predict/sequence');
      EchoSignPrediction? best;
      for (final window in _windows(samples)) {
        final response = await http
            .post(uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'sequence': window}))
            .timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) {
          lastError = 'Serveur : erreur ${response.statusCode}';
          continue;
        }
        final prediction = EchoSignPrediction.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
        final score = prediction.confidence ?? prediction.bestGuess?.score ?? 0;
        final bestScore = best?.confidence ?? best?.bestGuess?.score ?? 0;
        if (best == null || score > bestScore) best = prediction;
      }
      if (best != null) _onPrediction(best, DateTime.now().difference(started));
    } catch (e) {
      debugPrint('Prédiction impossible : $e');
      lastError = 'Serveur injoignable pendant l’analyse';
      EchoSignServer.invalidate();
    } finally {
      predicting = false;
      _notify();
    }
  }

  /// Séquences de 30 images au rythme d'apprentissage, à partir du geste
  /// enregistré : interpolation entre les images réelles, puis, comme à
  /// l'apprentissage, répétition de la dernière image si le geste est court
  /// ou fenêtres glissantes (demi-recouvrement) s'il est long.
  @visibleForTesting
  static List<List<double>> resample(
      List<({int ms, List<double> values})> input) {
    const step = 1000 / _trainingFps;
    final start = input.first.ms;
    final duration = input.last.ms - start;
    final count = (duration / step).floor() + 1;
    final out = <List<double>>[];
    var j = 0;
    for (var k = 0; k < count; k++) {
      final t = start + k * step;
      while (j < input.length - 2 && input[j + 1].ms < t) {
        j++;
      }
      final a = input[j];
      final b = input[j + 1 < input.length ? j + 1 : j];
      final span = b.ms - a.ms;
      final f = span <= 0 ? 0.0 : ((t - a.ms) / span).clamp(0.0, 1.0);
      out.add([
        for (var i = 0; i < a.values.length; i++)
          // Une partie absente d'un côté (0) n'est pas interpolée.
          a.values[i] == 0 || b.values[i] == 0
              ? (f < 0.5 ? a.values[i] : b.values[i])
              : a.values[i] + (b.values[i] - a.values[i]) * f
      ]);
    }
    return out;
  }

  static List<List<List<double>>> _windows(List<_Sample> samples) {
    final frames =
        resample([for (final s in samples) (ms: s.ms, values: s.keypoints)]);
    if (frames.length <= _sequenceLength) {
      return [
        [
          ...frames,
          for (var i = frames.length; i < _sequenceLength; i++) frames.last
        ]
      ];
    }
    const stride = _sequenceLength ~/ 2;
    return [
      for (var s = 0; s + _sequenceLength <= frames.length; s += stride)
        frames.sublist(s, s + _sequenceLength)
    ].take(3).toList();
  }

  void _onPrediction(EchoSignPrediction prediction, Duration took) {
    latency = took;
    final label = prediction.label;
    if (label != null && label.isNotEmpty) {
      _emit(EchoSignApiClient.displayLabel(label).toUpperCase(),
          prediction.confidence);
      return;
    }
    final guess = prediction.bestGuess;
    uncertain = guess == null || guess.score < _threshold / 3
        ? null
        : (
            label: EchoSignApiClient.displayLabel(guess.label),
            score: guess.score
          );
    _notify();
  }

  void _emit(String label, double? score) {
    uncertain = null;
    lastLabel = label;
    confidence = score;
    status = RecognitionStatus.recognized;
    AdminDataService.recordTranslation(label);
    _results.add(label);
    _notify();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (_disposed || status != RecognitionStatus.recognized) return;
      status = RecognitionStatus.analysing;
      _notify();
    });
  }

  /// Accepte l'hypothèse incertaine proposée par le modèle.
  void acceptUncertain() {
    final guess = uncertain;
    if (guess != null) _emit(guess.label.toUpperCase(), guess.score);
  }

  /// Convertit l'image caméra (YUV 4:2:0) en NV21 (format attendu côté
  /// Android), en tenant compte du pas des lignes et des pixels.
  static Uint8List _toNv21(CameraImage image) {
    if (image.planes.length == 1) return image.planes.first.bytes;
    final width = image.width;
    final height = image.height;
    final out = Uint8List(width * height * 3 ~/ 2);
    final y = image.planes[0];
    var index = 0;
    for (var row = 0; row < height; row++) {
      final start = row * y.bytesPerRow;
      out.setRange(index, index + width, y.bytes, start);
      index += width;
    }
    final u = image.planes[1];
    final v = image.planes[2];
    final uStride = u.bytesPerPixel ?? 1;
    final vStride = v.bytesPerPixel ?? 1;
    for (var row = 0; row < height ~/ 2; row++) {
      for (var col = 0; col < width ~/ 2; col++) {
        final vi = row * v.bytesPerRow + col * vStride;
        final ui = row * u.bytesPerRow + col * uStride;
        out[index++] = v.bytes[vi < v.bytes.length ? vi : v.bytes.length - 1];
        out[index++] = u.bytes[ui < u.bytes.length ? ui : u.bytes.length - 1];
      }
    }
    return out;
  }

  @override
  void dispose() {
    _disposed = true;
    _pictureTimer?.cancel();
    final controller = camera;
    if (_streaming && controller != null) {
      controller.stopImageStream().catchError((Object _) {});
    }
    controller?.dispose();
    _results.close();
    super.dispose();
  }
}

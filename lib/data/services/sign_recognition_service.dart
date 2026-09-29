import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'admin_data_service.dart';
import 'echosign_api_client.dart';

enum RecognitionStatus { idle, starting, ready, analysing, recognized, error }

/// Raison pour laquelle la reconnaissance ne peut pas fonctionner.
enum RecognitionProblem { none, camera, server, unsupported }

/// Reconnaissance des signes LSF depuis la caméra.
///
/// Le flux vidéo de la caméra est lu image par image ; MediaPipe (Android)
/// en extrait les points clés (1692 valeurs) qui sont envoyés au modèle
/// EchoSign par WebSocket. Pour éviter les résultats sans geste :
/// - seules les images où des mains sont visibles sont envoyées ;
/// - quand les mains disparaissent, le buffer du serveur est vidé (`reset`),
///   pour que deux signes successifs ne se mélangent pas ;
/// - aucune réponse n'est inventée : sans serveur joignable, un message
///   explique le problème.
class SignRecognitionService extends ChangeNotifier {
  static const _landmarkChannel = MethodChannel('zhenu/mediapipe');

  /// Images consécutives sans mains avant de considérer le signe terminé.
  static const _handsLostAfter = 4;

  /// Intervalle minimal entre deux images analysées.
  static const _minFrameGap = Duration(milliseconds: 70);

  CameraController? camera;
  RecognitionStatus status = RecognitionStatus.idle;
  RecognitionProblem problem = RecognitionProblem.none;
  bool cameraOn = false;
  bool online = false;

  /// Des mains sont visibles : un signe est en cours d'analyse.
  bool handsVisible = false;
  String? lastLabel;
  double? confidence;
  Duration? latency;
  int bufferFill = 0;

  /// Meilleure hypothèse lorsque le modèle n'est pas assez sûr de lui.
  ({String label, double score})? uncertain;

  final _results = StreamController<String>.broadcast();
  Stream<String> get results => _results.stream;

  EchoSignApiClient? _api;
  StreamSubscription<EchoSignPrediction>? _predictions;
  bool _streaming = false;
  bool _extracting = false;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _framesWithoutHands = 0;
  bool _sentSinceReset = false;
  DateTime? _signStart;
  String? _lastEmitted;
  DateTime? _lastEmittedAt;
  bool _disposed = false;

  bool get analysing =>
      status == RecognitionStatus.analysing ||
      status == RecognitionStatus.recognized;

  /// La reconnaissance réelle n'existe que sur Android (MediaPipe natif).
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Serveur EchoSign du projet (PC de développement sur le Wi-Fi local).
  /// À remplacer par l'adresse définitive du serveur une fois hébergé.
  static const defaultServer = 'http://192.168.100.132:8000';

  /// Adresse du serveur : réglage de l'administration, sinon valeur fournie
  /// à la compilation (`--dart-define=ECHOSIGN_URL=http://IP:8000`).
  static Future<String> serverAddress() async {
    final config = await AdminDataService.loadModelConfig();
    final configured = (config['endpoint'] as String? ?? '').trim();
    if (configured.isNotEmpty) return configured;
    const fromBuild = String.fromEnvironment('ECHOSIGN_URL');
    if (fromBuild.isNotEmpty) return fromBuild;
    const legacy = String.fromEnvironment('ECHOSIGN_WS_URL');
    if (legacy.isNotEmpty) return legacy;
    return defaultServer;
  }

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
        imageFormatGroup:
            supported ? ImageFormatGroup.nv21 : ImageFormatGroup.unknown,
      );
      await controller.initialize();
      camera = controller;
      cameraOn = true;
      status = RecognitionStatus.ready;
      // Prépare les détecteurs pendant que l'utilisateur se place.
      if (supported) {
        unawaited(_landmarkChannel
            .invokeMethod<bool>('warmup')
            .catchError((Object _) => false));
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

  Future<void> _connect() async {
    if (online && _api != null) return;
    final url = await endpoint();
    if (url.isEmpty) return;
    final api = EchoSignApiClient(endpoint: url);
    try {
      await api.connect().timeout(const Duration(seconds: 4));
      _api = api;
      _predictions = api.predictions.listen(_onPrediction, onError: (_) {
        online = false;
        _notify();
      });
      online = true;
    } catch (e) {
      debugPrint('Modèle EchoSign injoignable ($url) : $e');
      online = false;
      await api.dispose();
    }
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
    _notify();
    await _connect();
    if (!online) {
      problem = RecognitionProblem.server;
      status = RecognitionStatus.error;
      _notify();
      return;
    }
    problem = RecognitionProblem.none;
    status = RecognitionStatus.analysing;
    handsVisible = false;
    lastLabel = null;
    uncertain = null;
    _lastEmitted = null;
    _framesWithoutHands = 0;
    await _api?.reset();
    _sentSinceReset = false;
    if (!_streaming) {
      await controller.startImageStream(_onFrame);
      _streaming = true;
    }
    _notify();
  }

  Future<void> stopAnalysis() async {
    final controller = camera;
    if (_streaming && controller != null) {
      try {
        await controller.stopImageStream();
      } catch (_) {}
    }
    _streaming = false;
    handsVisible = false;
    uncertain = null;
    if (_sentSinceReset) {
      await _api?.reset();
      _sentSinceReset = false;
    }
    if (analysing) status = RecognitionStatus.ready;
    _notify();
  }

  /// Image du flux caméra ➜ points clés ➜ serveur (si des mains sont vues).
  Future<void> _onFrame(CameraImage image) async {
    final api = _api;
    final controller = camera;
    if (_disposed ||
        !analysing ||
        api == null ||
        controller == null ||
        _extracting ||
        api.awaitingReply ||
        DateTime.now().difference(_lastFrameAt) < _minFrameGap) {
      return;
    }
    _extracting = true;
    _lastFrameAt = DateTime.now();
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
      if (keypoints == null ||
          keypoints.length != EchoSignApiClient.frameSize) {
        return;
      }
      final values = keypoints.cast<num>();
      if (_hasHands(values)) {
        _framesWithoutHands = 0;
        if (!handsVisible) {
          handsVisible = true;
          _signStart = DateTime.now();
          _notify();
        }
        await api.sendKeypoints(values);
        _sentSinceReset = true;
      } else if (++_framesWithoutHands >= _handsLostAfter && handsVisible) {
        // Fin du signe : on vide le buffer pour le signe suivant.
        handsVisible = false;
        uncertain = null;
        _lastEmitted = null;
        if (_sentSinceReset) {
          await api.reset();
          _sentSinceReset = false;
        }
        _notify();
      }
    } on MissingPluginException {
      problem = RecognitionProblem.unsupported;
      status = RecognitionStatus.error;
      await stopAnalysis();
    } catch (e) {
      debugPrint('Image ignorée : $e');
    } finally {
      _extracting = false;
    }
  }

  /// Les 126 dernières valeurs sont les deux mains (21 points × 3 chacune).
  static bool _hasHands(List<num> keypoints) {
    for (var i = keypoints.length - 126; i < keypoints.length; i++) {
      if (keypoints[i] != 0) return true;
    }
    return false;
  }

  /// Convertit l'image caméra en NV21 (format attendu côté Android).
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
    final pixelStride = u.bytesPerPixel ?? 1;
    for (var row = 0; row < height ~/ 2; row++) {
      for (var col = 0; col < width ~/ 2; col++) {
        final offset = row * u.bytesPerRow + col * pixelStride;
        out[index++] = v.bytes[offset];
        out[index++] = u.bytes[offset];
      }
    }
    return out;
  }

  void _emit(String label, double? score) {
    // Le serveur répond à chaque image : un même signe maintenu n'est
    // ajouté qu'une fois.
    final now = DateTime.now();
    if (label == _lastEmitted &&
        _lastEmittedAt != null &&
        now.difference(_lastEmittedAt!) < const Duration(seconds: 3)) {
      _lastEmittedAt = now;
      return;
    }
    _lastEmitted = label;
    _lastEmittedAt = now;
    uncertain = null;
    final start = _signStart;
    latency = start == null ? null : now.difference(start);
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

  void _onPrediction(EchoSignPrediction prediction) {
    // Réponses reçues après la fin du geste : ignorées.
    if (!handsVisible) return;
    final label = prediction.label;
    bufferFill = prediction.bufferFill ?? bufferFill;
    if (label != null && label.isNotEmpty) {
      _emit(EchoSignApiClient.displayLabel(label).toUpperCase(),
          prediction.confidence);
    } else {
      final guess = prediction.belowThreshold ? prediction.bestGuess : null;
      uncertain = guess == null
          ? null
          : (
              label: EchoSignApiClient.displayLabel(guess.label),
              score: guess.score
            );
      _notify();
    }
  }

  /// Accepte l'hypothèse incertaine proposée par le modèle.
  void acceptUncertain() {
    final guess = uncertain;
    if (guess != null) _emit(guess.label.toUpperCase(), guess.score);
  }

  @override
  void dispose() {
    _disposed = true;
    _predictions?.cancel();
    _api?.dispose();
    final controller = camera;
    if (_streaming && controller != null) {
      controller.stopImageStream().catchError((Object _) {});
    }
    controller?.dispose();
    _results.close();
    super.dispose();
  }
}

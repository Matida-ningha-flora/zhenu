import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Réponse du modèle EchoSign (WebSocket `/ws/recognize` ou
/// `POST /predict/sequence`).
class EchoSignPrediction {
  /// Signe reconnu, ou `null` tant que la séquence est incomplète ou que la
  /// confiance est sous le seuil du serveur.
  final String? label;
  final double? confidence;
  final List<Map<String, dynamic>> topPredictions;
  final int? bufferFill;
  final bool ready;
  final bool belowThreshold;

  const EchoSignPrediction({
    required this.label,
    required this.confidence,
    required this.topPredictions,
    required this.bufferFill,
    required this.ready,
    this.belowThreshold = false,
  });

  factory EchoSignPrediction.fromJson(Map<String, dynamic> json) {
    // Le serveur renvoie `top3` ({label, score}) ; l'ancien format utilisait
    // `top_predictions` ({label, confidence}).
    final rawTop = json['top3'] ?? json['top_predictions'];
    final top = rawTop is List
        ? rawTop.whereType<Map>().map((item) {
            final map = Map<String, dynamic>.from(item);
            map['score'] ??= map['confidence'];
            return map;
          }).toList()
        : <Map<String, dynamic>>[];
    return EchoSignPrediction(
      label: json['label'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      topPredictions: top,
      bufferFill: (json['buffer_fill'] as num?)?.toInt(),
      ready: json['ready'] == true || json['label'] != null,
      belowThreshold: json['below_threshold'] == true,
    );
  }

  /// Meilleure hypothèse, même sous le seuil de confiance.
  ({String label, double score})? get bestGuess {
    if (topPredictions.isEmpty) return null;
    final first = topPredictions.first;
    final label = first['label'] as String?;
    if (label == null) return null;
    return (label: label, score: (first['score'] as num?)?.toDouble() ?? 0);
  }
}

/// État du serveur renvoyé par `GET /health`.
class EchoSignHealth {
  final bool online;
  final bool modelLoaded;
  final int signCount;
  final Duration latency;

  const EchoSignHealth({
    required this.online,
    required this.modelLoaded,
    required this.signCount,
    required this.latency,
  });
}

class EchoSignApiClient {
  static const int frameSize = 1692;
  static const int sequenceLength = 30;

  final Uri endpoint;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final StreamController<EchoSignPrediction> _predictions =
      StreamController<EchoSignPrediction>.broadcast();
  int _sentFrameCount = 0;
  DateTime? _pendingSince;

  EchoSignApiClient({String endpoint = 'ws://127.0.0.1:8000/ws/recognize'})
      : endpoint = Uri.parse(endpoint);

  Stream<EchoSignPrediction> get predictions => _predictions.stream;
  bool get isConnected => _channel != null;
  int get sentFrameCount => _sentFrameCount;

  /// Une image a été envoyée et le serveur n'a pas encore répondu.
  /// On n'envoie pas l'image suivante avant sa réponse : le délai de
  /// reconnaissance reste ainsi borné même si le serveur est lent.
  bool get awaitingReply {
    final since = _pendingSince;
    if (since == null) return false;
    // Sécurité : une réponse perdue ne bloque pas le flux indéfiniment.
    if (DateTime.now().difference(since) > const Duration(seconds: 5)) {
      _pendingSince = null;
      return false;
    }
    return true;
  }

  /// Adresses à partir de l'adresse du serveur saisie par l'administrateur :
  /// `http://192.168.1.20:8000`, `ws://…/ws/recognize` ou `https://…`.
  static ({Uri websocket, Uri health})? resolve(String address) {
    var value = address.trim();
    if (value.isEmpty) return null;
    if (!value.contains('://')) value = 'http://$value';
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return null;
    final secure = uri.scheme == 'https' || uri.scheme == 'wss';
    if (!['http', 'https', 'ws', 'wss'].contains(uri.scheme)) return null;
    final base = uri.replace(path: '', query: null, fragment: null);
    final wsPath =
        uri.path.isEmpty || uri.path == '/' ? '/ws/recognize' : uri.path;
    return (
      websocket: base.replace(scheme: secure ? 'wss' : 'ws', path: wsPath),
      health: base.replace(scheme: secure ? 'https' : 'http', path: '/health'),
    );
  }

  /// Interroge `GET /health` ; renvoie `null` si le serveur est injoignable.
  static Future<EchoSignHealth?> checkHealth(String address,
      {http.Client? client}) async {
    final urls = resolve(address);
    if (urls == null) return null;
    final started = DateTime.now();
    final httpClient = client ?? http.Client();
    try {
      final response =
          await httpClient.get(urls.health).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return EchoSignHealth(
        online: json['status'] == 'ok',
        modelLoaded: json['model_loaded'] == true,
        signCount: (json['sign_count'] as num?)?.toInt() ?? 0,
        latency: DateTime.now().difference(started),
      );
    } catch (_) {
      return null;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Glose du modèle ➜ texte lisible : « A_BIENTOT » ➜ « A BIENTOT »,
  /// « ADAPTER-NEG » ➜ « ADAPTER (NÉGATION) ».
  static String displayLabel(String gloss) {
    var value = gloss.trim();
    var negation = false;
    if (value.toUpperCase().endsWith('-NEG')) {
      negation = true;
      value = value.substring(0, value.length - 4);
    }
    // Variantes internes du jeu de données (« ACCEPTER_2M »).
    value = value.replaceAll(RegExp(r'_\d+M$'), '');
    value = value
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return negation ? '$value (NÉGATION)' : value;
  }

  Future<void> connect() async {
    if (isConnected) return;

    final channel = WebSocketChannel.connect(endpoint);
    _channel = channel;
    _sentFrameCount = 0;
    _pendingSince = null;
    _subscription = channel.stream.listen(
      (message) {
        _pendingSince = null;
        final decoded = jsonDecode(message as String);
        if (decoded is Map<String, dynamic>) {
          _predictions.add(EchoSignPrediction.fromJson(decoded));
        }
      },
      onError: _predictions.addError,
      onDone: disconnect,
    );
    await channel.ready;
  }

  Future<void> sendKeypoints(List<num> keypoints) async {
    if (keypoints.length != frameSize) {
      throw ArgumentError.value(
        keypoints.length,
        'keypoints',
        'Each frame must contain exactly $frameSize values.',
      );
    }
    if (!isConnected) {
      throw StateError('EchoSign WebSocket is not connected.');
    }

    _channel!.sink.add(jsonEncode({'keypoints': keypoints}));
    _pendingSince = DateTime.now();
    _sentFrameCount++;
  }

  /// Vide le buffer du serveur entre deux signes (commande `reset`).
  Future<void> reset() async {
    if (!isConnected) return;
    _channel!.sink.add(jsonEncode({'reset': true}));
    _pendingSince = DateTime.now();
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _sentFrameCount = 0;
    _pendingSince = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _predictions.close();
  }
}

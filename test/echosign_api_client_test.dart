import 'package:flutter_test/flutter_test.dart';
import 'package:zhendu_app/data/services/echosign_api_client.dart';

/// Test en direct contre le serveur (désactivé par défaut) :
/// flutter test test/echosign_api_client_test.dart --dart-define=ECHOSIGN_LIVE=http://localhost:8000
const _live = String.fromEnvironment('ECHOSIGN_LIVE');

void main() {
  test('rejects frames that do not contain 1692 keypoints', () async {
    final client = EchoSignApiClient();

    expect(
      () => client.sendKeypoints(List<num>.filled(1691, 0)),
      throwsArgumentError,
    );

    await client.dispose();
  });

  test('lit le format du serveur (top3, score, seuil)', () {
    final prediction = EchoSignPrediction.fromJson({
      'label': null,
      'confidence': 0.3142,
      'top3': [
        {'label': 'MERCI', 'score': 0.3142},
        {'label': 'PEUX_TU_REPETER', 'score': 0.3006},
        {'label': 'POURQUOI', 'score': 0.0823},
      ],
      'ready': true,
      'buffer_fill': 30,
      'below_threshold': true,
    });

    expect(prediction.label, isNull);
    expect(prediction.belowThreshold, isTrue);
    expect(prediction.topPredictions, hasLength(3));
    expect(prediction.bestGuess!.label, 'MERCI');
    expect(prediction.bestGuess!.score, closeTo(0.3142, 0.0001));
    expect(prediction.bufferFill, 30);
  });

  test('reste compatible avec l’ancien format top_predictions', () {
    final prediction = EchoSignPrediction.fromJson({
      'label': '1',
      'confidence': 0.8427,
      'top_predictions': [
        {'label': '1', 'confidence': 0.8427},
      ],
      'buffer_fill': 30,
    });
    expect(prediction.label, '1');
    expect(prediction.ready, isTrue);
    expect(prediction.bestGuess!.score, closeTo(0.8427, 0.0001));
  });

  test('déduit les adresses depuis l’adresse du serveur', () {
    final lan = EchoSignApiClient.resolve('http://192.168.100.132:8000')!;
    expect(lan.websocket.toString(), 'ws://192.168.100.132:8000/ws/recognize');
    expect(lan.health.toString(), 'http://192.168.100.132:8000/health');

    final bare = EchoSignApiClient.resolve('192.168.1.20:8000')!;
    expect(bare.websocket.toString(), 'ws://192.168.1.20:8000/ws/recognize');

    final secure = EchoSignApiClient.resolve('https://api.exemple.fr')!;
    expect(secure.websocket.toString(), 'wss://api.exemple.fr/ws/recognize');

    final ws = EchoSignApiClient.resolve('ws://10.0.0.2:8000/ws/recognize')!;
    expect(ws.health.toString(), 'http://10.0.0.2:8000/health');

    expect(EchoSignApiClient.resolve(''), isNull);
    expect(EchoSignApiClient.resolve('ftp://x'), isNull);
  });

  test('rend les gloses du modèle lisibles', () {
    expect(EchoSignApiClient.displayLabel('A_BIENTOT'), 'A BIENTOT');
    expect(
        EchoSignApiClient.displayLabel('ACCIDENT_VOITURE'), 'ACCIDENT VOITURE');
    expect(EchoSignApiClient.displayLabel('ACCEPTER_2M'), 'ACCEPTER');
    expect(EchoSignApiClient.displayLabel('ADAPTER-NEG'), 'ADAPTER (NÉGATION)');
    expect(EchoSignApiClient.displayLabel('A-COTE'), 'A COTE');
    expect(EchoSignApiClient.displayLabel('100'), '100');
  });

  group('serveur réel', () {
    test('santé du serveur', () async {
      final health = await EchoSignApiClient.checkHealth(_live);
      expect(health, isNotNull);
      expect(health!.modelLoaded, isTrue);
      expect(health.signCount, greaterThan(0));
      // ignore: avoid_print
      print(
          'Serveur : ${health.signCount} signes, ${health.latency.inMilliseconds} ms');
    });

    test('30 images au rythme du serveur : une prédiction complète', () async {
      final url = EchoSignApiClient.resolve(_live)!.websocket.toString();
      final client = EchoSignApiClient(endpoint: url);
      await client.connect();
      final replies = <EchoSignPrediction>[];
      final times = <int>[];
      final sub = client.predictions.listen(replies.add);
      final frame = List<num>.filled(EchoSignApiClient.frameSize, 0.1);
      for (var i = 0; i < EchoSignApiClient.sequenceLength; i++) {
        final start = DateTime.now();
        await client.sendKeypoints(frame);
        while (client.awaitingReply) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        times.add(DateTime.now().difference(start).inMilliseconds);
      }
      await sub.cancel();
      await client.dispose();
      expect(replies, hasLength(EchoSignApiClient.sequenceLength));
      expect(replies.last.ready, isTrue);
      expect(replies.last.topPredictions, isNotEmpty);
      final full = times.skip(EchoSignApiClient.sequenceLength - 1).first;
      // ignore: avoid_print
      print(
          'Délai par image : ${times.reduce((a, b) => a + b) ~/ times.length} ms '
          '(prédiction complète : $full ms) — meilleure hypothèse : '
          '${replies.last.bestGuess}');
    }, timeout: const Timeout(Duration(minutes: 2)));
  }, skip: _live.isEmpty ? 'serveur non fourni' : false);
}

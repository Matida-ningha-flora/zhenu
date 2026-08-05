import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import '../../core/constants/app_colors.dart';
import '../widgets/hand_skeleton_painter.dart';

class TranslatorScreen extends StatefulWidget {
  final String role;

  const TranslatorScreen({
    super.key,
    required this.role,
  });

  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen>
    with SingleTickerProviderStateMixin {
  late int _translationMode; // 0 = Signes ➔ Voix, 1 = Voix/Texte ➔ Signes, 2 = Sous-titres, 3 = Salon Direct
  bool _isCameraActive = false;
  bool _isCameraStarting = false;
  bool _isScanning = false;
  bool _isConnectedWebSocket = false;
  String _translationResult = '';
  String _status = 'idle'; // 'idle', 'scanning', 'success'

  // Caméra physique
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  // Salon en Direct
  bool _isConnectedToRoom = false;
  String _selectedRoom = 'Salon LSC - Famille';
  final List<Map<String, dynamic>> _roomMessages = [];
  final List<String> _availableRooms = [
    'Salon LSC - Famille',
    'Discussion Médicale (Dr. Diallo)',
    'Cours de Soutien Scolaire LSC'
  ];
  final TextEditingController _chatTextController = TextEditingController();
  Timer? _chatSimulationTimer;
  String _activeAvatarGesture = '';
  bool _isAvatarSigning = false;
  Timer? _avatarGestureTimer;
  bool _isMicrophoneRecording = false;
  
  // Console de logs WebSocket
  List<String> _wsLogs = [
    '[API] Connexion au serveur EchoSign...',
    '[API] Mode démo initialisé.',
    '[IA] Modèle LSC-Cameroon chargé.',
  ];
  Timer? _wsLogTimer;
  bool _showLogs = false; // Toggle pour afficher la console de logs

  // Variables pour le mode sous-titrage
  bool _isSubtitling = false;
  String _subtitlesText = '';
  List<String> _detectedKeywords = [];
  Timer? _subtitlesTimer;
  final List<String> _simulatedSubtitles = [
    "Bonjour ", "tout ", "le ", "monde. ", "Je ", "suis ", "heureux ", "de ", "vous ", "rencontrer. ", 
    "En ", "cas ", "d'urgence, ", "l'application ", "Zhẽnù ", "peut ", "appeler ", "de ", "l'aide ", 
    "et ", "traduire ", "en ", "français. ", "Merci ", "beaucoup ", "pour ", "votre ", "soutien."
  ];

  // Animation pour le squelette de la main
  late AnimationController _animationController;
  
  // Contrôleurs pour la traduction inversée
  final TextEditingController _textInputController = TextEditingController();
  String _reversedTranslationResult = '';
  String _selectedWordForSign = '';
  bool _isRecordingVoice = false;

  // Liste de signes simulés pour la démonstration
  final Map<String, Map<String, dynamic>> _mockSignDatabase = {
    'BONJOUR': {
      'icon': '👋',
      'desc': 'Placez la main droite ouverte près de votre tempe droite, puis déplacez-la vers l\'avant en souriant.',
      'regional': 'LSC (Cameroun) - Signe standard de salutation',
    },
    'MERCI': {
      'icon': '🙏',
      'desc': 'Touchez vos lèvres avec le bout des doigts de votre main plate droite, puis descendez la main vers le bas et vers l\'avant.',
      'regional': 'LSC (Cameroun) - Courant, exprime la gratitude',
    },
    'URGENCE': {
      'icon': '🚨',
      'desc': 'Croisez les poignets devant votre poitrine, puis ouvrez et fermez rapidement vos mains deux fois.',
      'regional': 'LSC (Cameroun) - Utilisé pour signaler un besoin immédiat',
    },
    'AIDE': {
      'icon': '🤝',
      'desc': 'Placez le poing fermé de la main droite sur la paume ouverte de la main gauche, puis soulevez les deux mains ensemble.',
      'regional': 'LSC (Cameroun) - Demander de l\'aide',
    },
  };

  Timer? _simulatedScanTimer;

  @override
  void initState() {
    super.initState();
    _translationMode = widget.role == 'sourd' ? 0 : 1;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _simulatedScanTimer?.cancel();
    _wsLogTimer?.cancel();
    _subtitlesTimer?.cancel();
    _textInputController.dispose();
    _cameraController?.dispose();
    _chatSimulationTimer?.cancel();
    _avatarGestureTimer?.cancel();
    _chatTextController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isCameraStarting = true;
    });
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        final camera = _cameras!.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras!.first,
        );
        _cameraController = CameraController(
          camera,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            _isCameraActive = true;
            _isCameraStarting = false;
          });
        }
      } else {
        throw Exception("Aucune caméra disponible.");
      }
    } catch (e) {
      print("Erreur initialisation caméra physique: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Impossible d'activer la caméra physique ($e). Mode simulé.",
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
        setState(() {
          _isCameraActive = true;
          _isCameraInitialized = false;
          _isCameraStarting = false;
        });
      }
    }
  }

  void _deactivateCamera() {
    _cameraController?.dispose();
    _cameraController = null;
    setState(() {
      _isCameraActive = false;
      _isCameraInitialized = false;
      _isScanning = false;
      _status = 'idle';
      _simulatedScanTimer?.cancel();
    });
  }

  void _startWsLogSimulation() {
    _wsLogTimer?.cancel();
    if (!_isConnectedWebSocket) return;
    _wsLogTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!mounted) return;
      final time = DateTime.now().toIso8601String().substring(11, 19);
      final list = [
        '[$time] [POSE] Landmarks extracted: 21 points (1692 features)',
        '[$time] [INF] LSTM temporal sequence analyzed (window=30)',
        '[$time] [API] Sending landmarks frame...',
        '[$time] [WS] Latency: 14ms',
      ];
      setState(() {
        _wsLogs.add(list[timer.tick % list.length]);
        if (_wsLogs.length > 20) _wsLogs.removeAt(0);
      });
    });
  }

  void _startSubtitling() {
    if (_isSubtitling) {
      _stopSubtitling();
      return;
    }
    setState(() {
      _isSubtitling = true;
      _subtitlesText = '';
      _detectedKeywords = [];
    });

    int wordIndex = 0;
    _subtitlesTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!mounted) return;
      if (wordIndex < _simulatedSubtitles.length) {
        setState(() {
          _subtitlesText += _simulatedSubtitles[wordIndex];
          // Vérifier si le mot correspond à un mot-clé du dictionnaire
          String currentWord = _simulatedSubtitles[wordIndex].replaceAll(RegExp(r'[.,!?\s]'), '').toUpperCase();
          if (_mockSignDatabase.containsKey(currentWord) && !_detectedKeywords.contains(currentWord)) {
            _detectedKeywords.add(currentWord);
          }
          wordIndex++;
        });
      } else {
        _stopSubtitling();
      }
    });
  }

  void _stopSubtitling() {
    _subtitlesTimer?.cancel();
    setState(() {
      _isSubtitling = false;
    });
  }

  void _simulateVoiceInput() {
    setState(() {
      _isRecordingVoice = true;
    });

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(32),
          height: 240,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'RECONNAISSANCE VOCALE ACTIVE',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                'Parlez maintenant...',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              // Waveform animée
              SizedBox(
                height: 60,
                width: double.infinity,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: SoundwavePainter(
                        animationValue: _animationController.value,
                        color: AppColors.primary,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    // Arrêter le micro après 2.5s et renseigner "MERCI"
    Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.pop(context); // Fermer le bottom sheet
      setState(() {
        _isRecordingVoice = false;
        _textInputController.text = 'MERCI';
      });
      _translateReversed();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.mic_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Reconnaissance vocale : "MERCI"',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    });
  }

  void _toggleWebSocket() {
    setState(() {
      _isConnectedWebSocket = !_isConnectedWebSocket;
      if (_isConnectedWebSocket) {
        _status = 'scanning';
        _wsLogs.add('[API] Connexion WebSocket au serveur EchoSign API établie.');
        _startWsLogSimulation();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_done_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Connexion WebSocket au serveur EchoSign API établie.',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      } else {
        _status = 'idle';
        _isScanning = false;
        _simulatedScanTimer?.cancel();
        _wsLogTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_off_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Mode Démo local réactivé.',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    });
  }

  void _startScanning() {
    if (_isScanning) {
      // Arrêter le scan
      setState(() {
        _isScanning = false;
        _status = 'idle';
      });
      _simulatedScanTimer?.cancel();
      return;
    }

    setState(() {
      _isScanning = true;
      _status = 'scanning';
      _translationResult = 'Analyse des mouvements...';
    });

    // Simuler le processus d'inférence de l'IA (idéal pour le jury en concours !)
    int step = 0;
    _simulatedScanTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!mounted) return;

      setState(() {
        if (step == 0) {
          _translationResult = 'Points clés extraits (1692 features)...';
          step++;
        } else if (step == 1) {
          _translationResult = 'Séquence temporelle analysée (LSTM)...';
          step++;
        } else {
          // Choisir un signe au hasard pour simuler une détection réussie
          final keys = _mockSignDatabase.keys.toList();
          final detected = keys[timer.tick % keys.length];
          _translationResult = detected;
          _status = 'success';
          _isScanning = false;
          timer.cancel();
          _triggerTTS(detected);
        }
      });
    });
  }

  // Simuler la lecture audio (Text to Speech)
  void _triggerTTS(String word) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.volume_up_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              'Synthèse Vocale : "$word"',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _translateReversed() {
    final input = _textInputController.text.toUpperCase().trim();
    if (input.isEmpty) return;

    setState(() {
      if (_mockSignDatabase.containsKey(input)) {
        _selectedWordForSign = input;
        _reversedTranslationResult = _mockSignDatabase[input]!['desc'] as String;
      } else {
        _selectedWordForSign = '';
        // Simuler épellation par lettres si le mot n'est pas dans le dictionnaire
        _reversedTranslationResult =
            'Mot non trouvé dans le dictionnaire. Épellation lettre par lettre requise : ' +
                input.split('').join(' - ');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    String titleText = 'Sourd ➔ Entendant';
    if (_translationMode == 1) {
      titleText = 'Entendant ➔ Sourd';
    } else if (_translationMode == 2) {
      titleText = 'Sous-titrage Ambiant';
    } else if (_translationMode == 3) {
      titleText = 'Salon de Discussion Direct';
    }

    final bool isDeaf = widget.role == 'sourd';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          titleText,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isConnectedWebSocket ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              color: _isConnectedWebSocket ? AppColors.success : Colors.grey,
            ),
            tooltip: 'Connexion API WebSocket',
            onPressed: _toggleWebSocket,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Sélecteur de mode conditionnel (3 choix)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  children: isDeaf
                      ? [
                          // Sourd : Signes ➔ Voix (0), Sous-titrage (2), Salon Direct (3)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _translationMode = 0;
                                _reversedTranslationResult = '';
                                _selectedWordForSign = '';
                                _textInputController.clear();
                              }),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: _translationMode == 0 ? AppColors.primaryGradient : null,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: _translationMode == 0
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.25),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          )
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Signes ➔ Voix',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.5,
                                    color: _translationMode == 0 ? Colors.white : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _translationMode = 2;
                                _translationResult = '';
                                _status = 'idle';
                                _isScanning = false;
                                _simulatedScanTimer?.cancel();
                              }),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: _translationMode == 2 ? AppColors.primaryGradient : null,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: _translationMode == 2
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.25),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          )
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Sous-titrage',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.5,
                                    color: _translationMode == 2 ? Colors.white : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _translationMode = 3;
                                _translationResult = '';
                                _status = 'idle';
                                _isScanning = false;
                                _simulatedScanTimer?.cancel();
                              }),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: _translationMode == 3 ? AppColors.primaryGradient : null,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: _translationMode == 3
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.25),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          )
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Salon Direct',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.5,
                                    color: _translationMode == 3 ? Colors.white : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ]
                      : [
                          // Entendant : Voix ➔ Signes (1), Signes ➔ Voix (0), Salon Direct (3)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _translationMode = 1;
                                _translationResult = '';
                                _status = 'idle';
                                _isScanning = false;
                                _simulatedScanTimer?.cancel();
                              }),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: _translationMode == 1 ? AppColors.primaryGradient : null,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: _translationMode == 1
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.25),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          )
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Voix ➔ Signes',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.5,
                                    color: _translationMode == 1 ? Colors.white : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _translationMode = 0;
                                _reversedTranslationResult = '';
                                _selectedWordForSign = '';
                                _textInputController.clear();
                              }),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: _translationMode == 0 ? AppColors.primaryGradient : null,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: _translationMode == 0
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.25),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          )
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Signes ➔ Voix',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.5,
                                    color: _translationMode == 0 ? Colors.white : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _translationMode = 3;
                                _translationResult = '';
                                _status = 'idle';
                                _isScanning = false;
                                _simulatedScanTimer?.cancel();
                              }),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: _translationMode == 3 ? AppColors.primaryGradient : null,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: _translationMode == 3
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.25),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          )
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Salon Direct',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.5,
                                    color: _translationMode == 3 ? Colors.white : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                ),
              ),
            ),

            // Contenu en fonction du mode
            Expanded(
              child: _translationMode == 0
                  ? _buildDeafToHearing()
                  : (_translationMode == 1
                      ? _buildHearingToDeaf()
                      : (_translationMode == 2
                          ? _buildAmbientSubtitles()
                          : _buildLiveChatRoom())),
            ),
          ],
        ),
      ),
    );
  }

  // Écran Traduction Signe -> Voix
  Widget _buildDeafToHearing() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fenêtre Caméra simulée premium
          Container(
            height: 350,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Caméra physique réelle si disponible, sinon gradient
                if (_isCameraInitialized && _cameraController != null)
                  CameraPreview(_cameraController!)
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Color(0xFF1E1B4B), Color(0xFF090514)],
                        radius: 1.2,
                      ),
                    ),
                  ),
                
                if (!_isCameraActive)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isCameraStarting) ...[
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                shape: BoxShape.circle,
                              ),
                              child: const CircularProgressIndicator(
                                color: AppColors.secondary,
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Accès à la caméra...',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Configuration du modèle local LSC...',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white60,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.videocam_off_rounded,
                                color: Colors.white.withOpacity(0.6),
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Caméra inactive',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Vous devez activer la caméra pour capturer et traduire les signes.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white60,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _initializeCamera,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.videocam_rounded, color: Colors.white),
                              label: Text(
                                'ACTIVER LA CAMÉRA',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else ...[
                  // Grille de ciblage caméra
                  CustomPaint(
                    painter: CameraGridPainter(),
                  ),
                  // Dessiner le squelette de main MediaPipe animé
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: HandSkeletonPainter(
                          animationValue: _animationController.value,
                          status: _status,
                        ),
                      );
                    },
                  ),
                  // Laser de scan vertical si en cours
                  if (_isScanning)
                    const Positioned(
                      top: 0, left: 0, right: 0,
                      child: LaserScanLine(),
                    ),
                  // Badges d'état par-dessus la caméra
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: AppColors.error.withOpacity(0.3), blurRadius: 8),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'LIVE CAMERA',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                              ),
                              child: Text(
                                _isConnectedWebSocket ? 'MODÈLE CLOUD' : 'MODÈLE LOCAL TFLITE',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Bouton de désactivation de la caméra
                            IconButton(
                              icon: const Icon(Icons.videocam_off_rounded, color: Colors.white, size: 16),
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.error.withOpacity(0.8),
                                padding: const EdgeInsets.all(8),
                                minimumSize: Size.zero,
                              ),
                              onPressed: _deactivateCamera,
                              tooltip: 'Désactiver la caméra',
                            ),
                          ],
                        ),
                        if (_isConnectedWebSocket) ...[
                          const SizedBox(height: 8),
                          IconButton(
                            icon: Icon(
                              _showLogs ? Icons.terminal_rounded : Icons.terminal_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.12),
                              padding: const EdgeInsets.all(8),
                              minimumSize: Size.zero,
                            ),
                            onPressed: () {
                              setState(() {
                                _showLogs = !_showLogs;
                              });
                            },
                            tooltip: 'Console de logs API',
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Overlay d'informations technologiques (HUD)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHudRow('ENGINE:', 'LSC-Cameroon v2.1'),
                        const SizedBox(height: 2),
                        _buildHudRow('TRACKING:', _isScanning ? 'ACTIVE (21 pts)' : 'STANDBY'),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildHudRow('CONFIDENCE:', _status == 'success' ? '98.4%' : (_isScanning ? '84.2%' : 'N/A')),
                        const SizedBox(height: 2),
                        _buildHudRow('LATENCY:', '14 ms'),
                      ],
                    ),
                  ),

                  // Console de logs WebSocket
                  if (_isConnectedWebSocket && _showLogs)
                    Positioned(
                      bottom: 44,
                      left: 16,
                      right: 16,
                      child: Container(
                        height: 120,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'WS API LIVE STREAM CONSOLE',
                                  style: GoogleFonts.shareTechMono(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.bold),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _showLogs = false),
                                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.white60),
                                )
                              ],
                            ),
                            const Divider(color: Colors.white10, height: 10, thickness: 1),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _wsLogs.length,
                                reverse: true,
                                itemBuilder: (context, idx) {
                                  final log = _wsLogs[_wsLogs.length - 1 - idx];
                                  return Text(
                                    log,
                                    style: GoogleFonts.shareTechMono(fontSize: 8.5, color: Colors.greenAccent),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Bouton d'action principale
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (_isCameraActive
                          ? (_isScanning ? AppColors.error : AppColors.primary)
                          : Colors.grey)
                      .withOpacity(0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _isCameraActive ? _startScanning : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCameraActive
                    ? (_isScanning ? AppColors.error : AppColors.primary)
                    : Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: Icon(
                _isScanning ? Icons.stop_circle_rounded : Icons.videocam_rounded,
                color: Colors.white,
                size: 24,
              ),
              label: Text(
                !_isCameraActive
                    ? 'ACTIVER LA CAMÉRA D\'ABORD'
                    : (_isScanning ? 'ARRÊTER LE SCAN' : 'DÉMARRER LA TRADUCTION'),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Résultat de la traduction
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.grey.shade100, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TRADUCTION EN FRANÇAIS',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade400,
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (_translationResult.isNotEmpty && _status == 'success')
                      IconButton(
                        icon: const Icon(Icons.volume_up_rounded, color: AppColors.primary, size: 22),
                        onPressed: () => _triggerTTS(_translationResult),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(minHeight: 100),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _translationResult.isEmpty
                        ? 'Activez la caméra et effectuez un geste pour voir la traduction ici.'
                        : _translationResult,
                    style: GoogleFonts.poppins(
                      fontSize: (_translationResult.length > 15 || _status == 'scanning') ? 16 : 30,
                      fontWeight: FontWeight.bold,
                      color: _status == 'success' ? AppColors.primary : Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHudRow(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.shareTechMono(fontSize: 11, color: Colors.white38),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: GoogleFonts.shareTechMono(
            fontSize: 11,
            color: Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Écran Traduction Voix/Texte -> Signe
  Widget _buildHearingToDeaf() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Saisie texte et voix
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.grey.shade100, width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'EXPRIMEZ-VOUS (VOIX OU TEXTE)',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade400,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textInputController,
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'Ex: BONJOUR, MERCI, AIDE...',
                          hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          fillColor: AppColors.background,
                        ),
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _translateReversed(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Bouton micro (simulation reconnaissance vocale)
                    IconButton(
                      icon: const Icon(Icons.mic_rounded, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.all(14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                        shadowColor: AppColors.primary.withOpacity(0.3),
                      ),
                      onPressed: _simulateVoiceInput,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _translateReversed,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    backgroundColor: AppColors.primary,
                  ),
                  child: Text('TRADUIRE EN SIGNE', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Résultat traduction inverse
          if (_reversedTranslationResult.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.grey.shade100, width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'REPRÉSENTATION DU GESTE',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade400,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_selectedWordForSign.isNotEmpty &&
                      _mockSignDatabase.containsKey(_selectedWordForSign))
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.06),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primary.withOpacity(0.12), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.05),
                                  blurRadius: 15,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _mockSignDatabase[_selectedWordForSign]!['icon'] as String,
                              style: const TextStyle(fontSize: 66),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _selectedWordForSign,
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _mockSignDatabase[_selectedWordForSign]!['regional'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Instructions du geste :',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _reversedTranslationResult,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAmbientSubtitles() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Explication du mode
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.settings_voice_rounded, color: AppColors.primary, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Le mode sous-titrage ambiant écoute les voix environnantes et affiche le texte en temps réel pour faciliter la conversation.',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Cadre de visualisation de l'audio
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Arrière plan néon/sombre
                Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF020617)],
                      radius: 1.2,
                    ),
                  ),
                ),
                // Soundwave animée
                if (_isSubtitling)
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: SoundwavePainter(
                          animationValue: _animationController.value,
                          color: AppColors.secondary,
                        ),
                      );
                    },
                  )
                else
                  Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mic_none_rounded, color: Colors.white54, size: 24),
                    ),
                  ),

                // Indicateur
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isSubtitling ? AppColors.success.withOpacity(0.9) : Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isSubtitling) ...[
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _isSubtitling ? 'ÉCOUTE ACTIVE' : 'MICRO STANDBY',
                          style: GoogleFonts.poppins(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Bouton micro
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (_isSubtitling ? AppColors.error : AppColors.primary).withOpacity(0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _startSubtitling,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSubtitling ? AppColors.error : AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: Icon(_isSubtitling ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 24),
              label: Text(
                _isSubtitling ? 'ARRÊTER L\'ÉCOUTE' : 'DÉMARRER LE SOUS-TITRAGE',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14.5, color: Colors.white, letterSpacing: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Zone d'affichage du texte transcrit
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.grey.shade100, width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'SOUS-TITRES EN DIRECT',
                  style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5),
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(minHeight: 120),
                  alignment: Alignment.topLeft,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Text(
                    _subtitlesText.isEmpty
                        ? 'Cliquez sur démarrer et parlez pour transcrire la voix ici.'
                        : _subtitlesText,
                    style: GoogleFonts.poppins(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                  ),
                ),
                
                // Mots-clés en signes détectés
                if (_detectedKeywords.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'SIGNES LSC DÉTECTÉS (CLIQUEZ POUR APPRENDRE)',
                    style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _detectedKeywords.map((word) {
                      return ActionChip(
                        onPressed: () {
                          setState(() {
                            _selectedWordForSign = word;
                            _reversedTranslationResult = _mockSignDatabase[word]!['desc'] as String;
                          });
                          // Afficher le bottom sheet d'infos sur le signe
                          _showSignInfoBottomSheet(word);
                        },
                        avatar: Text(_mockSignDatabase[word]!['icon'] as String),
                        label: Text(
                          word,
                          style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        backgroundColor: AppColors.primary.withOpacity(0.08),
                        side: BorderSide(color: AppColors.primary.withOpacity(0.15)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSignInfoBottomSheet(String word) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        final signData = _mockSignDatabase[word]!;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 45, height: 4.5,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(5)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withOpacity(0.12)),
                    ),
                    alignment: Alignment.center,
                    child: Text(signData['icon'] as String, style: const TextStyle(fontSize: 34)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word,
                          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'LSC (Cameroun)',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondaryDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'DESCRIPTION DU GESTE',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Text(
                  signData['desc'] as String,
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade800, height: 1.55),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: Text('COMPRIS', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- METHODES SALON DE DISCUSSION EN DIRECT ---

  Widget _buildLiveChatRoom() {
    if (!_isConnectedToRoom) {
      return _buildRoomSelectionView();
    }
    return _buildActiveChatRoomView();
  }

  Widget _buildRoomSelectionView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withOpacity(0.12)),
            ),
            child: Column(
              children: [
                const Icon(Icons.hub_rounded, color: AppColors.primary, size: 36),
                const SizedBox(height: 12),
                Text(
                  'SALONS DE DISCUSSION DIRECTE',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Discutez en temps réel avec une ou plusieurs personnes. Traduction voix-signe et signe-voix intégrée.',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          
          Text(
            'REJOINDRE UN SALON',
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Choisissez votre salon :',
                    style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedRoom,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary),
                        onChanged: (String? val) {
                          if (val != null) {
                            setState(() {
                              _selectedRoom = val;
                            });
                          }
                        },
                        items: _availableRooms.map((room) {
                          return DropdownMenuItem<String>(
                            value: room,
                            child: Text(room, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _connectToRoom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Text(
                      'SE CONNECTER AU SALON',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _connectToRoom() {
    setState(() {
      _isConnectedToRoom = true;
      _roomMessages.clear();
      _roomMessages.add({
        'sender': 'Système',
        'text': 'Vous avez rejoint le "${_selectedRoom}". Connexion chiffrée établie.',
        'isSystem': true,
      });
    });

    _chatSimulationTimer?.cancel();
    int step = 0;
    _chatSimulationTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (!mounted || !_isConnectedToRoom) {
        timer.cancel();
        return;
      }
      setState(() {
        if (widget.role == 'sourd') {
          if (step == 0) {
            _receiveChatMessage('Maman (Entendant)', 'Coucou ! Comment vas-tu ? Tu as mangé ?');
            step++;
          } else if (step == 1) {
            _receiveChatMessage('Maman (Entendant)', 'Je viens de finir mon travail. Dis-moi si tu as besoin d\'AIDE.');
            step++;
          } else {
            _receiveChatMessage('Maman (Entendant)', 'D\'accord mon chéri. Prends soin de toi. MERCI.');
            timer.cancel();
          }
        } else {
          if (step == 0) {
            _receiveChatMessage('Jean (Sourd)', '[Geste] BONJOUR');
            _triggerTTS('Bonjour');
            step++;
          } else if (step == 1) {
            _receiveChatMessage('Jean (Sourd)', '[Geste] AIDE');
            _triggerTTS('Aide');
            step++;
          } else {
            _receiveChatMessage('Jean (Sourd)', '[Geste] MERCI');
            _triggerTTS('Merci');
            timer.cancel();
          }
        }
      });
    });
  }

  void _receiveChatMessage(String sender, String text) {
    setState(() {
      _roomMessages.add({
        'sender': sender,
        'text': text,
        'isSystem': false,
        'isMe': false,
      });

      if (widget.role == 'sourd') {
        String cleanText = text.toUpperCase();
        String keyword = '';
        if (cleanText.contains('BONJOUR')) {
          keyword = 'BONJOUR';
        } else if (cleanText.contains('MERCI')) {
          keyword = 'MERCI';
        } else if (cleanText.contains('URGENCE')) {
          keyword = 'URGENCE';
        } else if (cleanText.contains('AIDE')) {
          keyword = 'AIDE';
        }

        if (keyword.isNotEmpty) {
          _activeAvatarGesture = keyword;
          _isAvatarSigning = true;
          _avatarGestureTimer?.cancel();
          _avatarGestureTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) {
              setState(() {
                _isAvatarSigning = false;
                _activeAvatarGesture = '';
              });
            }
          });
        }
      }
    });
  }

  void _disconnectFromRoom() {
    _chatSimulationTimer?.cancel();
    _avatarGestureTimer?.cancel();
    _deactivateCamera();
    setState(() {
      _isConnectedToRoom = false;
      _roomMessages.clear();
      _isMicrophoneRecording = false;
      _isAvatarSigning = false;
      _activeAvatarGesture = '';
    });
  }

  void _sendChatMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _roomMessages.add({
        'sender': widget.role == 'sourd' ? 'Moi (Sourd)' : 'Moi (Entendant)',
        'text': text,
        'isSystem': false,
        'isMe': true,
      });
    });
  }

  Widget _buildActiveChatRoomView() {
    final bool isDeaf = widget.role == 'sourd';
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
                onPressed: _disconnectFromRoom,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedRoom,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isDeaf
                              ? 'Connecté avec Maman (Entendant)'
                              : 'Connecté avec Jean (Sourd)',
                          style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                onPressed: _disconnectFromRoom,
                tooltip: 'Quitter le salon',
              ),
            ],
          ),
        ),

        if (isDeaf) _buildAvatarInterpreterCard(),

        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                itemCount: _roomMessages.length,
                itemBuilder: (context, idx) {
                  final msg = _roomMessages[idx];
                  final bool isSystem = msg['isSystem'] ?? false;
                  if (isSystem) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          msg['text']!,
                          style: GoogleFonts.shareTechMono(fontSize: 10, color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final bool isMe = msg['isMe'] ?? false;
                  final text = msg['text']!;
                  final bool isGesture = text.startsWith('[Geste]');

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(14),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      decoration: BoxDecoration(
                        color: isMe
                            ? AppColors.primary
                            : (isGesture ? AppColors.secondary.withOpacity(0.12) : Colors.white),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isMe ? 20 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 20),
                        ),
                        border: isMe ? null : Border.all(color: Colors.grey.shade100),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg['sender']!,
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isMe
                                  ? Colors.white70
                                  : (isGesture ? AppColors.secondaryDark : Colors.grey.shade500),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (isGesture)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _getGestureEmoji(text),
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  text.replaceAll('[Geste] ', ''),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    color: isMe ? Colors.white : AppColors.secondaryDark,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              text,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                color: isMe ? Colors.white : Colors.black87,
                                height: 1.4,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              if (isDeaf)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () {
                      if (_isCameraActive) {
                        _deactivateCamera();
                      } else {
                        _initializeCamera();
                      }
                    },
                    child: Container(
                      width: 90,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isCameraActive ? AppColors.secondary : Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_isCameraActive && _isCameraInitialized && _cameraController != null)
                            CameraPreview(_cameraController!)
                          else
                            Container(
                              color: Colors.grey.shade900,
                              alignment: Alignment.center,
                              child: Icon(
                                _isCameraStarting ? Icons.sync : Icons.videocam_off_rounded,
                                color: Colors.white60,
                                size: 24,
                              ),
                            ),
                          Positioned(
                            bottom: 4, left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _isCameraActive ? 'LIVE' : 'OFF',
                                style: GoogleFonts.poppins(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade100)),
          ),
          child: SafeArea(
            top: false,
            child: isDeaf
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'SIGNES RAPIDES (CAPTURE CAMERA EN DIRECT) :',
                        style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['BONJOUR', 'MERCI', 'URGENCE', 'AIDE'].map((word) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                onPressed: () {
                                  _sendChatMessage('[Geste] $word');
                                  Timer(const Duration(seconds: 3), () {
                                    if (mounted && _isConnectedToRoom) {
                                      _receiveChatMessage('Maman (Entendant)', 'D\'accord, j\'ai bien reçu le signe $word !');
                                    }
                                  });
                                },
                                avatar: Text(_mockSignDatabase[word]!['icon'] as String),
                                label: Text(
                                  word,
                                  style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.secondaryDark),
                                ),
                                backgroundColor: AppColors.secondary.withOpacity(0.08),
                                side: BorderSide(color: AppColors.secondary.withOpacity(0.15)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextField(
                                  controller: _chatTextController,
                                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                                  decoration: InputDecoration(
                                    hintText: 'Écrire un message...',
                                    hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onSubmitted: (val) {
                                    if (val.trim().isNotEmpty) {
                                      _sendChatMessage(val);
                                      _chatTextController.clear();
                                    }
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.send_rounded, color: AppColors.primary, size: 20),
                                onPressed: () {
                                  if (_chatTextController.text.trim().isNotEmpty) {
                                    _sendChatMessage(_chatTextController.text);
                                    _chatTextController.clear();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          _isMicrophoneRecording ? Icons.stop_circle_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: _isMicrophoneRecording ? AppColors.error : AppColors.primary,
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        onPressed: _toggleLiveChatVoiceInput,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarInterpreterCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: (_isAvatarSigning ? AppColors.secondary : AppColors.primary).withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: (_isAvatarSigning ? AppColors.secondary : AppColors.primary).withOpacity(0.15),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _isAvatarSigning
                  ? (_mockSignDatabase[_activeAvatarGesture]!['icon'] as String)
                  : '🤟',
              style: TextStyle(fontSize: _isAvatarSigning ? 32 : 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INTERPRÈTE LSC VIRTUEL',
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: _isAvatarSigning ? AppColors.secondaryDark : AppColors.primary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isAvatarSigning
                      ? 'Signe en cours : "${_activeAvatarGesture}"'
                      : 'Prêt. L\'interprète traduira en direct ce qui est dit.',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: _isAvatarSigning ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
                if (_isAvatarSigning) ...[
                  const SizedBox(height: 2),
                  Text(
                    _mockSignDatabase[_activeAvatarGesture]!['desc'] as String,
                    style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade500, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGestureEmoji(String text) {
    String word = text.replaceAll('[Geste] ', '').toUpperCase().trim();
    if (_mockSignDatabase.containsKey(word)) {
      return _mockSignDatabase[word]!['icon'] as String;
    }
    return '👋';
  }

  void _toggleLiveChatVoiceInput() {
    if (_isMicrophoneRecording) {
      setState(() {
        _isMicrophoneRecording = false;
      });
      return;
    }

    setState(() {
      _isMicrophoneRecording = true;
    });

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(32),
          height: 240,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ENREGISTREMENT VOCAL EN DIRECT',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                'Parlez maintenant à votre interlocuteur...',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 60,
                width: double.infinity,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: SoundwavePainter(
                        animationValue: _animationController.value,
                        color: AppColors.primary,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.pop(context);
      setState(() {
        _isMicrophoneRecording = false;
      });
      
      _sendChatMessage("Coucou Jean, as-tu besoin d'aide ?");
      
      Timer(const Duration(seconds: 3), () {
        if (mounted && _isConnectedToRoom) {
          _receiveChatMessage('Jean (Sourd)', '[Geste] AIDE');
          _triggerTTS('Aide');
        }
      });
    });
  }
}

class SoundwavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  SoundwavePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final double width = size.width;
    final double height = size.height;
    final double centerY = height / 2;
    const int barCount = 19;
    final double spacing = width / (barCount + 1);

    for (int i = 0; i < barCount; i++) {
      final double progress = i / barCount;
      final double waveFactor = sin(animationValue * pi * 4 + progress * pi * 5);
      final double barHeight = (centerY * 0.7) * (waveFactor.abs() * 0.7 + 0.3);
      final double x = spacing * (i + 1);
      canvas.drawLine(
        Offset(x, centerY - barHeight),
        Offset(x, centerY + barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SoundwavePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue || oldDelegate.color != color;
}

// Dessine les cibles géométriques sur la caméra
class CameraGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Lignes verticales
    canvas.drawLine(Offset(size.width * 0.33, 0), Offset(size.width * 0.33, size.height), paint);
    canvas.drawLine(Offset(size.width * 0.66, 0), Offset(size.width * 0.66, size.height), paint);

    // Lignes horizontales
    canvas.drawLine(Offset(0, size.height * 0.33), Offset(size.width, size.height * 0.33), paint);
    canvas.drawLine(Offset(0, size.height * 0.66), Offset(size.width, size.height * 0.66), paint);

    // Coins de centrage
    final cornerPaint = Paint()
      ..color = AppColors.secondary.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    const len = 24.0;
    const margin = 28.0;

    // Haut Gauche
    canvas.drawLine(const Offset(margin, margin), const Offset(margin + len, margin), cornerPaint);
    canvas.drawLine(const Offset(margin, margin), const Offset(margin, margin + len), cornerPaint);

    // Haut Droite
    canvas.drawLine(Offset(size.width - margin, margin), Offset(size.width - margin - len, margin), cornerPaint);
    canvas.drawLine(Offset(size.width - margin, margin), Offset(size.width - margin, margin + len), cornerPaint);

    // Bas Gauche
    canvas.drawLine(Offset(margin, size.height - margin), Offset(margin + len, size.height - margin), cornerPaint);
    canvas.drawLine(Offset(margin, size.height - margin), Offset(margin, size.height - margin - len), cornerPaint);

    // Bas Droite
    canvas.drawLine(Offset(size.width - margin, size.height - margin), Offset(size.width - margin - len, size.height - margin), cornerPaint);
    canvas.drawLine(Offset(size.width - margin, size.height - margin), Offset(size.width - margin, size.height - margin - len), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Laser animatif de scan
class LaserScanLine extends StatefulWidget {
  const LaserScanLine({super.key});

  @override
  State<LaserScanLine> createState() => _LaserScanLineState();
}

class _LaserScanLineState extends State<LaserScanLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          margin: EdgeInsets.only(top: _controller.value * 347),
          height: 3,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.secondary.withOpacity(0.1),
                AppColors.secondary,
                AppColors.secondary.withOpacity(0.1),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withOpacity(0.8),
                blurRadius: 10,
                spreadRadius: 1.5,
              ),
            ],
          ),
        );
      },
    );
  }
}

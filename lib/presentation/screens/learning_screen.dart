import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/learning_data_service.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> with TickerProviderStateMixin {
  // Navigation active tab (0: Parcours par Modules, 1: Atelier Caméra IA, 2: Flashcards, 3: Quiz)
  int _activeSubTab = 0;

  // Données dynamiques
  List<Map<String, dynamic>> _courses = [];
  Map<String, dynamic> _userStats = {};
  bool _isLoading = true;

  // Vue du Module actif & Feuille de Route à étapes
  Map<String, dynamic>? _activeCourse;
  Map<String, dynamic>? _activeStep;
  int _currentSignIndexInStep = 0;

  // Modificateurs de Lecteur Vidéo Démonstratif LSC
  bool _isVideoPlaying = true;
  double _videoSpeed = 1.0; // 0.5x ou 1.0x
  bool _isLooping = true;

  // Mode Test Caméra IA Obligatoire & Pratique Libre
  String _selectedPracticeSign = 'BONJOUR';
  bool _isCameraActive = false;
  bool _isAiDetecting = false;
  double _aiConfidence = 0.0;
  String _aiFeedbackMessage = 'Positionnez votre main devant la caméra pour passer le test.';
  Timer? _detectionTimer;

  // Mode Flashcards
  int _currentFlashcardIndex = 0;
  bool _isFlashcardFlipped = false;
  int _masteredCardsCount = 0;

  // Mode Quiz
  bool _isInQuiz = false;
  int _currentQuestionIndex = 0;
  int _quizScore = 0;
  String? _selectedQuizAnswer;
  bool _quizAnswered = false;
  List<Map<String, dynamic>> _activeQuizQuestions = [];

  // Confetti Animation controllers
  late AnimationController _confettiController;
  final List<ConfettiParticle> _confettiParticles = [];

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _loadData();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _detectionTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final courses = await LearningDataService.getCourses();
    final stats = await LearningDataService.getUserStats();
    if (mounted) {
      setState(() {
        _courses = courses;
        _userStats = stats;
        _isLoading = false;
        _prepareQuizQuestions();
      });
    }
  }

  void _prepareQuizQuestions() {
    final List<Map<String, dynamic>> allQuestions = [];
    for (var c in _courses) {
      final steps = List<Map<String, dynamic>>.from(c['steps'] ?? []);
      for (var s in steps) {
        final quiz = List<Map<String, dynamic>>.from(s['quizQuestions'] ?? []);
        allQuestions.addAll(quiz);
      }
    }
    _activeQuizQuestions = allQuestions.isNotEmpty
        ? allQuestions
        : [
            {
              'question': 'Quel geste correspond au signe "MERCI" en Langue des Signes Camerounaise ?',
              'options': [
                'Croiser les mains sur la poitrine.',
                'Toucher ses lèvres avec les doigts plats puis descendre la main vers l\'avant.',
                'Frotter son ventre avec la main ouverte.',
                'Lever le pouce vers le haut en souriant.'
              ],
              'answer': 'Toucher ses lèvres avec les doigts plats puis descendre la main vers l\'avant.',
              'hint': 'Ce signe utilise la main dominante partant de la bouche.'
            },
          ];
  }

  void _generateConfetti() {
    final random = math.Random();
    _confettiParticles.clear();
    for (int i = 0; i < 70; i++) {
      final double angle = random.nextDouble() * 2 * math.pi;
      final double speed = 0.05 + random.nextDouble() * 0.25;
      _confettiParticles.add(
        ConfettiParticle(
          x: 0.5 * MediaQuery.of(context).size.width,
          y: 0.4 * MediaQuery.of(context).size.height,
          color: [
            Colors.amber, Colors.redAccent, Colors.blueAccent,
            Colors.greenAccent, Colors.pinkAccent, Colors.orangeAccent
          ][random.nextInt(6)],
          size: 6 + random.nextDouble() * 10,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed - 0.15,
          rotation: random.nextDouble() * math.pi,
          rotationSpeed: (random.nextDouble() - 0.5) * 8,
        ),
      );
    }
    _confettiController.forward(from: 0.0);
  }

  // --- OUVERTURE D'UNE ÉTAPE DU MODULE ---
  void _openStep(Map<String, dynamic> step) {
    if (step['isUnlocked'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Étape verrouillée 🔒 ! Réussissez le test caméra ou l\'étape précédente pour la débloquer.',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _activeStep = step;
      _currentSignIndexInStep = 0;
      _isCameraActive = false;
      _aiConfidence = 0.0;
      _aiFeedbackMessage = 'Positionnez votre main devant la caméra pour valider.';
    });
  }

  // --- VALIDATION D'UNE ÉTAPE ET DÉBLOCAGE DE LA SUIVANTE ---
  void _completeActiveStep() async {
    if (_activeCourse == null || _activeStep == null) return;

    final courseId = _activeCourse!['id'] as String;
    final stepId = _activeStep!['id'] as String;
    final xpReward = _activeCourse!['xpReward'] as int? ?? 50;

    final updatedStats = await LearningDataService.completeStepAndUnlockNext(courseId, stepId, xpReward);
    _generateConfetti();

    if (mounted) {
      setState(() {
        _userStats = updatedStats;
      });
      await _loadData();

      // Mettre à jour l'instance active du cours pour rafraîchir la feuille de route
      final updatedCourse = _courses.firstWhere((c) => c['id'] == courseId, orElse: () => _activeCourse!);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            '🎉 Étape Validée & Suivante Débloquée !',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.primary),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔓', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 12),
              Text(
                'Bravo ! Le test est réussi. L\'étape suivante de la feuille de route est désormais déverrouillée !',
                style: GoogleFonts.inter(color: Colors.grey.shade700, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '+$xpReward XP d\'Expérience Remportés',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF047857), fontSize: 13),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _activeCourse = updatedCourse;
                  _activeStep = null;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('CONTINUER LE PARCOURS', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  // --- EXECUTION DU TEST CAMÉRA IA OBLIGATOIRE ---
  void _runMandatoryCameraTest() {
    if (_isCameraActive) {
      _detectionTimer?.cancel();
      setState(() {
        _isCameraActive = false;
        _isAiDetecting = false;
        _aiConfidence = 0.0;
        _aiFeedbackMessage = 'Test caméra mis en pause.';
      });
    } else {
      setState(() {
        _isCameraActive = true;
        _isAiDetecting = true;
        _aiConfidence = 0.30;
        _aiFeedbackMessage = 'Analyse IA du geste en cours devant la caméra...';
      });

      _detectionTimer = Timer.periodic(const Duration(milliseconds: 550), (timer) {
        if (!mounted) return;
        final random = math.Random();
        setState(() {
          _aiConfidence = math.min(1.0, _aiConfidence + 0.18 + random.nextDouble() * 0.12);
          if (_aiConfidence >= 0.88) {
            _aiFeedbackMessage = '✅ GESTE VALIDÉ À ${(_aiConfidence * 100).toStringAsFixed(1)}% ! FÉLICITATIONS.';
            timer.cancel();
            _isAiDetecting = false;
            _completeActiveStep();
          } else {
            _aiFeedbackMessage = 'Alignement de la main... Tenez la posture bien droite face à l\'objectif.';
          }
        });
      });
    }
  }

  void _addXp(int xp) async {
    final newToday = (_userStats['todayXp'] ?? 0) + xp;
    final newTotal = (_userStats['totalXp'] ?? 0) + xp;
    final updated = {
      ..._userStats,
      'todayXp': newToday,
      'totalXp': newTotal,
    };
    await LearningDataService.saveUserStats(updated);
    if (mounted) {
      setState(() => _userStats = updated);
    }
  }

  // --- CONTROLES QUIZ ---
  void _startQuiz() {
    setState(() {
      _isInQuiz = true;
      _currentQuestionIndex = 0;
      _quizScore = 0;
      _selectedQuizAnswer = null;
      _quizAnswered = false;
    });
  }

  void _submitQuizAnswer(String option) {
    if (_quizAnswered) return;
    final isCorrect = option == _activeQuizQuestions[_currentQuestionIndex]['answer'];
    setState(() {
      _selectedQuizAnswer = option;
      _quizAnswered = true;
      if (isCorrect) {
        _quizScore++;
        _addXp(20);
        _generateConfetti();
      }
    });
  }

  void _nextQuizQuestion() {
    if (_currentQuestionIndex < _activeQuizQuestions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedQuizAnswer = null;
        _quizAnswered = false;
      });
    } else {
      _showQuizResultDialog();
    }
  }

  void _showQuizResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final percent = (_quizScore / _activeQuizQuestions.length) * 100;
        final xpEarned = _quizScore * 20;
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text(
            percent >= 70 ? '🎉 Évaluation Réussie !' : '💪 Continuez d\'apprendre !',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.primary),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Text(
                'Évaluation sur les leçons de LSC complétée.',
                style: GoogleFonts.inter(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$_quizScore/${_activeQuizQuestions.length}',
                  style: GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, color: AppColors.success, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '+$xpEarned XP d\'Expérience Remportés',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF047857), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _isInQuiz = false);
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                backgroundColor: AppColors.primary,
              ),
              child: Text('RETOURNER AU HUB', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_isInQuiz) {
      return _buildQuizLayout();
    }

    if (_activeStep != null) {
      return _buildActiveStepViewer();
    }

    if (_activeCourse != null) {
      return _buildModuleRoadmapView();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Apprentissage LSC Séquentiel',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Actualiser',
            onPressed: _loadData,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              children: [
                // En-tête Gamification (XP, Série de jours)
                _buildGamificationHeader(),

                // Sub-tabs de navigation
                _buildSubTabSelector(),

                // Contenu dynamique selon l'onglet actif
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
                    child: _buildSubTabContent(),
                  ),
                ),
              ],
            ),
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _confettiController,
              builder: (context, child) {
                return CustomPaint(
                  painter: ConfettiPainter(
                    particles: _confettiParticles,
                    animationValue: _confettiController.value,
                  ),
                  child: Container(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- GAMIFICATION HEADER ---
  Widget _buildGamificationHeader() {
    final streakDays = _userStats['streakDays'] ?? 0;
    final level = _userStats['level'] ?? 1;
    final totalXp = _userStats['totalXp'] ?? 0;
    final todayXp = _userStats['todayXp'] ?? 0;
    final double todayXpNum = ((_userStats['todayXp'] as num?) ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Text(
                          '$streakDays Jours',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange.shade900),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: AppColors.primary, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Niveau $level',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: AppColors.success, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$totalXp XP Total',
                      style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF047857)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Objectif quotidien : $todayXp / 100 XP',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
              ),
              Text(
                '${(math.min(todayXpNum / 100.0, 1.0) * 100).toInt()}%',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: math.min(todayXpNum / 100.0, 1.0),
              backgroundColor: Colors.grey.shade100,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 7,
            ),
          ),
        ],
      ),
    );
  }

  // --- SUB TAB SELECTOR ---
  Widget _buildSubTabSelector() {
    final tabs = [
      {'label': '📚 Modules', 'index': 0},
      {'label': '📷 Pratique IA', 'index': 1},
      {'label': '🃏 Flashcards', 'index': 2},
      {'label': '🏆 Quiz', 'index': 3},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: tabs.map((t) {
          final idx = t['index'] as int;
          final isSelected = _activeSubTab == idx;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () => setState(() => _activeSubTab = idx),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    t['label'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- DYNAMIC SUB-TAB CONTENT ---
  Widget _buildSubTabContent() {
    switch (_activeSubTab) {
      case 0:
        return _buildCoursesListTab();
      case 1:
        return _buildAiCameraPracticeTab();
      case 2:
        return _buildFlashcardsTab();
      case 3:
        return _buildQuizTab();
      default:
        return _buildCoursesListTab();
    }
  }

  // --- SUB TAB 0: MODULES LIST ---
  Widget _buildCoursesListTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROGRAMMES D\'ÉTUDE LSC (PARCOURS SÉQUENTIEL)',
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 14),

        ..._courses.map((course) {
          final color = Color(course['colorHex'] as int? ?? 0xFF3B82F6);
          final steps = List<Map<String, dynamic>>.from(course['steps'] ?? []);
          final progress = (course['progress'] as num? ?? 0.0).toDouble();

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: InkWell(
              onTap: () => setState(() => _activeCourse = course),
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: color.withValues(alpha: 0.2)),
                          ),
                          alignment: Alignment.center,
                          child: Text(course['icon'] as String? ?? '📖', style: const TextStyle(fontSize: 26)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      (course['category'] as String? ?? 'Général').toUpperCase(),
                                      style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: color),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '+${course['xpReward']} XP',
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                course['title'] as String? ?? '',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: color, size: 18),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      course['desc'] as String? ?? '',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey.shade100,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${steps.length} Étapes séquentielles',
                          style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '📸 Test Caméra Inclus',
                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  // --- VUE FEUILLE DE ROUTE DU MODULE (ROADMAP A ÉTAPES SÉQUENTIELLES) ---
  Widget _buildModuleRoadmapView() {
    final steps = List<Map<String, dynamic>>.from(_activeCourse!['steps'] ?? []);
    final color = Color(_activeCourse!['colorHex'] as int? ?? 0xFF3B82F6);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _activeCourse!['title'] as String? ?? 'Module LSC',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => setState(() => _activeCourse = null),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Carte En-tête du Module
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Text(_activeCourse!['icon'] as String? ?? '📖', style: const TextStyle(fontSize: 40)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FEUILLE DE ROUTE DU MODULE',
                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _activeCourse!['title'] as String? ?? '',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                        ),
                        Text(
                          'Réussissez chaque étape pour débloquer la suivante.',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'ÉTAPES DU PARCOURS',
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.5),
            ),
            const SizedBox(height: 14),

            // Timeline Séquentielle à Étapes
            ...List.generate(steps.length, (idx) {
              final step = steps[idx];
              final isUnlocked = step['isUnlocked'] == true;
              final isCompleted = step['isCompleted'] == true;
              final isCameraTest = step['type'] == 'camera_test';
              final isQuiz = step['type'] == 'quiz';

              Color badgeColor = Colors.grey.shade300;
              IconData badgeIcon = Icons.lock_rounded;

              if (isCompleted) {
                badgeColor = AppColors.success;
                badgeIcon = Icons.check_rounded;
              } else if (isUnlocked) {
                badgeColor = isCameraTest ? AppColors.secondary : AppColors.primary;
                badgeIcon = isCameraTest ? Icons.camera_front_rounded : (isQuiz ? Icons.help_outline_rounded : Icons.play_arrow_rounded);
              }

              return Column(
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isUnlocked ? (isCompleted ? AppColors.success : color) : Colors.grey.shade200,
                        width: isUnlocked ? 1.5 : 1,
                      ),
                    ),
                    color: isUnlocked ? Colors.white : Colors.grey.shade50,
                    child: InkWell(
                      onTap: () => _openStep(step),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: badgeColor.withValues(alpha: 0.15),
                              child: Icon(badgeIcon, color: badgeColor, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'ÉTAPE ${step['stepNumber'] ?? idx + 1}',
                                        style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.bold, color: badgeColor),
                                      ),
                                      const SizedBox(width: 8),
                                      if (isCameraTest)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.secondary.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'TEST CAMÉRA OBLIGATOIRE',
                                            style: GoogleFonts.poppins(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.secondary),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    step['title'] as String? ?? '',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: isUnlocked ? Colors.black87 : Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isUnlocked
                                        ? (isCompleted ? '✅ Étape validée (+XP)' : '👉 Cliquez pour démarrer')
                                        : '🔒 Bloqué - Réussissez l\'étape précédente',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: isUnlocked ? (isCompleted ? AppColors.success : color) : Colors.grey.shade400,
                                      fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isUnlocked ? Icons.chevron_right_rounded : Icons.lock_outline_rounded,
                              color: isUnlocked ? color : Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Connecteur visuel entre les étapes
                  if (idx < steps.length - 1)
                    Container(
                      width: 3,
                      height: 24,
                      color: isCompleted ? AppColors.success : Colors.grey.shade300,
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // --- VISUALISEUR D'ÉTAPE ACTIVE (VIDÉO LSC OU TEST CAMÉRA) ---
  Widget _buildActiveStepViewer() {
    final isCameraTest = _activeStep!['type'] == 'camera_test';
    final isQuizStep = _activeStep!['type'] == 'quiz';

    if (isQuizStep) {
      return _buildQuizLayout();
    }

    if (isCameraTest) {
      return _buildMandatoryCameraTestViewer();
    }

    // Sinon: Étape de Découverte avec Lecteur Vidéo & Démonstration
    final signs = List<Map<String, dynamic>>.from(_activeStep!['signs'] ?? []);
    if (signs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Étape')),
        body: const Center(child: Text('Aucun signe associé à cette étape.')),
      );
    }

    final sign = signs[_currentSignIndexInStep];
    final stepsGuide = List<String>.from(sign['steps'] ?? []);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _activeStep!['title'] as String? ?? 'Démonstration Vidéo LSC',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => setState(() => _activeStep = null),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Barre de progression dans l'étape
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SIGNE ${_currentSignIndexInStep + 1}/${signs.length} : ${sign['word']}',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      Text(
                        sign['variant'] ?? 'LSC Standard',
                        style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_currentSignIndexInStep + 1) / signs.length,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LECTEUR VIDÉO DÉMONSTRATIF INTERACTIF LSC
                    Container(
                      height: 230,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Simulation flux vidéo HD avec animation de mouvement
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white30),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    sign['emoji'] ?? '🤟',
                                    style: const TextStyle(fontSize: 48),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'DÉMONSTRATION VIDÉO HD LSC',
                                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                ),
                                Text(
                                  'Geste : ${sign['word']}',
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),

                          // Contrôles du Lecteur Vidéo (Play/Pause, Ralenti 0.5x, Boucle)
                          Positioned(
                            bottom: 12,
                            left: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(_isVideoPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
                                        onPressed: () => setState(() => _isVideoPlaying = !_isVideoPlaying),
                                      ),
                                      Text(
                                        _isVideoPlaying ? 'LECTURE EN COURS' : 'PAUSE',
                                        style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      // Bouton Vitesse Ralentie
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _videoSpeed = _videoSpeed == 1.0 ? 0.5 : 1.0;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _videoSpeed == 0.5 ? AppColors.primary : Colors.white24,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${_videoSpeed}x RALENTI',
                                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: Icon(Icons.loop_rounded, color: _isLooping ? AppColors.primary : Colors.white54, size: 20),
                                        onPressed: () => setState(() => _isLooping = !_isLooping),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Explication exacte du geste
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DESCRIPTION DU GESTE :',
                              style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              sign['description'] ?? '',
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade800, height: 1.45),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Guide Pas-à-pas
                    if (stepsGuide.isNotEmpty)
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DÉCOMPOSITION DU MOUVEMENT :',
                                style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 10),
                              ...stepsGuide.map((st) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(st, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade800)),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Navigation bas de vidéo
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Row(
                children: [
                  if (_currentSignIndexInStep > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => setState(() => _currentSignIndexInStep--),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentSignIndexInStep < signs.length - 1) {
                          setState(() => _currentSignIndexInStep++);
                        } else {
                          _completeActiveStep();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _currentSignIndexInStep < signs.length - 1 ? 'SIGNE SUIVANT' : 'VALIDER ET ACCÉDER AU TEST CAMÉRA 📸',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ÉCRAN DE TEST CAMÉRA IA OBLIGATOIRE ---
  Widget _buildMandatoryCameraTestViewer() {
    final requiredSign = _activeStep!['requiredCameraSign'] ?? 'BONJOUR';
    final instruction = _activeStep!['instruction'] ?? 'Activez votre caméra et effectuez le signe.';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '📸 Test Caméra IA Obligatoire',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => setState(() => _activeStep = null),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                color: AppColors.secondary.withValues(alpha: 0.1),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.camera_front_rounded, color: AppColors.secondary, size: 24),
                          const SizedBox(width: 10),
                          Text(
                            'CONSIGNE DU TEST :',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.secondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        instruction,
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.black87, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'SIGNE CIBLE : $requiredSign',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // VISEUR CAMÉRA IA SIMULÉ
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _isCameraActive ? AppColors.success : Colors.grey.shade800,
                      width: 2.5,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_isCameraActive) ...[
                        CustomPaint(
                          painter: HandKeypointsPainter(confidence: _aiConfidence),
                        ),
                        Center(
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.7), width: 2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ] else
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam_off_outlined, color: Colors.grey.shade600, size: 56),
                              const SizedBox(height: 12),
                              Text(
                                'Caméra Inactive',
                                style: GoogleFonts.poppins(color: Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Cliquez ci-dessous pour déclencher le test IA.',
                                style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),

                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                color: _isCameraActive ? Colors.greenAccent : Colors.redAccent,
                                size: 10,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isCameraActive
                                    ? (_isAiDetecting ? 'ANALYSE IA DU GESTE' : 'VALIDÉ ✅')
                                    : 'ATTENTE D\'ACTIVATION',
                                style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Barre de précision
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('SCORE DE CONFIANCE IA :', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                          Text(
                            '${(_aiConfidence * 100).toStringAsFixed(1)}%',
                            style: GoogleFonts.shareTechMono(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _aiConfidence >= 0.85 ? AppColors.success : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _aiConfidence,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(_aiConfidence >= 0.85 ? AppColors.success : AppColors.primary),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_aiFeedbackMessage, style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              ElevatedButton.icon(
                onPressed: _runMandatoryCameraTest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCameraActive ? AppColors.error : AppColors.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                icon: Icon(_isCameraActive ? Icons.stop_rounded : Icons.camera_front_rounded, color: Colors.white),
                label: Text(
                  _isCameraActive ? 'ARRÊTER LE TEST' : 'ACTIVATION DE LA CAMÉRA (LANCER LE TEST)',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SUB TAB 1: PRATIQUE LIBRE CAMÉRA IA ---
  Widget _buildAiCameraPracticeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.camera_front_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ATELIER DE DÉTECTION GESTUELLE IA',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                          ),
                          Text(
                            'Répétez le signe face à votre objectif pour obtenir un feedback immédiat.',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Sélection du signe à pratiquer
                Text(
                  'CHOISISSEZ LE SIGNE À PRATIQUER :',
                  style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['BONJOUR', 'MERCI', 'HÔPITAL', 'NDOLÈ', 'KOSSAM', 'Lettre A'].map((sg) {
                      final isSel = _selectedPracticeSign == sg;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(sg),
                          selected: isSel,
                          selectedColor: AppColors.primary,
                          labelStyle: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isSel ? Colors.white : Colors.black87,
                          ),
                          onSelected: (sel) {
                            if (sel) {
                              setState(() {
                                _selectedPracticeSign = sg;
                                _isCameraActive = false;
                                _aiConfidence = 0.0;
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Viseur Caméra Simulé
        Container(
          height: 270,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isCameraActive ? AppColors.success : Colors.grey.shade800,
              width: 2,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_isCameraActive) ...[
                CustomPaint(
                  painter: HandKeypointsPainter(confidence: _aiConfidence),
                ),
                Center(
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.6), width: 1.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ] else
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_off_outlined, color: Colors.grey.shade600, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Caméra inactive',
                        style: GoogleFonts.poppins(color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        color: _isCameraActive ? Colors.greenAccent : Colors.redAccent,
                        size: 10,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isCameraActive
                            ? (_isAiDetecting ? 'ANALYSE IA EN COURS' : 'SIGNE RECONNU ✅')
                            : 'STANDBY',
                        style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PRÉCISION DU GESTE :',
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                    ),
                    Text(
                      '${(_aiConfidence * 100).toStringAsFixed(1)}%',
                      style: GoogleFonts.shareTechMono(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _aiConfidence >= 0.85 ? AppColors.success : AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _aiConfidence,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _aiConfidence >= 0.85 ? AppColors.success : AppColors.primary,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _aiFeedbackMessage,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        ElevatedButton.icon(
          onPressed: () {
            if (_isCameraActive) {
              _detectionTimer?.cancel();
              setState(() {
                _isCameraActive = false;
                _isAiDetecting = false;
              });
            } else {
              setState(() {
                _isCameraActive = true;
                _isAiDetecting = true;
                _aiConfidence = 0.25;
              });
              _detectionTimer = Timer.periodic(const Duration(milliseconds: 600), (t) {
                if (!mounted) return;
                setState(() {
                  _aiConfidence = math.min(1.0, _aiConfidence + 0.15);
                  if (_aiConfidence >= 0.90) {
                    _aiFeedbackMessage = '✅ Signe $_selectedPracticeSign reconnu avec succès !';
                    _isAiDetecting = false;
                    t.cancel();
                    _generateConfetti();
                    _addXp(15);
                  }
                });
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _isCameraActive ? AppColors.error : AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          icon: Icon(_isCameraActive ? Icons.stop_rounded : Icons.play_arrow_rounded, color: Colors.white),
          label: Text(
            _isCameraActive ? 'ARRÊTER L\'ANALYSE' : 'LANCER LA PRATIQUE CAMÉRA',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    );
  }

  // --- SUB TAB 2: FLASHCARDS ---
  Widget _buildFlashcardsTab() {
    final List<Map<String, String>> cards = [
      {'word': 'BONJOUR', 'emoji': '👋', 'desc': 'Partir du menton avec la main plate ouverte vers l\'avant.', 'variant': 'LSC Standard'},
      {'word': 'MERCI', 'emoji': '🙏', 'desc': 'Toucher ses lèvres avec les doigts plats puis descendre la main.', 'variant': 'LSC Universel'},
      {'word': 'HÔPITAL', 'emoji': '🏥', 'desc': 'Tracez une croix médicale sur le bras avec l\'index et le majeur.', 'variant': 'LSC Urgent'},
      {'word': 'NDOLÈ', 'emoji': '🥬', 'desc': 'Simuler le lavage des feuilles de Ndolè en mouvements circulaires.', 'variant': 'Cameroun Littoral'},
      {'word': 'KOSSAM', 'emoji': '🥛', 'desc': 'Mimer la traite des vaches verticalement de haut en bas.', 'variant': 'Nord-Cameroun'},
    ];

    final card = cards[_currentFlashcardIndex % cards.length];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CARTES MAÎTRISÉES : $_masteredCardsCount',
              style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.success, letterSpacing: 1.2),
            ),
            Text(
              'Carte ${(_currentFlashcardIndex % cards.length) + 1}/${cards.length}',
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 16),

        GestureDetector(
          onTap: () => setState(() => _isFlashcardFlipped = !_isFlashcardFlipped),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 260,
            decoration: BoxDecoration(
              gradient: _isFlashcardFlipped ? AppColors.primaryGradient : null,
              color: _isFlashcardFlipped ? null : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6)),
              ],
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            child: _isFlashcardFlipped
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'EXPLICATION DU GESTE',
                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        card['desc']!,
                        style: GoogleFonts.inter(fontSize: 15, color: Colors.white, height: 1.45),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Variante : ${card['variant']}',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white70, fontStyle: FontStyle.italic),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(card['emoji']!, style: const TextStyle(fontSize: 64)),
                      const SizedBox(height: 12),
                      Text(
                        card['word']!,
                        style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '👉 Touchez la carte pour révéler le geste',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentFlashcardIndex++;
                    _isFlashcardFlipped = false;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                icon: const Icon(Icons.replay_rounded, color: Colors.grey),
                label: Text('À REVOIR', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _masteredCardsCount++;
                    _currentFlashcardIndex++;
                    _isFlashcardFlipped = false;
                    _addXp(10);
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                label: Text('MAÎTRISÉ (+10 XP)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- SUB TAB 3: QUIZ ---
  Widget _buildQuizTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Évaluation LSC',
                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Testez vos connaissances sur l\'ensemble des leçons de langue des signes.',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.85), height: 1.45),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _startQuiz,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'LANCER LE QUIZ DÉFI',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Text('🏆', style: TextStyle(fontSize: 64)),
            ],
          ),
        ),
      ],
    );
  }

  // --- QUIZ LAYOUT SCREEN ---
  Widget _buildQuizLayout() {
    final questionData = _activeQuizQuestions[_currentQuestionIndex];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Quiz Évaluation', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() => _isInQuiz = false),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'QUESTION ${_currentQuestionIndex + 1}/${_activeQuizQuestions.length}',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      Text(
                        'Score : $_quizScore XP: +${_quizScore * 20}',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF047857)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_currentQuestionIndex + 1) / _activeQuizQuestions.length,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          Text(
                            questionData['question'] as String,
                            style: GoogleFonts.poppins(fontSize: 15.5, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.4),
                            textAlign: TextAlign.center,
                          ),
                          if (questionData['hint'] != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '💡 Indice : ${questionData['hint']}',
                              style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: (questionData['options'] as List).length,
                      itemBuilder: (context, index) {
                        final option = (questionData['options'] as List)[index] as String;
                        final isSelected = _selectedQuizAnswer == option;
                        final isCorrect = option == questionData['answer'];

                        Color cardColor = Colors.white;
                        Color textColor = Colors.black87;
                        BorderSide border = BorderSide.none;

                        if (_quizAnswered) {
                          if (isCorrect) {
                            cardColor = const Color(0xFFECFDF5);
                            textColor = const Color(0xFF047857);
                            border = const BorderSide(color: Color(0xFFA7F3D0), width: 1.5);
                          } else if (isSelected) {
                            cardColor = const Color(0xFFFEF2F2);
                            textColor = const Color(0xFFB91C1C);
                            border = const BorderSide(color: Color(0xFFFCA5A5), width: 1.5);
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () => _submitQuizAnswer(option),
                            borderRadius: BorderRadius.circular(18),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(18),
                                border: border != BorderSide.none ? Border.fromBorderSide(border) : Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: isSelected ? AppColors.primary : Colors.grey.shade100,
                                    child: Text(
                                      String.fromCharCode(65 + index),
                                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: textColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_quizAnswered)
                    ElevatedButton(
                      onPressed: _nextQuizQuestion,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        backgroundColor: AppColors.primary,
                      ),
                      child: Text(
                        _currentQuestionIndex == _activeQuizQuestions.length - 1 ? 'VOIR LES RÉSULTATS' : 'QUESTION SUIVANTE',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
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
}

// Painter pour la simulation des points de repère de la main IA (Keypoints Mesh)
class HandKeypointsPainter extends CustomPainter {
  final double confidence;
  HandKeypointsPainter({required this.confidence});

  @override
  void paint(Canvas canvas, Size size) {
    if (confidence <= 0.05) return;

    final paintLine = Paint()
      ..color = Colors.greenAccent.withValues(alpha: math.min(0.9, confidence))
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final paintDot = Paint()
      ..color = Colors.amberAccent
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);

    final points = [
      Offset(center.dx, center.dy + 40),
      Offset(center.dx - 30, center.dy + 10),
      Offset(center.dx - 45, center.dy - 20),
      Offset(center.dx - 15, center.dy - 40),
      Offset(center.dx + 5, center.dy - 45),
      Offset(center.dx + 25, center.dy - 35),
      Offset(center.dx + 40, center.dy - 15),
    ];

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[0], points[i + 1], paintLine);
    }

    for (var p in points) {
      canvas.drawCircle(p, 4.5, paintDot);
    }
  }

  @override
  bool shouldRepaint(covariant HandKeypointsPainter oldDelegate) {
    return oldDelegate.confidence != confidence;
  }
}

// Confetti painter helper
class ConfettiParticle {
  late double x;
  late double y;
  late Color color;
  late double size;
  late double vx;
  late double vy;
  late double rotation;
  late double rotationSpeed;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double animationValue;

  ConfettiPainter({required this.particles, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    if (animationValue == 0.0) return;
    for (var p in particles) {
      final currentX = p.x + p.vx * animationValue * 300;
      final currentY = p.y + p.vy * animationValue * 300 + (0.5 * 300 * animationValue * animationValue);
      final paint = Paint()..color = p.color.withValues(alpha: 1.0 - animationValue);

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(p.rotation + p.rotationSpeed * animationValue);
      canvas.drawRect(Rect.fromLTWH(-p.size / 2, -p.size / 2, p.size, p.size), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

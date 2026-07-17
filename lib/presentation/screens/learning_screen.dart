import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> with TickerProviderStateMixin {
  bool _isInQuiz = false;
  int _currentQuestionIndex = 0;
  int _score = 0;
  String? _selectedAnswer;
  bool _answered = false;

  // Gamification stats
  int _todayXp = 40;
  int _totalXp = 320;

  // Confetti Animation controllers
  late AnimationController _confettiController;
  final List<ConfettiParticle> _confettiParticles = [];

  // Liste des cours
  final List<Map<String, dynamic>> _courses = [
    {
      'title': 'Alphabet LSC & LSF',
      'desc': 'Apprenez à épeler votre nom et les mots simples.',
      'lessons': 26,
      'progress': 0.6,
      'color': AppColors.primary,
      'icon': '🔤',
    },
    {
      'title': 'Salutations & Présentations',
      'desc': 'Dire bonjour, merci, demander comment ça va.',
      'lessons': 10,
      'progress': 0.3,
      'color': AppColors.signLanguageBlue,
      'icon': '👋',
    },
    {
      'title': 'Vie Quotidienne au Cameroun',
      'desc': 'Nourriture locale, marchés, transports, lieux.',
      'lessons': 15,
      'progress': 0.0,
      'color': AppColors.secondary,
      'icon': '🏙️',
    },
    {
      'title': 'Urgences & Sécurité',
      'desc': 'Signes cruciaux pour la santé et la protection.',
      'lessons': 8,
      'progress': 0.0,
      'color': Colors.red.shade400,
      'icon': '🚨',
    },
  ];

  // Liste des questions du quiz de démo
  final List<Map<String, dynamic>> _quizQuestions = [
    {
      'question': 'Quel geste correspond au signe "MERCI" en Langue des Signes ?',
      'options': [
        'Croiser les mains sur la poitrine.',
        'Toucher ses lèvres avec les doigts plats puis descendre la main.',
        'Frotter son ventre avec la main ouverte.',
        'Lever le pouce vers le haut en souriant.'
      ],
      'answer': 'Toucher ses lèvres avec les doigts plats puis descendre la main.',
      'hint': 'Ce signe utilise la main dominante partant de la bouche.'
    },
    {
      'question': 'Pour le signe "HÔPITAL" en LSC, que dessine-t-on sur son bras ?',
      'options': [
        'Un cercle',
        'Une ligne droite',
        'Une croix rouge médicale',
        'Un triangle équilatéral'
      ],
      'answer': 'Une croix rouge médicale',
      'hint': 'Pensez au symbole international de la santé dessiné avec les doigts.'
    },
    {
      'question': 'Quelle est la variante locale du signe "KOSSAM" (Lait) ?',
      'options': [
        'Frotter ses mains verticalement comme pour traire une vache.',
        'Imiter le geste de boire un bol.',
        'Dessiner la forme d\'une bouteille de lait.',
        'Tapoter son menton deux fois.'
      ],
      'answer': 'Frotter ses mains verticalement comme pour traire une vache.',
      'hint': 'Inspiré de la traite traditionnelle du lait dans le Nord du Cameroun.'
    }
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
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

  void _startQuiz() {
    setState(() {
      _isInQuiz = true;
      _currentQuestionIndex = 0;
      _score = 0;
      _selectedAnswer = null;
      _answered = false;
    });
  }

  void _submitAnswer(String option) {
    if (_answered) return;
    final isCorrect = option == _quizQuestions[_currentQuestionIndex]['answer'];
    setState(() {
      _selectedAnswer = option;
      _answered = true;
      if (isCorrect) {
        _score++;
        _todayXp += 20;
        _totalXp += 20;
        _generateConfetti();
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _quizQuestions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _answered = false;
      });
    } else {
      // Fin du quiz
      _showQuizResultDialog();
    }
  }

  void _showQuizResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final percent = (_score / _quizQuestions.length) * 100;
        final xpEarned = _score * 20;
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text(
            percent >= 70 ? '🎉 Félicitations !' : '💪 Continuez d\'apprendre !',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.primary),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Text(
                'Évaluation complétée avec succès.',
                style: GoogleFonts.inter(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$_score/${_quizQuestions.length}',
                  style: GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'XP Remportés :',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.success.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, color: AppColors.success, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '+$xpEarned XP d\'Expérience',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF047857), fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (percent >= 100) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Text(
                    '🏆 Médaille de Perfection débloquée',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 11),
                  ),
                ),
              ],
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _isInQuiz = false;
                });
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                backgroundColor: AppColors.primary,
              ),
              child: Text('RETOURNER AUX COURS', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInQuiz) {
      return _buildQuizLayout();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Apprentissage',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            // Tableau de bord Gamification (Série de jours & XP)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade100, width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Série de 5 jours d\'affilée',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                              ),
                              Text(
                                'Prochain palier dans 2 jours',
                                style: GoogleFonts.inter(fontSize: 9.5, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.flash_on_rounded, color: Colors.orange, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'XP x1.5 ACTIF',
                              style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Objectif quotidien : XP aujourd\'hui',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '$_todayXp / 100 XP',
                        style: GoogleFonts.shareTechMono(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: math.min(_todayXp / 100.0, 1.0),
                      backgroundColor: AppColors.background,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 7,
                    ),
                  ),
                ],
              ),
            ),
            // Carte héro Quiz
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
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
                          'Testez vos acquis !',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Évaluez votre niveau sur la langue des signes locale et gagnez de l\'expérience.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.85),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: _startQuiz,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: Text(
                            'LANCER LE QUIZ',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('🏆', style: TextStyle(fontSize: 72)),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Text(
              'VOS PROGRAMMES D\'ÉTUDE',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 14),

            // Liste de cours
            ..._courses.map((course) {
              final color = course['color'] as Color;
              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: color.withOpacity(0.12)),
                        ),
                        alignment: Alignment.center,
                        child: Text(course['icon'] as String, style: const TextStyle(fontSize: 26)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course['title'] as String,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              course['desc'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: course['progress'] as double,
                                      backgroundColor: Colors.grey.shade100,
                                      valueColor: AlwaysStoppedAnimation<Color>(color),
                                      minHeight: 5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${((course['progress'] as double) * 100).toInt()}%',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${course['lessons']} leçons structurées',
                              style: GoogleFonts.inter(fontSize: 9.5, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizLayout() {
    final questionData = _quizQuestions[_currentQuestionIndex];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Quiz Évaluation',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
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
                  // Jauge de progression du quiz
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'QUESTION ${_currentQuestionIndex + 1}/${_quizQuestions.length}',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt_rounded, color: AppColors.success, size: 16),
                            Text(
                              'XP: +${_score * 20}',
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF047857)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_currentQuestionIndex + 1) / _quizQuestions.length,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Boîte de question
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          Text(
                            questionData['question'] as String,
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.45),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          // Indice caché
                          Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: Center(
                                child: Text(
                                  'Besoin d\'un indice ?',
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              showTrailingIcon: false,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                  child: Text(
                                    questionData['hint'] as String,
                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Options de réponse
                  Expanded(
                    child: ListView.builder(
                      itemCount: (questionData['options'] as List).length,
                      itemBuilder: (context, index) {
                        final option = (questionData['options'] as List)[index] as String;
                        final isSelected = _selectedAnswer == option;
                        final isCorrect = option == questionData['answer'];

                        Color cardColor = Colors.white;
                        Color textColor = Colors.black87;
                        BorderSide border = BorderSide.none;

                        if (_answered) {
                          if (isCorrect) {
                            cardColor = const Color(0xFFECFDF5);
                            textColor = const Color(0xFF047857);
                            border = const BorderSide(color: Color(0xFFA7F3D0), width: 1.5);
                          } else if (isSelected) {
                            cardColor = const Color(0xFFFEF2F2);
                            textColor = const Color(0xFFB91C1C);
                            border = const BorderSide(color: Color(0xFFFCA5A5), width: 1.5);
                          }
                        } else if (isSelected) {
                          cardColor = AppColors.primary.withOpacity(0.06);
                          border = const BorderSide(color: AppColors.primary, width: 1.5);
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => _submitAnswer(option),
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: border != BorderSide.none ? Border.fromBorderSide(border) : Border.all(color: Colors.grey.shade100),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 30, height: 30,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected ? AppColors.primary : Colors.grey.shade100,
                                      border: isSelected ? null : Border.all(color: Colors.grey.shade200),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      String.fromCharCode(65 + index), // A, B, C, D
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: GoogleFonts.inter(
                                        fontSize: 13.5,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  if (_answered && isCorrect)
                                    const Icon(Icons.check_circle_rounded, color: AppColors.success),
                                  if (_answered && isSelected && !isCorrect)
                                    const Icon(Icons.cancel_rounded, color: AppColors.error),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bouton suivant
                  if (_answered)
                    ElevatedButton(
                      onPressed: _nextQuestion,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        backgroundColor: AppColors.primary,
                      ),
                      child: Text(
                        _currentQuestionIndex == _quizQuestions.length - 1 ? 'VOIR LES RÉSULTATS' : 'QUESTION SUIVANTE',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Superposition du CustomPaint Confetti
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
}

// Classes des particules et du peintre de confettis
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
    if (animationValue == 0.0 || animationValue == 1.0) return;

    for (var p in particles) {
      final paint = Paint()
        ..color = p.color
        ..style = PaintingStyle.fill;

      final double currentX = p.x + p.vx * animationValue * size.width;
      final double currentY = p.y + p.vy * animationValue * size.height + 0.5 * 9.8 * 80 * animationValue * animationValue;
      final double currentRotation = p.rotation + p.rotationSpeed * animationValue;

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(currentRotation);
      
      if (p.size.toInt() % 2 == 0) {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5), paint);
      } else {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) => true;
}

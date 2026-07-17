import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> with SingleTickerProviderStateMixin {
  bool _isAlertActive = false;
  String _activeAlertTitle = '';
  String _activeAlertMessage = '';
  String _activeAlertVoiceText = '';
  Color _activeAlertColor = Colors.red;
  IconData _activeAlertIcon = Icons.warning_rounded;

  // Variables pour le compte à rebours de sécurité
  bool _isCountingDown = false;
  int _countdownValue = 3;
  Timer? _countdownTimer;
  Map<String, dynamic>? _pendingEmergencyData;
  
  // Animation controller pour le pulse de l'SOS et radar
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Contacts d'urgence par défaut
  final List<Map<String, String>> _emergencyContacts = [
    {'name': 'Maman', 'phone': '+237 677 88 99 00', 'relation': 'Famille'},
    {'name': 'Dr. Robert (Médecin)', 'phone': '+237 699 55 44 33', 'relation': 'Médecin'},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown(Map<String, dynamic> data) {
    setState(() {
      _isCountingDown = true;
      _countdownValue = 3;
      _pendingEmergencyData = data;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdownValue > 1) {
        setState(() {
          _countdownValue--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isCountingDown = false;
        });
        _triggerEmergency(
          title: _pendingEmergencyData!['title']!,
          message: _pendingEmergencyData!['message']!,
          voiceText: _pendingEmergencyData!['voiceText']!,
          color: _pendingEmergencyData!['color']!,
          icon: _pendingEmergencyData!['icon']!,
        );
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _isCountingDown = false;
      _pendingEmergencyData = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Envoi SOS annulé.',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.grey.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _triggerEmergency({
    required String title,
    required String message,
    required String voiceText,
    required Color color,
    required IconData icon,
  }) {
    setState(() {
      _isAlertActive = true;
      _activeAlertTitle = title;
      _activeAlertMessage = message;
      _activeAlertVoiceText = voiceText;
      _activeAlertColor = color;
      _activeAlertIcon = icon;
    });

    // Simuler le son TTS
    _playVoiceAlert(voiceText);

    // Simuler l'envoi de SMS / GPS
    _simulateSmsDispatch(title);
  }

  void _playVoiceAlert(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.volume_up_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Lancement synthèse vocale haute voix : "$text"',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: _activeAlertColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _simulateSmsDispatch(String type) {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_isAlertActive) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🚨 SMS d\'urgence avec coordonnées GPS (Yaoundé, Cameroun) envoyé aux contacts de confiance.',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  void _cancelAlert() {
    setState(() {
      _isAlertActive = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Alerte annulée. Signal de détresse désactivé.',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isAlertActive) {
      return _buildActiveAlertScreen();
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              'Urgences Sourds',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Message d'en-tête explicatif
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2), // Rouge très clair
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFFEE2E2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppColors.error, size: 24),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'En situation d\'urgence, cliquez sur l\'un des boutons ci-dessous pour déclencher une assistance vocale forte et envoyer votre position GPS par SMS.',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF991B1B),
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  Text(
                    'DÉCLENCHER UNE ALERTE INSTANTANÉE',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade400,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Grille de 4 boutons d'urgence haute visibilité
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.95,
                    children: [
                      _buildEmergencyButton(
                        title: 'Santé / Hôpital',
                        subtitle: 'Blessure, malaise, santé',
                        icon: Icons.local_hospital_rounded,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFEC4899)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        color: const Color(0xFFEF4444),
                        voiceText: 'Attention s\'il vous plaît, je suis une personne sourde. J\'ai un malaise ou besoin d\'aide médicale urgente. Veuillez appeler un médecin.',
                        message: 'J\'AI BESOIN D\'UNE AIDE MÉDICALE URGENTE',
                      ),
                      _buildEmergencyButton(
                        title: 'Danger / Police',
                        subtitle: 'Agression, vol, menace',
                        icon: Icons.local_police_rounded,
                        gradient: AppColors.primaryGradient,
                        color: AppColors.primary,
                        voiceText: 'S\'il vous plaît, je suis en danger imminent et je ne peux pas parler. Veuillez appeler la police immédiatement.',
                        message: 'JE SUIS EN DANGER. APPELEZ LA POLICE',
                      ),
                      _buildEmergencyButton(
                        title: 'Perdu / Aide',
                        subtitle: 'Besoin d\'orientation',
                        icon: Icons.map_rounded,
                        gradient: AppColors.secondaryGradient,
                        color: AppColors.secondary,
                        voiceText: 'Bonjour, je suis sourd et je me suis égaré. S\'il vous plaît, aidez-moi à retrouver mon chemin ou à contacter ma famille.',
                        message: 'JE SUIS PERDU. AIDEZ-MOI S\'IL VOUS PLAÎT',
                      ),
                      _buildEmergencyButton(
                        title: 'Incendie / Feu',
                        subtitle: 'Feu, explosion, fumée',
                        icon: Icons.local_fire_department_rounded,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF97316), Color(0xFFEF4444)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        color: const Color(0xFFF97316),
                        voiceText: 'Alerte ! Il y a un début d\'incendie ici. S\'il vous plaît, contactez les pompiers immédiatement.',
                        message: 'INCENDIE / FEU. APPELEZ LES POMPIERS',
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // Vos contacts de confiance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CONTACTS DE CONFIANCE (SMS)',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade400,
                          letterSpacing: 1.5,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Ajout de contact de confiance (Simulation Démo)', style: GoogleFonts.inter()),
                              backgroundColor: AppColors.primary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(
                          'Ajouter',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ..._emergencyContacts.map((contact) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      borderOnForeground: false,
                      elevation: 0,
                      color: Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primary.withOpacity(0.08),
                          child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 22),
                        ),
                        title: Text(
                          contact['name']!,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14.5, color: Colors.black87),
                        ),
                        subtitle: Text(
                          '${contact['relation']} • ${contact['phone']}',
                          style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                          onPressed: () {},
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ),
        if (_isCountingDown)
          _buildCountdownOverlay(),
      ],
    );
  }

  Widget _buildCountdownOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.92),
      alignment: Alignment.center,
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  'DÉTRESSE IMMINENTE LSC',
                  style: GoogleFonts.poppins(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              
              // Pulsing circular countdown visualizer
              Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 180 * _pulseAnimation.value,
                        height: 180 * _pulseAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withOpacity(0.08 * (2.0 - _pulseAnimation.value)),
                        ),
                      );
                    },
                  ),
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.shade900.withOpacity(0.85),
                      border: Border.all(color: Colors.redAccent, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.red.withOpacity(0.45), blurRadius: 30),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$_countdownValue',
                      style: GoogleFonts.poppins(
                        fontSize: 60,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 44),
              Text(
                'Envoi du SMS et de la position GPS à vos contacts de confiance dans $_countdownValue secondes...',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 13.5,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 54),
              
              ElevatedButton.icon(
                onPressed: _cancelCountdown,
                icon: const Icon(Icons.cancel_rounded, color: Colors.white, size: 22),
                label: Text(
                  'ANNULER L\'ALERTE',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: const BorderSide(color: Colors.white30, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required LinearGradient gradient,
    required Color color,
    required String voiceText,
    required String message,
  }) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return InkWell(
          onTap: () => _startCountdown({
            'title': title,
            'message': message,
            'voiceText': voiceText,
            'color': color,
            'icon': icon,
          }),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.35 * _pulseAnimation.value),
                  blurRadius: 16 * _pulseAnimation.value,
                  spreadRadius: 2.0 * (_pulseAnimation.value - 1.0),
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Écran d'alerte active plein écran à contraste élevé
  Widget _buildActiveAlertScreen() {
    return Scaffold(
      backgroundColor: _activeAlertColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              
              // Pulsing details with GPS radar sweep
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          child: Icon(_activeAlertIcon, size: 40, color: Colors.white),
                        ),
                      );
                    },
                  ),
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black38,
                      border: Border.all(color: Colors.white30, width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: RadarGridPainter(
                            animationValue: _pulseController.value,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Localisation details
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('LOCALISATION GPS DETECTÉE:', style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 9.5)),
                        const Icon(Icons.gps_fixed_rounded, color: Colors.greenAccent, size: 12),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Messa I, Yaoundé (Hôpital Central)', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        Text('LAT: 3.87° N | LNG: 11.52° E', style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Carte d'affichage géante
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _activeAlertColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'MESSAGE D\'URGENCE',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _activeAlertColor,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        _activeAlertMessage,
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Présentez cet écran directement aux personnes autour de vous.',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: Colors.grey.shade600,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Actions d'alerte en cours
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _playVoiceAlert(_activeAlertVoiceText),
                      icon: const Icon(Icons.volume_up_rounded, color: Colors.black87),
                      label: Text(
                        'RÉPÉTER LA VOIX',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _cancelAlert,
                      icon: const Icon(Icons.cancel_rounded, color: Colors.white),
                      label: Text(
                        'ANNULER SOS',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class RadarGridPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  RadarGridPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2;

    final linePaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric circles
    canvas.drawCircle(center, maxRadius * 0.25, linePaint);
    canvas.drawCircle(center, maxRadius * 0.50, linePaint);
    canvas.drawCircle(center, maxRadius * 0.75, linePaint);
    canvas.drawCircle(center, maxRadius, linePaint);

    // Draw axes
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy), Offset(center.dx + maxRadius, center.dy), linePaint);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius), Offset(center.dx, center.dy + maxRadius), linePaint);

    // Draw sweep line
    final sweepPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..strokeWidth = 1.5;
    final double sweepAngle = animationValue * pi * 2;
    canvas.drawLine(
      center,
      Offset(center.dx + cos(sweepAngle) * maxRadius, center.dy + sin(sweepAngle) * maxRadius),
      sweepPaint,
    );

    // Blip point
    final blipPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(center.dx + maxRadius * 0.4, center.dy - maxRadius * 0.3),
      4.0,
      blipPaint,
    );
  }

  @override
  bool shouldRepaint(covariant RadarGridPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

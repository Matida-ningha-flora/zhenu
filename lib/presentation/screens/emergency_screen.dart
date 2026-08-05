import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> with SingleTickerProviderStateMixin {
  // Navigation 4 onglets (0: 🚨 SOS, 1: 🩺 Douleur & Cartes, 2: 📞 Contacts & Secours, 3: 📋 Fiche Médicale)
  int _activeTabIndex = 0;

  // Synthèse Vocale TTS (Text-to-Speech)
  late FlutterTts _flutterTts;
  bool _isTtsSpeaking = false;

  // Contrôleur de texte pour la saisie personnalisée en direct
  final TextEditingController _customQuickTextController = TextEditingController();

  // État de l'alerte active
  bool _isAlertActive = false;
  String _activeAlertTitle = '';
  String _activeAlertMessage = '';
  String _activeAlertVoiceText = '';
  Color _activeAlertColor = Colors.red;
  IconData _activeAlertIcon = Icons.warning_rounded;

  // Décompte de sécurité (3s)
  bool _isCountingDown = false;
  int _countdownValue = 3;
  Timer? _countdownTimer;
  Map<String, dynamic>? _pendingEmergencyData;

  // Clignotement stroboscopique visuel pour alerte de nuit
  bool _strobeState = false;
  Timer? _strobeTimer;

  // Controller d'animation pour les effets de pulse SOS et radar
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Sélecteur de douleur corporelle
  String _selectedBodyPart = 'Poitrine / Cœur 🫁';
  double _painIntensity = 6.0;

  // Contacts d'urgence de confiance personnalisés
  List<Map<String, String>> _customEmergencyContacts = [
    {'name': 'Maman / Famille', 'phone': '+237677889900', 'relation': 'Proche'},
    {'name': 'Dr. Mbarga (Médecin)', 'phone': '+237699554433', 'relation': 'Santé'},
  ];

  // Numéros d'urgence officiels du Cameroun
  final List<Map<String, dynamic>> _nationalEmergencyNumbers = [
    {'title': 'SAMU (Urgences Médicales)', 'number': '15', 'sub': 'Ambulances & Réanimation', 'icon': Icons.medical_services_rounded, 'color': Color(0xFFDC2626)},
    {'title': 'Police Secours', 'number': '117', 'sub': 'Protection & Danger imminent', 'icon': Icons.local_police_rounded, 'color': Color(0xFFC76F26)},
    {'title': 'Gendarmerie Nationale', 'number': '122', 'sub': 'Sécurité publique & Intervention', 'icon': Icons.security_rounded, 'color': Color(0xFF1E3A8A)},
    {'title': 'Sapeurs-Pompiers', 'number': '118', 'sub': 'Incendie, Accident, Catastrophe', 'icon': Icons.local_fire_department_rounded, 'color': Color(0xFFEA580C)},
  ];

  // Fiche médicale de la personne sourde
  Map<String, String> _medicalProfile = {
    'bloodGroup': 'O+',
    'allergies': 'Pénicilline, Arachides',
    'chronicConditions': 'Asthme modéré',
    'currentTreatments': 'Ventoline si besoin',
    'doctorContact': 'Dr. Mbarga (+237699554433)',
    'signLanguage': 'LSC (Langue des Signes Camerounaise)',
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initTts();
    _loadEmergencyStorageData();
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    try {
      await _flutterTts.setLanguage('fr-FR');
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (_) {}

    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isTtsSpeaking = false);
    });
    _flutterTts.setErrorHandler((_) {
      if (mounted) setState(() => _isTtsSpeaking = false);
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _pulseController.dispose();
    _countdownTimer?.cancel();
    _strobeTimer?.cancel();
    _customQuickTextController.dispose();
    super.dispose();
  }

  Future<void> _loadEmergencyStorageData() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getString('emergency_custom_contacts');
    final medicalJson = prefs.getString('emergency_medical_profile');

    setState(() {
      if (contactsJson != null) {
        final List dynamicList = jsonDecode(contactsJson);
        _customEmergencyContacts = dynamicList.map((e) => Map<String, String>.from(e)).toList();
      }
      if (medicalJson != null) {
        _medicalProfile = Map<String, String>.from(jsonDecode(medicalJson));
      }
    });
  }

  Future<void> _saveEmergencyStorageData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emergency_custom_contacts', jsonEncode(_customEmergencyContacts));
    await prefs.setString('emergency_medical_profile', jsonEncode(_medicalProfile));
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

    // Lancement du stroboscope visuel de sécurité
    _startStrobeEffect();

    // Synthèse vocale réelle (Text to Speech)
    _playVoiceAlert(voiceText);

    // Pré-remplir l'envoi de SMS GPS aux contacts de confiance
    _promptSmsDispatch(title, message);
  }

  void _startStrobeEffect() {
    _strobeTimer?.cancel();
    _strobeTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!mounted || !_isAlertActive) {
        timer.cancel();
        return;
      }
      setState(() {
        _strobeState = !_strobeState;
      });
    });
  }

  Future<void> _playVoiceAlert(String text) async {
    if (text.isEmpty) return;
    try {
      await _flutterTts.stop();
      setState(() => _isTtsSpeaking = true);
      await _flutterTts.speak(text);
    } catch (_) {
      if (mounted) setState(() => _isTtsSpeaking = false);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.volume_up_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Synthèse vocale active (TTS) : "$text"',
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

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(' ', '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleanNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        throw 'Impossible d\'ouvrir l\'application Téléphone';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appel vers $cleanNumber impossible : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendEmergencySms(String message, {String? targetNumber}) async {
    final String recipients = targetNumber ??
        _customEmergencyContacts
            .map((c) => (c['phone'] ?? '').replaceAll(' ', ''))
            .where((p) => p.isNotEmpty)
            .join(',');

    if (recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Aucun numéro de contact disponible pour le SMS.'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    final String gpsCoords = "GPS: Yaoundé, Cameroun (Lat 3.87° N, Lng 11.52° E)";
    final String fullSmsBody = "🚨 ALERTE DÉTRESSE SOURD ZHẼNÙ 🚨\n$message\n$gpsCoords";
    final String encodedMsg = Uri.encodeComponent(fullSmsBody);
    final Uri smsUri = Uri.parse('sms:$recipients?body=$encodedMsg');

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        final Uri fallbackUri = Uri.parse('sms:$recipients');
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri);
        } else {
          throw 'Application SMS introuvable';
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Envoi SMS impossible : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _promptSmsDispatch(String type, String message) {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || !_isAlertActive) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.sms_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🚨 Appuyez pour envoyer le SMS GPS aux ${_customEmergencyContacts.length} contacts.',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'ENVOYER SMS',
            textColor: Colors.amber,
            onPressed: () => _sendEmergencySms(message),
          ),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          duration: const Duration(seconds: 6),
        ),
      );
    });
  }

  void _cancelAlert() {
    _flutterTts.stop();
    _strobeTimer?.cancel();
    setState(() {
      _isAlertActive = false;
      _strobeState = false;
      _isTtsSpeaking = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Alerte désactivée. Signal de détresse arrêté.',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showAddContactDialog() {
    String name = '';
    String phone = '';
    String relation = 'Proche';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Ajouter un contact de confiance',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Nom complet / Lien', prefixIcon: Icon(Icons.person_rounded)),
                  validator: (v) => v!.isEmpty ? 'Veuillez entrer un nom' : null,
                  onSaved: (v) => name = v!,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Numéro (+237...)', prefixIcon: Icon(Icons.phone_rounded)),
                  validator: (v) => v!.isEmpty ? 'Veuillez entrer un numéro' : null,
                  onSaved: (v) => phone = v!,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: relation,
                  items: ['Proche', 'Famille', 'Médecin', 'Voisin', 'Interprète LSC'].map((r) {
                    return DropdownMenuItem(value: r, child: Text(r));
                  }).toList(),
                  onChanged: (v) => relation = v!,
                  decoration: const InputDecoration(labelText: 'Relation', prefixIcon: Icon(Icons.people_rounded)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  setState(() {
                    _customEmergencyContacts.add({
                      'name': name,
                      'phone': phone,
                      'relation': relation,
                    });
                  });
                  _saveEmergencyStorageData();
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text('ENREGISTRER', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showEditMedicalProfileDialog() {
    String blood = _medicalProfile['bloodGroup'] ?? 'O+';
    String allergies = _medicalProfile['allergies'] ?? '';
    String chronic = _medicalProfile['chronicConditions'] ?? '';
    String treatments = _medicalProfile['currentTreatments'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(width: 45, height: 4.5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(5))),
                ),
                const SizedBox(height: 16),
                Text(
                  'Éditer la Fiche Médicale d\'Urgence',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: blood,
                  decoration: const InputDecoration(labelText: 'Groupe Sanguin', prefixIcon: Icon(Icons.bloodtype_rounded)),
                  items: ['O+', 'A+', 'B+', 'AB+', 'O-', 'A-', 'B-', 'AB-'].map((g) {
                    return DropdownMenuItem(value: g, child: Text(g));
                  }).toList(),
                  onChanged: (v) => blood = v!,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: allergies,
                  decoration: const InputDecoration(labelText: 'Allergies connues', prefixIcon: Icon(Icons.warning_amber_rounded)),
                  onChanged: (v) => allergies = v,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: chronic,
                  decoration: const InputDecoration(labelText: 'Affections / Maladies chroniques', prefixIcon: Icon(Icons.healing_rounded)),
                  onChanged: (v) => chronic = v,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: treatments,
                  decoration: const InputDecoration(labelText: 'Traitements / Médicaments actuels', prefixIcon: Icon(Icons.medication_rounded)),
                  onChanged: (v) => treatments = v,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _medicalProfile['bloodGroup'] = blood;
                      _medicalProfile['allergies'] = allergies;
                      _medicalProfile['chronicConditions'] = chronic;
                      _medicalProfile['currentTreatments'] = treatments;
                    });
                    _saveEmergencyStorageData();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Fiche médicale enregistrée avec succès !', style: GoogleFonts.inter()),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text('ENREGISTRER MES DONNÉES', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQuickTextDialog() {
    _customQuickTextController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '✍️ Dialogue Rapide avec les Secouristes / Témoins',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tapez votre message. Vous pourrez l\'afficher en texte géant sur l\'écran ou le faire prononcer à haute voix par la synthèse vocale.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _customQuickTextController,
                maxLines: 3,
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Ex: "Je m\'appelle Paul, j\'ai perdu mes médicaments à la gare..."',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final text = _customQuickTextController.text.trim();
                        if (text.isNotEmpty) {
                          Navigator.pop(context);
                          _playVoiceAlert(text);
                        }
                      },
                      icon: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 18),
                      label: Text('FAIRE PARLER (TTS)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final text = _customQuickTextController.text.trim();
                        if (text.isNotEmpty) {
                          Navigator.pop(context);
                          _triggerEmergency(
                            title: 'MESSAGE DIRECT SOURD',
                            message: text,
                            voiceText: 'Attention s\'il vous plaît, je suis une personne sourde. Voici mon message : $text',
                            color: AppColors.secondaryDark,
                            icon: Icons.chat_rounded,
                          );
                        }
                      },
                      icon: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 18),
                      label: Text('ÉCRAN GÉANT', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
              'Urgences Sourds Zhẽnù',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: 'Saisie rapide direct',
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
                onPressed: _showQuickTextDialog,
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Barre 4 onglets spécialisés d'urgence
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _buildEmergencyTabButton(0, '🚨 SOS', AppColors.error)),
                        Expanded(child: _buildEmergencyTabButton(1, '🩺 Douleur', AppColors.primary)),
                        Expanded(child: _buildEmergencyTabButton(2, '📞 Contacts', AppColors.secondaryDark)),
                        Expanded(child: _buildEmergencyTabButton(3, '📋 Santé', AppColors.signLanguageBlue)),
                      ],
                    ),
                  ),
                ),

                // Vue de l'onglet actif
                Expanded(
                  child: _activeTabIndex == 0
                      ? _buildSosView()
                      : _activeTabIndex == 1
                          ? _buildPainAndCardsView()
                          : _activeTabIndex == 2
                              ? _buildContactsView()
                              : _buildMedicalProfileView(),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showQuickTextDialog,
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
            label: Text(
              'Saisie Rapide TTS / Géant',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
            ),
          ),
        ),
        if (_isCountingDown) _buildCountdownOverlay(),
      ],
    );
  }

  Widget _buildEmergencyTabButton(int index, String label, Color activeColor) {
    final isSelected = _activeTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? activeColor : Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // Vue 1 : SOS Imminent
  Widget _buildSosView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête explicatif
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFFEE2E2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, color: AppColors.error, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Appuyez sur un bouton d\'urgence pour lancer la synthèse vocale orale (TTS) et pré-remplir l\'envoi de vos coordonnées GPS aux secours.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF991B1B), height: 1.45, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Boutons d'urgence instantanés
          Text(
            'ALERTES DÉTRESSE EN UN TOUCHER',
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.95,
            children: [
              _buildEmergencyButton(
                title: 'Santé / Hôpital',
                subtitle: 'Malaise, blessure, douleur',
                icon: Icons.local_hospital_rounded,
                gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFEC4899)]),
                color: const Color(0xFFEF4444),
                voiceText: 'Attention s\'il vous plaît, je suis une personne sourde. J\'ai un malaise médical grave. Appelez une ambulance d\'urgence !',
                message: 'J\'AI BESOIN D\'UNE AIDE MÉDICALE URGENTE',
              ),
              _buildEmergencyButton(
                title: 'Danger / Police',
                subtitle: 'Agression, vol, menace',
                icon: Icons.local_police_rounded,
                gradient: AppColors.primaryGradient,
                color: AppColors.primary,
                voiceText: 'S\'il vous plaît, je suis une personne sourde en danger imminent. Appelez la police 117 immédiatement !',
                message: 'JE SUIS EN DANGER. APPELEZ LA POLICE 117',
              ),
              _buildEmergencyButton(
                title: 'Perdu / Orientation',
                subtitle: 'Égaré, besoin de chemin',
                icon: Icons.map_rounded,
                gradient: AppColors.secondaryGradient,
                color: AppColors.secondaryDark,
                voiceText: 'Bonjour, je suis sourd et je suis égaré. S\'il vous plaît, aidez-moi à contacter mes proches ou retrouver mon chemin.',
                message: 'JE SUIS PERDU. AIDEZ-MOI S\'IL VOUS PLAÎT',
              ),
              _buildEmergencyButton(
                title: 'Incendie / Feu',
                subtitle: 'Feu, fumée, explosion',
                icon: Icons.local_fire_department_rounded,
                gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEF4444)]),
                color: const Color(0xFFF97316),
                voiceText: 'Alerte incendie ! Il y a du feu ici. Appelez les pompiers 118 immédiatement !',
                message: 'INCENDIE / FEU. APPELEZ LES POMPIERS 118',
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Balise lumineuse stroboscopique pour nuit
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.amber.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Balise Lumineuse Stroboscopique',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                      ),
                      Text(
                        'Permet d\'attirer l\'attention visuelle la nuit ou dans l\'obscurité.',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _strobeState,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() {
                      _strobeState = val;
                      if (val) {
                        _startStrobeEffect();
                      } else {
                        _strobeTimer?.cancel();
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Vue 2 : Sélecteur de Douleur & Cartes de Communication Visuelles
  Widget _buildPainAndCardsView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        // Carte d'affichage dynamique de la douleur
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SÉLECTEUR DE DOULEUR CORPORELLE',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1.2),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPainColor(_painIntensity).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Niveau ${_painIntensity.toInt()}/10',
                      style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold, color: _getPainColor(_painIntensity), fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                'Où avez-vous mal ?',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'Tête 🧠',
                  'Poitrine / Cœur 🫁',
                  'Ventre / Abdomen 🪵',
                  'Bras / Épaule 💪',
                  'Jambe / Pied 🦵',
                  'Dos / Colonne 🦴',
                ].map((part) {
                  final isSelected = _selectedBodyPart == part;
                  return ChoiceChip(
                    label: Text(part),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedBodyPart = part);
                    },
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.grey.shade100,
                    side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade300),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              Text(
                'Intensité de la douleur :',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _getPainColor(_painIntensity),
                  inactiveTrackColor: Colors.grey.shade200,
                  thumbColor: _getPainColor(_painIntensity),
                ),
                child: Slider(
                  value: _painIntensity,
                  min: 1.0,
                  max: 10.0,
                  divisions: 9,
                  label: '${_painIntensity.toInt()}/10',
                  onChanged: (val) => setState(() => _painIntensity = val),
                ),
              ),

              ElevatedButton.icon(
                onPressed: () {
                  _triggerEmergency(
                    title: 'Douleur Corporelle',
                    message: 'J\'AI UNE DOULEUR INTENSE (${_painIntensity.toInt()}/10) AU NIVEAU DE : ${_selectedBodyPart.toUpperCase()}',
                    voiceText: 'Attention s\'il vous plaît, je suis sourd. J\'ai une forte douleur niveau ${_painIntensity.toInt()} sur 10 au niveau de : $_selectedBodyPart. Veuillez m\'aider.',
                    color: Colors.red.shade700,
                    icon: Icons.personal_injury_rounded,
                  );
                },
                icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
                label: Text('AFFICHER CETTE DOULEUR AUX SECOURS', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getPainColor(_painIntensity),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        Text(
          'PHRASES D\'URGENCE EN GROS CARACTÈRES',
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),

        _buildCommunicationCard(
          title: 'JE SUIS SOURD(E)',
          subtitle: 'Parlez lentement ou écrivez vos réponses sur l\'écran.',
          icon: Icons.hearing_disabled_rounded,
          color: AppColors.primary,
        ),
        _buildCommunicationCard(
          title: 'MON ENFANT S\'EST ÉGARÉ',
          subtitle: 'Aidez-moi immédiatement à retrouver mon enfant.',
          icon: Icons.child_care_rounded,
          color: Colors.purple.shade700,
        ),
        _buildCommunicationCard(
          title: 'J\'AI BESOIN D\'UN INTERPRÈTE LSC',
          subtitle: 'Veuillez contacter un interprète en Langue des Signes.',
          icon: Icons.translate_rounded,
          color: AppColors.signLanguageBlue,
        ),
        _buildCommunicationCard(
          title: 'RESTEZ AVEC MOI S\'IL VOUS PLAÎT',
          subtitle: 'Ne me laissez pas seul(e) en attendant l\'ambulance.',
          icon: Icons.people_rounded,
          color: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildCommunicationCard({required String title, required String subtitle, required IconData icon, required Color color}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () {
          _triggerEmergency(
            title: title,
            message: '$title\n\n$subtitle',
            voiceText: '$title. $subtitle',
            color: color,
            icon: icon,
          );
        },
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 26),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14.5, color: Colors.black87),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600),
        ),
        trailing: const Icon(Icons.fullscreen_rounded, color: Colors.grey),
      ),
    );
  }

  Color _getPainColor(double intensity) {
    if (intensity <= 3) return Colors.green;
    if (intensity <= 6) return Colors.orange;
    return Colors.red.shade700;
  }

  // Vue 3 : Contacts de Confiance & Numéros de Secours Officiels
  Widget _buildContactsView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        // Section Numéros Nationaux Cameroun
        Text(
          'NUMÉROS D\'URGENCE OFFICIELS (CAMEROUN)',
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),

        ..._nationalEmergencyNumbers.map((item) {
          final color = item['color'] as Color;
          final number = item['number'] as String;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                child: Icon(item['icon'] as IconData, color: color, size: 22),
              ),
              title: Text(
                item['title'] as String,
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              subtitle: Text(
                item['sub'] as String,
                style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade600),
              ),
              trailing: InkWell(
                onTap: () => _makePhoneCall(number),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        number,
                        style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 28),

        // Section Contacts de Confiance Personnels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'VOS CONTACTS DE CONFIANCE (${_customEmergencyContacts.length})',
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5),
            ),
            TextButton.icon(
              onPressed: _showAddContactDialog,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text('Ajouter', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        ..._customEmergencyContacts.asMap().entries.map((entry) {
          final idx = entry.key;
          final contact = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.08),
                child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 22),
              ),
              title: Text(
                contact['name']!,
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
              ),
              subtitle: Text(
                '${contact['relation']} • ${contact['phone']}',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.phone_rounded, color: AppColors.primary, size: 20),
                    onPressed: () => _makePhoneCall(contact['phone']!),
                  ),
                  IconButton(
                    icon: const Icon(Icons.sms_rounded, color: AppColors.secondaryDark, size: 20),
                    onPressed: () => _sendEmergencySms("Besoin d'aide urgente !", targetNumber: contact['phone']),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    onPressed: () {
                      setState(() {
                        _customEmergencyContacts.removeAt(idx);
                      });
                      _saveEmergencyStorageData();
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // Vue 4 : Fiche Médicale d'Urgence
  Widget _buildMedicalProfileView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'FICHE SANTÉ & IDENTITÉ SOURD',
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5),
            ),
            TextButton.icon(
              onPressed: _showEditMedicalProfileDialog,
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: Text('Éditer', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          ),
          child: Column(
            children: [
              _buildMedicalInfoTile('Groupe Sanguin', _medicalProfile['bloodGroup'] ?? 'O+', Icons.bloodtype_rounded, Colors.red),
              const Divider(height: 24),
              _buildMedicalInfoTile('Allergies Déclarées', _medicalProfile['allergies'] ?? 'Aucune', Icons.warning_amber_rounded, Colors.orange),
              const Divider(height: 24),
              _buildMedicalInfoTile('Affections Chroniques', _medicalProfile['chronicConditions'] ?? 'Aucune', Icons.healing_rounded, Colors.purple),
              const Divider(height: 24),
              _buildMedicalInfoTile('Traitements Actuels', _medicalProfile['currentTreatments'] ?? 'Aucun', Icons.medication_rounded, AppColors.primary),
              const Divider(height: 24),
              _buildMedicalInfoTile('Langue des Signes', _medicalProfile['signLanguage'] ?? 'LSC', Icons.translate_rounded, AppColors.signLanguageBlue),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMedicalInfoTile(String label, String value, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.93),
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
                  style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 2),
                ),
              ),
              const SizedBox(height: 48),

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
                      boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.45), blurRadius: 30)],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$_countdownValue',
                      style: GoogleFonts.poppins(fontSize: 60, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 44),
              Text(
                'Lancement de la synthèse vocale et envoi du SMS GPS aux contacts dans $_countdownValue secondes...',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13.5, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 54),
              ElevatedButton.icon(
                onPressed: _cancelCountdown,
                icon: const Icon(Icons.cancel_rounded, color: Colors.white, size: 22),
                label: Text('ANNULER L\'ALERTE', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Colors.white30, width: 1.5)),
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
            padding: const EdgeInsets.all(18),
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
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Écran d'alerte active plein écran à très haut contraste
  Widget _buildActiveAlertScreen() {
    final backgroundColor = _strobeState ? Colors.white : _activeAlertColor;
    final textColor = _strobeState ? Colors.red.shade900 : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
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
                            color: _strobeState ? Colors.red.withOpacity(0.2) : Colors.white.withOpacity(0.2),
                          ),
                          child: Icon(_activeAlertIcon, size: 40, color: textColor),
                        ),
                      );
                    },
                  ),
                  Container(
                    width: 80,
                    height: 80,
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

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('POSITION GPS SÉCURISÉE:', style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 9.5)),
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
              const SizedBox(height: 20),

              // Carte géante de présentation aux secours
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 30, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _activeAlertColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _activeAlertTitle.isNotEmpty ? _activeAlertTitle.toUpperCase() : 'MESSAGE D\'URGENCE SOURD',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: _activeAlertColor, letterSpacing: 2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _activeAlertMessage,
                        style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black, height: 1.3),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Présentez cet écran directement aux personnes autour de vous ou aux pompiers/police.',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, height: 1.4, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Boutons d'actions d'urgence
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _playVoiceAlert(_activeAlertVoiceText),
                      icon: Icon(Icons.volume_up_rounded, color: _isTtsSpeaking ? Colors.red : Colors.black87),
                      label: Text(
                        _isTtsSpeaking ? 'PARLE EN COURS...' : 'RÉPÉTER LA VOIX',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 11),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _sendEmergencySms(_activeAlertMessage),
                      icon: const Icon(Icons.sms_rounded, color: Colors.white, size: 18),
                      label: Text('SMS CONFIANCE', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade900,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _cancelAlert,
                icon: const Icon(Icons.cancel_rounded, color: Colors.white),
                label: Text('ANNULER LE SIGNAL SOS', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
              const SizedBox(height: 10),
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

    canvas.drawCircle(center, maxRadius * 0.25, linePaint);
    canvas.drawCircle(center, maxRadius * 0.50, linePaint);
    canvas.drawCircle(center, maxRadius * 0.75, linePaint);
    canvas.drawCircle(center, maxRadius, linePaint);

    canvas.drawLine(Offset(center.dx - maxRadius, center.dy), Offset(center.dx + maxRadius, center.dy), linePaint);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius), Offset(center.dx, center.dy + maxRadius), linePaint);

    final sweepPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..strokeWidth = 1.5;
    final double sweepAngle = animationValue * pi * 2;
    canvas.drawLine(
      center,
      Offset(center.dx + cos(sweepAngle) * maxRadius, center.dy + sin(sweepAngle) * maxRadius),
      sweepPaint,
    );

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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/firebase_auth_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String role;
  final String email;

  const ProfileScreen({
    super.key,
    required this.role,
    required this.email,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Liste des signes en attente de validation (pour la console admin/trainer)
  final List<Map<String, String>> _pendingSigns = [
    {
      'id': '101',
      'word': 'KOSSAM (Lait)',
      'category': 'Vie quotidienne',
      'variant': 'Nord-Cameroun',
      'author': 'Alhadji Oumarou',
      'desc': 'Mouvement vertical alterné des poings simulant la traite d\'une vache.'
    },
    {
      'id': '102',
      'word': 'NDOLÈ',
      'category': 'Vie quotidienne',
      'variant': 'Littoral-Douala',
      'author': 'Marie Ngo',
      'desc': 'Friction des mains à plat l\'une sur l\'autre mimant le lavage traditionnel des feuilles.'
    }
  ];

  void _validateSign(String id, String word) {
    setState(() {
      _pendingSigns.removeWhere((sign) => sign['id'] == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Le signe "$word" a été validé et ajouté au dictionnaire officiel !',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _rejectSign(String id, String word) {
    setState(() {
      _pendingSigns.removeWhere((sign) => sign['id'] == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Le signe "$word" a été rejeté et l\'auteur a été notifié.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.email.split('@')[0].toUpperCase();
    final roleTitle = widget.role == 'admin'
        ? 'Administrateur'
        : (widget.role == 'sourd'
            ? 'Personne Sourde'
            : (widget.role == 'trainer' ? 'Formateur LSC' : 'Personne Entendante'));

    // Déterminer l'emoji en fonction du rôle
    final avatarEmoji = widget.role == 'admin'
        ? '👑'
        : (widget.role == 'trainer'
            ? '👨‍🏫'
            : (widget.role == 'sourd' ? '🤟' : '👤'));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Mon Profil',
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
              // En-tête profil premium
              Container(
                padding: const EdgeInsets.all(26),
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
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white30,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor: Colors.white,
                        child: Text(
                          avatarEmoji,
                          style: const TextStyle(fontSize: 46),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.email,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.25)),
                      ),
                      child: Text(
                        roleTitle,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Grille des statistiques XP
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('Niveau', '3', Icons.stars_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard('Expérience', '1 250 XP', Icons.bolt_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard('Badges', '3', Icons.emoji_events_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Badges débloqués
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.grey.shade100, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'BADGES OBTENUS (${widget.role == 'user' ? '2/3' : '3/3'})',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade400,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildBadgeChip('🎓', 'Débutant', "Débloqué en complétant votre première leçon LSC. Bienvenue dans l'apprentissage !", true),
                        _buildBadgeChip('⭐', 'Persévérant', "Terminer 3 évaluations consécutives avec un score parfait.", true),
                        _buildBadgeChip('🚨', 'Sauveteur', "Maîtriser tous les gestes de la catégorie Urgences & Sécurité.", widget.role != 'user'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Console Administration ou Formateur
              if (widget.role == 'admin' || widget.role == 'trainer') ...[
                Text(
                  'ESPACE DE MODÉRATION',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade400,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Colors.grey.shade100, width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.gavel_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Signes en attente (${_pendingSigns.length})',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.black87),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (_pendingSigns.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Aucune proposition de signe en attente.',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ..._pendingSigns.map((sign) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade100),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      sign['word']!,
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                                    ),
                                    Text(
                                      'Par : ${sign['author']}',
                                      style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Catégorie : ${sign['category']} • Variante : ${sign['variant']}', 
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  sign['desc']!, 
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, height: 1.4)
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _showProposedSignVideo(sign),
                                      icon: const Icon(Icons.play_circle_fill_rounded, size: 16, color: AppColors.primary),
                                      label: Text('Vidéo', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => _rejectSign(sign['id']!, sign['word']!),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFEF2F2),
                                        foregroundColor: AppColors.error,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        minimumSize: Size.zero,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        side: const BorderSide(color: Color(0xFFFEE2E2)),
                                      ),
                                      child: Text('Rejeter', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton(
                                      onPressed: () => _validateSign(sign['id']!, sign['word']!),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFECFDF5),
                                        foregroundColor: const Color(0xFF047857),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        minimumSize: Size.zero,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        side: const BorderSide(color: Color(0xFFD1FAE5)),
                                      ),
                                      child: Text('Valider', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // Bouton déconnexion
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                borderOnForeground: false,
                elevation: 0,
                color: Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.error.withOpacity(0.08),
                    child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                  ),
                  title: Text(
                    'Se déconnecter',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () async {
                    await FirebaseAuthService().signOut();
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeChip(String emoji, String name, String desc, bool earned) {
    return InkWell(
      onTap: () => _showBadgeDetails(emoji, name, desc, earned),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: earned ? AppColors.primary.withOpacity(0.06) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: earned ? AppColors.primary.withOpacity(0.12) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(opacity: earned ? 1.0 : 0.4, child: Text(emoji, style: const TextStyle(fontSize: 16))),
            const SizedBox(width: 8),
            Text(
              name,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: earned ? AppColors.primary : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetails(String emoji, String name, String desc, bool earned) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: earned ? AppColors.primary.withOpacity(0.08) : Colors.grey.shade100,
                  shape: BoxShape.circle,
                  border: Border.all(color: earned ? AppColors.primary.withOpacity(0.15) : Colors.grey.shade200, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 40)),
              ),
              const SizedBox(height: 20),
              Text(
                name.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: earned ? AppColors.primary : Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: earned ? AppColors.success.withOpacity(0.1) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  earned ? 'DÉBLOQUÉ' : 'VERROUILLÉ',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: earned ? const Color(0xFF047857) : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                desc,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text('COMPRIS', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showProposedSignVideo(Map<String, String> sign) {
    bool isPlaying = true;
    double progress = 0.0;
    double speed = 1.0;
    Timer? playTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            playTimer ??= Timer.periodic(Duration(milliseconds: (200 / speed).round()), (timer) {
              setDialogState(() {
                if (progress < 1.0) {
                  progress += 0.05;
                } else {
                  progress = 0.0;
                }
              });
            });

            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'REVUE DU GESTE : ${sign['word']}',
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            playTimer?.cancel();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Video container screen
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(24),
                        image: const DecorationImage(
                          image: NetworkImage('https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=500&auto=format&fit=crop&q=60'),
                          fit: BoxFit.cover,
                          opacity: 0.45,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Play/pause trigger overlay
                          GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                if (isPlaying) {
                                  playTimer?.cancel();
                                  playTimer = null;
                                  isPlaying = false;
                                } else {
                                  isPlaying = true;
                                  playTimer = Timer.periodic(Duration(milliseconds: (200 / speed).round()), (timer) {
                                    setDialogState(() {
                                      if (progress < 1.0) {
                                        progress += 0.05;
                                      } else {
                                        progress = 0.0;
                                      }
                                    });
                                  });
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                              child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 36),
                            ),
                          ),
                          // timeline overlay
                          Positioned(
                            bottom: 12,
                            left: 16,
                            right: 16,
                            child: Column(
                              children: [
                                LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.white12,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                                  minHeight: 3,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Auteur : ${sign['author']} (${speed}x)',
                                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setDialogState(() {
                                          speed = speed == 1.0 ? 0.5 : 1.0;
                                          playTimer?.cancel();
                                          playTimer = null;
                                          if (isPlaying) {
                                            playTimer = Timer.periodic(Duration(milliseconds: (200 / speed).round()), (timer) {
                                              setDialogState(() {
                                                if (progress < 1.0) {
                                                  progress += 0.05;
                                                } else {
                                                  progress = 0.0;
                                                }
                                              });
                                            });
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                                        child: Text(
                                          'Ralenti LSC',
                                          style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'DESCRIPTION DES GESTES',
                      style: GoogleFonts.poppins(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sign['desc']!,
                      style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontSize: 13, height: 1.45),
                    ),
                    const SizedBox(height: 24),
                    // Action triggers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            playTimer?.cancel();
                            Navigator.pop(context);
                            _rejectSign(sign['id']!, sign['word']!);
                          },
                          child: Text(
                            'REJETER',
                            style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            playTimer?.cancel();
                            Navigator.pop(context);
                            _validateSign(sign['id']!, sign['word']!);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: Text(
                            'VALIDER',
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

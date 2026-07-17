import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Tous';

  final List<String> _categories = [
    'Tous',
    'Salutations',
    'Urgences',
    'Nombres',
    'Vie quotidienne',
  ];

  // Base de données locale de signes officiels
  final List<Map<String, dynamic>> _officialSigns = [
    {
      'id': '1',
      'word': 'BONJOUR',
      'category': 'Salutations',
      'emoji': '👋',
      'description': 'Placez la main droite ouverte près de votre tempe droite, puis déplacez-la vers l\'avant.',
      'variant': 'LSC (Langue des Signes Camerounaise) - Standard national',
      'difficulty': 'Facile'
    },
    {
      'id': '2',
      'word': 'MERCI',
      'category': 'Salutations',
      'emoji': '🙏',
      'description': 'Touchez vos lèvres avec le bout des doigts de votre main plate droite, puis descendez la main.',
      'variant': 'LSF / LSC - Universel',
      'difficulty': 'Facile'
    },
    {
      'id': '3',
      'word': 'HÔPITAL',
      'category': 'Urgences',
      'emoji': '🏥',
      'description': 'Tracez une croix sur votre bras gauche avec l\'index et le majeur de votre main droite.',
      'variant': 'LSC - Indique la croix rouge médicale',
      'difficulty': 'Moyen'
    },
    {
      'id': '4',
      'word': 'DANGER',
      'category': 'Urgences',
      'emoji': '⚠️',
      'description': 'Tapez deux fois le dos de la main gauche plate avec le poing droit fermé.',
      'variant': 'LSC - Vigilance accrue',
      'difficulty': 'Moyen'
    },
    {
      'id': '5',
      'word': 'UN',
      'category': 'Nombres',
      'emoji': '☝️',
      'description': 'Levez l\'index de la main droite, paume tournée vers l\'avant.',
      'variant': 'Universel',
      'difficulty': 'Facile'
    },
    {
      'id': '6',
      'word': 'DEUX',
      'category': 'Nombres',
      'emoji': '✌️',
      'description': 'Levez l\'index et le majeur, paume tournée vers l\'avant.',
      'variant': 'Universel',
      'difficulty': 'Facile'
    },
    {
      'id': '7',
      'word': 'MANGER',
      'category': 'Vie quotidienne',
      'emoji': '🍎',
      'description': 'Amenez le bout des doigts serrés de la main droite vers la bouche plusieurs fois.',
      'variant': 'LSC / LSF - Standard',
      'difficulty': 'Facile'
    },
    {
      'id': '8',
      'word': 'BOIRE',
      'category': 'Vie quotidienne',
      'emoji': '🥛',
      'description': 'Simulez le fait de tenir un verre avec la main droite en forme de C et inclinez-le vers la bouche.',
      'variant': 'Universel',
      'difficulty': 'Facile'
    },
  ];

  // Liste pour stocker les propositions collaboratives de la communauté
  final List<Map<String, dynamic>> _communitySuggestions = [
    {
      'word': 'KOSSAM (Lait)',
      'category': 'Vie quotidienne',
      'emoji': '🥛',
      'description': 'Frotter les mains l\'une contre l\'autre verticalement (simule la traite des vaches).',
      'variant': 'Variante régionale Nord-Cameroun (Fulfulde)',
      'author': 'Alhadji Oumarou',
      'status': 'En attente',
    },
    {
      'word': 'NDOLÈ',
      'category': 'Vie quotidienne',
      'emoji': '🥬',
      'description': 'Simuler le fait de laver des feuilles avec les mains en mouvements circulaires.',
      'variant': 'Variante culturelle Cameroun Littoral',
      'author': 'Marie Ngo',
      'status': 'En attente',
    }
  ];

  void _showAddSignDialog() {
    final formKey = GlobalKey<FormState>();
    String signName = '';
    String signCategory = 'Vie quotidienne';
    String signDescription = '';
    String signVariant = 'LSC (Langue des Signes Camerounaise)';
    String recordedVideoName = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
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
                      Text(
                        'Proposer un nouveau signe',
                        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Aidez la communauté à enrichir la Langue des Signes Camerounaise !',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      // Nom du signe
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Nom du signe (ex: NDOLÈ, KOSSAM...)',
                          prefixIcon: const Icon(Icons.abc_rounded),
                        ),
                        validator: (v) => v!.isEmpty ? 'Veuillez entrer un nom' : null,
                        onSaved: (v) => signName = v!,
                      ),
                      const SizedBox(height: 16),
                      // Catégorie
                      DropdownButtonFormField<String>(
                        value: signCategory,
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                        decoration: const InputDecoration(
                          labelText: 'Catégorie',
                          prefixIcon: Icon(Icons.category_rounded),
                        ),
                        items: _categories.where((c) => c != 'Tous').map((c) {
                          return DropdownMenuItem(value: c, child: Text(c));
                        }).toList(),
                        onChanged: (v) => setModalState(() => signCategory = v!),
                      ),
                      const SizedBox(height: 16),
                      // Description du geste
                      TextFormField(
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description détaillée du geste',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.description_rounded),
                        ),
                        validator: (v) => v!.isEmpty ? 'Veuillez décrire le geste' : null,
                        onSaved: (v) => signDescription = v!,
                      ),
                      const SizedBox(height: 16),
                      // Variante
                      TextFormField(
                        initialValue: signVariant,
                        decoration: const InputDecoration(
                          labelText: 'Région / Variante dialectale',
                          prefixIcon: Icon(Icons.map_rounded),
                        ),
                        onSaved: (v) => signVariant = v!,
                      ),
                      // Upload vidéo fictif premium
                      StatefulBuilder(
                        builder: (context, setModalState) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: recordedVideoName.isEmpty 
                                    ? AppColors.primary.withOpacity(0.3) 
                                    : AppColors.success, 
                                style: BorderStyle.solid,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              color: recordedVideoName.isEmpty 
                                  ? AppColors.primary.withOpacity(0.04) 
                                  : AppColors.success.withOpacity(0.04),
                            ),
                            child: InkWell(
                              onTap: () {
                                _showCameraSimulator(context, (videoName) {
                                  setModalState(() {
                                    recordedVideoName = videoName;
                                  });
                                });
                              },
                              child: Column(
                                children: [
                                  Icon(
                                    recordedVideoName.isEmpty 
                                        ? Icons.video_camera_back_rounded 
                                        : Icons.check_circle_rounded, 
                                    size: 36, 
                                    color: recordedVideoName.isEmpty 
                                        ? AppColors.primary 
                                        : AppColors.success,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    recordedVideoName.isEmpty 
                                        ? 'Enregistrer ou Uploader une vidéo' 
                                        : 'Vidéo enregistrée : $recordedVideoName',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 13, 
                                      color: recordedVideoName.isEmpty 
                                          ? AppColors.primary 
                                          : AppColors.success,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    recordedVideoName.isEmpty 
                                        ? 'Format recommandé : .mp4, 2 à 5 secondes max'
                                        : 'Appuyez à nouveau pour réenregistrer',
                                    style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            formKey.currentState!.save();
                            setState(() {
                              _communitySuggestions.add({
                                'word': signName.toUpperCase(),
                                'category': signCategory,
                                'emoji': '🆕',
                                'description': signDescription,
                                'variant': signVariant,
                                'author': 'Moi (Démo)',
                                'status': 'En attente',
                              });
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Proposition enregistrée ! En attente de validation par un modérateur.', style: GoogleFonts.inter()),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: Text('SOUMETTRE LE SIGNE', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSignDetails(Map<String, dynamic> sign) {
    bool isPlaying = false;
    double progress = 0.0;
    double playbackSpeed = 1.0;
    Timer? videoTimer;

    void stopPlayback() {
      videoTimer?.cancel();
      isPlaying = false;
    }

    void startPlayback(StateSetter setModalState) {
      videoTimer?.cancel();
      isPlaying = true;
      videoTimer = Timer.periodic(Duration(milliseconds: (200 / playbackSpeed).round()), (timer) {
        setModalState(() {
          if (progress < 1.0) {
            progress += 0.05;
          } else {
            progress = 0.0; // Loop video
          }
        });
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                        child: Text(sign['emoji'] as String, style: const TextStyle(fontSize: 34)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sign['word'] as String,
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
                                sign['category'] as String,
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondaryDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Lecteur Vidéo simulé haute fidélité
                  Text(
                    'DÉMONSTRATION DU SIGNE',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.darkBackground,
                      borderRadius: BorderRadius.circular(24),
                      image: const DecorationImage(
                        image: NetworkImage('https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=500&auto=format&fit=crop&q=60'),
                        fit: BoxFit.cover,
                        opacity: 0.35,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Filtre teinté bleu sombre
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              colors: [Colors.black.withOpacity(0.4), AppColors.darkBackground.withOpacity(0.7)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        // Bouton Play
                        GestureDetector(
                          onTap: () {
                            if (isPlaying) {
                              setModalState(() {
                                stopPlayback();
                              });
                            } else {
                              setModalState(() {
                                startPlayback(setModalState);
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                            ),
                            child: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                        
                        // Sélecteur de vitesse et barre de progression
                        Positioned(
                          bottom: 12,
                          left: 16,
                          right: 16,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                  activeTrackColor: AppColors.secondary,
                                  inactiveTrackColor: Colors.white30,
                                  thumbColor: Colors.white,
                                ),
                                child: Slider(
                                  value: progress,
                                  onChanged: (val) {
                                    setModalState(() {
                                      progress = val;
                                    });
                                  },
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Démonstration LSC (${playbackSpeed}x)',
                                    style: GoogleFonts.inter(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        if (playbackSpeed == 1.0) {
                                          playbackSpeed = 0.5; // Ralenti pour mieux observer le geste !
                                        } else if (playbackSpeed == 0.5) {
                                          playbackSpeed = 1.5;
                                        } else {
                                          playbackSpeed = 1.0;
                                        }
                                        
                                        if (isPlaying) {
                                          startPlayback(setModalState);
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white24,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Vitesse LSC',
                                        style: GoogleFonts.shareTechMono(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
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
                      sign['description'] as String,
                      style: GoogleFonts.inter(fontSize: 14.5, color: Colors.grey.shade800, height: 1.55),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  Text(
                    'VARIANTE RÉGIONALE',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sign['variant'] as String,
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 28),
                  
                  ElevatedButton.icon(
                    onPressed: () {
                      stopPlayback();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Lancement du module d\'apprentissage interactif pour "${sign['word']}"', style: GoogleFonts.inter()),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      );
                    },
                    icon: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
                    label: Text('S\'ENTRAÎNER A CE SIGNE', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 2,
                      shadowColor: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      videoTimer?.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Filtrer la liste des signes
    final filteredSigns = _officialSigns.where((sign) {
      final matchesSearch = (sign['word'] as String).contains(_searchQuery.toUpperCase());
      final matchesCategory = _selectedCategory == 'Tous' || (sign['category'] as String) == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Dictionnaire des Signes',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Barre de recherche
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade100, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5)),
                  ],
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un mot (ex: BONJOUR, DANGER...)',
                    hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            // Catégories horizontales
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = cat == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedCategory = cat);
                      },
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      disabledColor: Colors.transparent,
                      side: BorderSide(
                        color: isSelected ? Colors.transparent : Colors.grey.shade200,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      showCheckmark: false,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),

            // Grille des signes officiels
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Text(
                    'SIGNES OFFICIELS (${filteredSigns.length})',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: filteredSigns.length,
                    itemBuilder: (context, index) {
                      final sign = filteredSigns[index];
                      return InkWell(
                        onTap: () => _showSignDetails(sign),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.grey.shade100, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(sign['emoji'] as String, style: const TextStyle(fontSize: 32)),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  sign['word'] as String,
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14.5, letterSpacing: 0.5),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  sign['category'] as String,
                                  style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 36),
                  
                  // Section communautaire
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PROPOSITIONS COMMUNAUTÉ (${_communitySuggestions.length})',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5),
                      ),
                      TextButton.icon(
                        onPressed: _showAddSignDialog,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text('Proposer', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  ..._communitySuggestions.map((sign) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.orange.shade50,
                          child: Text(sign['emoji'] as String, style: const TextStyle(fontSize: 20)),
                        ),
                        title: Text(
                          sign['word'] as String, 
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                        ),
                        subtitle: Text(
                          'Auteur : ${sign['author']} • ${sign['variant']}', 
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade100),
                          ),
                          child: Text(
                            sign['status'] as String,
                            style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  
                  const SizedBox(height: 96),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCameraSimulator(BuildContext parentContext, Function(String) onVideoCaptured) {
    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (context) {
        return CameraViewfinderSimulator(
          onVideoCaptured: onVideoCaptured,
        );
      },
    );
  }
}

class CameraViewfinderSimulator extends StatefulWidget {
  final Function(String) onVideoCaptured;

  const CameraViewfinderSimulator({super.key, required this.onVideoCaptured});

  @override
  State<CameraViewfinderSimulator> createState() => _CameraViewfinderSimulatorState();
}

class _CameraViewfinderSimulatorState extends State<CameraViewfinderSimulator>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _blinkController.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _recordSeconds++;
      });

      if (_recordSeconds >= 3) {
        _stopRecording();
      }
    });
  }

  void _stopRecording() {
    _recordTimer?.cancel();
    final fileName = 'lsc_gesture_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}.mp4';
    widget.onVideoCaptured(fileName);
    Navigator.pop(context); // Fermer le modal de la caméra

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Geste LSC enregistré avec succès !',
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        width: double.infinity,
        height: size.height * 0.7,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fond sombre futuriste
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0xFF1E1B4B), Color(0xFF020617)],
                  radius: 1.2,
                ),
              ),
            ),
            
            // Grille de ciblage
            CustomPaint(
              painter: CameraViewfinderGridPainter(),
            ),

            // Guide de silhouette de main pointillée
            Center(
              child: Opacity(
                opacity: _isRecording ? 0.35 : 0.2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isRecording ? AppColors.secondary : Colors.white,
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.back_hand_rounded,
                        size: 72,
                        color: _isRecording ? AppColors.secondary : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'PLACEZ VOTRE MAIN ICI',
                      style: GoogleFonts.poppins(
                        color: _isRecording ? AppColors.secondary : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Overlay de statut supérieur (Timer et point clignotant)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Point clignotant REC + Timer
                  Row(
                    children: [
                      FadeTransition(
                        opacity: _blinkController,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isRecording ? Colors.red : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isRecording ? 'REC 00:0$_recordSeconds' : 'STANDBY',
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  // Détails
                  Text(
                    'LSC ENREGISTREUR V1.0',
                    style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),

            // Actions de contrôle inférieures
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Bouton Annuler
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white12,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  
                  // Déclencheur d'enregistrement
                  GestureDetector(
                    onTap: () {
                      if (_isRecording) {
                        _stopRecording();
                      } else {
                        _startRecording();
                      }
                    },
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: _isRecording ? 24 : 54,
                          height: _isRecording ? 24 : 54,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(_isRecording ? 6 : 27),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bouton d'orientation caméra (Simulation)
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 22),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white12,
                      padding: const EdgeInsets.all(12),
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
}

class CameraViewfinderGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(Offset(size.width * 0.25, 0), Offset(size.width * 0.25, size.height), paint);
    canvas.drawLine(Offset(size.width * 0.75, 0), Offset(size.width * 0.75, size.height), paint);
    canvas.drawLine(Offset(0, size.height * 0.25), Offset(size.width, size.height * 0.25), paint);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.75), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

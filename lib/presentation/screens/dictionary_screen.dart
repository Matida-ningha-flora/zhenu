import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../widgets/hand_skeleton_painter.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> with SingleTickerProviderStateMixin {
  // Contrôle des onglets principaux (0: Mots ➔ Signe, 1: Signe ➔ Mot, 2: Favoris)
  int _activeTabIndex = 0;

  // Filtres de recherche par mot
  String _searchQuery = '';
  String _selectedCategory = 'Tous';
  String _selectedDifficulty = 'Tous';
  String _selectedLetter = 'Tous';

  // Filtres visuels par paramètres (Signe ➔ Mot)
  String? _paramHandshape;
  String? _paramLocation;
  String? _paramMovement;

  // Set des identifiants des signes favoris
  Set<String> _favoriteSignIds = {};

  @override
  void initState() {
    super.initState();
    _loadDictionaryData();
  }

  Future<void> _loadDictionaryData() async {
    final prefs = await SharedPreferences.getInstance();
    final officialJson = prefs.getString('dict_official_signs');
    final communityJson = prefs.getString('dict_community_suggestions');
    final favList = prefs.getStringList('dict_favorites');

    setState(() {
      if (officialJson != null) {
        final List dynamicList = jsonDecode(officialJson);
        _officialSigns = dynamicList.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      if (communityJson != null) {
        final List dynamicList = jsonDecode(communityJson);
        _communitySuggestions = dynamicList.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      if (favList != null) {
        _favoriteSignIds = favList.toSet();
      }
    });
  }

  Future<void> _saveDictionaryData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dict_official_signs', jsonEncode(_officialSigns));
    await prefs.setString('dict_community_suggestions', jsonEncode(_communitySuggestions));
    await prefs.setStringList('dict_favorites', _favoriteSignIds.toList());
  }

  void _toggleFavorite(String id) {
    setState(() {
      if (_favoriteSignIds.contains(id)) {
        _favoriteSignIds.remove(id);
      } else {
        _favoriteSignIds.add(id);
      }
    });
    _saveDictionaryData();
  }

  // Nettoyage des accents pour une recherche insensible aux accents
  String _normalizeString(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c');
  }

  final List<String> _categories = [
    'Tous',
    'Salutations',
    'Urgences',
    'Nombres',
    'Vie quotidienne',
    'Famille',
    'Santé',
    'Émotions',
    'Transport & Lieux',
    'Technologie & Travail',
    'Temps',
    'Culture & Cameroun',
  ];

  final List<String> _alphabet = [
    'Tous',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
  ];

  // Options pour la recherche visuelle par paramètres (Signe ➔ Mot)
  final List<Map<String, String>> _handshapes = [
    {'name': 'Main plate', 'icon': '✋'},
    {'name': 'Poing', 'icon': '✊'},
    {'name': 'Index', 'icon': '☝️'},
    {'name': 'Paume ouverte', 'icon': '🖐️'},
    {'name': 'Pince', 'icon': '🤏'},
    {'name': 'C-shape', 'icon': '🤌'},
    {'name': 'Victoire', 'icon': '✌️'},
    {'name': 'Cornes', 'icon': '🤘'},
  ];

  final List<Map<String, String>> _locations = [
    {'name': 'Tête / Visage', 'icon': '👤'},
    {'name': 'Bouche / Menton', 'icon': '👄'},
    {'name': 'Torse / Poitrine', 'icon': '🫁'},
    {'name': 'Bras / Poignet', 'icon': '💪'},
    {'name': 'Espace neutre', 'icon': '🌌'},
  ];

  final List<Map<String, String>> _movements = [
    {'name': 'Fixe', 'icon': '⏹️'},
    {'name': 'Linéaire (Haut/Bas)', 'icon': '↕️'},
    {'name': 'Circulaire', 'icon': '🔄'},
    {'name': 'Repétitif', 'icon': '🔁'},
    {'name': 'Oscillant', 'icon': '〰️'},
  ];

  // Base de données enrichie de 30+ signes officiels LSC avec guides de réalisation gestuelle
  List<Map<String, dynamic>> _officialSigns = [
    {
      'id': '1',
      'word': 'BONJOUR',
      'category': 'Salutations',
      'gestureEmoji': '👋',
      'gestureSummary': 'Main plate de la tempe vers l\'avant',
      'description': 'Placez la main droite ouverte près de votre tempe droite, puis déplacez-la doucement vers l\'avant en souriant.',
      'step1': 'Forme : Placez la main droite plate ouverte près de la tempe droite.',
      'step2': 'Mouvement : Inclinez et déplacez doucement la main vers l\'avant.',
      'step3': 'Expression : Accompagnez le geste d\'un léger sourire et d\'un contact visuel.',
      'variant': 'LSC (Langue des Signes Camerounaise) - Standard national',
      'difficulty': 'Facile',
      'handshape': 'Main plate',
      'location': 'Tête / Visage',
      'movement': 'Linéaire (Haut/Bas)',
      'dactylology': 'B - O - N - J - O - U - R',
      'exampleSentence': 'Bonjour tout le monde, bienvenue dans notre communauté !',
    },
    {
      'id': '2',
      'word': 'MERCI',
      'category': 'Salutations',
      'gestureEmoji': '🖐️',
      'gestureSummary': 'Main plate de la bouche vers l\'avant',
      'description': 'Touchez vos lèvres avec le bout des doigts de votre main plate droite, puis inclinez doucement la main vers l\'avant.',
      'step1': 'Forme : Touchez vos lèvres avec le bout des doigts de la main plate.',
      'step2': 'Mouvement : Descendez et avancez la main vers votre interlocuteur.',
      'step3': 'Attitude : Hochez légèrement la tête en signe de gratitude.',
      'variant': 'LSC / LSF - Universel',
      'difficulty': 'Facile',
      'handshape': 'Main plate',
      'location': 'Bouche / Menton',
      'movement': 'Linéaire (Haut/Bas)',
      'dactylology': 'M - E - R - C - I',
      'exampleSentence': 'Merci beaucoup pour votre soutien chaleureux.',
    },
    {
      'id': '3',
      'word': 'HÔPITAL',
      'category': 'Urgences',
      'gestureEmoji': '✌️',
      'gestureSummary': 'Tracer une croix sur le bras avec V',
      'description': 'Tracez une croix médicale sur le haut de votre bras gauche avec l\'index et le majeur joints de la main droite.',
      'step1': 'Forme : Joignez l\'index et le majeur de la main droite (forme en V).',
      'step2': 'Emplacement : Positionnez la main sur le haut du bras gauche opposé.',
      'step3': 'Mouvement : Tracez une ligne verticale puis une ligne horizontale (croix médicale).',
      'variant': 'LSC - Indique la croix rouge médicale',
      'difficulty': 'Moyen',
      'handshape': 'Victoire',
      'location': 'Bras / Poignet',
      'movement': 'Repétitif',
      'dactylology': 'H - O - P - I - T - A - L',
      'exampleSentence': 'L\'ambulance conduit le patient d\'urgence à l\'hôpital.',
    },
    {
      'id': '4',
      'word': 'DANGER',
      'category': 'Urgences',
      'gestureEmoji': '✊',
      'gestureSummary': 'Taper le poing sur la main plate',
      'description': 'Tapez deux fois le dos de la main gauche plat avec le poing droit fermé de manière ferme.',
      'step1': 'Forme : Placez la main gauche plate horizontale devant vous.',
      'step2': 'Mouvement : Fermez la main droite en poing et frappez deux fois le dos de la main gauche.',
      'step3': 'Visage : Adoptez une expression faciale d\'alerte et de vigilance.',
      'variant': 'LSC - Alerte & Vigilance',
      'difficulty': 'Moyen',
      'handshape': 'Poing',
      'location': 'Espace neutre',
      'movement': 'Repétitif',
      'dactylology': 'D - A - N - G - E - R',
      'exampleSentence': 'Attention, il y a un danger sur la route principale.',
    },
    {
      'id': '5',
      'word': 'KOSSAM (LAIT)',
      'category': 'Culture & Cameroun',
      'gestureEmoji': '✊',
      'gestureSummary': 'Mouvement vertical de traite des mains',
      'description': 'Frotter les deux mains l\'une contre l\'autre verticalement en simulant le geste traditionnel de la traite.',
      'step1': 'Forme : Fermez les deux mains en poings l\'une au-dessus de l\'autre.',
      'step2': 'Mouvement : Frottez les poings de haut en bas en alternance (traite du lait).',
      'step3': 'Origine : Geste traditionnel Fulfulde du Nord-Cameroun.',
      'variant': 'Variante régionale Nord-Cameroun (Fulfulde)',
      'difficulty': 'Facile',
      'handshape': 'Poing',
      'location': 'Espace neutre',
      'movement': 'Linéaire (Haut/Bas)',
      'dactylology': 'K - O - S - S - A - M',
      'exampleSentence': 'Je bois du kossam frais préparé ce matin.',
    },
    {
      'id': '6',
      'word': 'NDOLÈ',
      'category': 'Culture & Cameroun',
      'gestureEmoji': '🖐️',
      'gestureSummary': 'Mouvement circulaire de lavage des feuilles',
      'description': 'Simuler le lavage et le pressage des feuilles de ndolè avec les mains en mouvements circulaires.',
      'step1': 'Forme : Ouvrez les deux paumes l\'une en face de l\'autre.',
      'step2': 'Mouvement : Effectuez des mouvements circulaires de friction douce des paumes.',
      'step3': 'Origine : Imite le malaxage des feuilles de ndolè dans la tradition Littoral.',
      'variant': 'Variante culturelle Cameroun Littoral (Duala)',
      'difficulty': 'Moyen',
      'handshape': 'Paume ouverte',
      'location': 'Espace neutre',
      'movement': 'Circulaire',
      'dactylology': 'N - D - O - L - E',
      'exampleSentence': 'Le plat national de Ndolè est prêt pour la célébration.',
    },
    {
      'id': '7',
      'word': 'VOITURE',
      'category': 'Transport & Lieux',
      'gestureEmoji': '✊',
      'gestureSummary': 'Rotation des deux poings au volant',
      'description': 'Formez deux poings fermés devant la poitrine et faites-les pivoter alternativement comme pour tourner un volant.',
      'step1': 'Forme : Fermez les deux mains en poings fermés à hauteur de poitrine.',
      'step2': 'Emplacement : Placez les poings dans l\'espace neutre devant vous.',
      'step3': 'Mouvement : Inclinez alternativement le poing gauche et le poing droit (mouvement de volant).',
      'variant': 'Universel',
      'difficulty': 'Facile',
      'handshape': 'Poing',
      'location': 'Espace neutre',
      'movement': 'Oscillant',
      'dactylology': 'V - O - I - T - U - R - E',
      'exampleSentence': 'Nous prenons la voiture pour voyager à Yaoundé.',
    },
    {
      'id': '8',
      'word': 'MANGER',
      'category': 'Vie quotidienne',
      'gestureEmoji': '🤏',
      'gestureSummary': 'Pince de doigts ramenée à la bouche',
      'description': 'Regroupez les 5 doigts de la main droite en pince serrée et amenez-les vers la bouche à deux reprises.',
      'step1': 'Forme : Regroupez le bout des 5 doigts de la main droite en pince.',
      'step2': 'Emplacement : Positionnez la main près des lèvres.',
      'step3': 'Mouvement : Effectuez un mouvement répété d\'aller-retour vers la bouche.',
      'variant': 'LSC / LSF - Standard',
      'difficulty': 'Facile',
      'handshape': 'Pince',
      'location': 'Bouche / Menton',
      'movement': 'Repétitif',
      'dactylology': 'M - A - N - G - E - R',
      'exampleSentence': 'Il est l\'heure de manger ensemble à table.',
    },
    {
      'id': '9',
      'word': 'BOIRE',
      'category': 'Vie quotidienne',
      'gestureEmoji': '🤌',
      'gestureSummary': 'Main en C inclinée vers les lèvres',
      'description': 'Formez un C avec la main droite comme pour tenir un verre et inclinez le pouce vers votre bouche.',
      'step1': 'Forme : Formez un C arrondi avec le pouce et les autres doigts de la main droite.',
      'step2': 'Emplacement : Amenez le pouce près des lèvres.',
      'step3': 'Mouvement : Inclinez le poignet vers le haut en arrière comme pour boire un verre.',
      'variant': 'Universel',
      'difficulty': 'Facile',
      'handshape': 'C-shape',
      'location': 'Bouche / Menton',
      'movement': 'Linéaire (Haut/Bas)',
      'dactylology': 'B - O - I - R - E',
      'exampleSentence': 'Donnez-moi de l\'eau fraîche à boire s\'il vous plaît.',
    },
    {
      'id': '10',
      'word': 'UN',
      'category': 'Nombres',
      'gestureEmoji': '☝️',
      'gestureSummary': 'Index dressé verticalement',
      'description': 'Levez l\'index de la main droite vers le haut, paume tournée vers l\'avant.',
      'step1': 'Forme : Dressez l\'index de la main droite vers le ciel.',
      'step2': 'Emplacement : Maintenez l\'index fixe devant le torse.',
      'variant': 'Universel',
      'difficulty': 'Facile',
      'handshape': 'Index',
      'location': 'Espace neutre',
      'movement': 'Fixe',
      'dactylology': 'U - N',
      'exampleSentence': 'Je voudrais un seul verre d\'eau.',
    },
    {
      'id': '11',
      'word': 'DEUX',
      'category': 'Nombres',
      'gestureEmoji': '✌️',
      'gestureSummary': 'Index et majeur levés en V',
      'description': 'Levez l\'index et le majeur en forme de V, paume tournée vers l\'avant.',
      'step1': 'Forme : Écartez l\'index et le majeur en forme de V.',
      'step2': 'Emplacement : Paume tournée vers votre interlocuteur.',
      'variant': 'Universel',
      'difficulty': 'Facile',
      'handshape': 'Victoire',
      'location': 'Espace neutre',
      'movement': 'Fixe',
      'dactylology': 'D - E - U - X',
      'exampleSentence': 'Nous avons deux billets pour la rencontre.',
    },
    {
      'id': '12',
      'word': 'POLICE',
      'category': 'Urgences',
      'gestureEmoji': '✊',
      'gestureSummary': 'Poing tapoté sur la poitrine gauche',
      'description': 'Tapoter deux fois sur le côté gauche du torse avec le poing pour marquer l\'emplacement de l\'insigne.',
      'step1': 'Forme : Fermez la main droite en poing.',
      'step2': 'Mouvement : Tapotez deux fois sur le torse côté cœur (emplacement de l\'insigne).',
      'variant': 'LSC - National',
      'difficulty': 'Moyen',
      'handshape': 'Poing',
      'location': 'Torse / Poitrine',
      'movement': 'Repétitif',
      'dactylology': 'P - O - L - I - C - E',
      'exampleSentence': 'La police est sur place pour sécuriser la zone.',
    },
    {
      'id': '13',
      'word': 'AMBULANCE',
      'category': 'Urgences',
      'gestureEmoji': '☝️',
      'gestureSummary': 'Index tournant en lacet au-dessus de la tête',
      'description': 'Faire tourner l\'index en lacet au-dessus de la tête pour imiter la gyrophare.',
      'step1': 'Forme : Pointez l\'index droit vers le haut au-dessus de la tête.',
      'step2': 'Mouvement : Effectuez une rotation circulaire rapide avec l\'index (gyrophare).',
      'variant': 'LSC - Signal sonore visuel',
      'difficulty': 'Facile',
      'handshape': 'Index',
      'location': 'Tête / Visage',
      'movement': 'Circulaire',
      'dactylology': 'A - M - B - U - L - A - N - C - E',
      'exampleSentence': 'L\'ambulance arrive rapidement avec la sirène.',
    },
    {
      'id': '14',
      'word': 'SECOURS',
      'category': 'Urgences',
      'gestureEmoji': '🖐️',
      'gestureSummary': 'Balayage des mains ouvertes au-dessus des épaules',
      'description': 'Agiter les deux mains ouvertes au-dessus des épaules de gauche à droite.',
      'step1': 'Forme : Levez les deux paumes ouvertes au niveau des épaules.',
      'step2': 'Mouvement : Balayez les mains de gauche à droite en signe de détresse.',
      'variant': 'Universel LSC',
      'difficulty': 'Facile',
      'handshape': 'Paume ouverte',
      'location': 'Espace neutre',
      'movement': 'Oscillant',
      'dactylology': 'S - E - C - O - U - R - S',
      'exampleSentence': 'Appelez les secours immédiatement !',
    },
    {
      'id': '15',
      'word': 'PÈRE',
      'category': 'Famille',
      'gestureEmoji': '🖐️',
      'gestureSummary': 'Pouce tapotant la tempe droite',
      'description': 'Tapoter deux fois la tempe droite avec le pouce de la main plate ouverte.',
      'step1': 'Forme : Ouvrez la main droite en paume plate.',
      'step2': 'Mouvement : Tapotez le bout du pouce deux fois sur la tempe droite.',
      'variant': 'LSC Standard',
      'difficulty': 'Facile',
      'handshape': 'Paume ouverte',
      'location': 'Tête / Visage',
      'movement': 'Repétitif',
      'dactylology': 'P - E - R - E',
      'exampleSentence': 'Mon père travaille dans l\'enseignement.',
    },
    {
      'id': '16',
      'word': 'MÈRE',
      'category': 'Famille',
      'gestureEmoji': '✋',
      'gestureSummary': 'Paume tapotant la joue droite',
      'description': 'Tapoter deux fois la joue droite avec la paume de la main plate ouverte.',
      'step1': 'Forme : Placez la main droite plate contre la joue droite.',
      'step2': 'Mouvement : Tapotez doucement la joue deux fois.',
      'variant': 'LSC Standard',
      'difficulty': 'Facile',
      'handshape': 'Main plate',
      'location': 'Tête / Visage',
      'movement': 'Repétitif',
      'dactylology': 'M - E - R - E',
      'exampleSentence': 'Ma mère prépare un repas délicieux.',
    },
    {
      'id': '17',
      'word': 'ENFANT',
      'category': 'Famille',
      'gestureEmoji': '✋',
      'gestureSummary': 'Main plate abaissée vers le bas',
      'description': 'Mettre la main plate horizontale vers le bas et faire un petit mouvement vers le bas (hauteur d\'enfant).',
      'step1': 'Forme : Tenez la main droite plate horizontale paume vers le bas.',
      'step2': 'Mouvement : Effectuez deux légers mouvements de tapotement vers le bas.',
      'variant': 'LSC Standard',
      'difficulty': 'Facile',
      'handshape': 'Main plate',
      'location': 'Espace neutre',
      'movement': 'Linéaire (Haut/Bas)',
      'dactylology': 'E - N - F - A - N - T',
      'exampleSentence': 'L\'enfant apprend la langue des signes à l\'école.',
    },
    {
      'id': '18',
      'word': 'CONTENT',
      'category': 'Émotions',
      'gestureEmoji': '🖐️',
      'gestureSummary': 'Friction circulaire de la paume sur le cœur',
      'description': 'Frotter circulairement le milieu de la poitrine avec la paume de la main droite ouverte.',
      'step1': 'Forme : Posez la paume ouverte sur le centre de la poitrine.',
      'step2': 'Mouvement : Tournez la main en cercles doux dans le sens des aiguilles d\'une montre.',
      'variant': 'LSC / LSF',
      'difficulty': 'Facile',
      'handshape': 'Paume ouverte',
      'location': 'Torse / Poitrine',
      'movement': 'Circulaire',
      'dactylology': 'C - O - N - T - E - N - T',
      'exampleSentence': 'Je suis très content de te rencontrer.',
    },
    {
      'id': '19',
      'word': 'COLÈRE',
      'category': 'Émotions',
      'gestureEmoji': '🤏',
      'gestureSummary': 'Griffes remontant brusquement le torse',
      'description': 'Monter brusquement les doigts crochus de la poitrine vers le menton avec une expression ferme.',
      'step1': 'Forme : Pliez les doigts en forme de griffes.',
      'step2': 'Mouvement : Remontez brusquement les mains du torse vers le menton.',
      'variant': 'LSC Expression forte',
      'difficulty': 'Moyen',
      'handshape': 'Pince',
      'location': 'Torse / Poitrine',
      'movement': 'Linéaire (Haut/Bas)',
      'dactylology': 'C - O - L - E - R - E',
      'exampleSentence': 'Calme-toi, il ne faut pas se mettre en colère.',
    },
    {
      'id': '20',
      'word': 'CAMEROUN',
      'category': 'Culture & Cameroun',
      'gestureEmoji': '🤌',
      'gestureSummary': 'Main en C au cœur projetée vers l\'avant',
      'description': 'Former la lettre C avec la main droite au niveau du cœur puis avancer la main vers l\'avant.',
      'step1': 'Forme : Formez la lettre C avec la main droite sur le cœur.',
      'step2': 'Mouvement : Déplacez la main en C vers l\'avant avec assurance.',
      'variant': 'LSC Symbole National',
      'difficulty': 'Facile',
      'handshape': 'C-shape',
      'location': 'Torse / Poitrine',
      'movement': 'Linéaire (Haut/Bas)',
      'dactylology': 'C - A - M - E - R - O - U - N',
      'exampleSentence': 'Le Cameroun est un pays d\'une grande diversité culturelle.',
    },
    {
      'id': '21',
      'word': 'S\'IL TE PLAÎT',
      'category': 'Salutations',
      'gestureEmoji': '✋',
      'gestureSummary': 'Main plate glissant du torse vers le bas',
      'description': 'Placer la main plate sur la poitrine et la faire descendre doucement.',
      'step1': 'Forme : Posez la main plate au centre de la poitrine.',
      'step2': 'Mouvement : Glissez la main vers le bas en vous inclinant légèrement.',
      'variant': 'LSC Politesse',
      'difficulty': 'Facile',
      'handshape': 'Main plate',
      'location': 'Torse / Poitrine',
      'movement': 'Linéaire (Haut/Bas)',
      'dactylology': 'S - P - L',
      'exampleSentence': 'Donne-moi ce livre s\'il te plaît.',
    },
    {
      'id': '22',
      'word': 'AU REVOIR',
      'category': 'Salutations',
      'gestureEmoji': '🖐️',
      'gestureSummary': 'Agiter les doigts ou balancer la paume',
      'description': 'Agiter les doigts de la main ouverte de haut en bas devant soi.',
      'step1': 'Forme : Levez la main ouverte paume vers l\'avant.',
      'step2': 'Mouvement : Pliez et dépliez les 4 doigts de façon rythmée.',
      'variant': 'Universel',
      'difficulty': 'Facile',
      'handshape': 'Paume ouverte',
      'location': 'Espace neutre',
      'movement': 'Oscillant',
      'dactylology': 'A - U - R - E - V - O - I - R',
      'exampleSentence': 'Au revoir et à la semaine prochaine !',
    },
    {
      'id': '23',
      'word': 'ÉCOLE',
      'category': 'Technologie & Travail',
      'gestureEmoji': '✋',
      'gestureSummary': 'Paume droite tapotée sur paume gauche',
      'description': 'Tapoter deux fois la paume gauche ouverte avec la paume droite ouverte.',
      'step1': 'Forme : Placez la paume gauche horizontale vers le haut.',
      'step2': 'Mouvement : Frappez deux fois la paume droite sur la paume gauche.',
      'variant': 'LSC Éducation',
      'difficulty': 'Facile',
      'handshape': 'Main plate',
      'location': 'Espace neutre',
      'movement': 'Repétitif',
      'dactylology': 'E - C - O - L - E',
      'exampleSentence': 'Les enfants vont à l\'école tous les matins.',
    },
    {
      'id': '24',
      'word': 'ORDINATEUR',
      'category': 'Technologie & Travail',
      'gestureEmoji': '🖐️',
      'gestureSummary': 'Dactylographie virtuelle à dix doigts',
      'description': 'Faire un mouvement d\'intégration au clavier avec les dix doigts au-dessus de la table.',
      'step1': 'Forme : Placez les deux mains à plat devant vous.',
      'step2': 'Mouvement : Agitez le bout des 10 doigts comme pour saisir un texte au clavier.',
      'variant': 'LSC Moderne',
      'difficulty': 'Moyen',
      'handshape': 'Paume ouverte',
      'location': 'Espace neutre',
      'movement': 'Repétitif',
      'dactylology': 'O - R - D - I - N - A - T - E - U - R',
      'exampleSentence': 'J\'utilise mon ordinateur pour la traduction LSC.',
    },
    {
      'id': '25',
      'word': 'TÉLÉPHONE',
      'category': 'Technologie & Travail',
      'gestureEmoji': '🤘',
      'gestureSummary': 'Pouce et auriculaire (forme Y) à l\'oreille',
      'description': 'Former le signe du téléphone avec le pouce et l\'auriculaire et l\'amener près de l\'oreille.',
      'step1': 'Forme : Dépliez le pouce et l\'auriculaire en repliant les autres doigts.',
      'step2': 'Emplacement : Placez le pouce contre l\'oreille.',
      'variant': 'Universel',
      'difficulty': 'Facile',
      'handshape': 'Cornes',
      'location': 'Tête / Visage',
      'movement': 'Fixe',
      'dactylology': 'T - E - L - E - P - H - O - N - E',
      'exampleSentence': 'Appelle-moi sur mon téléphone portable.',
    },
    {
      'id': '26',
      'word': 'MÉDICAMENT',
      'category': 'Santé',
      'gestureEmoji': '☝️',
      'gestureSummary': 'Friction du majeur au centre de la paume opposée',
      'description': 'Frotter le majeur dans la paume de la main gauche plate (geste de broyer la pilule).',
      'step1': 'Forme : Placez la paume gauche à plat vers le haut.',
      'step2': 'Mouvement : Tournez le majeur droit en petit cercle dans la paume gauche.',
      'variant': 'LSC Santé',
      'difficulty': 'Moyen',
      'handshape': 'Index',
      'location': 'Espace neutre',
      'movement': 'Circulaire',
      'dactylology': 'M - E - D - I - C - A - M - E - N - T',
      'exampleSentence': 'Prenez ce médicament après le repas.',
    },
    {
      'id': '27',
      'word': 'MAISON',
      'category': 'Transport & Lieux',
      'gestureEmoji': '✋',
      'gestureSummary': 'Mains plates jointes en forme de toit',
      'description': 'Formez un toit avec les bouts des doigts des deux mains plates inclinées.',
      'step1': 'Forme : Joignez le bout des doigts des deux mains plates en V inversé.',
      'step2': 'Emplacement : Maintenez la forme de toit au-dessus du torse.',
      'variant': 'Universel',
      'difficulty': 'Facile',
      'handshape': 'Main plate',
      'location': 'Espace neutre',
      'movement': 'Fixe',
      'dactylology': 'M - A - I - S - O - N',
      'exampleSentence': 'Bienvenue dans notre maison.',
    },
    {
      'id': '28',
      'word': 'AUJOURD\'HUI',
      'category': 'Temps',
      'gestureEmoji': '☝️',
      'gestureSummary': 'Deux index pointant fermement vers le sol',
      'description': 'Pointer deux fois les deux index vers le bas devant soi à hauteur de poitrine.',
      'step1': 'Forme : Pointez les deux index vers le sol.',
      'step2': 'Mouvement : Effectuez deux petits coups nets vers le bas.',
      'variant': 'LSC Temporalité',
      'difficulty': 'Facile',
      'handshape': 'Index',
      'location': 'Torse / Poitrine',
      'movement': 'Repétitif',
      'dactylology': 'A - U - J - O - U - R - D - H - U - I',
      'exampleSentence': 'Aujourd\'hui nous apprenons de nouveaux signes.',
    },
    {
      'id': '29',
      'word': 'DEMAIN',
      'category': 'Temps',
      'gestureEmoji': '✊',
      'gestureSummary': 'Pouce pivotant de la joue vers l\'avant',
      'description': 'Faire pivoter le pouce depuis la joue vers l\'avant.',
      'step1': 'Forme : Placez le dos du pouce droit contre la joue.',
      'step2': 'Mouvement : Projetez le pouce vers l\'avant par pivotement du poignet.',
      'variant': 'LSC Standard',
      'difficulty': 'Moyen',
      'handshape': 'Poing',
      'location': 'Tête / Visage',
      'movement': 'Linéaire (Haut/Bas)',
      'dactylology': 'D - E - M - A - I - N',
      'exampleSentence': 'Nous nous reverrons demain matin.',
    },
    {
      'id': '30',
      'word': 'HEURE',
      'category': 'Temps',
      'gestureEmoji': '☝️',
      'gestureSummary': 'Index tapotant le poignet opposé',
      'description': 'Tapoter le poignet gauche avec l\'index droit comme pour indiquer une montre.',
      'step1': 'Forme : Tenez le poignet gauche horizontal.',
      'step2': 'Mouvement : Tapotez deux fois le poignet avec l\'index droit (montre).',
      'variant': 'Universel',
      'difficulty': 'Facile',
      'handshape': 'Index',
      'location': 'Bras / Poignet',
      'movement': 'Repétitif',
      'dactylology': 'H - E - U - R - E',
      'exampleSentence': 'Quelle heure est-il s\'il vous plaît ?',
    },
  ];

  // Propositions communautaires
  List<Map<String, dynamic>> _communitySuggestions = [
    {
      'id': 'c1',
      'word': 'BEIGNET HARICOT',
      'category': 'Culture & Cameroun',
      'gestureEmoji': '🧆',
      'gestureSummary': 'Attraper beignet + cuillère dans le haricot',
      'description': 'Simuler le fait d\'attraper un beignet rond puis d\'enfoncer la cuillère dans le haricot.',
      'variant': 'Variante populaire Douala / Yaoundé',
      'author': 'Alhadji Oumarou',
      'status': 'En attente',
      'votes': 14,
    },
    {
      'id': 'c2',
      'word': 'TUK-TUK (MOTOTAXI)',
      'category': 'Transport & Lieux',
      'gestureEmoji': '🛵',
      'gestureSummary': 'Poings au guidon + poignée d\'accélérateur',
      'description': 'Tenir le guidon avec deux poings et accélérer avec le poignet droit.',
      'variant': 'Variante urbaine Cameroun',
      'author': 'Marie Ngo',
      'status': 'En attente',
      'votes': 29,
    },
  ];

  void _upvoteCommunitySign(int index) {
    setState(() {
      final currentVotes = (_communitySuggestions[index]['votes'] as int? ?? 0);
      _communitySuggestions[index]['votes'] = currentVotes + 1;
    });
    _saveDictionaryData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Merci pour votre soutien ! Signe recommandé.', style: GoogleFonts.inter()),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

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
                        'Proposer un nouveau signe LSC',
                        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enregistrez le geste exact pour enrichir le dictionnaire !',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Nom du signe (ex: TARO, KWA...)',
                          prefixIcon: Icon(Icons.abc_rounded),
                        ),
                        validator: (v) => v!.isEmpty ? 'Veuillez entrer un nom' : null,
                        onSaved: (v) => signName = v!,
                      ),
                      const SizedBox(height: 16),
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
                      TextFormField(
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Comment réaliser le geste (Description pas à pas)',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.description_rounded),
                        ),
                        validator: (v) => v!.isEmpty ? 'Veuillez décrire l\'exécution du geste' : null,
                        onSaved: (v) => signDescription = v!,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: signVariant,
                        decoration: const InputDecoration(
                          labelText: 'Région / Variante dialectale',
                          prefixIcon: Icon(Icons.map_rounded),
                        ),
                        onSaved: (v) => signVariant = v!,
                      ),
                      const SizedBox(height: 16),
                      Container(
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
                                    ? 'Enregistrer la démonstration gestuelle' 
                                    : 'Démonstration enregistrée : $recordedVideoName',
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
                                    ? 'Appuyez pour capturer le mouvement des mains (3s)'
                                    : 'Appuyez à nouveau pour réenregistrer',
                                style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            formKey.currentState!.save();
                            setState(() {
                              _communitySuggestions.add({
                                'id': 'c_${DateTime.now().millisecondsSinceEpoch}',
                                'word': signName.toUpperCase(),
                                'category': signCategory,
                                'gestureEmoji': '🆕',
                                'gestureSummary': signDescription,
                                'description': signDescription,
                                'variant': signVariant,
                                'author': 'Moi (Membre Zhẽnù)',
                                'status': 'En attente',
                                'votes': 1,
                              });
                            });
                            _saveDictionaryData();
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Proposition enregistrée ! Merci pour votre contribution.', style: GoogleFonts.inter()),
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
                        child: Text('SOUMETTRE LE GESTE', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
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
    final String id = sign['id'] as String? ?? '0';
    bool isPlaying = true;
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
      videoTimer = Timer.periodic(Duration(milliseconds: (150 / playbackSpeed).round()), (timer) {
        setModalState(() {
          if (progress < 1.0) {
            progress += 0.05;
          } else {
            progress = 0.0;
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
            if (videoTimer == null && isPlaying) {
              startPlayback(setModalState);
            }

            final isFav = _favoriteSignIds.contains(id);

            return DraggableScrollableSheet(
              initialChildSize: 0.88,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 45, height: 4.5,
                          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(5)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 68, height: 68,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                            ),
                            alignment: Alignment.center,
                            child: Text(sign['gestureEmoji'] ?? '🤲', style: const TextStyle(fontSize: 32)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sign['word'] as String,
                                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  sign['gestureSummary'] ?? 'Comment exécuter le signe',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary.withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        sign['category'] as String,
                                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        sign['difficulty'] ?? 'Facile',
                                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Bouton synthèse vocale audio
                          IconButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.volume_up_rounded, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text('Prononciation audio de "${sign['word']}"', style: GoogleFonts.inter()),
                                    ],
                                  ),
                                  backgroundColor: AppColors.primary,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              );
                            },
                            icon: const Icon(Icons.volume_up_rounded, color: AppColors.primary),
                            style: IconButton.styleFrom(backgroundColor: AppColors.primary.withOpacity(0.08)),
                          ),
                          // Bouton Favoris
                          IconButton(
                            onPressed: () {
                              _toggleFavorite(id);
                              setModalState(() {});
                            },
                            icon: Icon(
                              isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: isFav ? Colors.amber.shade700 : Colors.grey.shade400,
                              size: 26,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Zone de démonstration visuelle du signe avec squelette de main animé
                      Text(
                        'DÉMONSTRATION DU GESTE LSC (SQUELETTE ANIMÉ)',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppColors.darkBackground,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Squelette de main dynamique MediaPipe LSC en mouvement
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: CustomPaint(
                                  painter: HandSkeletonPainter(
                                    animationValue: progress,
                                    status: isPlaying ? 'scanning' : 'idle',
                                  ),
                                ),
                              ),
                            ),

                            // Titre du signe et résumé gestuel superposé
                            Positioned(
                              top: 12,
                              left: 14,
                              right: 14,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(sign['gestureEmoji'] ?? '🤲', style: const TextStyle(fontSize: 14)),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Geste : ${sign['gestureSummary'] ?? 'Exécution du signe'}',
                                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        if (playbackSpeed == 1.0) {
                                          playbackSpeed = 0.5; // Ralenti pour observer les mouvements
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
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: playbackSpeed == 0.5 ? Colors.amber.shade700 : Colors.black54,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white24),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.speed_rounded, color: Colors.white, size: 12),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${playbackSpeed}x ${playbackSpeed == 0.5 ? '(Ralenti)' : ''}',
                                            style: GoogleFonts.shareTechMono(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Bouton Play / Pause central
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
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.22),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                                ),
                                child: Icon(
                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 38,
                                ),
                              ),
                            ),

                            // Barre de progression inférieure
                            Positioned(
                              bottom: 10,
                              left: 16,
                              right: 16,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 2.5,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
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
                                        'Démonstration du mouvement des mains',
                                        style: GoogleFonts.inter(fontSize: 10, color: Colors.white70),
                                      ),
                                      Text(
                                        '${(progress * 100).toInt()}%',
                                        style: GoogleFonts.shareTechMono(fontSize: 10, color: AppColors.secondary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Guide d'exécution étape par étape
                      Text(
                        'COMMENT RÉALISER LE SIGNE (ÉTAPES)',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
                        ),
                        child: Column(
                          children: [
                            _buildStepItem('1', 'Forme de la main : ${sign['handshape']}', sign['step1'] ?? sign['description']),
                            const SizedBox(height: 10),
                            _buildStepItem('2', 'Emplacement : ${sign['location']}', sign['step2'] ?? 'Positionnez la main au niveau indiqué.'),
                            if (sign['step3'] != null) ...[
                              const SizedBox(height: 10),
                              _buildStepItem('3', 'Mouvement : ${sign['movement']}', sign['step3']!),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Paramètres gestuels visuels
                      Text(
                        'PARAMÈTRES GESTUELS CLÉS',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildParamBadge('Forme', sign['handshape'] ?? 'Main plate', Icons.back_hand_rounded),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildParamBadge('Emplacement', sign['location'] ?? 'Visage', Icons.location_on_rounded),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildParamBadge('Mouvement', sign['movement'] ?? 'Fixe', Icons.sync_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Épellation en dactylologie
                      if (sign['dactylology'] != null) ...[
                        Text(
                          'ÉPELLATION MANUELLE (DACTYLOLOGIE)',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                          ),
                          child: Text(
                            sign['dactylology'] as String,
                            style: GoogleFonts.shareTechMono(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 2),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Exemple de phrase en contexte
                      if (sign['exampleSentence'] != null) ...[
                        Text(
                          'EXEMPLE DE PHRASE EN CONTEXTE',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '"${sign['exampleSentence']}"',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Variante régionale
                      Text(
                        'VARIANTE RÉGIONALE / DIALECTE',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sign['variant'] as String,
                        style: GoogleFonts.inter(fontSize: 12.5, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),

                      // Bouton s'entraîner
                      ElevatedButton.icon(
                        onPressed: () {
                          stopPlayback();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Lancement du module d\'entraînement pour "${sign['word']}"', style: GoogleFonts.inter()),
                              backgroundColor: AppColors.primary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          );
                        },
                        icon: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
                        label: Text('S\'ENTRAÎNER À CE GESTE', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).then((_) {
      videoTimer?.cancel();
    });
  }

  Widget _buildStepItem(String num, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            num,
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.black87),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildParamBadge(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 9.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredOfficialSigns = _officialSigns.where((sign) {
      final wordNorm = _normalizeString(sign['word'] as String);
      final queryNorm = _normalizeString(_searchQuery);
      final matchesSearch = queryNorm.isEmpty || wordNorm.contains(queryNorm);

      final matchesCategory = _selectedCategory == 'Tous' || (sign['category'] as String) == _selectedCategory;

      final matchesLetter = _selectedLetter == 'Tous' || (sign['word'] as String).startsWith(_selectedLetter);

      final matchesDifficulty = _selectedDifficulty == 'Tous' || (sign['difficulty'] ?? 'Facile') == _selectedDifficulty;

      return matchesSearch && matchesCategory && matchesLetter && matchesDifficulty;
    }).toList();

    final filteredParamSigns = _officialSigns.where((sign) {
      final matchesHandshape = _paramHandshape == null || sign['handshape'] == _paramHandshape;
      final matchesLocation = _paramLocation == null || sign['location'] == _paramLocation;
      final matchesMovement = _paramMovement == null || sign['movement'] == _paramMovement;
      return matchesHandshape && matchesLocation && matchesMovement;
    }).toList();

    final favoriteSigns = _officialSigns.where((sign) => _favoriteSignIds.contains(sign['id'])).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Dictionnaire LSC',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _selectedCategory = 'Tous';
                _selectedDifficulty = 'Tous';
                _selectedLetter = 'Tous';
                _paramHandshape = null;
                _paramLocation = null;
                _paramMovement = null;
              });
            },
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Réinitialiser les filtres',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                    Expanded(
                      child: _buildTabButton(0, '🔍 Mot ➔ Signe', filteredOfficialSigns.length),
                    ),
                    Expanded(
                      child: _buildTabButton(1, '✋ Signe ➔ Mot', filteredParamSigns.length),
                    ),
                    Expanded(
                      child: _buildTabButton(2, '⭐ Favoris', favoriteSigns.length),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: _activeTabIndex == 0
                  ? _buildTextToSignView(filteredOfficialSigns)
                  : _activeTabIndex == 1
                      ? _buildSignToTextView(filteredParamSigns)
                      : _buildFavoritesView(favoriteSigns),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, int count) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.shareTechMono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primary : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Vue 1 : Recherche Mot ➔ Signe
  Widget _buildTextToSignView(List<Map<String, dynamic>> signs) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200, width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Rechercher un mot (ex: BONJOUR, KOSSAM...)',
                hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),

        SizedBox(
          height: 34,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _alphabet.length,
            itemBuilder: (context, index) {
              final letter = _alphabet[index];
              final isSelected = letter == _selectedLetter;
              return GestureDetector(
                onTap: () => setState(() => _selectedLetter = letter),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryDark : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade200),
                  ),
                  child: Text(
                    letter,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        SizedBox(
          height: 38,
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
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade200),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  showCheckmark: false,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: signs.isEmpty
              ? _buildEmptyState('Aucun signe ne correspond à votre recherche.')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'EXÉCUTION DES GESTES (${signs.length})',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5),
                        ),
                        DropdownButton<String>(
                          value: _selectedDifficulty,
                          underline: const SizedBox(),
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                          items: ['Tous', 'Facile', 'Moyen', 'Avancé'].map((d) {
                            return DropdownMenuItem(value: d, child: Text('Niveau: $d'));
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedDifficulty = v!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.98,
                      ),
                      itemCount: signs.length,
                      itemBuilder: (context, index) {
                        final sign = signs[index];
                        final isFav = _favoriteSignIds.contains(sign['id']);

                        return InkWell(
                          onTap: () => _showSignDetails(sign),
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: Colors.grey.shade100, width: 1.5),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.08),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(sign['gestureEmoji'] ?? '🤲', style: const TextStyle(fontSize: 28)),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        sign['word'] as String,
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13.5),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.06),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          sign['gestureSummary'] ?? sign['category'],
                                          style: GoogleFonts.inter(fontSize: 9.5, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: IconButton(
                                    icon: Icon(
                                      isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                                      color: isFav ? Colors.amber.shade700 : Colors.grey.shade300,
                                      size: 20,
                                    ),
                                    onPressed: () => _toggleFavorite(sign['id'] as String),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),

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
                          label: Text('Proposer', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    ..._communitySuggestions.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final sign = entry.value;
                      final votes = sign['votes'] as int? ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.orange.shade50,
                            child: Text(sign['gestureEmoji'] ?? '🆕', style: const TextStyle(fontSize: 20)),
                          ),
                          title: Text(
                            sign['word'] as String,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                          ),
                          subtitle: Text(
                            'Par : ${sign['author']} • ${sign['variant']}',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.thumb_up_alt_rounded, color: AppColors.primary, size: 18),
                                onPressed: () => _upvoteCommunitySign(idx),
                              ),
                              Text('$votes', style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
        ),
      ],
    );
  }

  // Vue 2 : Recherche Signe ➔ Mot (Paramètres gestuels visuels)
  Widget _buildSignToTextView(List<Map<String, dynamic>> signs) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recherche par Observation Visuelle',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sélectionnez ce que vous voyez (Forme de main, Emplacement, Mouvement) pour retrouver le mot correspondant.',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          '1. FORME DE LA MAIN (HANDSHAPE)',
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _handshapes.map((item) {
            final name = item['name']!;
            final icon = item['icon']!;
            final isSelected = _paramHandshape == name;
            return ChoiceChip(
              label: Text('$icon  $name'),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _paramHandshape = selected ? name : null);
              },
              labelStyle: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.black87,
              ),
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade300),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        Text(
          '2. EMPLACEMENT DU GESTE (LOCATION)',
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _locations.map((item) {
            final name = item['name']!;
            final icon = item['icon']!;
            final isSelected = _paramLocation == name;
            return ChoiceChip(
              label: Text('$icon  $name'),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _paramLocation = selected ? name : null);
              },
              labelStyle: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.black87,
              ),
              selectedColor: AppColors.signLanguageBlue,
              backgroundColor: Colors.white,
              side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade300),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        Text(
          '3. TYPE DE MOUVEMENT (MOVEMENT)',
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _movements.map((item) {
            final name = item['name']!;
            final icon = item['icon']!;
            final isSelected = _paramMovement == name;
            return ChoiceChip(
              label: Text('$icon  $name'),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _paramMovement = selected ? name : null);
              },
              labelStyle: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.black87,
              ),
              selectedColor: AppColors.secondaryDark,
              backgroundColor: Colors.white,
              side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade300),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        if (_paramHandshape != null || _paramLocation != null || _paramMovement != null)
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _paramHandshape = null;
                _paramLocation = null;
                _paramMovement = null;
              });
            },
            icon: const Icon(Icons.cleaning_services_rounded, size: 16),
            label: Text('Réinitialiser les caractéristiques visuelles', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'MOTS CORRESPONDANTS (${signs.length})',
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5),
            ),
          ],
        ),
        const SizedBox(height: 12),

        signs.isEmpty
            ? _buildEmptyState('Aucun signe ne possède cette combinaison exacte de forme, emplacement et mouvement.')
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: signs.length,
                itemBuilder: (context, index) {
                  final sign = signs[index];
                  final isFav = _favoriteSignIds.contains(sign['id']);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      onTap: () => _showSignDetails(sign),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Text(sign['gestureEmoji'] ?? '🤲', style: const TextStyle(fontSize: 26)),
                      ),
                      title: Text(
                        sign['word'] as String,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                      ),
                      subtitle: Text(
                        '${sign['handshape']} • ${sign['location']} • ${sign['movement']}',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: isFav ? Colors.amber.shade700 : Colors.grey.shade300,
                        ),
                        onPressed: () => _toggleFavorite(sign['id'] as String),
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  // Vue 3 : Favoris
  Widget _buildFavoritesView(List<Map<String, dynamic>> signs) {
    if (signs.isEmpty) {
      return _buildEmptyState('Aucun signe enregistré dans vos favoris.\nCliquez sur l\'étoile ⭐ pour ajouter des mots.');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(
          'VOS SIGNES FAVORIS (${signs.length})',
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        ...signs.map((sign) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onTap: () => _showSignDetails(sign),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  shape: BoxShape.circle,
                ),
                child: Text(sign['gestureEmoji'] ?? '🤲', style: const TextStyle(fontSize: 26)),
              ),
              title: Text(
                sign['word'] as String,
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
              ),
              subtitle: Text(
                'Catégorie : ${sign['category']} • ${sign['difficulty'] ?? 'Facile'}',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.star_rounded, color: Colors.amber),
                onPressed: () => _toggleFavorite(sign['id'] as String),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500, height: 1.4),
              textAlign: TextAlign.center,
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
    Navigator.pop(context);

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
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0xFF1E1B4B), Color(0xFF020617)],
                  radius: 1.2,
                ),
              ),
            ),
            CustomPaint(
              painter: CameraViewfinderGridPainter(),
            ),
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
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                  Text(
                    'LSC ENREGISTREUR V1.0',
                    style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white12,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
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

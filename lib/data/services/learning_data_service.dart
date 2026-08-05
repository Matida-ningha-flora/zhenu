import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LearningDataService {
  static const String _coursesStorageKey = 'zhenu_learning_courses_v3';
  static const String _userStatsStorageKey = 'zhenu_user_learning_stats_v3';

  // Obtenir tous les cours et le parcours séquentiel
  static Future<List<Map<String, dynamic>>> getCourses() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_coursesStorageKey);

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((item) => Map<String, dynamic>.from(item)).toList();
      } catch (e) {
        debugPrint('Erreur lors du décodage des cours v3: $e');
      }
    }

    final defaultCourses = _getDefaultSequentialCourses();
    await saveCourses(defaultCourses);
    return defaultCourses;
  }

  // Sauvegarder les cours
  static Future<void> saveCourses(List<Map<String, dynamic>> courses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_coursesStorageKey, jsonEncode(courses));
  }

  // Obtenir les statistiques globales de l'apprenant
  static Future<Map<String, dynamic>> getUserStats() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_userStatsStorageKey);

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        return Map<String, dynamic>.from(jsonDecode(jsonStr));
      } catch (e) {
        debugPrint('Erreur décodage stats v3: $e');
      }
    }

    final defaultStats = {
      'todayXp': 50,
      'totalXp': 350,
      'streakDays': 5,
      'completedStepsCount': 3,
      'level': 3,
      'lastActivityDate': DateTime.now().toIso8601String().split('T')[0],
    };
    await saveUserStats(defaultStats);
    return defaultStats;
  }

  // Sauvegarder les stats
  static Future<void> saveUserStats(Map<String, dynamic> stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userStatsStorageKey, jsonEncode(stats));
  }

  // Valider une étape par test caméra ou vidéo et débloquer l'étape suivante
  static Future<Map<String, dynamic>> completeStepAndUnlockNext(
    String courseId,
    String stepId,
    int xpReward,
  ) async {
    final courses = await getCourses();
    final stats = await getUserStats();

    for (var course in courses) {
      if (course['id'] == courseId) {
        final steps = List<Map<String, dynamic>>.from(course['steps'] ?? []);
        int completedCount = 0;

        for (int i = 0; i < steps.length; i++) {
          if (steps[i]['id'] == stepId) {
            steps[i]['isCompleted'] = true;

            // Débloquer l'étape suivante si elle existe !
            if (i + 1 < steps.length) {
              steps[i + 1]['isUnlocked'] = true;
            }
          }

          if (steps[i]['isCompleted'] == true) {
            completedCount++;
          }
        }

        course['steps'] = steps;
        course['progress'] = steps.isNotEmpty ? (completedCount / steps.length) : 1.0;
        break;
      }
    }

    await saveCourses(courses);

    // Mettre à jour XP et Niveau
    int newTodayXp = (stats['todayXp'] ?? 0) + xpReward;
    int newTotalXp = (stats['totalXp'] ?? 0) + xpReward;
    int completedStepsCount = (stats['completedStepsCount'] ?? 0) + 1;
    int level = (newTotalXp / 100).floor() + 1;

    final updatedStats = {
      ...stats,
      'todayXp': newTodayXp,
      'totalXp': newTotalXp,
      'completedStepsCount': completedStepsCount,
      'level': level,
      'lastActivityDate': DateTime.now().toIso8601String().split('T')[0],
    };

    await saveUserStats(updatedStats);
    return updatedStats;
  }

  // Structure des cours séquentiels avec démonstrations vidéo LSC & tests caméra obligatoires
  static List<Map<String, dynamic>> _getDefaultSequentialCourses() {
    return [
      {
        'id': 'c1',
        'title': 'Alphabet & Épellation LSC',
        'desc': 'Apprenez à épeler les lettres de l\'alphabet LSC avec démonstrations vidéo HD et validation caméra.',
        'category': 'Débutant',
        'icon': '🔤',
        'colorHex': 0xFF3B82F6,
        'progress': 0.5,
        'xpReward': 150,
        'steps': [
          {
            'id': 's1_1',
            'stepNumber': 1,
            'title': 'Découverte : Voyelles (A, E, I)',
            'type': 'video_lesson',
            'isUnlocked': true,
            'isCompleted': true,
            'durationMinutes': 5,
            'signs': [
              {
                'word': 'Lettre A',
                'emoji': '🅰️',
                'description': 'Fermez le poing droit avec le pouce plaqué verticalement contre le côté de l\'index.',
                'facialExpression': 'Regard fixe vers l\'interlocuteur.',
                'variant': 'LSC Standard Cameroun',
                'steps': [
                  '1. Levez la main dominante à hauteur de poitrine.',
                  '2. Fermez les 4 doigts en poing serré.',
                  '3. Appuyez le pouce droit contre la face externe de l\'index.'
                ],
              },
              {
                'word': 'Lettre E',
                'emoji': '🇪',
                'description': 'Courbez tous les doigts vers la paume, le pouce venant appuyer sous les ongles.',
                'facialExpression': 'Neutre.',
                'variant': 'LSC / LSF Universel',
                'steps': [
                  '1. Main ouverte face à la caméra.',
                  '2. Repliez doucement la première phalange de chaque doigt.',
                  '3. Glissez le pouce sous l\'extrémité des doigts.'
                ],
              },
            ],
          },
          {
            'id': 's1_2',
            'stepNumber': 2,
            'title': '📸 Test Caméra IA Obligatoire : Valider la Lettre A',
            'type': 'camera_test',
            'isUnlocked': true,
            'isCompleted': true,
            'durationMinutes': 3,
            'requiredCameraSign': 'Lettre A',
            'instruction': 'Activez votre caméra et reproduisez la Lettre A pour débloquer l\'étape suivante.',
          },
          {
            'id': 's1_3',
            'stepNumber': 3,
            'title': 'Démonstration Vidéo : Consonnes Courantes (B, C, D)',
            'type': 'video_lesson',
            'isUnlocked': true,
            'isCompleted': false,
            'durationMinutes': 7,
            'signs': [
              {
                'word': 'Lettre B',
                'emoji': '🇧',
                'description': 'Main droite ouverte, 4 doigts tendus vers le haut, pouce rabattu sur la paume.',
                'facialExpression': 'Sourire concentré.',
                'variant': 'LSC Standard',
                'steps': [
                  '1. Tendez les 4 doigts vers le ciel.',
                  '2. Rabattez le pouce horizontalement au milieu de la paume.'
                ],
              },
              {
                'word': 'Lettre C',
                'emoji': '🇨',
                'description': 'Formez un demi-cercle avec la paume et les doigts figurant la lettre C.',
                'facialExpression': 'Neutre.',
                'variant': 'LSC / LSF',
                'steps': [
                  '1. Arrondissez la paume.',
                  '2. Positionnez le pouce en bas pour fermer la boucle.'
                ],
              },
            ],
          },
          {
            'id': 's1_4',
            'stepNumber': 4,
            'title': '📸 Test Caméra IA Obligatoire : Valider la Lettre B',
            'type': 'camera_test',
            'isUnlocked': false,
            'isCompleted': false,
            'durationMinutes': 3,
            'requiredCameraSign': 'Lettre B',
            'instruction': 'Exécutez la Lettre B devant la caméra pour valider cette étape et débloquer le Quiz.',
          },
          {
            'id': 's1_5',
            'stepNumber': 5,
            'title': '🏆 Quiz de Validation de l\'Alphabet LSC',
            'type': 'quiz',
            'isUnlocked': false,
            'isCompleted': false,
            'durationMinutes': 5,
            'quizQuestions': [
              {
                'question': 'Quelle est la position du pouce pour le signe de la lettre B ?',
                'options': [
                  'Pointé vers le haut',
                  'Rabattu horizontalement sur la paume',
                  'Caché derrière le poignet',
                  'Écarté vers la gauche'
                ],
                'answer': 'Rabattu horizontalement sur la paume',
                'hint': 'Les 4 doigts sont tendus vers le ciel tandis que le pouce s\'abaisse sur la paume.'
              }
            ]
          }
        ]
      },
      {
        'id': 'c2',
        'title': 'Salutations & Présentations LSC',
        'desc': 'Apprenez à dire Bonjour, Merci, Bonsoir et à vous présenter avec des démonstrations vidéo pas-à-pas.',
        'category': 'Débutant',
        'icon': '👋',
        'colorHex': 0xFF10B981,
        'progress': 0.25,
        'xpReward': 200,
        'steps': [
          {
            'id': 's2_1',
            'stepNumber': 1,
            'title': 'Découverte Vidéo : BONJOUR & BONSOIR',
            'type': 'video_lesson',
            'isUnlocked': true,
            'isCompleted': true,
            'durationMinutes': 6,
            'signs': [
              {
                'word': 'BONJOUR',
                'emoji': '☀️',
                'description': 'Main plate sur le menton s\'élançant vers l\'avant avec un hochement de tête chaleureux.',
                'facialExpression': 'Sourire amical et regard bienveillant.',
                'variant': 'LSC Standard Cameroun',
                'steps': [
                  '1. Posez le bout des doigts de la main droite sur votre menton.',
                  '2. Déplacez la main vers votre interlocuteur en ouvrant les doigts.'
                ],
              },
              {
                'word': 'BONSOIR',
                'emoji': '🌙',
                'description': 'Départ du menton puis abaissement des mains croisées figurant le coucher du soleil.',
                'facialExpression': 'Visage serein.',
                'variant': 'LSC Cameroun',
                'steps': [
                  '1. Geste du Bonjour depuis le menton.',
                  '2. Croiser légèrement les poignets vers le bas.'
                ],
              }
            ],
          },
          {
            'id': 's2_2',
            'stepNumber': 2,
            'title': '📸 Test Caméra IA Obligatoire : Valider BONJOUR',
            'type': 'camera_test',
            'isUnlocked': true,
            'isCompleted': false,
            'durationMinutes': 4,
            'requiredCameraSign': 'BONJOUR',
            'instruction': 'Réalisez le signe BONJOUR face à votre caméra pour débloquer la suite de la leçon.',
          },
          {
            'id': 's2_3',
            'stepNumber': 3,
            'title': 'Démonstration Vidéo : MERCI & S\'IL TE PLAÎT',
            'type': 'video_lesson',
            'isUnlocked': false,
            'isCompleted': false,
            'durationMinutes': 6,
            'signs': [
              {
                'word': 'MERCI',
                'emoji': '🙏',
                'description': 'Toucher les lèvres avec le bout des doigts de la main plate droite puis descendre la main vers l\'avant.',
                'facialExpression': 'Regard reconnaissant.',
                'variant': 'LSC / Universel',
                'steps': [
                  '1. Paume droite contre la bouche.',
                  '2. Descendre la main vers l\'avant de façon fluide.'
                ],
              }
            ],
          },
          {
            'id': 's2_4',
            'stepNumber': 4,
            'title': '📸 Test Caméra IA Obligatoire : Valider MERCI',
            'type': 'camera_test',
            'isUnlocked': false,
            'isCompleted': false,
            'durationMinutes': 3,
            'requiredCameraSign': 'MERCI',
            'instruction': 'Exécutez le signe MERCI devant la caméra pour valider l\'étape.',
          },
        ]
      },
      {
        'id': 'c3',
        'title': 'Vie Quotidienne & Culture Camerounaise',
        'desc': 'Signes de la nourriture locale (Ndolè, Kossam), marchés et transports (Ben-Skin).',
        'category': 'Intermédiaire',
        'icon': '🏙️',
        'colorHex': 0xFF8B5CF6,
        'progress': 0.0,
        'xpReward': 250,
        'steps': [
          {
            'id': 's3_1',
            'stepNumber': 1,
            'title': 'Découverte Vidéo : NDOLÈ & KOSSAM',
            'type': 'video_lesson',
            'isUnlocked': true,
            'isCompleted': false,
            'durationMinutes': 8,
            'signs': [
              {
                'word': 'NDOLÈ',
                'emoji': '🥬',
                'description': 'Mouvements circulaires des mains simulant le lavage traditionnel des feuilles de Ndolè.',
                'facialExpression': 'Sourire gourmand.',
                'variant': 'Variante Cameroun Littoral (Douala)',
                'steps': [
                  '1. Mains en forme de coupelle face à face.',
                  '2. Frotter en cercles alternés comme pour laver les feuilles.'
                ],
              },
              {
                'word': 'KOSSAM',
                'emoji': '🥛',
                'description': 'Mimer le mouvement de la traite des vaches du haut vers le bas.',
                'facialExpression': 'Neutre.',
                'variant': 'Variante Nord-Cameroun (Fulfulde)',
                'steps': [
                  '1. Poings serrés l\'un au-dessus de l\'autre.',
                  '2. Mouvement alternatif vertical.'
                ],
              }
            ],
          },
          {
            'id': 's3_2',
            'stepNumber': 2,
            'title': '📸 Test Caméra IA Obligatoire : Valider NDOLÈ',
            'type': 'camera_test',
            'isUnlocked': false,
            'isCompleted': false,
            'durationMinutes': 4,
            'requiredCameraSign': 'NDOLÈ',
            'instruction': 'Activez votre caméra et mimez le signe du NDOLÈ pour débloquer la suite !',
          },
        ]
      },
      {
        'id': 'c4',
        'title': 'Urgences & Sécurité Médicale',
        'desc': 'Signes cruciaux pour la santé (Hôpital, Danger, Au Secours) avec tests de réaction rapide.',
        'category': 'Essentiel',
        'icon': '🚨',
        'colorHex': 0xFFEF4444,
        'progress': 0.0,
        'xpReward': 300,
        'steps': [
          {
            'id': 's4_1',
            'stepNumber': 1,
            'title': 'Découverte Vidéo : HÔPITAL & AU SECOURS',
            'type': 'video_lesson',
            'isUnlocked': true,
            'isCompleted': false,
            'durationMinutes': 7,
            'signs': [
              {
                'word': 'HÔPITAL',
                'emoji': '🏥',
                'description': 'Tracez une croix médicale sur votre bras gauche avec l\'index et le majeur de la main droite.',
                'facialExpression': 'Attentif et sérieux.',
                'variant': 'LSC Médical',
                'steps': [
                  '1. Tendez l\'index et le majeur droits.',
                  '2. Tracez une ligne verticale puis horizontale sur l\'épaule opposée.'
                ],
              }
            ],
          },
          {
            'id': 's4_2',
            'stepNumber': 2,
            'title': '📸 Test Caméra IA Obligatoire : Valider HÔPITAL',
            'type': 'camera_test',
            'isUnlocked': false,
            'isCompleted': false,
            'durationMinutes': 4,
            'requiredCameraSign': 'HÔPITAL',
            'instruction': 'Effectuez le signe HÔPITAL devant la caméra pour valider votre apprentissage de sécurité.',
          },
        ]
      }
    ];
  }
}

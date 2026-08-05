import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/firebase_auth_service.dart';
import '../../data/services/learning_data_service.dart';
import 'learning_screen.dart';
import 'login_screen.dart';

class AdminDashboard extends StatefulWidget {
  final String email;
  const AdminDashboard({super.key, required this.email});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentTab = 0;
  
  // Database mock states
  List<Map<String, dynamic>> _officialSigns = [];
  List<Map<String, dynamic>> _communitySuggestions = [];
  List<Map<String, dynamic>> _mockUsers = [];
  List<Map<String, dynamic>> _learningCourses = [];

  // AI model version state
  String _aiModelVersion = 'LSC-Cameroon v2.1';
  bool _isCheckingModelUpdate = false;
  double _modelAccuracy = 98.4;
  int _modelLatency = 14;

  final TextEditingController _broadcastController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load dict
    final officialJson = prefs.getString('dict_official_signs');
    final communityJson = prefs.getString('dict_community_suggestions');
    
    final defaultOfficial = [
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
    ];

    final defaultCommunity = [
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

    setState(() {
      if (officialJson != null) {
        _officialSigns = List<Map<String, dynamic>>.from(jsonDecode(officialJson));
      } else {
        _officialSigns = defaultOfficial;
        prefs.setString('dict_official_signs', jsonEncode(_officialSigns));
      }

      if (communityJson != null) {
        _communitySuggestions = List<Map<String, dynamic>>.from(jsonDecode(communityJson));
      } else {
        _communitySuggestions = defaultCommunity;
        prefs.setString('dict_community_suggestions', jsonEncode(_communitySuggestions));
      }
    });

    // Load users
    final usersJson = prefs.getString('mock_users') ?? '{}';
    final Map<String, dynamic> decodedUsers = jsonDecode(usersJson);
    
    final defaultAccounts = {
      'user@test.com': {
        'uid': 'demo_user',
        'name': 'Apprenant Démo',
        'email': 'user@test.com',
        'role': 'normal',
        'avatarType': 'male',
        'level': 3,
        'xp': 1250,
      },
      'sourd@test.com': {
        'uid': 'demo_sourd',
        'name': 'Sourd Démo',
        'email': 'sourd@test.com',
        'role': 'sourd',
        'avatarType': 'female',
        'level': 2,
        'xp': 800,
      },
    };

    final allUsers = {...defaultAccounts, ...decodedUsers};
    final learningCourses = await LearningDataService.getCourses();

    setState(() {
      _mockUsers = allUsers.values.map((u) => Map<String, dynamic>.from(u)).toList();
      _learningCourses = learningCourses;
    });
  }

  Future<void> _saveAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dict_official_signs', jsonEncode(_officialSigns));
    await prefs.setString('dict_community_suggestions', jsonEncode(_communitySuggestions));
    
    final Map<String, dynamic> usersMap = {};
    for (var u in _mockUsers) {
      if (u['email'] != null) {
        usersMap[u['email']] = u;
      }
    }
    await prefs.setString('mock_users', jsonEncode(usersMap));
  }

  void _signOut() async {
    await FirebaseAuthService().signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Zhẽnù Admin Workspace',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
            ),
            Text(
              'Superviseur : ${widget.email}',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: AppColors.primaryDark,
        elevation: 2,
        shadowColor: AppColors.primaryDark.withOpacity(0.3),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: _signOut,
            tooltip: 'Se déconnecter',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildCurrentTabContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (idx) => setState(() => _currentTab = idx),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey.shade500,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 10),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_rounded),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fact_check_rounded),
            label: 'Signes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_rounded),
            label: 'Membres',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_rounded),
            label: 'Cours',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (_currentTab) {
      case 0:
        return _buildStatsView();
      case 1:
        return _buildSignValidationView();
      case 2:
        return _buildUsersManagementView();
      case 3:
        return _buildLessonsManagementView();
      case 4:
        return _buildSettingsView();
      default:
        return _buildStatsView();
    }
  }

  // --- TAB 1: STATS & AI CONTROL ---
  Widget _buildStatsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STATISTIQUES SYSTÈME GLOBALES',
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.3,
            children: [
              _buildMetricCard("Membres Actifs", "${_mockUsers.length}", Icons.people_outline_rounded, Colors.blue),
              _buildMetricCard("Signes validés", "${_officialSigns.length}", Icons.verified_rounded, Colors.green),
              _buildMetricCard("En attente validation", "${_communitySuggestions.length}", Icons.pending_actions_rounded, Colors.orange),
              _buildMetricCard("Requêtes IA / Jour", "2 481", Icons.bolt_rounded, Colors.purple),
            ],
          ),
          
          const SizedBox(height: 24),
          
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.psychology_rounded, color: AppColors.secondary, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "SUPERVISION DU MODÈLE IA",
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark),
                            ),
                            Text(
                              "Version Active : $_aiModelVersion",
                              style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildSubMetric("Précision", "${_modelAccuracy}%", Colors.green),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey.shade200),
                      Expanded(
                        child: _buildSubMetric("Latence", "${_modelLatency}ms", Colors.amber),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey.shade200),
                      Expanded(
                        child: _buildSubMetric("Moteur", "TensorFlow", Colors.blue),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  ElevatedButton(
                    onPressed: _isCheckingModelUpdate ? null : _checkAiModelUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isCheckingModelUpdate
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            "METTRE À JOUR LE MODÈLE IA LSC",
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11, letterSpacing: 0.8),
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

  void _checkAiModelUpdate() {
    setState(() {
      _isCheckingModelUpdate = true;
    });
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCheckingModelUpdate = false;
          _aiModelVersion = 'LSC-Cameroon v2.2-stable';
          _modelAccuracy = 99.1;
          _modelLatency = 11;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Modèle LSC mis à jour avec succès vers v2.2 !", style: GoogleFonts.inter()),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Widget _buildMetricCard(String title, String val, IconData icon, Color color) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              val,
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubMetric(String name, String value, Color valColor) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: valColor),
        ),
        Text(
          name,
          style: GoogleFonts.inter(fontSize: 9.5, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // --- TAB 2: SIGN VALIDATION PANEL ---
  Widget _buildSignValidationView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'VALIDATION DE SIGNES COMMUNAUTAIRES',
                style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_communitySuggestions.length} en attente',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.secondaryDark, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _communitySuggestions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: Colors.grey.shade300, size: 64),
                      const SizedBox(height: 12),
                      Text(
                        'Aucune proposition en attente !',
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _communitySuggestions.length,
                  itemBuilder: (context, idx) {
                    final suggestion = _communitySuggestions[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.primary.withOpacity(0.06),
                                  child: Text(
                                    suggestion['emoji'] ?? '🆕',
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        suggestion['word'] ?? '',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                                      ),
                                      Text(
                                        'Catégorie : ${suggestion['category'] ?? "Général"}',
                                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Text(
                              "DESCRIPTION DU GESTE :",
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 9.5, color: Colors.grey.shade400),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              suggestion['description'] ?? '',
                              style: GoogleFonts.inter(fontSize: 12.5, color: Colors.grey.shade800, height: 1.4),
                            ),
                            if (suggestion['variant'] != null && suggestion['variant'].isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.map_outlined, size: 14, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      suggestion['variant'],
                                      style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Par : ${suggestion['author'] ?? "Utilisateur"}',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.secondaryDark),
                                ),
                                Row(
                                  children: [
                                    IconButton.filledTonal(
                                      style: IconButton.styleFrom(
                                        backgroundColor: AppColors.error.withOpacity(0.08),
                                      ),
                                      icon: const Icon(Icons.close_rounded, color: AppColors.error),
                                      onPressed: () => _rejectSuggestion(idx),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () => _approveSuggestion(idx),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.success,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      icon: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                      label: Text('VALIDER', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _approveSuggestion(int index) {
    setState(() {
      final item = _communitySuggestions[index];
      
      // Add to official list
      _officialSigns.add({
        'id': '${_officialSigns.length + 1}',
        'word': item['word'],
        'category': item['category'],
        'emoji': item['emoji'] ?? '🆕',
        'description': item['description'],
        'variant': item['variant'] ?? 'LSC - Cameroun',
        'difficulty': 'Moyen',
      });
      
      // Remove from suggestions
      _communitySuggestions.removeAt(index);
      _saveAllData();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Le signe a été approuvé et ajouté au Dictionnaire LSC !", style: GoogleFonts.inter()),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _rejectSuggestion(int index) {
    setState(() {
      _communitySuggestions.removeAt(index);
      _saveAllData();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("La proposition de signe a été rejetée.", style: GoogleFonts.inter()),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- TAB 3: MEMBER MANAGEMENT ---
  Widget _buildUsersManagementView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'GESTION DES RÔLES ET UTILISATEURS (${_mockUsers.length})',
            style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _mockUsers.length,
            itemBuilder: (context, idx) {
              final user = _mockUsers[idx];
              final bool isSuspended = user['suspended'] == true;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: (user['role'] == 'sourd' ? AppColors.secondary : AppColors.primary).withOpacity(0.12),
                    child: Text(
                      user['role'] == 'sourd' ? '🤟' : (user['role'] == 'admin' ? '🛡️' : '🎓'),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  title: Text(
                    user['name'] ?? 'Utilisateur Zhẽnù',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user['email'] ?? '', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSuspended ? AppColors.error.withOpacity(0.1) : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isSuspended ? 'SUSPENDU' : (user['role'] ?? 'Membre').toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: isSuspended ? AppColors.error : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Niveau ${user['level'] ?? 1}', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Change role dialog button
                      IconButton(
                        icon: const Icon(Icons.manage_accounts_rounded, color: AppColors.primary),
                        onPressed: () => _showChangeRoleDialog(idx),
                      ),
                      IconButton(
                        icon: Icon(
                          isSuspended ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                          color: isSuspended ? AppColors.success : AppColors.error,
                        ),
                        onPressed: () => _toggleSuspendUser(idx),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _toggleSuspendUser(int index) {
    setState(() {
      final user = _mockUsers[index];
      final wasSuspended = user['suspended'] == true;
      user['suspended'] = !wasSuspended;
      _saveAllData();
    });
  }

  void _showChangeRoleDialog(int index) {
    final user = _mockUsers[index];
    String selectedRole = user['role'] ?? 'normal';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(
                'Modifier le Rôle',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: Text('Entendant / Apprenant', style: GoogleFonts.inter(fontSize: 13.5)),
                    value: 'normal',
                    groupValue: selectedRole,
                    onChanged: (val) => setModalState(() => selectedRole = val!),
                  ),
                  RadioListTile<String>(
                    title: Text('Utilisateur Sourd / Muet', style: GoogleFonts.inter(fontSize: 13.5)),
                    value: 'sourd',
                    groupValue: selectedRole,
                    onChanged: (val) => setModalState(() => selectedRole = val!),
                  ),
                  RadioListTile<String>(
                    title: Text('Administrateur Système', style: GoogleFonts.inter(fontSize: 13.5)),
                    value: 'admin',
                    groupValue: selectedRole,
                    onChanged: (val) => setModalState(() => selectedRole = val!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Annuler', style: GoogleFonts.poppins(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      user['role'] = selectedRole;
                      _saveAllData();
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Le rôle de ${user['name']} a été modifié en $selectedRole."),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: Text('Confirmer', style: GoogleFonts.poppins(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- TAB 4: LESSONS & PEDAGOGY MANAGEMENT (CMS APPRENTISSAGE) ---
  Widget _buildLessonsManagementView() {
    int totalLessonsCount = 0;
    int totalSignsCount = 0;

    for (var c in _learningCourses) {
      final steps = List<Map<String, dynamic>>.from(c['steps'] ?? c['lessons'] ?? []);
      totalLessonsCount += steps.length;
      for (var s in steps) {
        final signs = List<Map<String, dynamic>>.from(s['signs'] ?? []);
        totalSignsCount += signs.length;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // CMS Header Metrics & Action bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'GESTIONNAIRE PÉDAGOGIQUE LSC',
                    style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showPreviewLearnerDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.remove_red_eye_rounded, size: 14, color: Colors.white),
                    label: Text('Aperçu Apprenant', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildCmsMiniMetric('${_learningCourses.length}', 'Modules Actifs', Icons.school_rounded, AppColors.primary)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildCmsMiniMetric('$totalLessonsCount', 'Leçons Créées', Icons.menu_book_rounded, Colors.green)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildCmsMiniMetric('$totalSignsCount', 'Fiches Signes', Icons.back_hand_rounded, Colors.orange)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'LISTE DES COURS ENSEIGNÉS (${_learningCourses.length})',
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showCreateCourseDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                    label: Text('Créer un Module', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: _learningCourses.isEmpty
              ? Center(
                  child: Text('Aucun cours trouvé.', style: GoogleFonts.poppins(color: Colors.grey)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _learningCourses.length,
                  itemBuilder: (context, idx) {
                    final course = _learningCourses[idx];
                    final steps = List<Map<String, dynamic>>.from(course['steps'] ?? course['lessons'] ?? []);
                    final color = Color(course['colorHex'] as int? ?? 0xFF3B82F6);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(course['icon'] as String? ?? '📖', style: const TextStyle(fontSize: 22)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        course['title'] as String? ?? '',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        '${course['category']} • ${steps.length} Étapes • +${course['xpReward']} XP',
                                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                  onPressed: () => _deleteCourse(idx),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Dernière modif : En ligne',
                                  style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _showManageLessonsModal(course),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: color.withOpacity(0.12),
                                    foregroundColor: color,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  icon: Icon(Icons.edit_note_rounded, size: 16, color: color),
                                  label: Text(
                                    'GÉRER LEÇONS & SIGNES',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 10.5, color: color),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCmsMiniMetric(String val, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(val, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          Text(label, style: GoogleFonts.inter(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showPreviewLearnerDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text('Aperçu Apprenant (Mode Enseignant)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
            backgroundColor: AppColors.primaryDark,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: const LearningScreen(),
        ),
      ),
    );
  }

  void _showCreateCourseDialog() {
    final formKey = GlobalKey<FormState>();
    String title = '';
    String desc = '';
    String category = 'Débutant';
    String icon = '📚';
    int xpReward = 150;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Créer un Nouveau Module LSC', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Titre du module'),
                        validator: (v) => v!.isEmpty ? 'Entrez un titre' : null,
                        onSaved: (v) => title = v!,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Description synthétique'),
                        validator: (v) => v!.isEmpty ? 'Entrez une description' : null,
                        onSaved: (v) => desc = v!,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(labelText: 'Catégorie'),
                        items: ['Débutant', 'Intermédiaire', 'Avancé', 'Essentiel'].map((c) {
                          return DropdownMenuItem(value: c, child: Text(c));
                        }).toList(),
                        onChanged: (v) => setModalState(() => category = v!),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Emoji de couverture (ex: 🔤, 👋, 🏥)'),
                        initialValue: icon,
                        onSaved: (v) => icon = v ?? '📚',
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Gain en XP'),
                        initialValue: '150',
                        keyboardType: TextInputType.number,
                        validator: (v) => int.tryParse(v ?? '') == null ? 'Entrez un nombre' : null,
                        onSaved: (v) => xpReward = int.parse(v!),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Annuler', style: GoogleFonts.poppins(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();
                      final nowId = DateTime.now().millisecondsSinceEpoch;
                      final newCourse = {
                        'id': 'c_$nowId',
                        'title': title,
                        'desc': desc,
                        'category': category,
                        'icon': icon,
                        'colorHex': 0xFF3B82F6,
                        'progress': 0.0,
                        'xpReward': xpReward,
                        'steps': [
                          {
                            'id': 's_${nowId}_1',
                            'stepNumber': 1,
                            'title': 'Découverte Vidéo : Signes de base',
                            'type': 'video_lesson',
                            'isUnlocked': true,
                            'isCompleted': false,
                            'durationMinutes': 5,
                            'signs': [],
                          },
                          {
                            'id': 's_${nowId}_2',
                            'stepNumber': 2,
                            'title': '📸 Test Caméra IA Obligatoire',
                            'type': 'camera_test',
                            'isUnlocked': false,
                            'isCompleted': false,
                            'durationMinutes': 3,
                            'requiredCameraSign': 'BONJOUR',
                            'instruction': 'Activez la caméra et effectuez le signe pour débloquer la suite.',
                          }
                        ],
                      };
                      final updated = List<Map<String, dynamic>>.from(_learningCourses)..add(newCourse);
                      await LearningDataService.saveCourses(updated);
                      setState(() => _learningCourses = updated);
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: Text('Créer et Publier', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteCourse(int index) async {
    final updated = List<Map<String, dynamic>>.from(_learningCourses)..removeAt(index);
    await LearningDataService.saveCourses(updated);
    setState(() => _learningCourses = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Module d\'apprentissage supprimé.'), backgroundColor: AppColors.error),
    );
  }

  void _showManageLessonsModal(Map<String, dynamic> course) {
    final steps = List<Map<String, dynamic>>.from(course['steps'] ?? course['lessons'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Étapes du module : ${course['title']}',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary),
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddSignDialog(course);
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: steps.length,
                      itemBuilder: (context, idx) {
                        final step = steps[idx];
                        final signs = List<Map<String, dynamic>>.from(step['signs'] ?? []);
                        final isCamera = step['type'] == 'camera_test';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isCamera ? Icons.camera_front_rounded : Icons.play_circle_fill_rounded,
                                      color: isCamera ? AppColors.secondary : AppColors.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        step['title'] as String? ?? '',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13.5),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isCamera
                                      ? '📸 Test Caméra Requis pour le signe : ${step['requiredCameraSign']}'
                                      : '${signs.length} Fiches Démonstration Vidéo',
                                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                                ),
                                if (signs.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  ...signs.map((s) => Container(
                                        margin: const EdgeInsets.only(bottom: 4),
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                        child: Text('${s['emoji'] ?? '🤟'} ${s['word']} - ${s['variant']}', style: GoogleFonts.inter(fontSize: 11)),
                                      )),
                                ],
                              ],
                            ),
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
      },
    );
  }

  void _showAddSignDialog(Map<String, dynamic> course) {
    final formKey = GlobalKey<FormState>();
    String word = '';
    String emoji = '🤟';
    String desc = '';
    String variant = 'LSC Standard Cameroun';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Ajouter une Fiche de Signe', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Mot du signe (ex: MERCI, NDOLÈ)'),
                    validator: (v) => v!.isEmpty ? 'Entrez le mot' : null,
                    onSaved: (v) => word = v!,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Emoji visuel'),
                    initialValue: '🤟',
                    onSaved: (v) => emoji = v ?? '🤟',
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Description précise du geste'),
                    validator: (v) => v!.isEmpty ? 'Entrez une description' : null,
                    onSaved: (v) => desc = v!,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Variante régionale LSC'),
                    initialValue: 'LSC Standard Cameroun',
                    onSaved: (v) => variant = v!,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();

                  final steps = List<Map<String, dynamic>>.from(course['steps'] ?? course['lessons'] ?? []);
                  if (steps.isNotEmpty) {
                    final signs = List<Map<String, dynamic>>.from(steps[0]['signs'] ?? []);
                    signs.add({
                      'word': word,
                      'emoji': emoji,
                      'description': desc,
                      'variant': variant,
                      'steps': ['1. Former la posture.', '2. Effectuer le mouvement.'],
                    });
                    steps[0]['signs'] = signs;
                    course['steps'] = steps;
                  }

                  await LearningDataService.saveCourses(_learningCourses);
                  setState(() {});
                  if (mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text('Ajouter au Module', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // --- TAB 5: SYSTEM PARAMETERS & RULES ---
  Widget _buildSettingsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'DIFFUSION DE NOTIFICATIONS SYSTÈME',
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Envoyer un message en direct à tous les utilisateurs (Sourd & Entendants) :",
                    style: GoogleFonts.inter(color: Colors.grey.shade700, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _broadcastController,
                    maxLines: 3,
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Saisissez l\'alerte système (ex: Maintenance de l\'IA à 22h, Nouveau dictionnaire disponible...)',
                      hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _broadcastNotification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                    label: Text(
                      'DIFFUSER L\'ALERTE',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'PARAMÈTRES DE SÉCURITÉ',
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('Chiffrement des messages de discussion', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text('Sécurise les salons directs de bout en bout.', style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade500)),
                  value: true,
                  activeColor: AppColors.primary,
                  onChanged: (v) {},
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text('Accès hors-ligne strict', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text('Permet de faire tourner le dictionnaire sans connexion.', style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade500)),
                  value: true,
                  activeColor: AppColors.primary,
                  onChanged: (v) {},
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text('Historique local automatique', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text('Sauvegarde l\'historique des traductions sur l\'appareil.', style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade500)),
                  value: false,
                  activeColor: AppColors.primary,
                  onChanged: (v) {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _broadcastNotification() {
    if (_broadcastController.text.trim().isEmpty) return;
    
    final message = _broadcastController.text.trim();
    _broadcastController.clear();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text("Alerte système diffusée : \"$message\"")),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

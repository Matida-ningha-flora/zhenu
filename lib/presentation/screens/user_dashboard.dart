import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'translator_screen.dart';
import 'dictionary_screen.dart';
import 'emergency_screen.dart';
import 'learning_screen.dart';
import 'profile_screen.dart';

class UserDashboard extends StatefulWidget {
  final String role;
  final String email;

  const UserDashboard({
    super.key,
    required this.role,
    required this.email,
  });

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    final bool isDeaf = widget.role == 'sourd';
    _screens = [
      TranslatorScreen(role: widget.role),
      const DictionaryScreen(),
      if (isDeaf) ...[
        const EmergencyScreen(),
        const LearningScreen(),
      ] else
        const LearningScreen(),
      ProfileScreen(role: widget.role, email: widget.email),
    ];
  }

  List<NavigationDestination> _buildDestinations() {
    final bool isDeaf = widget.role == 'sourd';
    return [
      NavigationDestination(
        icon: Icon(
          Icons.translate_rounded,
          color: _currentIndex == 0 ? AppColors.primary : Colors.grey.shade600,
          size: 22,
        ),
        label: 'Traducteur',
      ),
      NavigationDestination(
        icon: Icon(
          Icons.menu_book_rounded,
          color: _currentIndex == 1 ? AppColors.primary : Colors.grey.shade600,
          size: 22,
        ),
        label: 'Dictionnaire',
      ),
      if (isDeaf) ...[
        NavigationDestination(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentIndex == 2 ? AppColors.error.withOpacity(0.15) : AppColors.error.withOpacity(0.05),
            ),
            child: Icon(
              Icons.campaign_rounded,
              color: _currentIndex == 2 ? AppColors.error : AppColors.error.withOpacity(0.8),
              size: 24,
            ),
          ),
          label: 'Urgence',
        ),
        NavigationDestination(
          icon: Icon(
            Icons.school_rounded,
            color: _currentIndex == 3 ? AppColors.primary : Colors.grey.shade600,
            size: 22,
          ),
          label: 'Apprentissage',
        ),
      ] else
        NavigationDestination(
          icon: Icon(
            Icons.school_rounded,
            color: _currentIndex == 2 ? AppColors.primary : Colors.grey.shade600,
            size: 22,
          ),
          label: 'Apprentissage',
        ),
      NavigationDestination(
        icon: Icon(
          Icons.person_rounded,
          color: _currentIndex == (isDeaf ? 4 : 3) ? AppColors.primary : Colors.grey.shade600,
          size: 22,
        ),
        label: 'Profil',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Permet aux écrans de s'étendre derrière la barre flottante
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              backgroundColor: Colors.white.withOpacity(0.96),
              indicatorColor: AppColors.primary.withOpacity(0.12),
              elevation: 0,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              height: 72,
              destinations: _buildDestinations(),
            ),
          ),
        ),
      ),
    );
  }
}

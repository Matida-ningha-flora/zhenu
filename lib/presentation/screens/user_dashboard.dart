import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/preferences/app_preferences.dart';
import '../../data/services/admin_data_service.dart';
import '../../data/services/notification_center.dart';
import '../../data/services/translation_history_service.dart';
import '../navigation.dart';
import 'dictionary_screen.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'preferences_screen.dart';
import 'profile_screen.dart';
import 'translator_screen.dart';

/// Espace utilisateur : un profil unique, adapté par les préférences.
class UserDashboard extends StatefulWidget {
  final String email;
  final String name;

  const UserDashboard({super.key, required this.email, this.name = ''});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _index = 0;
  bool _ready = false;
  final _translatorMode = ValueNotifier(TranslatorMode.sign);
  StreamSubscription<Map<String, dynamic>>? _notifications;
  Timer? _sessionTimer;
  int _sessionTimeoutMinutes = 30;

  @override
  void initState() {
    super.initState();
    TranslationHistoryService.useAccount(widget.email);
    AppPreferences.instance.loadForUser(widget.email).whenComplete(() {
      if (mounted) setState(() => _ready = true);
    });
    NotificationCenter.instance.start();
    _notifications =
        NotificationCenter.instance.incoming.listen(_showIncomingNotification);
    _configureSessionTimeout();
  }

  @override
  void dispose() {
    _notifications?.cancel();
    _sessionTimer?.cancel();
    _translatorMode.dispose();
    NotificationCenter.instance.stop();
    super.dispose();
  }

  Future<void> _configureSessionTimeout() async {
    final settings = await AdminDataService.loadSettings();
    _sessionTimeoutMinutes = settings['sessionTimeoutMinutes'] as int? ?? 30;
    _resetSessionTimer();
  }

  void _resetSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(Duration(minutes: _sessionTimeoutMinutes), () {
      if (mounted) signOutAndReturnToLogin(context);
    });
  }

  void _showIncomingNotification(Map<String, dynamic> item) {
    if (!mounted) return;
    final title = (item['title'] as String? ?? '').trim();
    final message = item['message'] as String? ?? '';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 6),
      content: Row(children: [
        const Icon(Icons.notifications_active_outlined, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(
            child: Text(title.isEmpty ? message : '$title — $message',
                maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]),
      action: SnackBarAction(
        label: tr('Voir', 'View'),
        onPressed: () {
          final id = item['id'].toString();
          if (id.startsWith('invite_') || id.startsWith('msg_')) {
            _openTranslator(TranslatorMode.conversation);
          } else {
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()));
          }
        },
      ),
    ));
  }

  /// Chaque onglet apparaît en fondu lorsqu'il devient actif (l'état des
  /// onglets est conservé par l'IndexedStack).
  List<Widget> _fadeTabs(List<Widget> tabs) => [
        for (var i = 0; i < tabs.length; i++)
          AnimatedOpacity(
            opacity: i == _index ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: tabs[i],
          ),
      ];

  void _openTranslator(TranslatorMode mode) {
    _translatorMode.value = mode;
    setState(() => _index = 1);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ListenableBuilder(
      listenable: AppPreferences.instance,
      builder: (context, _) {
        final prefs = AppPreferences.instance;
        if (!prefs.hasCompletedSetup) {
          return PreferencesScreen(
            isFirstSetup: true,
            onCompleted: () => setState(() {}),
          );
        }
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _resetSessionTimer(),
          child: KeyedSubtree(
            // Reconstruit tous les écrans lorsque la langue change.
            key: ValueKey(prefs.writtenLanguage),
            child: Scaffold(
              body: IndexedStack(
                index: _index,
                children: _fadeTabs([
                  HomeScreen(
                    name: widget.name,
                    onOpenTranslator: _openTranslator,
                    onOpenTab: (tab) => setState(() => _index = tab),
                  ),
                  TranslatorScreen(mode: _translatorMode),
                  const DictionaryScreen(),
                  ProfileScreen(email: widget.email, name: widget.name),
                ]),
              ),
              bottomNavigationBar: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant)),
                ),
                child: NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (index) =>
                      setState(() => _index = index),
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.home_outlined),
                      selectedIcon: const Icon(Icons.home_rounded),
                      label: tr('Accueil', 'Home'),
                    ),
                    NavigationDestination(
                      icon: const _AlertBadge(
                          child: Icon(Icons.sign_language_outlined)),
                      selectedIcon: const _AlertBadge(
                          child: Icon(Icons.sign_language_rounded)),
                      label: tr('Traduire', 'Translate'),
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.menu_book_outlined),
                      selectedIcon: const Icon(Icons.menu_book_rounded),
                      label: tr('Dictionnaire', 'Dictionary'),
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.person_outline_rounded),
                      selectedIcon: const Icon(Icons.person_rounded),
                      label: tr('Profil', 'Profile'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Pastille des conversations (invitations, messages non lus).
class _AlertBadge extends StatelessWidget {
  final Widget child;
  const _AlertBadge({required this.child});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: NotificationCenter.instance,
        builder: (context, _) {
          final count = NotificationCenter.instance.conversationAlerts;
          return Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            child: child,
          );
        },
      );
}

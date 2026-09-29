import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/preferences/app_preferences.dart';
import '../navigation.dart';
import '../widgets/motion.dart';
import '../widgets/ui_kit.dart';
import 'admin/admin_accounts.dart';
import 'admin/admin_content.dart';
import 'admin/admin_overview.dart';
import 'admin/admin_signs.dart';
import 'admin/admin_system.dart';

/// Espace d'administration NeuroSigne.
class AdminDashboard extends StatefulWidget {
  final String email;
  const AdminDashboard({super.key, required this.email});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    AppPreferences.instance.loadForUser(widget.email);
  }

  List<({IconData icon, IconData selected, String label})> get _sections => [
        (
          icon: Icons.space_dashboard_outlined,
          selected: Icons.space_dashboard_rounded,
          label: tr('Aperçu', 'Overview')
        ),
        (
          icon: Icons.fact_check_outlined,
          selected: Icons.fact_check_rounded,
          label: tr('Signes', 'Signs')
        ),
        (
          icon: Icons.people_outline_rounded,
          selected: Icons.people_rounded,
          label: tr('Comptes', 'Accounts')
        ),
        (
          icon: Icons.face_retouching_natural_outlined,
          selected: Icons.face_retouching_natural,
          label: tr('Avatars', 'Avatars')
        ),
        (
          icon: Icons.settings_outlined,
          selected: Icons.settings_rounded,
          label: tr('Système', 'System')
        ),
      ];

  Widget _page() => switch (_index) {
        1 => const AdminSignsSection(),
        2 => AdminAccountsSection(currentEmail: widget.email),
        3 => const AdminContentSection(),
        4 => const AdminSystemSection(),
        _ =>
          AdminOverviewSection(onNavigate: (i) => setState(() => _index = i)),
      };

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Se déconnecter ?', 'Sign out?')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('Annuler', 'Cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Se déconnecter', 'Sign out')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await signOutAndReturnToLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final sections = _sections;
    final appBar = AppBar(
      titleSpacing: wide ? 24 : null,
      title: Row(children: [
        const BrandMark(size: 32),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sections[_index].label, style: theme.textTheme.titleMedium),
            Text(tr('Administration', 'Administration'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ]),
      actions: [
        IconButton(
          tooltip: AppPreferences.instance.themeMode == ThemeMode.dark
              ? tr('Thème clair', 'Light theme')
              : tr('Thème sombre', 'Dark theme'),
          onPressed: () {
            final prefs = AppPreferences.instance;
            prefs.themeMode = prefs.themeMode == ThemeMode.dark
                ? ThemeMode.light
                : ThemeMode.dark;
            prefs.save();
          },
          icon: Icon(AppPreferences.instance.themeMode == ThemeMode.dark
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined),
        ),
        PopupMenuButton<String>(
          tooltip: widget.email,
          icon: const Icon(Icons.account_circle_outlined),
          onSelected: (value) {
            if (value == 'logout') _signOut();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: Text(widget.email),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: Row(children: [
                const Icon(Icons.logout_rounded, size: 20),
                const SizedBox(width: 12),
                Text(tr('Se déconnecter', 'Sign out')),
              ]),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );

    final body = FadeSlideIn(key: ValueKey(_index), offset: 12, child: _page());

    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            backgroundColor: theme.colorScheme.surface,
            indicatorColor: theme.colorScheme.primaryContainer,
            destinations: [
              for (final s in sections)
                NavigationRailDestination(
                  icon: Icon(s.icon),
                  selectedIcon: Icon(s.selected),
                  label: Text(s.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: body,
              ),
            ),
          ),
        ]),
      );
    }
    return Scaffold(
      appBar: appBar,
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final s in sections)
            NavigationDestination(
              icon: Icon(s.icon),
              selectedIcon: Icon(s.selected),
              label: s.label,
            ),
        ],
      ),
    );
  }
}

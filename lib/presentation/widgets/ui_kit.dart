import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'motion.dart';

/// Logo NeuroSigne : pictogramme LSF dans un carré arrondi en dégradé.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 56});

  static const asset = 'assets/branding/logo.jpg';

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF10111A),
          borderRadius: BorderRadius.circular(size * 0.26),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withValues(alpha: 0.28),
              blurRadius: size * 0.45,
              offset: Offset(0, size * 0.08),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          semanticLabel: 'NeuroSigne',
          // Repli si l'image manque : pictogramme sur dégradé caramel.
          errorBuilder: (_, __, ___) => DecoratedBox(
            decoration:
                const BoxDecoration(gradient: AppColors.primaryGradient),
            child: Icon(Icons.sign_language_rounded,
                color: Colors.white, size: size * 0.54),
          ),
        ),
      );
}

/// Carte de surface standard (bordure fine, sans ombre portée).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = Material(
      color: color ?? scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    // Les cartes cliquables s'enfoncent légèrement au toucher.
    return onTap == null ? card : PressableScale(child: card);
  }
}

/// Titre de section avec action optionnelle alignée à droite.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const SectionHeader(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(bottom: 10),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36)),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Pictogramme sur fond teinté (listes, cartes d'action).
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const IconTile(
      {super.key, required this.icon, required this.color, this.size = 44});

  @override
  Widget build(BuildContext context) {
    // En thème sombre, la teinte est éclaircie pour rester lisible.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = dark ? Color.lerp(color, Colors.white, 0.4)! : color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: dark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: tint, size: size * 0.52),
    );
  }
}

/// Petite étiquette d'état (en ligne, en attente, validé…).
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusPill(
      {super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// État vide homogène pour toutes les listes.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          IconTile(icon: icon, color: theme.colorScheme.primary, size: 64),
          const SizedBox(height: 18),
          Text(title,
              textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      ),
    );
  }
}

/// Ligne de menu utilisée dans le profil et les réglages.
class MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;

  const MenuRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.primary;
    return ListTile(
      onTap: onTap,
      minVerticalPadding: 12,
      leading: IconTile(icon: icon, color: tint, size: 40),
      title: Text(title,
          style: color != null
              ? TextStyle(color: color, fontWeight: FontWeight.w600)
              : null),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing ??
          (onTap == null
              ? null
              : Icon(Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant)),
    );
  }
}

/// Formate une date ISO en libellé relatif court.
String relativeTime(String iso, {bool english = false}) {
  final date = DateTime.tryParse(iso);
  if (date == null) return '';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return english ? 'Just now' : 'À l’instant';
  if (diff.inMinutes < 60) {
    return english
        ? '${diff.inMinutes} min ago'
        : 'Il y a ${diff.inMinutes} min';
  }
  if (diff.inHours < 24) {
    return english ? '${diff.inHours} h ago' : 'Il y a ${diff.inHours} h';
  }
  if (diff.inDays < 7) {
    return english ? '${diff.inDays} d ago' : 'Il y a ${diff.inDays} j';
  }
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

import 'package:flutter/material.dart';

import '../../data/services/admin_data_service.dart';

/// Portrait circulaire d'un style d'avatar. Les photos sont embarquées
/// (hors ligne) ; l'administration peut les remplacer par une URL.
class AvatarPortrait extends StatelessWidget {
  final String variant;

  const AvatarPortrait({super.key, required this.variant});

  static const photoAssets = {
    'guide': 'assets/avatars/avatar_guide.png',
    'female': 'assets/avatars/avatar_female.png',
    'male': 'assets/avatars/avatar_male.png',
    'neutral': 'assets/avatars/avatar_neutral.png',
    'illustrated': 'assets/avatars/avatar_illustrated.png',
  };

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: AdminDataService.cachedAvatars(),
        builder: (context, snapshot) {
          Map<String, dynamic>? item;
          for (final avatar
              in snapshot.data ?? const <Map<String, dynamic>>[]) {
            if (avatar['id'] == variant) {
              item = avatar;
              break;
            }
          }
          final source = item?['source'] as String? ?? '';
          final isRemote =
              source.startsWith('https://') || source.startsWith('http://');

          return ClipOval(
            child: isRemote
                ? Image.network(
                    source,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, __) => _localPhoto(context),
                  )
                : _localPhoto(context),
          );
        },
      );

  Widget _localPhoto(BuildContext context) => Image.asset(
        photoAssets[variant] ?? photoAssets['guide']!,
        fit: BoxFit.cover,
        errorBuilder: (context, _, __) => _fallback(context),
      );

  Widget _fallback(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: Icon(
        variant == 'female' ? Icons.face_3_rounded : Icons.face_rounded,
        color: scheme.onPrimaryContainer,
        size: 34,
      ),
    );
  }
}

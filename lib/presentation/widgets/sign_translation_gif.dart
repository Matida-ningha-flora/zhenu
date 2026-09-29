import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/services/sign_media_service.dart';
import 'avatar_portrait.dart';

/// Animation d'un signe.
///
/// Source prioritaire : les GIF du serveur EchoSign (`/media/gif/{signe}`).
/// Sinon, les médias fournis via SIGN_MEDIA_JSON (un mot ➜ une URL, ou des
/// URL par style d'avatar et `video`).
class SignTranslationGif extends StatelessWidget {
  final String text;
  final String variant;
  final double size;

  /// Affiché lorsqu'aucun média n'existe pour ce mot. Par défaut, un message
  /// explicite plutôt qu'une animation sans rapport.
  final Widget? fallback;

  const SignTranslationGif({
    super.key,
    required this.text,
    required this.variant,
    this.size = 240,
    this.fallback,
  });

  static final Map<String, dynamic> _media = _loadMedia();

  static Map<String, dynamic> _loadMedia() {
    const source =
        String.fromEnvironment('SIGN_MEDIA_JSON', defaultValue: '{}');
    try {
      return Map<String, dynamic>.from(jsonDecode(source) as Map);
    } catch (_) {
      return {};
    }
  }

  static Uri? mediaFor(String word, String variant) {
    final clean = word.replaceAll('[Geste] ', '').trim();
    final server = SignMediaService.instance.gifUrl(clean);
    if (server != null) return server;
    final entry = _media[clean.toLowerCase()];
    final value = entry is Map ? entry[variant] : entry;
    final uri = value is String ? Uri.tryParse(value) : null;
    final valid = uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    return valid ? uri : null;
  }

  @override
  Widget build(BuildContext context) {
    final word = text.replaceAll('[Geste] ', '').trim().toLowerCase();
    final uri = mediaFor(word, variant);
    if (uri == null && fallback != null) return fallback!;
    final scheme = Theme.of(context).colorScheme;
    if (uri != null) {
      return SignGifView(
        url: uri,
        height: size * 1.4,
        label: word,
        fallback: fallback ??
            _placeholder(context,
                'Animation indisponible. Vérifiez la connexion au serveur.'),
      );
    }
    return Container(
      width: size,
      height: size * 1.4,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: _placeholder(
          context,
          word.isEmpty
              ? 'En attente d’un signe'
              : 'Aucune animation disponible pour « $text ».'),
    );
  }

  Widget _placeholder(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.accessibility_new_rounded,
                color: scheme.onSurfaceVariant, size: 56),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Lecteur d'animation GIF : chargement progressif, repli en cas d'erreur
/// et, en mode avatar, portrait de l'interprète choisi en médaillon.
class SignGifView extends StatelessWidget {
  final Uri url;
  final double height;
  final String label;
  final Widget fallback;

  /// Style d'avatar affiché en médaillon (mode « avatar signant »).
  final String? avatar;

  const SignGifView({
    super.key,
    required this.url,
    required this.height,
    required this.label,
    required this.fallback,
    this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: height,
        width: double.infinity,
        color: AppColors.stage,
        child: Stack(fit: StackFit.expand, children: [
          Image.network(
            url.toString(),
            key: ValueKey(url),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            semanticLabel: 'Signe LSF : $label',
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              final total = progress.expectedTotalBytes;
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox.square(
                    dimension: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                      value: total == null
                          ? null
                          : progress.cumulativeBytesLoaded / total,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Chargement du signe…',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white70)),
                ]),
              );
            },
            errorBuilder: (_, __, ___) => fallback,
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(label.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ),
          ),
          if (avatar != null)
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: AvatarPortrait(variant: avatar!),
              ),
            ),
        ]),
      ),
    );
  }
}

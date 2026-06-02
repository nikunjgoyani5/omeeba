import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:omeeba_new/gen/assets.gen.dart';

/// Common widget for displaying user profile/avatar images with caching.
/// Uses [CachedNetworkImage]; shows [user_placeholder] when [imageUrl] is null/empty,
/// while loading, or on error.
class CommonProfileImage extends StatelessWidget {
  const CommonProfileImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.clipOval = true,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool clipOval;
  final int? memCacheWidth;
  final int? memCacheHeight;

  Widget _placeholder() {
    return Container(
color: Colors.white,
      width: width,
      height: height,
      child: Assets.images.userPlaceholder.image(fit: fit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUrl = imageUrl?.trim();
    final hasValidUrl = effectiveUrl != null && effectiveUrl.isNotEmpty;

    Widget child;
    if (!hasValidUrl) {
      child = _placeholder();
    } else if (effectiveUrl.startsWith('assets/')) {
      child = Image.asset(
        effectiveUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    } else {
      child = CachedNetworkImage(
        imageUrl: effectiveUrl,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
      );
    }

    if (clipOval) {
      return ClipOval(child: child);
    }
    return child;
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';
import 'package:omeeba_new/gen/assets.gen.dart';
import 'package:shimmer/shimmer.dart';

/// Common widget for displaying network images with caching support (CachedNetworkImage).
/// Use [useShimmerPlaceholder] for feed-style loading: grey placeholder + shimmer + smooth fade-in.
class CommonNetworkImage extends StatelessWidget {
  const CommonNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.memCacheWidth,
    this.memCacheHeight,
    this.cacheKey,
    this.useShimmerPlaceholder = false,
    this.fadeInDuration,
    this.fadeOutDuration,
    this.onImageLoaded,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  /// Reduces memory usage by caching a smaller decoded image. Use for thumbnails.
  final int? memCacheWidth;
  final int? memCacheHeight;
  final String? cacheKey;
  /// When true: grey placeholder with shimmer, smooth fade-in (feed-style). Ignores [placeholder].
  final bool useShimmerPlaceholder;
  /// Used only when [useShimmerPlaceholder] is true if not set. Default: 280ms / 120ms.
  final Duration? fadeInDuration;
  final Duration? fadeOutDuration;
  /// Optional callback that reports the intrinsic size of the loaded image.
  final void Function(Size size)? onImageLoaded;

  /// Default placeholder widget with SVG
  Widget _buildDefaultPlaceholder() {
    return SizedBox(
      width: width,
      height: height,
      child: Assets.icons.icImgPlaceholder.image(fit: fit),
    );
  }

  /// Grey placeholder with subtle shimmer — same size as image to prevent layout jump.
  Widget _buildShimmerPlaceholder() {
    return Shimmer.fromColors(
      baseColor: AppColors.grayEDF1F4,
      highlightColor: AppColors.greyF3F4F5,
      child: Container(
        width: width,
        height: height,
        color: AppColors.grayEDF1F4,
      ),
    );
  }

  /// Default error widget with SVG
  Widget _buildDefaultErrorWidget() {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(Assets.icons.icImgPlaceholder.path, fit: fit),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Return placeholder if imageUrl is empty or null to prevent errors
    if (imageUrl.isEmpty) {
      return errorWidget ?? _buildDefaultErrorWidget();
    }

    // Support local asset paths (e.g. "assets/images/foo.jpg")
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => errorWidget ?? _buildDefaultErrorWidget(),
      );
    }

    final effectivePlaceholder = useShimmerPlaceholder
        ? (BuildContext context, String url) => _buildShimmerPlaceholder()
        : (placeholder != null ? (BuildContext context, String url) => placeholder! : (BuildContext context, String url) => _buildDefaultPlaceholder());
    final effectiveFadeIn = useShimmerPlaceholder ? (fadeInDuration ?? const Duration(milliseconds: 280)) : Duration.zero;
    final effectiveFadeOut = useShimmerPlaceholder ? (fadeOutDuration ?? const Duration(milliseconds: 120)) : Duration.zero;

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      cacheKey: cacheKey ?? imageUrl,
      placeholder: effectivePlaceholder,
      errorWidget: (context, url, error) => errorWidget ?? _buildDefaultErrorWidget(),
      fadeInDuration: effectiveFadeIn,
      fadeOutDuration: effectiveFadeOut,
      imageBuilder: onImageLoaded == null
          ? null
          : (context, imageProvider) {
              final ImageStream stream = imageProvider.resolve(const ImageConfiguration());
              late ImageStreamListener listener;
              listener = ImageStreamListener(
                (ImageInfo info, bool _) {
                  final size = Size(
                    info.image.width.toDouble(),
                    info.image.height.toDouble(),
                  );
                  // Defer so we never call setState (or any parent logic) during build.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onImageLoaded?.call(size);
                  });
                  stream.removeListener(listener);
                },
              );
              stream.addListener(listener);
              return Image(
                image: imageProvider,
                width: width,
                height: height,
                fit: fit,
              );
            },
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Displays a network image with on-disk caching and decode-time
/// downsampling to its actual display size, instead of Flutter's default
/// in-memory-only cache (which discards everything on cold start) plus a
/// full-resolution decode of whatever was uploaded.
///
/// Pass [cacheWidth]/[cacheHeight] (logical pixels, multiplied by the device
/// pixel ratio internally) when the widget's own [width]/[height] isn't
/// already a concrete, finite size to decode at — e.g. a banner using
/// `width: double.infinity`.
///
/// IMPORTANT: pair any write to the underlying photo URL with
/// `CachedNetworkImage.evictFromCache(url)` if that URL is ever reused for
/// different bytes (e.g. a stable "user/avatar.jpg" storage path) — see
/// `UserState`'s `setProfilePhotoUrl`/`setClubPhoto`.
class AppNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final double? cacheWidth;
  final double? cacheHeight;
  final String? cacheKey;
  final BoxFit fit;
  final bool useOldImageOnUrlChange;
  final WidgetBuilder? placeholderBuilder;
  final WidgetBuilder? errorBuilder;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.cacheKey,
    this.fit = BoxFit.cover,
    this.useOldImageOnUrlChange = false,
    this.placeholderBuilder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final w = cacheWidth ?? (width != null && width!.isFinite ? width : null);
    final h =
        cacheHeight ?? (height != null && height!.isFinite ? height : null);

    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: w == null ? null : (w * dpr).round(),
      memCacheHeight: h == null ? null : (h * dpr).round(),
      cacheKey: cacheKey,
      useOldImageOnUrlChange: useOldImageOnUrlChange,
      fadeInDuration: const Duration(milliseconds: 120),
      fadeOutDuration: Duration.zero,
      placeholder: placeholderBuilder == null
          ? null
          : (ctx, _) => placeholderBuilder!(ctx),
      errorWidget: (ctx, _, _) =>
          errorBuilder?.call(ctx) ?? const SizedBox.shrink(),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/media_delivery_service.dart';

typedef PrivateMediaResolver =
    Future<ResolvedMedia> Function(
      String reference,
      MediaRendition rendition,
      MediaDimensions dimensions,
    );

typedef PrivateMediaResolvedBuilder =
    Widget Function(
      BuildContext context,
      ResolvedMedia media,
      MediaRendition rendition,
      WidgetBuilder errorBuilder,
    );

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
  final MediaRendition rendition;
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
    this.rendition = MediaRendition.feed,
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

    final dimensions = mediaDimensionsFor(
      rendition: rendition,
      logicalWidth: w,
      logicalHeight: h,
      devicePixelRatio: dpr,
    );
    final media = mediaDeliveryService.resolvePublic(
      value: url,
      rendition: rendition,
      dimensions: dimensions,
    );

    return CachedNetworkImage(
      imageUrl: media.url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: w == null ? null : (w * dpr).round(),
      memCacheHeight: h == null ? null : (h * dpr).round(),
      cacheKey: cacheKey ?? media.cacheKey,
      useOldImageOnUrlChange: useOldImageOnUrlChange,
      fadeInDuration: const Duration(milliseconds: 120),
      fadeOutDuration: Duration.zero,
      placeholder: placeholderBuilder == null
          ? null
          : (ctx, _) => placeholderBuilder!(ctx),
      errorWidget: (ctx, _, _) {
        final fallback = media.fallbackUrl;
        if (fallback != null && fallback != media.url) {
          return CachedNetworkImage(
            imageUrl: fallback,
            width: width,
            height: height,
            fit: fit,
            memCacheWidth: dimensions.width,
            memCacheHeight: dimensions.height,
            cacheKey: '${media.cacheKey}:original-fallback',
            errorWidget: (context, url, error) =>
                errorBuilder?.call(context) ?? const SizedBox.shrink(),
          );
        }
        return errorBuilder?.call(ctx) ?? const SizedBox.shrink();
      },
    );
  }
}

/// Lazily signs private Storage media only when the widget is built. Chat v2
/// can therefore keep its stable `chat-attachment://` identity in the model
/// without signing every attachment in a fetched history page.
class PrivateMediaNetworkImage extends StatefulWidget {
  const PrivateMediaNetworkImage({
    super.key,
    required this.reference,
    required this.rendition,
    required this.cacheWidth,
    this.cacheHeight,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderBuilder,
    this.errorBuilder,
    this.resolver,
    this.resolvedBuilder,
  });

  final String reference;
  final MediaRendition rendition;
  final double cacheWidth;
  final double? cacheHeight;
  final double? width;
  final double? height;
  final BoxFit fit;
  final WidgetBuilder? placeholderBuilder;
  final WidgetBuilder? errorBuilder;
  final PrivateMediaResolver? resolver;
  final PrivateMediaResolvedBuilder? resolvedBuilder;

  @override
  State<PrivateMediaNetworkImage> createState() =>
      _PrivateMediaNetworkImageState();
}

class _PrivateMediaNetworkImageState extends State<PrivateMediaNetworkImage> {
  late Future<ResolvedMedia> _resolution;
  late MediaRendition _activeRendition;
  bool _initialized = false;
  bool _fallbackScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _startPrimaryResolution();
    }
  }

  @override
  void didUpdateWidget(covariant PrivateMediaNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_initialized &&
        (oldWidget.reference != widget.reference ||
            oldWidget.rendition != widget.rendition ||
            oldWidget.cacheWidth != widget.cacheWidth ||
            oldWidget.cacheHeight != widget.cacheHeight ||
            oldWidget.resolver != widget.resolver ||
            oldWidget.resolvedBuilder != widget.resolvedBuilder)) {
      _startPrimaryResolution();
    }
  }

  void _startPrimaryResolution() {
    _fallbackScheduled = false;
    _activeRendition = widget.rendition;
    _resolution = _resolve(widget.rendition);
  }

  Future<ResolvedMedia> _resolve(MediaRendition rendition) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final dimensions = mediaDimensionsFor(
      rendition: rendition,
      logicalWidth: widget.cacheWidth,
      logicalHeight: widget.cacheHeight,
      devicePixelRatio: dpr,
    );
    final resolver = widget.resolver;
    if (resolver != null) {
      return resolver(widget.reference, rendition, dimensions);
    }
    return mediaDeliveryService.resolvePrivateForCurrentAccount(
      value: widget.reference,
      rendition: rendition,
      dimensions: dimensions,
    );
  }

  Widget _primaryError(BuildContext context) {
    if (!_fallbackScheduled && _activeRendition != MediaRendition.original) {
      _fallbackScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _activeRendition = MediaRendition.original;
          _resolution = _resolve(MediaRendition.original);
        });
      });
      return widget.placeholderBuilder?.call(context) ??
          const SizedBox.shrink();
    }
    return widget.errorBuilder?.call(context) ?? const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResolvedMedia>(
      future: _resolution,
      builder: (context, snapshot) {
        final media = snapshot.data;
        if (media == null) {
          if (snapshot.hasError) {
            return widget.errorBuilder?.call(context) ??
                const SizedBox.shrink();
          }
          return widget.placeholderBuilder?.call(context) ??
              const SizedBox.shrink();
        }
        final resolvedBuilder = widget.resolvedBuilder;
        if (resolvedBuilder != null) {
          return resolvedBuilder(
            context,
            media,
            _activeRendition,
            _primaryError,
          );
        }
        return AppNetworkImage(
          url: media.url,
          cacheKey: media.cacheKey,
          rendition: _activeRendition,
          width: widget.width,
          height: widget.height,
          cacheWidth: widget.cacheWidth,
          cacheHeight: widget.cacheHeight,
          fit: widget.fit,
          useOldImageOnUrlChange: true,
          placeholderBuilder: widget.placeholderBuilder,
          errorBuilder: _primaryError,
        );
      },
    );
  }
}

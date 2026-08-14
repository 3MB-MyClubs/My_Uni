import 'package:flutter/material.dart';

import 'loading_skeleton.dart';
import 'app_network_image.dart';
import '../services/media_delivery_service.dart';

void showProfilePhotoViewer({
  required BuildContext context,
  ImageProvider? imageProvider,
  String? networkUrl,
}) {
  assert(imageProvider != null || networkUrl != null);
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: _ProfilePhotoViewer(
            imageProvider: imageProvider,
            networkUrl: networkUrl,
          ),
        );
      },
    ),
  );
}

class _ProfilePhotoViewer extends StatelessWidget {
  final ImageProvider? imageProvider;
  final String? networkUrl;

  const _ProfilePhotoViewer({this.imageProvider, this.networkUrl});

  @override
  Widget build(BuildContext context) {
    final imageSize = MediaQuery.sizeOf(context).width * 0.84;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(color: Colors.transparent),
              ),
            ),
            Center(
              child: InteractiveViewer(
                minScale: 0.7,
                maxScale: 5,
                child: ClipOval(
                  child: networkUrl != null
                      ? AppNetworkImage(
                          url: networkUrl!,
                          rendition: MediaRendition.screen,
                          width: imageSize,
                          height: imageSize,
                          cacheWidth: imageSize,
                          cacheHeight: imageSize,
                          fit: BoxFit.cover,
                          placeholderBuilder: (_) =>
                              SkeletonBox(width: imageSize, height: imageSize),
                        )
                      : Image(
                          image: imageProvider!,
                          width: imageSize,
                          height: imageSize,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                              ? child
                              : ClipOval(
                                  child: SkeletonBox(
                                    width: imageSize,
                                    height: imageSize,
                                  ),
                                ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

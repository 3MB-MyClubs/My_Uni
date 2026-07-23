import 'package:flutter/material.dart';

import 'loading_skeleton.dart';

void showProfilePhotoViewer({
  required BuildContext context,
  required ImageProvider imageProvider,
}) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: _ProfilePhotoViewer(imageProvider: imageProvider),
        );
      },
    ),
  );
}

class _ProfilePhotoViewer extends StatelessWidget {
  final ImageProvider imageProvider;

  const _ProfilePhotoViewer({required this.imageProvider});

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
                  child: Image(
                    image: imageProvider,
                    width: imageSize,
                    height: imageSize,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
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

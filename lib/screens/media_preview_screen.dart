import 'dart:io';

import 'package:flutter/material.dart';

import '../models/chat_media_selection.dart';
import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../widgets/chat_video_player.dart';

/// WhatsApp-style staging route between gallery/camera selection and sending.
///
/// Popping this route returns `null`; only [_confirm] returns a
/// [MediaPreviewResult], which is the caller's signal to create messages and
/// begin uploads.
class MediaPreviewScreen extends StatefulWidget {
  const MediaPreviewScreen({
    super.key,
    required this.initialMedia,
    this.initialCaption = '',
  });

  final List<SelectedChatMedia> initialMedia;
  final String initialCaption;

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  late final TextEditingController _captionController;
  late final PageController _pageController;
  late List<SelectedChatMedia> _media;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _media = List<SelectedChatMedia>.of(widget.initialMedia);
    _captionController = TextEditingController(text: widget.initialCaption);
    _pageController = PageController();
    if (_media.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _removeCurrent() {
    if (_media.isEmpty) return;
    setState(() {
      _media.removeAt(_currentIndex);
      if (_currentIndex >= _media.length) {
        _currentIndex = _media.length - 1;
      }
    });
    if (_media.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
    });
  }

  void _confirm() {
    if (_media.isEmpty) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      MediaPreviewResult(
        items: List<SelectedChatMedia>.unmodifiable(_media),
        caption: _captionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _media.length;
    return Scaffold(
      key: const ValueKey('media-preview-screen'),
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF090708),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 58,
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('media-preview-cancel'),
                    tooltip: S.cancel,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      count == 0
                          ? S.mediaPreviewEmpty
                          : S.mediaPreviewPosition(_currentIndex + 1, count),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('media-preview-remove'),
                    tooltip: S.mediaPreviewRemove,
                    onPressed: count == 0 ? null : _removeCurrent,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: count == 0
                  ? Center(
                      child: Text(
                        S.mediaPreviewEmpty,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  : PageView.builder(
                      key: const ValueKey('media-preview-carousel'),
                      controller: _pageController,
                      itemCount: count,
                      onPageChanged: (index) {
                        setState(() => _currentIndex = index);
                      },
                      itemBuilder: (context, index) => _MediaPage(
                        key: ValueKey('media-preview-page-$index'),
                        media: _media[index],
                        active: index == _currentIndex,
                      ),
                    ),
            ),
            if (count > 1)
              SizedBox(
                key: const ValueKey('media-preview-thumbnails'),
                height: 76,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: count,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => _MediaThumbnail(
                    key: ValueKey('media-preview-thumbnail-$index'),
                    media: _media[index],
                    selected: index == _currentIndex,
                    onTap: () => _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                ),
              ),
            if (count > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 50),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: TextField(
                          key: const ValueKey('media-preview-caption'),
                          controller: _captionController,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 4000,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.newline,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            filled: false,
                            counterText: '',
                            hintText: S.mediaCaptionHint,
                            hintStyle: const TextStyle(color: Colors.white60),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Semantics(
                      button: true,
                      label: S.mediaSend,
                      child: Material(
                        color: AppColors.primaryRed,
                        shape: const CircleBorder(),
                        child: InkWell(
                          key: const ValueKey('media-preview-send'),
                          customBorder: const CircleBorder(),
                          onTap: _confirm,
                          child: const SizedBox(
                            width: 54,
                            height: 54,
                            child: Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaPage extends StatelessWidget {
  const _MediaPage({super.key, required this.media, required this.active});

  final SelectedChatMedia media;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (media.type == ChatMediaType.video) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ChatVideoPlayer(path: media.file.path, active: active),
      );
    }
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (MediaQuery.sizeOf(context).width * pixelRatio).round();
    return Image.file(
      File(media.file.path),
      width: double.infinity,
      fit: BoxFit.contain,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white70,
          size: 46,
        ),
      ),
    );
  }
}

class _MediaThumbnail extends StatelessWidget {
  const _MediaThumbnail({
    super.key,
    required this.media,
    required this.selected,
    required this.onTap,
  });

  final SelectedChatMedia media;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primaryRed : Colors.white30,
            width: selected ? 2.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: media.type == ChatMediaType.video
            ? const ColoredBox(
                color: Color(0xFF211B1E),
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              )
            : Image.file(
                File(media.file.path),
                fit: BoxFit.cover,
                cacheWidth: 144,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFF211B1E),
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                  ),
                ),
              ),
      ),
    );
  }
}

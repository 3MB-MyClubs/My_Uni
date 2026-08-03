import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Lightweight local/network video playback shared by media previews and chat
/// bubbles. A controller is created only while [active] is true, keeping a
/// multi-item carousel from decoding every video at once.
class ChatVideoPlayer extends StatefulWidget {
  const ChatVideoPlayer({
    super.key,
    required this.path,
    this.active = true,
    this.backgroundColor = Colors.black,
    this.placeholderIconSize = 42,
  });

  final String path;
  final bool active;
  final Color backgroundColor;
  final double placeholderIconSize;

  @override
  State<ChatVideoPlayer> createState() => _ChatVideoPlayerState();
}

class _ChatVideoPlayerState extends State<ChatVideoPlayer> {
  VideoPlayerController? _controller;
  Object? _error;
  int _initializationGeneration = 0;
  Future<void>? _pendingDisposal;

  @override
  void initState() {
    super.initState();
    if (widget.active) unawaited(_initialize());
  }

  @override
  void didUpdateWidget(covariant ChatVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _queueControllerDisposal();
      if (widget.active) unawaited(_initialize());
      return;
    }
    if (!oldWidget.active && widget.active) {
      unawaited(_initialize());
    } else if (oldWidget.active && !widget.active) {
      _queueControllerDisposal();
    }
  }

  Future<void> _initialize() async {
    final pendingDisposal = _pendingDisposal;
    if (pendingDisposal != null) await pendingDisposal;
    if (!mounted || _controller != null || !widget.active) return;
    final generation = ++_initializationGeneration;
    final isRemote =
        widget.path.startsWith('http://') || widget.path.startsWith('https://');
    final controller = isRemote
        ? VideoPlayerController.networkUrl(Uri.parse(widget.path))
        : VideoPlayerController.file(File(widget.path));
    _controller = controller;
    _error = null;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      if (!mounted || generation != _initializationGeneration) {
        if (identical(_controller, controller)) {
          _controller = null;
          _trackDisposal(_safelyDispose(controller));
        }
        return;
      }
      setState(() {});
    } catch (error) {
      if (generation != _initializationGeneration) return;
      if (identical(_controller, controller)) _controller = null;
      _trackDisposal(_safelyDispose(controller));
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _safelyDispose(VideoPlayerController controller) async {
    try {
      await controller.dispose().timeout(const Duration(seconds: 2));
    } catch (_) {
      // Initialization can fail before the plugin completes its internal
      // creation future. A bounded release keeps retry/back navigation usable.
    }
  }

  void _trackDisposal(Future<void> disposal) {
    _pendingDisposal = disposal;
    unawaited(
      disposal.whenComplete(() {
        if (identical(_pendingDisposal, disposal)) _pendingDisposal = null;
      }),
    );
  }

  void _queueControllerDisposal() {
    _initializationGeneration++;
    final controller = _controller;
    _controller = null;
    if (controller != null) _trackDisposal(_safelyDispose(controller));
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      await _initialize();
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (controller.value.isCompleted) {
        await controller.seekTo(Duration.zero);
      }
      await controller.play();
    }
  }

  @override
  void dispose() {
    _queueControllerDisposal();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initialized = controller?.value.isInitialized ?? false;
    return ColoredBox(
      color: widget.backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (initialized)
            Center(
              child: AspectRatio(
                aspectRatio: controller!.value.aspectRatio > 0
                    ? controller.value.aspectRatio
                    : 16 / 9,
                child: VideoPlayer(controller),
              ),
            )
          else
            Center(
              child: _error == null && widget.active
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Icon(
                      Icons.videocam_outlined,
                      size: widget.placeholderIconSize,
                      color: Colors.white70,
                    ),
            ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('chat-video-playback-toggle'),
                onTap: _togglePlayback,
                child: Center(
                  child: controller == null
                      ? _playButton(playing: false)
                      : AnimatedBuilder(
                          animation: controller,
                          builder: (context, _) =>
                              _playButton(playing: controller.value.isPlaying),
                        ),
                ),
              ),
            ),
          ),
          if (initialized)
            Positioned(
              left: 10,
              right: 10,
              bottom: 7,
              child: VideoProgressIndicator(
                controller!,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _playButton({required bool playing}) => AnimatedOpacity(
    opacity: playing ? 0 : 1,
    duration: const Duration(milliseconds: 160),
    child: Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _error == null ? Icons.play_arrow_rounded : Icons.refresh_rounded,
        color: Colors.white,
        size: 34,
      ),
    ),
  );
}

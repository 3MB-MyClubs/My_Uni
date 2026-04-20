import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/club_notification_service.dart';
import '../services/content_store.dart';
import '../services/mock_data.dart';

class CreateStoryScreen extends StatefulWidget {
  final VoidCallback onPosted;

  const CreateStoryScreen({super.key, required this.onPosted});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  String? _imagePath;
  bool _isEditingText = false;
  String _overlayText = '';
  double _textFracX = 0.5;
  double _textFracY = 0.45;
  int _colorIndex = 0;

  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  static const _textColors = [
    Colors.white,
    Colors.black,
    Color(0xFFFFE066),
    Color(0xFFFF6B6B),
    Color(0xFF66D9E8),
    Color(0xFF82E05A),
    Color(0xFFFF9ECD),
  ];

  Color get _currentColor => _textColors[_colorIndex % _textColors.length];

  String? get _clubId {
    final admin = authService.currentAdmin;
    if (admin == null) return null;
    try {
      return clubs.firstWhere((c) => c.adminUserIds.contains(admin.id)).id;
    } catch (_) {
      return clubs.isNotEmpty ? clubs.first.id : null;
    }
  }

  // ── Photo picking ──────────────────────────────────────────────────────────

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
    if (picked == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        IOSUiSettings(title: 'Crop Photo', resetAspectRatioEnabled: true),
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
        ),
      ],
    );
    if (cropped == null || !mounted) return;
    setState(() => _imagePath = cropped.path);
  }

  // ── Text editing ───────────────────────────────────────────────────────────

  void _activateTextAt(Offset local, Size size) {
    setState(() {
      _textFracX = (local.dx / size.width).clamp(0.0, 1.0);
      _textFracY = (local.dy / size.height).clamp(0.05, 0.85);
      _isEditingText = true;
    });
    _focusNode.requestFocus();
  }

  void _commitText() {
    setState(() {
      _overlayText = _textController.text;
      _isEditingText = false;
    });
    _focusNode.unfocus();
  }

  // ── Post ───────────────────────────────────────────────────────────────────

  void _post() {
    final cid = _clubId;
    if (cid == null) return;
    final text = _overlayText.trim();

    final newStory = ClubStory(
      id: 'st_${DateTime.now().millisecondsSinceEpoch}',
      clubId: cid,
      emoji: null,
      text: text,
      postedAt: DateTime.now(),
      imagePath: _imagePath,
      textOffsetX: _textFracX,
      textOffsetY: _textFracY,
      textColorValue: _currentColor.toARGB32(),
      createdByUserId: authService.currentAdmin?.id,
    );
    clubStories.insert(0, newStory);
    contentStore.saveClubStories();
    clubNotificationService.notifyFollowersAboutStory(newStory);
    widget.onPosted();
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isEditingText) {
        setState(() {
          _overlayText = _textController.text;
          _isEditingText = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final hasPhoto = _imagePath != null;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Background ────────────────────────────────────────────────────
          Positioned.fill(
            child: hasPhoto
                ? InteractiveViewer(
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: Image.file(
                      File(_imagePath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: _isEditingText
                        ? null
                        : (d) => _activateTextAt(d.localPosition, size),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
          ),

          // ── Dim overlay when editing text ─────────────────────────────────
          if (_isEditingText)
            Positioned.fill(
              child: GestureDetector(
                onTap: _commitText,
                child: Container(color: Colors.black.withValues(alpha: 0.45)),
              ),
            ),

          // ── Text overlay (placed + draggable) ─────────────────────────────
          if (_overlayText.isNotEmpty && !_isEditingText)
            _DraggableText(
              text: _overlayText,
              color: Color(_textColors[_colorIndex % _textColors.length].toARGB32()),
              fracX: _textFracX,
              fracY: _textFracY,
              screenSize: size,
              onDrag: (fx, fy) => setState(() {
                _textFracX = fx;
                _textFracY = fy;
              }),
              onTap: () {
                _textController.text = _overlayText;
                setState(() => _isEditingText = true);
                _focusNode.requestFocus();
              },
            ),

          // ── Text input field (Instagram-style centred over photo) ──────────
          if (_isEditingText)
            Positioned(
              left: 16,
              right: 16,
              top: (size.height * _textFracY - 28).clamp(
                  MediaQuery.of(context).padding.top + 60,
                  size.height * 0.7),
              child: Center(
                child: IntrinsicWidth(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: size.width - 48),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      style: TextStyle(
                        color: _currentColor,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(blurRadius: 6, color: Colors.black87),
                          Shadow(blurRadius: 12, color: Colors.black54),
                        ],
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Tap to type…',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Top bar ───────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    // Close
                    _CircleBtn(
                      icon: Icons.close,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    if (_isEditingText) ...[
                      // Color cycle button
                      GestureDetector(
                        onTap: () => setState(
                            () => _colorIndex = (_colorIndex + 1) % _textColors.length),
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: _currentColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Done
                      GestureDetector(
                        onTap: _commitText,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Text('Done',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ),
                      ),
                    ] else ...[
                      // Photo swap
                      if (hasPhoto)
                        _CircleBtn(
                          icon: Icons.image_outlined,
                          onTap: () => _showPickerSheet(),
                        ),
                      if (hasPhoto) const SizedBox(width: 8),
                      // "Aa" text toggle
                      GestureDetector(
                        onTap: () {
                          setState(() => _isEditingText = true);
                          _focusNode.requestFocus();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: const Text('Aa',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Post
                      GestureDetector(
                        onTap: _post,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Post',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              SizedBox(width: 6),
                              Icon(Icons.send_rounded, color: Colors.white, size: 15),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom controls (photo picker + emoji) ─────────────────────────
          if (!_isEditingText)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo picker row
                      if (!hasPhoto) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _BottomPickBtn(
                                icon: Icons.camera_alt_rounded,
                                label: 'Camera',
                                onTap: () => _pickPhoto(ImageSource.camera),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _BottomPickBtn(
                                icon: Icons.photo_library_rounded,
                                label: 'Library',
                                onTap: () => _pickPhoto(ImageSource.gallery),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryRed),
              title: const Text('Take a photo', style: TextStyle(color: AppColors.text)),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primaryRed),
              title: const Text('Choose from library', style: TextStyle(color: AppColors.text)),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remove photo', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _imagePath = null;
                  _overlayText = '';
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Draggable Text Overlay ───────────────────────────────────────────────────

class _DraggableText extends StatelessWidget {
  final String text;
  final Color color;
  final double fracX;
  final double fracY;
  final Size screenSize;
  final void Function(double fx, double fy) onDrag;
  final VoidCallback onTap;

  const _DraggableText({
    required this.text,
    required this.color,
    required this.fracX,
    required this.fracY,
    required this.screenSize,
    required this.onDrag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const maxW = 300.0;
    return Positioned(
      left: (fracX * screenSize.width - maxW / 2).clamp(0, screenSize.width - maxW),
      top: (fracY * screenSize.height - 22).clamp(40, screenSize.height - 80),
      child: GestureDetector(
        onTap: onTap,
        onPanUpdate: (d) {
          final newX = ((fracX * screenSize.width) + d.delta.dx)
              .clamp(0.0, screenSize.width) / screenSize.width;
          final newY = ((fracY * screenSize.height) + d.delta.dy)
              .clamp(40.0, screenSize.height - 80) / screenSize.height;
          onDrag(newX, newY);
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: maxW),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              shadows: const [
                Shadow(blurRadius: 6, color: Colors.black87),
                Shadow(blurRadius: 14, color: Colors.black54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Small circle button ──────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.black38,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      );
}

// ─── Bottom photo-picker button ───────────────────────────────────────────────

class _BottomPickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _BottomPickBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
        ),
      );
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../screens/create_post_screen.dart' show buildPostBanner;
import '../services/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/club_notification_service.dart';
import '../services/content_store.dart';
import '../services/mock_data.dart';
import '../services/supabase_post_service.dart';
import 'club_avatar.dart';

/// Presents the "Option C — Big Picture Cards" post composer as a bottom
/// sheet that slides up over the Home Feed when a club owner taps the
/// "What's happening at your club?" prompt. Self-contained: posting still
/// goes through [supabasePostService.createPost], the same path the rest of
/// the app already uses.
///
/// Flow is two-step: compose (text + optional photo) → confirm (a preview
/// matching the Home Feed card, published only once the admin confirms).
Future<void> showBigPicturePostComposerSheet({
  required BuildContext context,
  required dynamic club,
  required Color color,
  required VoidCallback onPosted,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _BigPicturePostComposerSheet(
      club: club,
      color: color,
      onPosted: onPosted,
    ),
  );
}

class _BigPicturePostComposerSheet extends StatefulWidget {
  final dynamic club;
  final Color color;
  final VoidCallback onPosted;

  const _BigPicturePostComposerSheet({
    required this.club,
    required this.color,
    required this.onPosted,
  });

  @override
  State<_BigPicturePostComposerSheet> createState() =>
      _BigPicturePostComposerSheetState();
}

class _BigPicturePostComposerSheetState
    extends State<_BigPicturePostComposerSheet> {
  static const int _maxChars = 500;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _imagePath;
  bool _posting = false;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  bool get _canPost => !_posting && _controller.text.trim().isNotEmpty;

  void _reviewPost() {
    if (!_canPost) return;
    _focusNode.unfocus();
    setState(() => _confirming = true);
  }

  void _backToEdit() {
    setState(() => _confirming = false);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (picked == null || !mounted) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      maxWidth: 1920,
      maxHeight: 1920,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        IOSUiSettings(
          title: AppLocalizations.of(context)!.cropPhoto,
          resetAspectRatioEnabled: true,
          rotateButtonsHidden: false,
        ),
        AndroidUiSettings(
          toolbarTitle: AppLocalizations.of(context)!.cropPhoto,
          toolbarColor: AppColors.primaryRed,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
          showCropGrid: true,
        ),
      ],
    );
    if (cropped != null && mounted) setState(() => _imagePath = cropped.path);
  }

  void _showPhotoPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.camera_alt_rounded,
                color: AppColors.primaryRed,
              ),
              title: Text(
                AppLocalizations.of(context)!.takePhoto,
                style: TextStyle(color: AppColors.text),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library_rounded,
                color: AppColors.primaryRed,
              ),
              title: Text(
                AppLocalizations.of(context)!.chooseFromLib,
                style: TextStyle(color: AppColors.text),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _post() async {
    if (_posting || _controller.text.trim().isEmpty) return;
    final content = _controller.text.trim();
    final club = widget.club;
    setState(() => _posting = true);
    try {
      final post = await supabasePostService.createPost(
        clubId: club.id as String,
        authorId: authService.currentAdmin?.id ?? '',
        content: content,
        taggedClubIds: const [],
        taggedUserIds: const [],
        imagePath: _imagePath,
      );
      if (!mounted) return;
      newsPosts.insert(0, post);
      unawaited(contentStore.saveNewsPosts());
      contentStore.notifyContentChanged();
      unawaited(clubNotificationService.notifyFollowersAboutPost(post));
      widget.onPosted();
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _posting = false;
        _confirming = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
<<<<<<< Updated upstream
          const SnackBar(
            content: Text('Could not publish post. Check Supabase settings.'),
=======
          SnackBar(
            content: Text(
              error is ContentSafetyException
                  ? AppLocalizations.of(context)!.contentSafetyRejected
                  : AppLocalizations.of(context)!.publishErrorGeneric,
            ),
>>>>>>> Stashed changes
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.club;
    final clubName = club.name as String;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _confirming
                        ? _ConfirmStep(
                            key: const ValueKey('confirm'),
                            club: club,
                            clubName: clubName,
                            color: widget.color,
                            text: _controller.text,
                            imagePath: _imagePath,
                          )
                        : _ComposeStep(
                            key: const ValueKey('compose'),
                            club: club,
                            clubName: clubName,
                            color: widget.color,
                            controller: _controller,
                            focusNode: _focusNode,
                            maxChars: _maxChars,
                            imagePath: _imagePath,
                            onAddPhoto: _showPhotoPickerSheet,
                            onRemovePhoto: () =>
                                setState(() => _imagePath = null),
                          ),
                  ),
                ),
              ),
              // Bottom action bar. Compose: Cancel / Post (moves to the
              // confirm step). Confirm: Back (returns to editing) / Confirm
              // (actually publishes) — a deliberate two-step flow so the
              // admin sees exactly what will be posted before it goes live.
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.divider.withValues(alpha: 0.6),
                      width: 0.6,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _posting
                          ? null
                          : (_confirming
                                ? _backToEdit
                                : () => Navigator.of(context).pop()),
                      child: Text(
                        _confirming
                            ? AppLocalizations.of(context)!.back
                            : AppLocalizations.of(context)!.cancel,
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _confirming
                          ? (_posting ? null : _post)
                          : (_canPost ? _reviewPost : null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primaryRed
                            .withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(22)),
                        ),
                      ),
                      child: _posting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _confirming
                                  ? AppLocalizations.of(context)!.confirm
                                  : AppLocalizations.of(context)!.post,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Step 1 — write the post: club header, the auto-growing text area, and a
/// small photo control (a pill button, or a tiny "photo added" chip once one
/// is picked — never a large inline preview).
class _ComposeStep extends StatelessWidget {
  final dynamic club;
  final String clubName;
  final Color color;
  final TextEditingController controller;
  final FocusNode focusNode;
  final int maxChars;
  final String? imagePath;
  final VoidCallback onAddPhoto;
  final VoidCallback onRemovePhoto;

  const _ComposeStep({
    super.key,
    required this.club,
    required this.clubName,
    required this.color,
    required this.controller,
    required this.focusNode,
    required this.maxChars,
    required this.imagePath,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  bool get _hasPhoto => imagePath != null && imagePath!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Posting-as header
        Row(
          children: [
            ClubAvatar(
              clubId: club.id as String,
              clubName: clubName,
              color: color,
              imageUrl: club.logoUrl as String?,
              size: 34,
              fontSize: 14,
              shape: 'circle',
            ),
            const SizedBox(width: 10),
            Text(
              clubName,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: AppColors.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Large, auto-growing text area — a blank canvas that blends into
        // the page background, same as the Home Feed prompt: no box, no
        // border, no fill, just text directly on the surface.
        Container(
          width: double.infinity,
          color: AppColors.background,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            minLines: 4,
            maxLines: null,
            maxLength: maxChars,
            textCapitalization: TextCapitalization.sentences,
            cursorColor: AppColors.primaryRed,
            style: TextStyle(fontSize: 17, color: AppColors.text, height: 1.4),
            decoration: InputDecoration(
              isCollapsed: true,
              counterText: '',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              hintText: AppLocalizations.of(context)!.whatsHappeningAtClub,
              hintStyle: TextStyle(
                fontSize: 17,
                color: AppColors.secondaryText,
                height: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Small photo control — a pill button, or a tiny chip once a photo
        // has been picked (never a large preview inline in the composer).
        if (!_hasPhoto)
          GestureDetector(
            onTap: onAddPhoto,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.all(Radius.circular(20)),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_photo_alternate_rounded,
                    size: 17,
                    color: AppColors.primaryRed,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context)!.addPhoto,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          GestureDetector(
            onTap: onAddPhoto,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.all(Radius.circular(20)),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    child: Image.file(
                      File(imagePath!),
                      width: 26,
                      height: 26,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 15,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context)!.photoAdded,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onRemovePhoto,
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Step 2 — confirm: the club owner sees the post exactly as it will look
/// in the Home Feed (Text Card or Photo Card) before it actually publishes.
class _ConfirmStep extends StatelessWidget {
  final dynamic club;
  final String clubName;
  final Color color;
  final String text;
  final String? imagePath;

  const _ConfirmStep({
    super.key,
    required this.club,
    required this.clubName,
    required this.color,
    required this.text,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppLocalizations.of(context)!.readyToPost,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppLocalizations.of(context)!.feedPreviewHint,
          style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
        ),
        const SizedBox(height: 14),
        _FeedStylePreviewCard(
          club: club,
          clubName: clubName,
          color: color,
          text: text,
          imagePath: imagePath,
        ),
      ],
    );
  }
}

/// Mirrors the Home Feed card's look (club header + text + optional image)
/// so the confirmation preview matches what the post will actually look
/// like — a Text Card when there's no photo, a Photo Card once one is added.
class _FeedStylePreviewCard extends StatelessWidget {
  final dynamic club;
  final String clubName;
  final Color color;
  final String text;
  final String? imagePath;

  const _FeedStylePreviewCard({
    required this.club,
    required this.clubName,
    required this.color,
    required this.text,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;
    final trimmed = text.trim();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClubAvatar(
            clubId: club.id as String,
            clubName: clubName,
            color: color,
            imageUrl: club.logoUrl as String?,
            size: 38,
            fontSize: 16,
            shape: 'circle',
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clubName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context)!.justNow,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.secondaryText,
                  ),
                ),
                if (trimmed.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    trimmed,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.text,
                      height: 1.4,
                    ),
                  ),
                ],
                if (hasImage) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    child: buildPostBanner(
                      imagePath: imagePath,
                      fallbackColor: color,
                      fallbackLetter: clubName.isNotEmpty ? clubName[0] : '?',
                      height: 150,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

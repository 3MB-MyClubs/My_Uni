import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/club_admin_access.dart';
import '../services/club_notification_service.dart';
import '../services/content_store.dart';
import '../services/mock_data.dart';
import '../services/supabase_post_service.dart';
import '../widgets/content_image_uploader.dart';
import '../widgets/mention_text_field.dart';

// ── Template definitions ─────────────────────────────────────────────────────

class PostTemplate {
  final String id;
  final String label;
  final List<Color> colors;
  final Alignment begin;
  final Alignment end;

  const PostTemplate({
    required this.id,
    required this.label,
    required this.colors,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });
}

const _templates = [
  PostTemplate(
    id: 'tpl:0',
    label: 'Sunset',
    colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
  ),
  PostTemplate(
    id: 'tpl:1',
    label: 'Ocean',
    colors: [Color(0xFF667EEA), Color(0xFF64D9E8)],
  ),
  PostTemplate(
    id: 'tpl:2',
    label: 'Forest',
    colors: [Color(0xFF2E7D32), Color(0xFF81C784)],
  ),
  PostTemplate(
    id: 'tpl:3',
    label: 'Midnight',
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
  ),
  PostTemplate(
    id: 'tpl:4',
    label: 'Rose',
    colors: [Color(0xFF8C1D40), Color(0xFFE91E8C)],
  ),
  PostTemplate(
    id: 'tpl:5',
    label: 'Gold',
    colors: [Color(0xFFB8860B), Color(0xFFFFD700)],
  ),
  PostTemplate(
    id: 'tpl:6',
    label: 'Aurora',
    colors: [Color(0xFF6A1B9A), Color(0xFF00BCD4)],
  ),
  PostTemplate(
    id: 'tpl:7',
    label: 'Lava',
    colors: [Color(0xFFE65100), Color(0xFFFF8F00)],
  ),
];

Widget buildPostBanner({
  required String? imagePath,
  required Color fallbackColor,
  required String fallbackLetter,
  double height = 200,
}) {
  // Network image (Picsum / any https URL)
  if (imagePath != null && imagePath.startsWith('https://')) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ClipRRect(
        child: Image.network(
          imagePath,
          fit: BoxFit.cover,
          width: double.infinity,
          height: height,
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : Container(
                  width: double.infinity,
                  height: height,
                  color: fallbackColor.withValues(alpha: 0.12),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  ),
                ),
          errorBuilder: (ctx, e, _) => Container(
            width: double.infinity,
            height: height,
            color: fallbackColor.withValues(alpha: 0.18),
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: fallbackColor.withValues(alpha: 0.4),
                size: 40,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Gallery photo — interactive (pan / pinch-to-zoom)
  if (imagePath != null && !imagePath.startsWith('tpl:')) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ClipRect(
        child: InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(double.infinity),
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.file(
            File(imagePath),
            fit: BoxFit.cover,
            width: double.infinity,
            height: height,
          ),
        ),
      ),
    );
  }

  // Template or fallback gradient
  final gradient = imagePath != null
      ? LinearGradient(
          colors: _templates
              .firstWhere((t) => t.id == imagePath, orElse: () => _templates[0])
              .colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : LinearGradient(
          colors: [
            fallbackColor.withValues(alpha: 0.7),
            fallbackColor.withValues(alpha: 0.25),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

  return Container(
    width: double.infinity,
    height: height,
    decoration: BoxDecoration(gradient: gradient),
    child: Center(
      child: Text(
        fallbackLetter,
        style: TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.w900,
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
    ),
  );
}

// ── Create Post Screen ───────────────────────────────────────────────────────

class CreatePostScreen extends StatefulWidget {
  final VoidCallback? onPosted;
  const CreatePostScreen({super.key, this.onPosted});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  bool _isPosting = false;
  bool _requiresPhoto = false;

  _ClubOption? _selectedClub;
  late final List<_ClubOption> _myClubs;
  final Set<String> _selectedTaggedClubIds = {};
  final Set<String> _selectedTaggedUserIds = {};

  // Image state
  String? _imagePath;

  bool get _hasUploadedPhoto =>
      _imagePath != null &&
      _imagePath!.isNotEmpty &&
      !_imagePath!.startsWith('tpl:');

  @override
  void initState() {
    super.initState();
    final adminId = authService.currentAdmin?.id ?? '';
    _myClubs = clubs
        .where((c) => clubIsManagedByAdmin(c, adminId))
        .map((c) => _ClubOption(id: c.id, name: c.name))
        .toList();
    if (_myClubs.length == 1) _selectedClub = _myClubs.first;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  String _mentionKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  bool _containsMention(String content, String label) {
    final lower = content.toLowerCase();
    final firstWordMention = '@${label.split(' ').first.toLowerCase()}';
    final fullNameMention = '@${label.toLowerCase()}';
    final compactContent = _mentionKey(content);
    final compactMention = _mentionKey('@$label');
    return lower.contains(firstWordMention) ||
        lower.contains(fullNameMention) ||
        compactContent.contains(compactMention);
  }

  List<String> _extractTaggedClubIds(String content) {
    final tagged = <String>{..._selectedTaggedClubIds};
    final lower = content.toLowerCase();
    for (final club in clubs) {
      if (club.id == _selectedClub?.id) continue;
      if (_containsMention(lower, club.name)) {
        tagged.add(club.id);
      }
    }
    return tagged.toList();
  }

  List<String> _extractTaggedUserIds(String content) {
    final tagged = <String>{..._selectedTaggedUserIds};
    for (final user in users) {
      if (_containsMention(content, user.name)) {
        tagged.add(user.id);
      }
    }
    return tagged.toList();
  }

  void _rememberMention(MentionOption option) {
    if (option.type == MentionType.club) {
      if (option.id != _selectedClub?.id) {
        _selectedTaggedClubIds.add(option.id);
      }
    } else {
      _selectedTaggedUserIds.add(option.id);
    }
  }

  List<MentionOption> get _mentionOptions => [
    ...clubs.map(
      (club) =>
          MentionOption(id: club.id, label: club.name, type: MentionType.club),
    ),
    ...users.map(
      (user) => MentionOption(
        id: user.id,
        label: user.name,
        type: MentionType.student,
      ),
    ),
  ];

  Future<void> _post() async {
    final content = _contentController.text.trim();
    if (content.isEmpty || _selectedClub == null) return;
    if (_requiresPhoto && !_hasUploadedPhoto) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please upload a photo before posting.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    setState(() => _isPosting = true);

    try {
      final post = await supabasePostService.createPost(
        clubId: _selectedClub!.id,
        authorId: authService.currentAdmin?.id ?? '',
        content: content,
        taggedClubIds: _extractTaggedClubIds(content),
        taggedUserIds: _extractTaggedUserIds(content),
        imagePath: _requiresPhoto ? _imagePath : null,
      );
      if (!mounted) return;
      newsPosts.insert(0, post);
      unawaited(contentStore.saveNewsPosts());
      unawaited(clubNotificationService.notifyFollowersAboutPost(post));
      widget.onPosted?.call();
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      debugPrint('Create post failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _isPosting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_publishErrorMessage(error)),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  String _publishErrorMessage(Object error) {
    final text = error.toString();
    if (text.contains('row-level security') ||
        text.contains('permission denied') ||
        text.contains('42501')) {
      return 'Could not publish post. Check club_posts RLS policies for this club account.';
    }
    if (text.contains('image_path') || text.contains('column')) {
      return 'Could not publish post. Run the latest club_posts SQL migration.';
    }
    if (text.contains('post-images') || text.contains('storage')) {
      return 'Could not upload photo. Check the post-images bucket policies.';
    }
    return 'Could not publish post. Check Supabase settings.';
  }

  bool get _canPost =>
      _contentController.text.trim().isNotEmpty &&
      _selectedClub != null &&
      (!_requiresPhoto || _hasUploadedPhoto);

  @override
  Widget build(BuildContext context) {
    final adminName = authService.currentAdmin?.name ?? 'Club';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.secondaryText),
          ),
        ),
        leadingWidth: 70,
        title: Text('New Post', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AnimatedOpacity(
              opacity: _canPost ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 150),
              child: ElevatedButton(
                onPressed: _canPost && !_isPosting ? () => _post() : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: _isPosting
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Post',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Form fields ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Who is posting
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.admin_panel_settings,
                          color: AppColors.primaryRed,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            adminName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Club picker
                if (_myClubs.length > 1) ...[
                  Text(
                    'Posting as',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<_ClubOption>(
                        value: _selectedClub,
                        isExpanded: true,
                        hint: Text(
                          'Select club',
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                        dropdownColor: AppColors.card,
                        items: _myClubs
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedClub = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                _PhotoUploadChoice(
                  enabled: _requiresPhoto,
                  imagePath: _imagePath,
                  hasUploadedPhoto: _hasUploadedPhoto,
                  onEnabledChanged: (value) {
                    setState(() {
                      _requiresPhoto = value;
                      if (!value) _imagePath = null;
                    });
                  },
                  onImageChanged: (path) => setState(() => _imagePath = path),
                ),
                const SizedBox(height: 16),

                // Tag hint
                Row(
                  children: [
                    Icon(
                      Icons.alternate_email,
                      size: 13,
                      color: AppColors.secondaryText,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Type @ to tag a club or student',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Content
                MentionTextField(
                  controller: _contentController,
                  options: _mentionOptions,
                  onMentionSelected: _rememberMention,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.text,
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Write something for your club members…',
                    hintStyle: TextStyle(
                      fontSize: 15,
                      color: AppColors.secondaryText,
                    ),
                    border: InputBorder.none,
                    filled: false,
                  ),
                  maxLines: null,
                  minLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Photo upload choice ──────────────────────────────────────────────────────

class _PhotoUploadChoice extends StatelessWidget {
  final bool enabled;
  final String? imagePath;
  final bool hasUploadedPhoto;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<String?> onImageChanged;

  const _PhotoUploadChoice({
    required this.enabled,
    required this.imagePath,
    required this.hasUploadedPhoto,
    required this.onEnabledChanged,
    required this.onImageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? AppColors.primaryRed : AppColors.divider,
          width: enabled ? 1.4 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.lightRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  enabled
                      ? Icons.add_photo_alternate_rounded
                      : Icons.notes_rounded,
                  color: AppColors.primaryRed,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      enabled ? 'Photo post' : 'Text update',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      enabled
                          ? hasUploadedPhoto
                                ? 'Photo attached. This post will include it.'
                                : 'Upload a photo to unlock posting.'
                          : 'No photo needed. This will publish as an update.',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: enabled,
                activeThumbColor: AppColors.primaryRed,
                onChanged: onEnabledChanged,
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: enabled
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: ContentImageUploader(
                imagePath: imagePath,
                onChanged: onImageChanged,
                height: 180,
                emptyTitle: 'Upload photo (required)',
                emptySubtitle: 'Tap to choose from camera or library',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Club option ───────────────────────────────────────────────────────────────

class _ClubOption {
  final String id;
  final String name;
  const _ClubOption({required this.id, required this.name});

  @override
  bool operator ==(Object other) => other is _ClubOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

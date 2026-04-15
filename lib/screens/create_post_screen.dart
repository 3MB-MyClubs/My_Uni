import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/content_store.dart';
import '../services/mock_data.dart';
import '../models/news_post.dart';

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
  PostTemplate(id: 'tpl:0', label: 'Sunset',   colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)]),
  PostTemplate(id: 'tpl:1', label: 'Ocean',    colors: [Color(0xFF667EEA), Color(0xFF64D9E8)]),
  PostTemplate(id: 'tpl:2', label: 'Forest',   colors: [Color(0xFF2E7D32), Color(0xFF81C784)]),
  PostTemplate(id: 'tpl:3', label: 'Midnight', colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]),
  PostTemplate(id: 'tpl:4', label: 'Rose',     colors: [Color(0xFF8C1D40), Color(0xFFE91E8C)]),
  PostTemplate(id: 'tpl:5', label: 'Gold',     colors: [Color(0xFFB8860B), Color(0xFFFFD700)]),
  PostTemplate(id: 'tpl:6', label: 'Aurora',   colors: [Color(0xFF6A1B9A), Color(0xFF00BCD4)]),
  PostTemplate(id: 'tpl:7', label: 'Lava',     colors: [Color(0xFFE65100), Color(0xFFFF8F00)]),
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
                  child: const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white54),
                  ),
                ),
          errorBuilder: (ctx, e, _) => Container(
            width: double.infinity,
            height: height,
            color: fallbackColor.withValues(alpha: 0.18),
            child: Center(
              child: Icon(Icons.broken_image_outlined,
                  color: fallbackColor.withValues(alpha: 0.4), size: 40),
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
          child: Image.file(File(imagePath), fit: BoxFit.cover,
              width: double.infinity, height: height),
        ),
      ),
    );
  }

  // Template or fallback gradient
  final gradient = imagePath != null
      ? LinearGradient(
          colors: _templates.firstWhere((t) => t.id == imagePath,
              orElse: () => _templates[0]).colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : LinearGradient(
          colors: [fallbackColor.withValues(alpha: 0.7), fallbackColor.withValues(alpha: 0.25)],
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

class _CreatePostScreenState extends State<CreatePostScreen>
    with SingleTickerProviderStateMixin {
  final _contentController = TextEditingController();
  bool _isPosting = false;

  _ClubOption? _selectedClub;
  late final List<_ClubOption> _myClubs;

  // Image state
  String? _imagePath;          // null | "tpl:N" | file path
  late final TabController _mediaTabController;

  @override
  void initState() {
    super.initState();
    _mediaTabController = TabController(length: 2, vsync: this);
    final adminId = authService.currentAdmin?.id ?? '';
    _myClubs = clubs
        .where((c) => c.adminUserIds.contains(adminId))
        .map((c) => _ClubOption(id: c.id, name: c.name))
        .toList();
    if (_myClubs.length == 1) _selectedClub = _myClubs.first;
  }

  @override
  void dispose() {
    _contentController.dispose();
    _mediaTabController.dispose();
    super.dispose();
  }

  List<String> _extractTaggedClubIds(String content) {
    final tagged = <String>[];
    final lower = content.toLowerCase();
    for (final club in clubs) {
      if (club.id == _selectedClub?.id) continue;
      final mention = '@${club.name.split(' ').first.toLowerCase()}';
      if (lower.contains(mention)) tagged.add(club.id);
    }
    return tagged;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
    if (picked == null || !mounted) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        IOSUiSettings(
          title: 'Crop Photo',
          resetAspectRatioEnabled: true,
          rotateButtonsHidden: false,
        ),
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: AppColors.primaryRed,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
          showCropGrid: true,
        ),
      ],
    );
    if (cropped != null && mounted) setState(() => _imagePath = cropped.path);
  }

  void _showPhotoPicker() {
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
            Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryRed),
              title: const Text('Take a photo', style: TextStyle(color: AppColors.text)),
              onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primaryRed),
              title: const Text('Choose from library', style: TextStyle(color: AppColors.text)),
              onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.gallery); },
            ),
            if (_imagePath != null && !_imagePath!.startsWith('tpl:'))
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove photo', style: TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(context); setState(() => _imagePath = null); },
              ),
          ],
        ),
      ),
    );
  }

  void _post() {
    final content = _contentController.text.trim();
    if (content.isEmpty || _selectedClub == null) return;
    setState(() => _isPosting = true);

    final post = NewsPost(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      clubId: _selectedClub!.id,
      authorId: authService.currentAdmin?.id ?? '',
      content: content,
      createdAt: DateTime.now(),
      taggedClubIds: _extractTaggedClubIds(content),
      imagePath: _imagePath,
    );
    newsPosts.insert(0, post);
    contentStore.saveNewsPosts();
    widget.onPosted?.call();
    Navigator.of(context).pop();
  }

  bool get _canPost =>
      _contentController.text.trim().isNotEmpty &&
      _selectedClub != null;

  Color get _clubColor {
    if (_selectedClub == null) return AppColors.primaryRed;
    final idx = clubs.indexWhere((c) => c.id == _selectedClub!.id);
    const colors = [
      Color(0xFFB41C18), Color(0xFF1565C0), Color(0xFF2E7D32),
      Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00838F),
    ];
    return colors[(idx < 0 ? 0 : idx) % colors.length];
  }

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
          child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
        ),
        leadingWidth: 70,
        title: const Text('New Post', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AnimatedOpacity(
              opacity: _canPost ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 150),
              child: ElevatedButton(
                onPressed: _canPost && !_isPosting ? _post : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Cover image preview ──────────────────────────────────────────
          buildPostBanner(
            imagePath: _imagePath,
            fallbackColor: _clubColor,
            fallbackLetter: adminName.isNotEmpty ? adminName[0] : 'C',
            height: 220,
          ),

          // ── Media picker panel ───────────────────────────────────────────
          Container(
            color: AppColors.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TabBar(
                  controller: _mediaTabController,
                  labelColor: AppColors.primaryRed,
                  unselectedLabelColor: AppColors.secondaryText,
                  indicatorColor: AppColors.primaryRed,
                  tabs: const [
                    Tab(text: 'Templates'),
                    Tab(text: 'Gallery'),
                  ],
                ),
                SizedBox(
                  height: 100,
                  child: TabBarView(
                    controller: _mediaTabController,
                    children: [
                      // Templates
                      _TemplatesRow(
                        selected: _imagePath,
                        onSelect: (id) => setState(() => _imagePath = id),
                      ),
                      // Gallery
                      _GalleryPickRow(
                        imagePath: _imagePath != null && !_imagePath!.startsWith('tpl:')
                            ? _imagePath
                            : null,
                        onPick: _showPhotoPicker,
                        onClear: () => setState(() => _imagePath = null),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
            ),
          ),

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
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.admin_panel_settings, color: AppColors.primaryRed, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(adminName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text)),
                          const Text('Club Admin', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Club picker
                if (_myClubs.length > 1) ...[
                  const Text('Posting as', style: TextStyle(fontSize: 12, color: AppColors.secondaryText, fontWeight: FontWeight.w500)),
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
                        hint: const Text('Select club', style: TextStyle(color: AppColors.secondaryText)),
                        dropdownColor: AppColors.card,
                        items: _myClubs.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                        onChanged: (v) => setState(() => _selectedClub = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Tag hint
                Row(
                  children: const [
                    Icon(Icons.alternate_email, size: 13, color: AppColors.secondaryText),
                    SizedBox(width: 4),
                    Text('Use @ClubName to tag a collaborating club',
                        style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                  ],
                ),
                const SizedBox(height: 8),

                // Content
                TextField(
                  controller: _contentController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 15, color: AppColors.text, height: 1.6),
                  decoration: const InputDecoration(
                    hintText: 'Write something for your club members…',
                    hintStyle: TextStyle(fontSize: 15, color: AppColors.secondaryText),
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

// ── Templates row ────────────────────────────────────────────────────────────

class _TemplatesRow extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;

  const _TemplatesRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      itemCount: _templates.length,
      itemBuilder: (_, i) {
        final tpl = _templates[i];
        final isSelected = selected == tpl.id;
        return GestureDetector(
          onTap: () => onSelect(tpl.id),
          child: Container(
            width: 68,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: tpl.colors, begin: tpl.begin, end: tpl.end),
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: isSelected
                  ? [BoxShadow(color: tpl.colors.first.withValues(alpha: 0.5), blurRadius: 8)]
                  : [],
            ),
            child: Stack(
              children: [
                if (isSelected)
                  const Center(child: Icon(Icons.check_circle, color: Colors.white, size: 24)),
                Positioned(
                  bottom: 4,
                  left: 0, right: 0,
                  child: Text(
                    tpl.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10, color: Colors.white,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Gallery pick row ─────────────────────────────────────────────────────────

class _GalleryPickRow extends StatelessWidget {
  final String? imagePath;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _GalleryPickRow({required this.imagePath, required this.onPick, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Pick button
        GestureDetector(
          onTap: onPick,
          child: Container(
            width: 80, height: 80,
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined, color: AppColors.secondaryText, size: 28),
                SizedBox(height: 4),
                Text('Pick photo', style: TextStyle(fontSize: 10, color: AppColors.secondaryText)),
              ],
            ),
          ),
        ),

        // Preview of picked photo
        if (imagePath != null)
          Stack(
            children: [
              Container(
                width: 80, height: 80,
                margin: const EdgeInsets.only(top: 10, bottom: 10, right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryRed, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(imagePath!), fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 6, right: 6,
                child: GestureDetector(
                  onTap: onClear,
                  child: Container(
                    width: 20, height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 13),
                  ),
                ),
              ),
            ],
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'No photo selected yet.\nTap "Pick photo" to choose\nfrom your library.',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText, height: 1.5),
            ),
          ),
      ],
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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/board_member_request.dart';
import '../models/club.dart';
import '../models/notification.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/user_state.dart';
import '../services/user_prefs_service.dart';
import '../services/content_store.dart';
import '../services/event_access.dart';
import '../widgets/club_avatar.dart';
import '../widgets/club_follow_button.dart';
import 'event_detail_screen.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';
import 'chat_screen.dart';
import 'create_post_screen.dart' show buildPostBanner;
import '../widgets/user_avatar.dart';

bool _isDarkClubTheme(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _clubPagePanel(BuildContext context) =>
    _isDarkClubTheme(context) ? const Color(0xFF160008) : AppColors.surfaceAlt;

Color _clubPageCard(BuildContext context) =>
    _isDarkClubTheme(context) ? const Color(0x0EFFFFFF) : AppColors.card;

Color _clubPageBorder(BuildContext context) =>
    _isDarkClubTheme(context) ? const Color(0x14FFFFFF) : AppColors.divider;

Color _clubPageStrongBorder(BuildContext context) => _isDarkClubTheme(context)
    ? const Color(0x2EFFFFFF)
    : AppColors.divider.withValues(alpha: 0.95);

Color _clubPageBodyText(BuildContext context) => _isDarkClubTheme(context)
    ? const Color(0xD1FFFFFF)
    : AppColors.text.withValues(alpha: 0.82);

class ClubProfileScreen extends StatefulWidget {
  final Club club;
  final Color color;

  const ClubProfileScreen({super.key, required this.club, required this.color});

  @override
  State<ClubProfileScreen> createState() => _ClubProfileScreenState();
}

class _ClubProfileScreenState extends State<ClubProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Posts by this club
  List get _clubPosts =>
      newsPosts.where((p) => p.clubId == widget.club.id).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // Events by this club
  List get _clubEvents =>
      events.where((e) => e.clubId == widget.club.id).toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  // Posts that tag this club via @ClubName
  List get _taggedPosts =>
      newsPosts
          .where(
            (p) =>
                p.clubId != widget.club.id &&
                p.taggedClubIds.contains(widget.club.id),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // Events co-hosted: events from other clubs that explicitly tag this club
  // (taggedClubIds on events not modelled, so we use posts for now)
  // Partner clubs = clubs whose posts tag this club OR this club's posts tag them
  List<Club> get _partnerClubs {
    final ids = <String>{};
    for (final p in newsPosts) {
      if (p.clubId == widget.club.id) {
        ids.addAll(p.taggedClubIds);
      } else if (p.taggedClubIds.contains(widget.club.id)) {
        ids.add(p.clubId);
      }
    }
    return clubs.where((c) => ids.contains(c.id)).toList();
  }

  /// True when the currently logged-in admin is the admin of THIS club.
  bool get _isThisClubAdmin {
    final admin = authService.currentAdmin;
    if (admin == null) return false;
    return widget.club.adminUserIds.contains(admin.id);
  }

  Future<void> _pickClubPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        IOSUiSettings(
          title: 'Crop Photo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: AppColors.primaryRed,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
        ),
      ],
    );
    if (cropped == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Use this photo?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
        ),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(File(cropped.path), fit: BoxFit.cover),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Use Photo'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final docsDir = await getApplicationDocumentsDirectory();
      final ext = cropped.path.contains('.')
          ? cropped.path.substring(cropped.path.lastIndexOf('.'))
          : '.jpg';
      final permanentPath = '${docsDir.path}/club_${widget.club.id}$ext';
      await File(cropped.path).copy(permanentPath);
      if (!mounted) return;
      userState.setClubPhoto(widget.club.id, permanentPath);
      await userPrefsService.saveClubPhoto(widget.club.id, permanentPath);
      setState(() {});
    }
  }

  // ── Banner (cover) photo ─────────────────────────────────────────────────────

  Future<void> _pickClubBanner(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      uiSettings: [
        IOSUiSettings(
          title: 'Crop Banner',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
        AndroidUiSettings(
          toolbarTitle: 'Crop Banner',
          toolbarColor: AppColors.primaryRed,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
        ),
      ],
    );
    if (cropped == null || !mounted) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final ext = cropped.path.contains('.')
        ? cropped.path.substring(cropped.path.lastIndexOf('.'))
        : '.jpg';
    final permanentPath = '${docsDir.path}/club_banner_${widget.club.id}$ext';
    await File(cropped.path).copy(permanentPath);
    if (!mounted) return;
    userState.setClubBanner(widget.club.id, permanentPath);
    await userPrefsService.saveClubBanner(widget.club.id, permanentPath);
    setState(() {});
  }

  void _showBannerOptions() {
    final hasBanner = userState.clubBannerPaths.containsKey(widget.club.id);
    showModalBottomSheet(
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
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Cover Photo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This photo appears as the background of your club page',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.lightRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.primaryRed,
                ),
              ),
              title: Text(
                'Take a Photo',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickClubBanner(ImageSource.camera);
              },
            ),
            Divider(height: 1, indent: 16),
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.lightRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primaryRed,
                ),
              ),
              title: Text(
                'Choose from Library',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickClubBanner(ImageSource.gallery);
              },
            ),
            if (hasBanner) ...[
              Divider(height: 1, indent: 16),
              ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.red),
                ),
                title: const Text(
                  'Remove Cover Photo',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  userState.removeClubBanner(widget.club.id);
                  await userPrefsService.removeClubBanner(widget.club.id);
                  if (mounted) setState(() {});
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showClubPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Change Club Photo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.lightRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.primaryRed,
                ),
              ),
              title: Text(
                'Take a Photo',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickClubPhoto(ImageSource.camera);
              },
            ),
            Divider(height: 1, indent: 16),
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.lightRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primaryRed,
                ),
              ),
              title: Text(
                'Choose from Library',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickClubPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openBoardManagement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BoardManagementSheet(club: widget.club),
    ).then((_) => setState(() {}));
  }

  String _handleFor(String name) {
    final words = name.split(RegExp(r'[\s\-]+'));
    final initials = words
        .where((w) => w.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(w[0]))
        .map((w) => w[0])
        .join()
        .toLowerCase();
    return initials.isEmpty
        ? name.toLowerCase().replaceAll(RegExp(r'\s+'), '')
        : initials;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _monthAbbr(int m) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return months[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    final memberCount = clubMemberCount(widget.club.id);
    final bg = AppColors.background;
    final cardColor = _clubPageCard(context);
    final borderColor = _clubPageBorder(context);
    final borderBright = _clubPageStrongBorder(context);
    final subText = AppColors.secondaryText;
    final panelText = AppColors.text;
    final bodyText = _clubPageBodyText(context);
    final handle = _handleFor(widget.club.name);
    final showFollowAction = !_isThisClubAdmin;
    final showMediaAction = _isThisClubAdmin;

    return Scaffold(
      backgroundColor: bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          // ── Nav bar ──
          SliverAppBar(
            pinned: true,
            toolbarHeight: 44,
            backgroundColor: bg,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            leading: IconButton(
              icon: Icon(
                Icons.chevron_left_rounded,
                color: panelText,
                size: 28,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '@$handle',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: panelText,
                    letterSpacing: -0.3,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 10,
                      color: AppColors.primaryRed,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Official Club',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.primaryRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: panelText,
                  size: 22,
                ),
                onPressed: _isThisClubAdmin ? _openBoardManagement : null,
              ),
            ],
          ),

          // ── Scrollable header ──
          SliverToBoxAdapter(
            child: ListenableBuilder(
              listenable: userState,
              builder: (context, _) {
                final bannerPath = userState.clubBannerPaths[widget.club.id];
                final hasBanner =
                    bannerPath != null && File(bannerPath).existsSync();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.topCenter,
                          radius: 1.4,
                          colors: [
                            widget.color.withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.68],
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Optional banner photo
                          if (hasBanner) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(
                                File(bannerPath),
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Avatar + Stats row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: _isThisClubAdmin
                                    ? _showClubPhotoOptions
                                    : null,
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 104,
                                      height: 104,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(28),
                                        gradient: LinearGradient(
                                          begin: const Alignment(-0.8, -0.8),
                                          end: const Alignment(0.8, 0.8),
                                          colors: [
                                            widget.color.withValues(
                                              alpha: 0.23,
                                            ),
                                            widget.color.withValues(
                                              alpha: 0.44,
                                            ),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: widget.color.withValues(
                                            alpha: 0.40,
                                          ),
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: widget.color.withValues(
                                              alpha: 0.10,
                                            ),
                                            blurRadius: 0,
                                            spreadRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(26),
                                        child: ClubAvatar(
                                          clubId: widget.club.id,
                                          clubName: widget.club.name,
                                          color: widget.color,
                                          size: 104,
                                          fontSize: 46,
                                          borderRadius: 28,
                                        ),
                                      ),
                                    ),
                                    if (_isThisClubAdmin)
                                      Positioned(
                                        right: 2,
                                        bottom: 2,
                                        child: Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryRed,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: bg,
                                              width: 2,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.edit,
                                            color: panelText,
                                            size: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 22),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _StatCell(
                                      value: '${_clubPosts.length}',
                                      label: 'Posts',
                                      dark: true,
                                    ),
                                    Container(
                                      width: 1,
                                      height: 28,
                                      color: borderColor,
                                    ),
                                    _StatCell(
                                      value: '$memberCount',
                                      label: 'Members',
                                      dark: true,
                                    ),
                                    Container(
                                      width: 1,
                                      height: 28,
                                      color: borderColor,
                                    ),
                                    _StatCell(
                                      value: '${_clubEvents.length}',
                                      label: 'Events',
                                      dark: true,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Name
                          Text(
                            widget.club.name,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: panelText,
                              letterSpacing: -0.5,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Badges
                          Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.color.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '@$handle',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: widget.color,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryRed.withValues(
                                    alpha: 0.18,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Cultural',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryRed,
                                  ),
                                ),
                              ),
                              Text(
                                '· Est. 2010',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Bio
                          Text(
                            widget.club.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: bodyText,
                              height: 1.6,
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Action buttons: Follow | Message | +
                          Row(
                            children: [
                              if (showFollowAction) ...[
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: ClubFollowButton(
                                      clubId: widget.club.id,
                                      size: 'large',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ] else
                                const Spacer(),
                              Expanded(
                                flex: showFollowAction ? 1 : 2,
                                child: GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        otherUserId: widget.club.id,
                                        otherUserName: widget.club.name,
                                      ),
                                    ),
                                  ),
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: borderBright),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Message',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: panelText,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (showMediaAction) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _showBannerOptions,
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Icon(
                                      hasBanner
                                          ? Icons.add_photo_alternate_outlined
                                          : Icons.image_outlined,
                                      color: panelText,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),

                    // Section divider
                    Container(height: 1, color: borderColor),
                  ],
                );
              },
            ),
          ),

          // ── Sticky tab bar ──
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primaryRed,
                unselectedLabelColor: subText,
                indicatorColor: AppColors.primaryRed,
                indicatorSize: TabBarIndicatorSize.tab,
                labelPadding: EdgeInsets.zero,
                tabs: [
                  _IconTab(icon: Icons.grid_view_rounded, label: 'POSTS'),
                  _IconTab(icon: Icons.event_rounded, label: 'EVENTS'),
                  _IconTab(icon: Icons.people_alt_outlined, label: 'COLLABS'),
                  _IconTab(icon: Icons.assignment_outlined, label: 'BOARD'),
                ],
              ),
              backgroundColor: bg,
              height: 58,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _PostsTab(posts: _clubPosts, clubColor: widget.color),
            _EventsTab(
              events: _clubEvents,
              monthAbbr: _monthAbbr,
              clubColor: widget.color,
            ),
            _CollaborationsTab(
              taggedPosts: _taggedPosts,
              partnerClubs: _partnerClubs,
              thisClub: widget.club,
              clubColor: widget.color,
              timeAgo: _timeAgo,
            ),
            _BoardTab(club: widget.club),
          ],
        ),
      ),
    );
  }
}

// ─── Posts Tab ────────────────────────────────────────────────────────────────

class _PostsTab extends StatelessWidget {
  final List posts;
  final Color clubColor;

  const _PostsTab({required this.posts, required this.clubColor});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Center(
        child: Text(
          'No posts yet.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(1.5),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1.5,
        mainAxisSpacing: 1.5,
        childAspectRatio: 1.0,
      ),
      itemCount: posts.length,
      itemBuilder: (context, i) =>
          _PostGridTile(post: posts[i], clubColor: clubColor),
    );
  }
}

class _PostGridTile extends StatelessWidget {
  final dynamic post;
  final Color clubColor;

  const _PostGridTile({required this.post, required this.clubColor});

  @override
  Widget build(BuildContext context) {
    final imagePath = post.imagePath as String?;
    final likeCount = postLikeCount(post.id as String);
    final commentCount = comments.where((c) => c.postId == post.id).length;
    final clubInitial = clubs
        .firstWhere((c) => c.id == post.clubId, orElse: () => clubs.first)
        .name[0]
        .toUpperCase();

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Thumbnail image ──
        _PostThumbnail(
          imagePath: imagePath,
          clubColor: clubColor,
          clubInitial: clubInitial,
        ),

        // ── Ink ripple + navigation (single tap handler) ──
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PostDetailScreen(post: post, clubColor: clubColor),
              ),
            ),
            splashColor: Colors.white30,
            highlightColor: Colors.black12,
          ),
        ),

        // ── Image badge (top-right) ──
        if (imagePath != null)
          Positioned(
            top: 6,
            right: 6,
            child: Icon(
              Icons.photo_library_rounded,
              size: 14,
              color: Colors.white.withValues(alpha: 0.9),
              shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),

        // ── Likes / comments overlay (bottom) ──
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.favorite, size: 11, color: Colors.white),
                const SizedBox(width: 3),
                Text(
                  '$likeCount',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                  ),
                ),
                const SizedBox(width: 7),
                Icon(Icons.chat_bubble_rounded, size: 11, color: Colors.white),
                const SizedBox(width: 3),
                Text(
                  '$commentCount',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 2, color: Colors.black)],
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

class _PostThumbnail extends StatelessWidget {
  final String? imagePath;
  final Color clubColor;
  final String clubInitial;

  const _PostThumbnail({
    required this.imagePath,
    required this.clubColor,
    required this.clubInitial,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath != null && imagePath!.startsWith('https://')) {
      return Image.network(
        // Use a smaller 200×200 thumb for the grid — same seed = same image
        imagePath!.replaceAll(RegExp(r'/\d+/\d+$'), '/200/200'),
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Container(
                color: clubColor.withValues(alpha: 0.12),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: clubColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
        errorBuilder: (ctx, e, st) =>
            _Fallback(color: clubColor, letter: clubInitial),
      );
    }

    if (imagePath != null && !imagePath!.startsWith('tpl:')) {
      // Local file path
      return Image.file(
        File(imagePath!),
        fit: BoxFit.cover,
        errorBuilder: (ctx, e, st) =>
            _Fallback(color: clubColor, letter: clubInitial),
      );
    }

    // tpl:N or null → gradient fallback
    return _Fallback(color: clubColor, letter: clubInitial);
  }
}

class _Fallback extends StatelessWidget {
  final Color color;
  final String letter;

  const _Fallback({required this.color, required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.18),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

// ─── Events Tab ───────────────────────────────────────────────────────────────

class _EventsTab extends StatelessWidget {
  final List events;
  final String Function(int) monthAbbr;
  final Color clubColor;

  const _EventsTab({
    required this.events,
    required this.monthAbbr,
    required this.clubColor,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = _clubPageCard(context);
    final borderColor = _clubPageBorder(context);
    final panelColor = _clubPagePanel(context);
    if (events.isEmpty) {
      return Center(
        child: Text(
          'No events yet.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final event = events[i];
        final dt = event.dateTime as DateTime;
        final diff = dt.difference(DateTime.now());
        final daysLabel = diff.isNegative
            ? 'Passed'
            : diff.inDays == 0
            ? 'Today'
            : diff.inDays == 1
            ? 'Tomorrow'
            : 'In ${diff.inDays} days';

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  EventDetailScreen(event: event as dynamic, color: clubColor),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date badge
                Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(
                    vertical: 7,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: panelColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        monthAbbr(dt.month),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryRed,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '${dt.day}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title as String,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.text,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 11,
                            color: AppColors.secondaryText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            daysLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                      if (canViewEventAttendance(event)) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 11,
                              color: AppColors.secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(event.attendeeUserIds as List).length} attending',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Text(
                      'RSVP',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
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

// ─── Collaborations Tab ───────────────────────────────────────────────────────

class _CollaborationsTab extends StatelessWidget {
  final List taggedPosts;
  final List<Club> partnerClubs;
  final Club thisClub;
  final Color clubColor;
  final String Function(DateTime) timeAgo;

  const _CollaborationsTab({
    required this.taggedPosts,
    required this.partnerClubs,
    required this.thisClub,
    required this.clubColor,
    required this.timeAgo,
  });

  static const List<Color> _colors = [
    Color(0xFF8C1D40),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
  ];

  @override
  Widget build(BuildContext context) {
    final cardColor = _clubPageCard(context);
    final borderColor = _clubPageBorder(context);
    final strongBorderColor = _clubPageStrongBorder(context);
    final isEmpty = taggedPosts.isEmpty && partnerClubs.isEmpty;

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      children: [
        if (isEmpty)
          Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text(
                'No collaborations yet.\nPosts that tag this club with @ will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.secondaryText, height: 1.6),
              ),
            ),
          ),

        // ── Partner clubs ──
        if (partnerClubs.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'PARTNER CLUBS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          ...partnerClubs.map((club) {
            final color = _colors[clubs.indexOf(club) % _colors.length];
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClubProfileScreen(club: club, color: color),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: cardColor,
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      ClubAvatar(
                        clubId: club.id,
                        clubName: club.name,
                        color: color,
                        size: 48,
                        fontSize: 20,
                        borderRadius: 14,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              club.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${clubMemberCount(club.id)} members',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: strongBorderColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'View ›',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
        ],

        // ── Tagged posts ──
        if (taggedPosts.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'POSTS FEATURING THIS CLUB',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          ...taggedPosts.map((post) {
            final authorClub = clubs.firstWhere(
              (c) => c.id == post.clubId,
              orElse: () => clubs.first,
            );
            final color = _colors[clubs.indexOf(authorClub) % _colors.length];
            final commentCount = comments
                .where((c) => c.postId == post.id)
                .length;
            final likeCount = postLikeCount(post.id as String);

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PostDetailScreen(post: post, clubColor: color),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                decoration: BoxDecoration(
                  color: cardColor,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.hardEdge,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                      child: Row(
                        children: [
                          ClubAvatar(
                            clubId: authorClub.id,
                            clubName: authorClub.name,
                            color: color,
                            size: 36,
                            fontSize: 15,
                            borderRadius: 10,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authorClub.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.text,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  timeAgo(post.createdAt as DateTime),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Collab badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: clubColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.handshake_outlined,
                                  size: 12,
                                  color: clubColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Collab',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: clubColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Banner
                    buildPostBanner(
                      imagePath: post.imagePath as String?,
                      fallbackColor: color,
                      fallbackLetter: authorClub.name[0],
                      height: 140,
                    ),
                    // Stats
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.favorite, size: 14, color: Colors.pink),
                          const SizedBox(width: 4),
                          Text(
                            '$likeCount',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 14,
                            color: AppColors.secondaryText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$commentCount',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

// ─── Sticky tab bar delegate ──────────────────────────────────────────────────

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;
  final double height;
  const _StickyTabBarDelegate(
    this.tabBar, {
    required this.backgroundColor,
    this.height = 0,
  });

  double get _h => height > 0 ? height : tabBar.preferredSize.height;

  @override
  double get minExtent => _h;
  @override
  double get maxExtent => _h;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: backgroundColor,
      child: SizedBox(
        height: _h,
        child: Center(child: tabBar),
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate old) => false;
}

// ─── Board Management Sheet ───────────────────────────────────────────────────

class _BoardManagementSheet extends StatefulWidget {
  final Club club;
  const _BoardManagementSheet({required this.club});

  @override
  State<_BoardManagementSheet> createState() => _BoardManagementSheetState();
}

class _BoardManagementSheetState extends State<_BoardManagementSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  List get _matchedUsers {
    if (_query.trim().isEmpty) return [];
    final q = _query.trim().toLowerCase();
    return users
        .where(
          (u) =>
              u.name.toLowerCase().contains(q) &&
              !widget.club.boardMemberIds.contains(u.id),
        )
        .toList();
  }

  List get _currentBoardMembers =>
      users.where((u) => widget.club.boardMemberIds.contains(u.id)).toList();

  void _addMember(String userId) {
    setState(() {
      if (!widget.club.boardMemberIds.contains(userId)) {
        widget.club.boardMemberIds.add(userId);
      }
      _searchController.clear();
      _query = '';
    });
    contentStore.saveBoardMemberIds();
  }

  Future<void> _editTitleInSheet(dynamic u) async {
    final current = widget.club.boardMemberTitles[u.id] ?? '';
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Set title for ${u.name}',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          style: TextStyle(color: AppColors.text),
          decoration: InputDecoration(
            hintText: 'e.g. President, Secretary…',
            hintStyle: TextStyle(color: AppColors.secondaryText),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          if (current.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: Text(
                'Remove title',
                style: TextStyle(color: AppColors.primaryRed),
              ),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    setState(() {
      if (result.isEmpty) {
        widget.club.boardMemberTitles.remove(u.id);
      } else {
        widget.club.boardMemberTitles[u.id] = result;
      }
    });
    contentStore.saveBoardMemberTitles();
  }

  Future<void> _removeMember(dynamic u) async {
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Remove Board Member',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to remove ${u.name} from the board?',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Remove',
              style: TextStyle(color: AppColors.primaryRed),
            ),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;

    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Confirm Removal',
          style: TextStyle(
            color: AppColors.primaryRed,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will permanently remove ${u.name} from the board of ${widget.club.name}. Continue?',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yes, Remove'),
          ),
        ],
      ),
    );
    if (second != true || !mounted) return;

    setState(() => widget.club.boardMemberIds.remove(u.id));
    contentStore.saveBoardMemberIds();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boardMembers = _currentBoardMembers;
    final matches = _matchedUsers;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle + title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.manage_accounts_outlined,
                        color: AppColors.primaryRed,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Manage Board Members',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Members added here are added instantly, no confirmation needed.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Search field
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(fontSize: 14, color: AppColors.text),
                    decoration: InputDecoration(
                      hintText: 'Search users by name...',
                      hintStyle: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.secondaryText,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),

            Divider(height: 1),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Search results
                  if (matches.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'Add to Board',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondaryText,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    ...matches.map(
                      (u) => ListTile(
                        leading: UserAvatar(
                          userId: u.id,
                          name: u.name,
                          size: 40,
                          fontSize: 16,
                          backgroundColor: AppColors.lightRed,
                          textColor: AppColors.primaryRed,
                        ),
                        title: Text(
                          u.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        subtitle: Text(
                          u.email,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: () => _addMember(u.id),
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.lightRed,
                            foregroundColor: AppColors.primaryRed,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Add',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    Divider(height: 16),
                  ],

                  // Current board members
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Text(
                      boardMembers.isEmpty
                          ? 'No board members yet'
                          : 'Current Board Members (${boardMembers.length})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondaryText,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  if (boardMembers.isEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Text(
                        'Search for a user above to add them to the board.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    )
                  else
                    ...boardMembers.map(
                      (u) => ListTile(
                        leading: UserAvatar(
                          userId: u.id,
                          name: u.name,
                          size: 40,
                          fontSize: 16,
                          backgroundColor: const Color(
                            0xFF1565C0,
                          ).withValues(alpha: 0.12),
                          textColor: const Color(0xFF1565C0),
                        ),
                        title: Text(
                          u.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.club.boardMemberTitles[u.id]?.isNotEmpty ==
                                      true
                                  ? widget.club.boardMemberTitles[u.id]!
                                  : 'No title set',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    widget
                                            .club
                                            .boardMemberTitles[u.id]
                                            ?.isNotEmpty ==
                                        true
                                    ? const Color(0xFF1565C0)
                                    : AppColors.secondaryText,
                                fontWeight:
                                    widget
                                            .club
                                            .boardMemberTitles[u.id]
                                            ?.isNotEmpty ==
                                        true
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            Text(
                              u.email,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.edit_outlined,
                                color: Color(0xFF1565C0),
                                size: 20,
                              ),
                              tooltip: 'Set title',
                              onPressed: () => _editTitleInSheet(u),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: AppColors.secondaryText,
                                size: 22,
                              ),
                              tooltip: 'Remove from board',
                              onPressed: () => _removeMember(u),
                            ),
                          ],
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

// ─── Board Tab ────────────────────────────────────────────────────────────────

class _BoardTab extends StatefulWidget {
  final Club club;
  const _BoardTab({required this.club});

  @override
  State<_BoardTab> createState() => _BoardTabState();
}

class _BoardTabState extends State<_BoardTab> {
  // Only the club's own admin can approve/decline requests, add/remove members,
  // or assign titles. Board members and external users have no write access.
  bool get _isClubAdmin {
    final adminId = authService.currentAdmin?.id ?? '';
    final userId = authService.currentUser?.id ?? '';
    return widget.club.adminUserIds.contains(adminId) ||
        widget.club.adminUserIds.contains(userId);
  }

  Future<void> _editTitle(dynamic u) async {
    final current = widget.club.boardMemberTitles[u.id] ?? '';
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Set title for ${u.name}',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          style: TextStyle(color: AppColors.text),
          decoration: InputDecoration(
            hintText: 'e.g. President, Secretary…',
            hintStyle: TextStyle(color: AppColors.secondaryText),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          if (current.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: Text(
                'Remove title',
                style: TextStyle(color: AppColors.primaryRed),
              ),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    setState(() {
      if (result.isEmpty) {
        widget.club.boardMemberTitles.remove(u.id);
      } else {
        widget.club.boardMemberTitles[u.id] = result;
      }
    });
    contentStore.saveBoardMemberTitles();
  }

  List<BoardMemberRequest> get _pendingRequests => boardMemberRequests
      .where((r) => r.clubId == widget.club.id && r.status == 'pending')
      .toList();

  void _approve(BoardMemberRequest req) {
    setState(() {
      if (!widget.club.boardMemberIds.contains(req.userId)) {
        widget.club.boardMemberIds.add(req.userId);
      }
      userState.pendingBoardRequests.remove('${req.userId}:${req.clubId}');
      req.status = 'approved';
    });

    contentStore.saveBoardMemberRequests();
    contentStore.saveBoardMemberIds();
    userPrefsService.removeBoardRequest(req.userId, req.clubId);

    userState.addMessageNotification(
      AppNotification(
        id: 'board_approved_${req.userId}_${req.clubId}_${DateTime.now().millisecondsSinceEpoch}',
        userId: req.userId,
        message:
            'Your board member request for ${widget.club.name} was approved!',
        createdAt: DateTime.now(),
        targetType: 'club',
        targetId: req.clubId,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${req.userName} approved as board member.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );
  }

  void _decline(BoardMemberRequest req) {
    setState(() {
      userState.pendingBoardRequests.remove('${req.userId}:${req.clubId}');
      req.status = 'declined';
    });

    contentStore.saveBoardMemberRequests();
    userPrefsService.removeBoardRequest(req.userId, req.clubId);

    userState.addMessageNotification(
      AppNotification(
        id: 'board_declined_${req.userId}_${req.clubId}_${DateTime.now().millisecondsSinceEpoch}',
        userId: req.userId,
        message:
            'Your board member request for ${widget.club.name} was declined. You may reapply at any time.',
        createdAt: DateTime.now(),
        targetType: 'club',
        targetId: req.clubId,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${req.userName}\'s request was declined.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmRemove(dynamic u) async {
    // First confirmation
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Remove Board Member',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to remove ${u.name} from the board?',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Remove',
              style: TextStyle(color: AppColors.primaryRed),
            ),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;

    // Second confirmation
    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Confirm Removal',
          style: TextStyle(
            color: AppColors.primaryRed,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will permanently remove ${u.name} from the board of ${widget.club.name}. Continue?',
          style: TextStyle(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yes, Remove'),
          ),
        ],
      ),
    );
    if (second != true || !mounted) return;

    setState(() => widget.club.boardMemberIds.remove(u.id));
    contentStore.saveBoardMemberIds();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${u.name} removed from the board.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final members = users
        .where((u) => widget.club.boardMemberIds.contains(u.id))
        .toList();
    final pending = _pendingRequests;
    final authorized = _isClubAdmin;
    final cardColor = _clubPageCard(context);
    final borderColor = _clubPageBorder(context);
    final panelText = AppColors.text;
    final mutedText = AppColors.secondaryText;

    // Request-to-join button state for regular users
    final currentUser = authService.currentUser;
    final isAlreadyMember =
        currentUser != null &&
        widget.club.boardMemberIds.contains(currentUser.id);
    final hasPendingRequest =
        currentUser != null &&
        userState.hasPendingBoardRequest(currentUser.id, widget.club.id);

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        // ── Pending Requests (admin/board only) ───────────────────────────────
        if (authorized && pending.isNotEmpty) ...[
          Container(
            color: cardColor,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.pending_actions_outlined,
                  color: Color(0xFFF57C00),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pending Requests',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: panelText,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1EF57C00),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${pending.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF57C00),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...pending.map((req) {
            final requester = users
                .where((u) => u.id == req.userId)
                .firstOrNull;
            return Container(
              color: cardColor,
              margin: const EdgeInsets.only(bottom: 1),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  UserAvatar(
                    userId: req.userId,
                    name: req.userName,
                    size: 44,
                    fontSize: 18,
                    backgroundColor: const Color(0xFFFFF3E0),
                    textColor: const Color(0xFFF57C00),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: requester == null
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    UserProfileScreen(user: requester),
                              ),
                            ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.userName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: panelText,
                            ),
                          ),
                          Text(
                            req.userEmail,
                            style: TextStyle(fontSize: 12, color: mutedText),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Requested ${_timeAgoFromDate(req.requestedAt)}',
                            style: TextStyle(fontSize: 11, color: mutedText),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Decline
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.primaryRed,
                      size: 22,
                    ),
                    tooltip: 'Decline',
                    onPressed: () => _decline(req),
                  ),
                  // Approve
                  IconButton(
                    icon: Icon(
                      Icons.check_rounded,
                      color: Color(0xFF2E7D32),
                      size: 22,
                    ),
                    tooltip: 'Approve',
                    onPressed: () => _approve(req),
                  ),
                ],
              ),
            );
          }),
          Divider(height: 1),
          const SizedBox(height: 8),
        ],

        // ── Board Members header ───────────────────────────────────────────────
        Container(
          width: double.infinity,
          color: cardColor,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                color: Color(0xFF1565C0),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Board Members',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: panelText,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x1E1565C0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${members.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: borderColor),

        // ── Board Members list ─────────────────────────────────────────────────
        if (members.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 48, color: mutedText),
                SizedBox(height: 12),
                Text(
                  'No board members yet.',
                  style: TextStyle(fontSize: 15, color: mutedText),
                ),
                SizedBox(height: 6),
                Text(
                  'Approved requests will appear here.',
                  style: TextStyle(fontSize: 12, color: mutedText),
                ),
              ],
            ),
          )
        else
          ...members.map((u) {
            final title = widget.club.boardMemberTitles[u.id];
            final isAdmin = _isClubAdmin;
            return Column(
              children: [
                ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(user: u),
                    ),
                  ),
                  leading: UserAvatar(
                    userId: u.id,
                    name: u.name,
                    size: 44,
                    fontSize: 18,
                    backgroundColor: const Color(
                      0xFF1565C0,
                    ).withValues(alpha: 0.12),
                    textColor: const Color(0xFF1565C0),
                  ),
                  title: Text(
                    u.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: panelText,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null && title.isNotEmpty)
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        Text(
                          'Board Member',
                          style: TextStyle(fontSize: 12, color: mutedText),
                        ),
                      Text(
                        u.email,
                        style: TextStyle(fontSize: 11, color: mutedText),
                      ),
                    ],
                  ),
                  trailing: authorized
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isAdmin)
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: Color(0xFF1565C0),
                                  size: 20,
                                ),
                                tooltip: 'Set title',
                                onPressed: () => _editTitle(u),
                              ),
                            IconButton(
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: mutedText,
                                size: 22,
                              ),
                              tooltip: 'Remove from board',
                              onPressed: () => _confirmRemove(u),
                            ),
                          ],
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x1E1565C0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Board',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                        ),
                ),
                Divider(height: 1, indent: 72, color: borderColor),
              ],
            );
          }),

        // ── Request to Join Board (regular users only) ────────────────────────
        if (!authorized && currentUser != null && !isAlreadyMember)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: GestureDetector(
              onTap: hasPendingRequest ? null : _requestJoinBoard,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: hasPendingRequest
                      ? Colors.transparent
                      : AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasPendingRequest
                        ? AppColors.divider
                        : AppColors.primaryRed,
                  ),
                ),
                child: Text(
                  hasPendingRequest ? 'Request Sent' : 'Request to Join Board',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: hasPendingRequest ? mutedText : Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _requestJoinBoard() {
    final currentUser = authService.currentUser;
    if (currentUser == null) return;

    final req = BoardMemberRequest(
      id: 'req_${currentUser.id}_${widget.club.id}_${DateTime.now().millisecondsSinceEpoch}',
      userId: currentUser.id,
      userName: currentUser.name,
      userEmail: currentUser.email,
      clubId: widget.club.id,
      requestedAt: DateTime.now(),
    );
    setState(() {
      boardMemberRequests.add(req);
      userState.sendBoardRequest(currentUser.id, widget.club.id);
    });
    contentStore.saveBoardMemberRequests();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Board membership request sent!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF2E7D32),
      ),
    );
  }

  String _timeAgoFromDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─── Stat cell ────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final bool dark;
  const _StatCell({
    required this.value,
    required this.label,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: dark
                ? AppColors.secondaryText.withValues(alpha: 0.9)
                : AppColors.secondaryText,
          ),
        ),
      ],
    );
  }
}

// ─── Icon tab (icon + label) ──────────────────────────────────────────────────

class _IconTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _IconTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

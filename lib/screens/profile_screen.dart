import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/club_avatar.dart';
import '../models/club.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/content_store.dart';
import '../services/mock_data.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import '../widgets/user_avatar.dart';
import 'club_profile_screen.dart';
import 'event_detail_screen.dart';
import 'rsvp_list_screen.dart';
import 'post_detail_screen.dart';
import 'settings_screen.dart';
import 'user_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  const ProfileScreen({super.key, this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const List<Color> _clubColors = [
    Color(0xFFB41C18),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
  ];

  Color _clubColor(int index) => _clubColors[index % _clubColors.length];

  int _contentTab = 0; // 0 = Posts, 1 = Stories, 2 = Events
  static const List<String> _yearOptions = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    '5th Year',
    'Graduate',
  ];

  Widget _initialAvatar(String name) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryRed.withValues(alpha: 0.18),
        ),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryRed,
            ),
          ),
        ),
      );

  Future<void> _pickProfilePhoto(String userId, ImageSource source) async {
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
        backgroundColor: AppColors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Use this photo?',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(File(cropped.path), fit: BoxFit.cover),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Use Photo'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Copy from temp dir to permanent app documents dir so the file
      // survives app restarts (temp files are cleared by the OS).
      final docsDir = await getApplicationDocumentsDirectory();
      final ext = cropped.path.contains('.')
          ? cropped.path.substring(cropped.path.lastIndexOf('.'))
          : '.jpg';
      final permanentPath =
          '${docsDir.path}/profile_$userId$ext';
      await File(cropped.path).copy(permanentPath);

      if (!mounted) return;
      userState.setProfilePhoto(userId, permanentPath);
      userPrefsService.save(userId);
      setState(() {});
    }
  }

  Future<void> _editMajorAndYear(BuildContext context, String userId) async {
    final majorController = TextEditingController(
      text: userState.majors[userId] ?? '',
    );
    var selectedYear = userState.years[userId];

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppColors.surfaceAlt,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Major & Year',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: majorController,
                maxLength: 48,
                style: TextStyle(color: AppColors.text),
                decoration: InputDecoration(
                  labelText: 'Major',
                  hintText: 'e.g. Business Administration',
                  hintStyle: TextStyle(color: AppColors.secondaryText),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedYear != null && selectedYear!.isNotEmpty
                    ? selectedYear
                    : null,
                dropdownColor: AppColors.card,
                decoration: const InputDecoration(
                  labelText: 'Year',
                ),
                items: _yearOptions
                    .map(
                      (year) => DropdownMenuItem<String>(
                        value: year,
                        child: Text(
                          year,
                          style: TextStyle(color: AppColors.text),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setModalState(() => selectedYear = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                userState.setMajor(userId, majorController.text);
                userState.setYear(userId, selectedYear ?? '');
                await userPrefsService.save(userId);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    majorController.dispose();
  }

  Future<void> _editBio(BuildContext context, String userId) async {
    final bioController = TextEditingController(text: userState.bios[userId] ?? '');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Bio',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        content: TextField(
          controller: bioController,
          maxLength: 80,
          maxLines: 3,
          style: TextStyle(color: AppColors.text),
          decoration: InputDecoration(
            hintText: 'Tell people a little about yourself',
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
          ElevatedButton(
            onPressed: () async {
              userState.setBio(userId, bioController.text);
              await userPrefsService.save(userId);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    bioController.dispose();
  }

  List<User> _followersForUser(String userId) {
    return users
        .where((user) => user.id != userId && user.followingUserIds.contains(userId))
        .toList();
  }

  List<User> _followingUsers() {
    return users
        .where((user) => userState.followedUserIds.contains(user.id))
        .toList();
  }

  void _showFollowersSheet(List<User> followers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.72,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.people_alt_outlined,
                      size: 18, color: AppColors.primaryRed),
                  const SizedBox(width: 8),
                  Text(
                    'Followers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${followers.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: followers.isEmpty
                    ? Center(
                        child: Text(
                          'No followers yet.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: followers.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: AppColors.divider),
                        itemBuilder: (_, index) {
                          final follower = followers[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 0, vertical: 4),
                            leading: UserAvatar(
                              userId: follower.id,
                              name: follower.name,
                              size: 42,
                              fontSize: 18,
                            ),
                            title: Text(
                              userState.displayNameFor(
                                  follower.id, follower.name),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                            subtitle: userState.usernameFor(follower.id) != null
                                ? Text(
                                    follower.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryText,
                                    ),
                                  )
                                : null,
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.secondaryText,
                            ),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      UserProfileScreen(user: follower),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFollowingSheet(List<User> following) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.72,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.person_add_alt_1_outlined,
                      size: 18, color: AppColors.primaryRed),
                  const SizedBox(width: 8),
                  Text(
                    'Following',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${following.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: following.isEmpty
                    ? Center(
                        child: Text(
                          'Not following anyone yet.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: following.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: AppColors.divider),
                        itemBuilder: (_, index) {
                          final person = following[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 0, vertical: 4),
                            leading: UserAvatar(
                              userId: person.id,
                              name: person.name,
                              size: 42,
                              fontSize: 18,
                            ),
                            title: Text(
                              userState.displayNameFor(person.id, person.name),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                            subtitle: userState.usernameFor(person.id) != null
                                ? Text(
                                    person.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryText,
                                    ),
                                  )
                                : null,
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.secondaryText,
                            ),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      UserProfileScreen(user: person),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfilePhotoOptions(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Change Profile Photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: AppColors.primaryRed.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.camera_alt_outlined, color: AppColors.primaryRed),
              ),
              title: Text('Take a Photo', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
              subtitle: Text('Use your camera right now', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
              onTap: () {
                Navigator.pop(context);
                _pickProfilePhoto(userId, ImageSource.camera);
              },
            ),
            Divider(height: 1, indent: 16, color: AppColors.divider),
            ListTile(
              leading: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: AppColors.primaryRed.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.photo_library_outlined, color: AppColors.primaryRed),
              ),
              title: Text('Choose from Library', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
              subtitle: Text('Pick from your photo library', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
              onTap: () {
                Navigator.pop(context);
                _pickProfilePhoto(userId, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    final admin = authService.currentAdmin;
    final myId = user?.id ?? admin?.id ?? '';
    final realName = user?.name ?? admin?.name ?? 'Guest';
    final displayName = userState.displayNameFor(myId, realName);
    final isAdmin = admin != null;

    final myClubs = isAdmin
        ? clubs
        : clubs
            .where((c) => userState.isFollowing(c.id))
            .toList();

    final myEventCount = events
        .where((e) => myClubs.any((c) => c.id == e.clubId))
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) setState(() {});
        },
        color: AppColors.primaryRed,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(context, displayName),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListenableBuilder(
                  listenable: userState,
                  builder: (context, _) => _buildProfileHeader(
                    displayName,
                    realName,
                    isAdmin,
                    myClubs.length,
                    myEventCount,
                  ),
                ),
                Divider(height: 1, color: AppColors.divider),
                _buildMyClubsSection(myClubs),
                if (isAdmin)
                  _buildMyContentSection(admin.id),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, String name) {
    return SliverAppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.text,
      pinned: true,
      title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.text)),
      actions: [
        IconButton(
          icon: Icon(Icons.settings_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SettingsScreen(onLogout: widget.onLogout ?? () {}),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(
    String displayName,
    String realName,
    bool isAdmin,
    int clubCount,
    int eventCount,
  ) {
    final name = displayName;
    final myId = authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    final isSuperAdmin = isAdmin && authService.currentAdmin?.id == 'admin1';

    final followers = !isAdmin ? _followersForUser(myId) : const <User>[];
    final following = !isAdmin ? _followingUsers() : const <User>[];

    // Stats for club admins: posts, events, board members
    final Club? managedClub = isAdmin
        ? clubs.cast<Club?>().firstWhere(
            (c) => c!.adminUserIds.contains(myId), orElse: () => null)
        : null;
    final int postCount = managedClub != null
        ? newsPosts.where((p) => p.clubId == managedClub.id).length
        : 0;
    final int boardMemberCount = managedClub?.boardMemberIds.length ?? 0;
    if (isAdmin) {
      return _buildAdminProfileHeader(
        name: name,
        realName: realName,
        isSuperAdmin: isSuperAdmin,
        managedClub: managedClub,
        myId: myId,
        postCount: postCount,
        eventCount: eventCount,
        boardMemberCount: boardMemberCount,
      );
    }

    return _buildStudentProfileHeader(
      name: name,
      realName: realName,
      userId: myId,
      clubCount: clubCount,
      followers: followers,
      following: following,
    );
  }

  Widget _buildAdminProfileHeader({
    required String name,
    required String realName,
    required bool isSuperAdmin,
    required Club? managedClub,
    required String myId,
    required int postCount,
    required int eventCount,
    required int boardMemberCount,
  }) {
    return Container(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _showProfilePhotoOptions(context, myId),
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppColors.primaryRed, AppColors.accentGold],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.background,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: () {
                            final photoPath = userState.profilePhotoPaths[myId];
                            final file = photoPath != null ? File(photoPath) : null;
                            if (file != null && file.existsSync()) {
                              return ClipOval(
                                child: Image.file(
                                  file,
                                  fit: BoxFit.cover,
                                  width: 88,
                                  height: 88,
                                  errorBuilder: (ctx, e, st) => _initialAvatar(name),
                                ),
                              );
                            }
                            return _initialAvatar(name);
                          }(),
                        ),
                      ),
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.background, width: 2.5),
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatCell(value: '$postCount', label: 'Posts'),
                      _StatCell(value: '$eventCount', label: 'Events'),
                      _StatCell(value: '$boardMemberCount', label: 'Members'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: AppColors.text,
              ),
            ),
            if (name != realName) ...[
              const SizedBox(height: 2),
              Text(
                realName,
                style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
              ),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isSuperAdmin
                      ? [const Color(0xFF6A1B9A), const Color(0xFF8E24AA)]
                      : [AppColors.primaryRed, const Color(0xFFE53935)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (isSuperAdmin
                            ? const Color(0xFF6A1B9A)
                            : AppColors.primaryRed)
                        .withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSuperAdmin
                        ? Icons.admin_panel_settings_rounded
                        : Icons.shield_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isSuperAdmin ? 'Super Admin' : 'Club Admin',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (managedClub != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '·',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      managedClub.name.split(' ').first,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentProfileHeader({
    required String name,
    required String realName,
    required String userId,
    required int clubCount,
    required List<User> followers,
    required List<User> following,
  }) {
    final major = (userState.majors[userId] ?? '').trim();
    final year = (userState.years[userId] ?? '').trim();
    final bio = (userState.bios[userId] ?? '').trim();
    final majorYearText = [if (major.isNotEmpty) major, if (year.isNotEmpty) year].join(' · ');
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _showProfilePhotoOptions(context, userId),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primaryRed, AppColors.accentGold],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.background,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: () {
                      final photoPath = userState.profilePhotoPaths[userId];
                      final file = photoPath != null ? File(photoPath) : null;
                      if (file != null && file.existsSync()) {
                        return ClipOval(
                          child: Image.file(
                            file,
                            fit: BoxFit.cover,
                            width: 96,
                            height: 96,
                            errorBuilder: (ctx, e, st) => _initialAvatar(name),
                          ),
                        );
                      }
                      return _initialAvatar(name);
                    }(),
                  ),
                ),
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 2.5),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: AppColors.text,
            ),
          ),
          if (name != realName) ...[
            const SizedBox(height: 2),
            Text(
              realName,
              style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
            ),
          ],
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _editMajorAndYear(context, userId),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.school_outlined, size: 17, color: AppColors.primaryRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      majorYearText.isEmpty ? 'Add major & year' : majorYearText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: majorYearText.isEmpty
                            ? AppColors.secondaryText
                            : AppColors.text,
                        fontStyle: majorYearText.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => _editBio(context, userId),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.edit_note_rounded, size: 18, color: AppColors.primaryRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bio.isEmpty ? 'Add a bio…' : bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: bio.isEmpty ? AppColors.secondaryText : AppColors.text,
                        fontStyle: bio.isEmpty ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildStudentStatsCard(
            clubCount: clubCount,
            followers: followers,
            following: following,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentStatsCard({
    required int clubCount,
    required List<User> followers,
    required List<User> following,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: _BigStatCell(
              icon: Icons.groups_2_rounded,
              value: '$clubCount',
              label: 'Clubs',
            ),
          ),
          Container(width: 1, height: 56, color: AppColors.divider),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showFollowersSheet(followers),
              child: _BigStatCell(
                icon: Icons.people_alt_outlined,
                value: '${followers.length}',
                label: 'Followers',
              ),
            ),
          ),
          Container(width: 1, height: 56, color: AppColors.divider),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showFollowingSheet(following),
              child: _BigStatCell(
                icon: Icons.person_add_alt_1_outlined,
                value: '${following.length}',
                label: 'Following',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyClubsSection(List myClubs) {
    final adminId = authService.currentAdmin?.id ?? '';
    final Club? managedClub = adminId.isNotEmpty
        ? clubs.cast<Club?>().firstWhere(
            (c) => c!.adminUserIds.contains(adminId),
            orElse: () => null)
        : null;
    final boardMembers = managedClub != null
        ? users.where((u) => managedClub.boardMemberIds.contains(u.id)).toList()
        : <dynamic>[];
    final pendingCount = managedClub != null
        ? boardMemberRequests
            .where((r) => r.clubId == managedClub.id && r.status == 'pending')
            .length
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── My Clubs ──────────────────────────────────────────────────────
        Container(
          color: AppColors.surfaceAlt,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              Row(
                children: [
                  Icon(Icons.groups_2_rounded,
                      size: 18, color: AppColors.primaryRed),
                  const SizedBox(width: 8),
                  Text(
                    'My Clubs',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text),
                  ),
                  if (myClubs.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${myClubs.length}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryRed),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              myClubs.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.divider, width: 1),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.explore_outlined,
                              size: 32, color: AppColors.secondaryText),
                          SizedBox(height: 8),
                          Text(
                            "You haven't followed any clubs yet.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Explore clubs and follow the ones you like.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : SizedBox(
                      height: 118,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: myClubs.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: 10),
                        itemBuilder: (ctx, i) {
                          final club = myClubs[i];
                          final color = _clubColor(i);
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) => ClubProfileScreen(
                                    club: club, color: color),
                              ),
                            ).then((_) => setState(() {})),
                            child: Container(
                              width: 90,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 8),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  ClubAvatar(
                                    clubId: club.id,
                                    clubName: club.name,
                                    color: color,
                                    size: 52,
                                    fontSize: 20,
                                    borderRadius: 14,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    club.name.split(' ').first,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.text,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ],
          ),
        ),

        // ── Board Members (club admin only) ───────────────────────────────
        if (managedClub != null) ...[
          const SizedBox(height: 8),
          Container(
            color: AppColors.surfaceAlt,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                GestureDetector(
                  onTap: () {
                    final idx = clubs.indexOf(managedClub);
                    final color = _clubColor(idx < 0 ? 0 : idx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClubProfileScreen(
                            club: managedClub, color: color),
                      ),
                    ).then((_) => setState(() {}));
                  },
                  child: Row(
                    children: [
                      Icon(Icons.shield_rounded,
                          size: 18, color: Color(0xFF1565C0)),
                      const SizedBox(width: 8),
                      Text(
                        'Board Members',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0x1A1565C0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${managedClub.boardMemberIds.length}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1565C0)),
                        ),
                      ),
                      if (pendingCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0x1AF57C00),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.pending_actions_outlined,
                                  size: 12, color: Color(0xFFF57C00)),
                              const SizedBox(width: 3),
                              Text(
                                '$pendingCount pending',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFF57C00)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.secondaryText),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (boardMembers.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 18, horizontal: 16),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0x1A1565C0).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0x281565C0), width: 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 28, color: Color(0xFF90CAF9)),
                        SizedBox(height: 6),
                        Text(
                          'No board members yet.',
                          style: TextStyle(
                              color: Color(0xFF1565C0),
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Approved requests will appear here.',
                          style: TextStyle(
                              color: Color(0xFF1565C0), fontSize: 11),
                        ),
                      ],
                    ),
                  )
                else
                  ...boardMembers.asMap().entries.map((entry) {
                    final i = entry.key;
                    final u = entry.value;
                    final title = managedClub.boardMemberTitles[u.id];
                    final hasTitle = title != null && title.isNotEmpty;
                    return Column(
                      children: [
                        if (i > 0)
                          Divider(
                              height: 1,
                              indent: 60,
                              color: AppColors.divider),
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    UserProfileScreen(user: u)),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 4),
                            child: Row(
                              children: [
                                UserAvatar(
                                  userId: u.id,
                                  name: u.name,
                                  size: 44,
                                  fontSize: 18,
                                  backgroundColor: const Color(0xFF1565C0)
                                      .withValues(alpha: 0.12),
                                  textColor: const Color(0xFF1565C0),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(u.name,
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.text)),
                                      const SizedBox(height: 2),
                                      Text(
                                        hasTitle ? title : u.email,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: hasTitle
                                                ? const Color(0xFF1565C0)
                                                : AppColors.secondaryText,
                                            fontWeight: hasTitle
                                                ? FontWeight.w600
                                                : FontWeight.normal),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0x1A1565C0),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.shield_rounded,
                                          size: 11,
                                          color: Color(0xFF1565C0)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Board',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1565C0)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── My Content section (admin only) ──────────────────────────────────────────

  Widget _buildMyContentSection(String adminId) {
    final managedClub = clubs.cast<Club?>().firstWhere(
        (c) => c!.adminUserIds.contains(adminId),
        orElse: () => null);
    if (managedClub == null) return const SizedBox.shrink();

    final clubIdx   = clubs.indexOf(managedClub);
    final clubColor = _clubColor(clubIdx < 0 ? 0 : clubIdx);

    final myPosts = newsPosts
        .where((p) => p.clubId == managedClub.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final myStories = clubStories
        .where((s) => s.clubId == managedClub.id)
        .toList()
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));

    final myEvents = events
        .where((e) => e.clubId == managedClub.id)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: AppColors.divider),
        Container(
          color: AppColors.surfaceAlt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Row(
                  children: [
                    Icon(Icons.grid_view_rounded, size: 18, color: clubColor),
                    const SizedBox(width: 8),
                    Text('My Content',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: clubColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        managedClub.name,
                        style: TextStyle(
                            fontSize: 11,
                            color: clubColor,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Tab chips ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
                  children: [
                    _ContentTabChip(
                      label: 'Posts',
                      count: myPosts.length,
                      selected: _contentTab == 0,
                      color: clubColor,
                      onTap: () => setState(() => _contentTab = 0),
                    ),
                    const SizedBox(width: 8),
                    _ContentTabChip(
                      label: 'Stories',
                      count: myStories.length,
                      selected: _contentTab == 1,
                      color: clubColor,
                      onTap: () => setState(() => _contentTab = 1),
                    ),
                    const SizedBox(width: 8),
                    _ContentTabChip(
                      label: 'Events',
                      count: myEvents.length,
                      selected: _contentTab == 2,
                      color: clubColor,
                      onTap: () => setState(() => _contentTab = 2),
                    ),
                  ],
                ),
              ),

              // ── Tab content ──
              if (_contentTab == 0) _buildPostsList(myPosts, clubColor, adminId),
              if (_contentTab == 1) _buildStoriesList(myStories, clubColor, adminId),
              if (_contentTab == 2) _buildEventsList(myEvents, clubColor, adminId),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool?> _confirmDelete(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
        content: Text(message,
            style: TextStyle(color: AppColors.secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsList(List myPosts, Color color, String adminId) {
    if (myPosts.isEmpty) {
      return const _EmptyHint(text: 'No posts yet.');
    }
    return Column(
      children: myPosts.map((p) {
        return Dismissible(
          key: ValueKey(p.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red.withValues(alpha: 0.85),
            child: Icon(Icons.delete_outline, color: Colors.white, size: 22),
          ),
          confirmDismiss: (_) => _confirmDelete('Delete post?',
              'This post will be permanently removed.'),
          onDismissed: (_) {
            final ok = contentStore.deletePost(p.id, adminId);
            if (mounted) {
              if (ok) {
                setState(() {});
              } else {
                Navigator.popUntil(context, (r) => r.isFirst);
              }
            }
          },
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostDetailScreen(post: p, clubColor: color),
                  ),
                ).then((_) => setState(() {})),
                leading: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: p.imagePath != null && p.imagePath!.startsWith('http')
                      ? Image.network(p.imagePath!, fit: BoxFit.cover,
                          errorBuilder: (ctx2, err, stack) => Center(
                            child: Text(
                              clubs.firstWhere((c) => c.id == p.clubId,
                                  orElse: () => clubs.first).name[0],
                              style: TextStyle(fontSize: 22,
                                  fontWeight: FontWeight.bold, color: color),
                            ),
                          ))
                      : p.imagePath != null
                          ? Image.file(File(p.imagePath!), fit: BoxFit.cover)
                          : Center(
                              child: Text(
                                clubs.firstWhere((c) => c.id == p.clubId,
                                    orElse: () => clubs.first).name[0],
                                style: TextStyle(fontSize: 22,
                                    fontWeight: FontWeight.bold, color: color),
                              ),
                            ),
                ),
                title: Text(
                  p.content.length > 80 ? '${p.content.substring(0, 80)}…' : p.content,
                  style: TextStyle(fontSize: 13, color: AppColors.text, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _timeAgoLabel(p.createdAt),
                  style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
                ),
                trailing: Icon(Icons.swipe_left_outlined,
                    size: 16, color: AppColors.secondaryText),
              ),
              Divider(height: 1, indent: 84, color: AppColors.divider),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStoriesList(List myStories, Color color, String adminId) {
    if (myStories.isEmpty) {
      return const _EmptyHint(text: 'No stories yet.');
    }
    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        itemCount: myStories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final s = myStories[i];
          final hasPhoto = s.imagePath != null;
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 90,
              height: 160,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background
                  GestureDetector(
                    onTap: () => _showStoryPreview(ctx, s),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasPhoto && s.imagePath!.startsWith('http'))
                          Image.network(s.imagePath!, fit: BoxFit.cover,
                              errorBuilder: (c2, e, st) => _storyGradientBox(color))
                        else if (hasPhoto)
                          Image.file(File(s.imagePath!), fit: BoxFit.cover)
                        else
                          _storyGradientBox(color),
                        // Dark scrim
                        Container(color: Colors.black.withValues(alpha: 0.25)),
                        // Text preview
                        if (s.text.isNotEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(6, 28, 6, 20),
                              child: Text(
                                s.text,
                                textAlign: TextAlign.center,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Color(s.textColorValue),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  shadows: const [
                                    Shadow(blurRadius: 4, color: Colors.black87),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        // Date chip
                        Positioned(
                          bottom: 5,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              _timeAgoLabel(s.postedAt),
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Delete button
                  Positioned(
                      top: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: () => _confirmDelete(
                          'Delete story?',
                          'This story will be permanently removed.',
                        ).then((confirmed) {
                          if (confirmed != true || !mounted) return;
                          final ok = contentStore.deleteStory(s.id, adminId);
                          if (mounted) {
                            if (ok) {
                              setState(() {});
                            } else {
                              Navigator.popUntil(context, (r) => r.isFirst);
                            }
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.delete_outline,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _storyGradientBox(Color color) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.8),
              color.withValues(alpha: 0.4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );

  void _showStoryPreview(BuildContext context, dynamic story) {
    final hasPhoto = story.imagePath != null;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            height: MediaQuery.of(ctx).size.height * 0.72,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF1a1a2e),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasPhoto && (story.imagePath as String).startsWith('http'))
                  Image.network(story.imagePath as String, fit: BoxFit.cover,
                      errorBuilder: (c2, e, st) => _storyGradientBox(AppColors.primaryRed))
                else if (hasPhoto)
                  Image.file(File(story.imagePath as String), fit: BoxFit.cover)
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1a1a2e), Color(0xFF0f3460)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                Container(color: Colors.black.withValues(alpha: 0.2)),
                if ((story.text as String).isNotEmpty)
                  Align(
                    alignment: Alignment(
                      ((story.textOffsetX as double) - 0.5) * 2,
                      ((story.textOffsetY as double) - 0.5) * 2,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        story.text as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(story.textColorValue as int),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(blurRadius: 6, color: Colors.black87),
                            Shadow(blurRadius: 12, color: Colors.black54),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Close hint
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
                // Time label
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      _timeAgoLabel(story.postedAt as DateTime),
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventsList(List myEvents, Color color, String adminId) {
    if (myEvents.isEmpty) {
      return const _EmptyHint(text: 'No events yet.');
    }
    return Column(
      children: myEvents.map((e) {
        final now      = DateTime.now();
        final isLive   = e.dateTime.isBefore(now) && e.endTime.isAfter(now);
        final isPast   = e.endTime.isBefore(now);
        final diff     = e.dateTime.difference(now);

        String statusLabel;
        Color  statusColor;
        if (isLive) {
          statusLabel = 'Live';
          statusColor = Colors.green;
        } else if (isPast) {
          statusLabel = 'Ended';
          statusColor = AppColors.secondaryText;
        } else if (diff.inDays == 0) {
          statusLabel = 'Today';
          statusColor = Colors.orange;
        } else if (diff.inDays == 1) {
          statusLabel = 'Tomorrow';
          statusColor = color;
        } else {
          statusLabel = 'In ${diff.inDays}d';
          statusColor = color;
        }

        return Dismissible(
          key: ValueKey(e.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red.withValues(alpha: 0.85),
            child: Icon(Icons.delete_outline, color: Colors.white, size: 22),
          ),
          confirmDismiss: (_) => _confirmDelete(
            'Delete event?',
            'This event will be permanently removed.',
          ),
          onDismissed: (_) {
            final ok = contentStore.deleteEvent(e.id, adminId);
            if (mounted) {
              if (ok) {
                setState(() {});
              } else {
                Navigator.popUntil(context, (r) => r.isFirst);
              }
            }
          },
          child: Column(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventDetailScreen(event: e, color: color),
                  ),
                ).then((_) => setState(() {})),
                leading: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${e.dateTime.day}',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color),
                      ),
                      Text(
                        _monthAbbr(e.dateTime.month),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color),
                      ),
                    ],
                  ),
                ),
                title: Text(
                  e.title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  e.location,
                  style: TextStyle(
                      fontSize: 11, color: AppColors.secondaryText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.swipe_left_outlined,
                        size: 14, color: AppColors.secondaryText),
                  ],
                ),
              ),
              // View RSVPs link — only visible to the owning club admin
              Padding(
                padding: const EdgeInsets.only(left: 84, right: 16, bottom: 8),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RsvpListScreen(event: e, color: color),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people_outline, size: 14, color: color),
                      const SizedBox(width: 4),
                      Text(
                        '${e.attendeeUserIds.length} attending · View RSVPs',
                        style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right, size: 14, color: color),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, indent: 84, color: AppColors.divider),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _timeAgoLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative) {
      final ahead = dt.difference(DateTime.now());
      if (ahead.inDays > 0) return 'in ${ahead.inDays}d';
      if (ahead.inHours > 0) return 'in ${ahead.inHours}h';
      return 'soon';
    }
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[dt.month - 1]} ${dt.day}';
  }

  String _monthAbbr(int m) =>
      ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
}

class _ContentTabChip extends StatelessWidget {
  final String   label;
  final int      count;
  final bool     selected;
  final Color    color;
  final VoidCallback onTap;

  const _ContentTabChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.secondaryText,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppColors.lightRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : AppColors.secondaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Center(
        child: Text(
          text,
          style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
      ],
    );
  }
}

class _BigStatCell extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _BigStatCell({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryRed),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }
}


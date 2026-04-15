import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../models/club.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import '../widgets/user_avatar.dart';
import 'club_profile_screen.dart';
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
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Use this photo?',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(File(cropped.path), fit: BoxFit.cover),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Use Photo'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => userState.profilePhotoPaths[userId] = cropped.path);
      userPrefsService.save(userId);
    }
  }

  void _showProfilePhotoOptions(BuildContext context, String userId) {
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
            const Text('Change Profile Photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: AppColors.lightRed, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.camera_alt_outlined, color: AppColors.primaryRed),
              ),
              title: const Text('Take a Photo', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
              subtitle: const Text('Use your camera right now', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
              onTap: () {
                Navigator.pop(context);
                _pickProfilePhoto(userId, ImageSource.camera);
              },
            ),
            const Divider(height: 1, indent: 16),
            ListTile(
              leading: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: AppColors.lightRed, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.photo_library_outlined, color: AppColors.primaryRed),
              ),
              title: const Text('Choose from Library', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
              subtitle: const Text('Pick from your photo library', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
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

    final displayName = user?.name ?? admin?.name ?? 'Guest';
    final displayEmail = user?.email ?? admin?.email ?? '';
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
                _buildProfileHeader(displayName, displayEmail, isAdmin, myClubs.length, myEventCount),
                const Divider(height: 1),
                _buildMyClubsSection(myClubs),
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
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
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
    String name,
    String email,
    bool isAdmin,
    int clubCount,
    int eventCount,
  ) {
    final myId = authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

    return Container(
      color: AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar + stats ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showProfilePhotoOptions(context, myId),
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [AppColors.primaryRed, AppColors.accentGold],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.card,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: () {
                                final photoPath = userState.profilePhotoPaths[myId];
                                if (photoPath != null) {
                                  return ClipOval(
                                    child: Image.file(
                                      File(photoPath),
                                      fit: BoxFit.cover,
                                      width: 76,
                                      height: 76,
                                    ),
                                  );
                                }
                                return Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.lightRed,
                                  ),
                                  child: Center(
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryRed,
                                      ),
                                    ),
                                  ),
                                );
                              }(),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: AppColors.primaryRed,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.card, width: 2),
                              ),
                              child: const Icon(Icons.add, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatCell(value: '$clubCount', label: 'Clubs'),
                          _StatCell(value: '$eventCount', label: 'Events'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text)),
                const SizedBox(height: 2),
                Text(email,
                    style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                if (isAdmin) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.lightRed,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Super Admin',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryRed,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],

                // Board role badge — only for regular users who are board members.
                if (!isAdmin) Builder(builder: (_) {
                  final userId = authService.currentUser?.id ?? '';
                  if (userId.isEmpty) return const SizedBox.shrink();
                  final boardClub = clubs.cast<Club?>().firstWhere(
                      (c) => c!.boardMemberIds.contains(userId),
                      orElse: () => null);
                  if (boardClub == null) return const SizedBox.shrink();
                  final title = boardClub.boardMemberTitles[userId];
                  final hasTitle = title != null && title.isNotEmpty;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClubProfileScreen(
                            club: boardClub,
                            color: _clubColor(clubs.indexOf(boardClub)),
                          ),
                        ),
                      ).then((_) => setState(() {})),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1565C0).withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shield_rounded,
                                    size: 14, color: Colors.white),
                                const SizedBox(width: 5),
                                Text(
                                  hasTitle
                                      ? title
                                      : 'Board Member',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2),
                                ),
                                const SizedBox(width: 6),
                                const Text('·',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w400)),
                                const SizedBox(width: 6),
                                Text(
                                  boardClub.name,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right,
                              size: 16, color: Color(0xFF1565C0)),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyClubsSection(List myClubs) {
    // Find the club this admin manages (if any) to show board members inline.
    final adminId = authService.currentAdmin?.id ?? '';
    final Club? managedClub = adminId.isNotEmpty
        ? clubs.cast<Club?>().firstWhere(
            (c) => c!.adminUserIds.contains(adminId),
            orElse: () => null)
        : null;
    final boardMembers = managedClub != null
        ? users.where((u) => managedClub.boardMemberIds.contains(u.id)).toList()
        : <dynamic>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── My Clubs ──
        Container(
          color: AppColors.card,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Clubs',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
              ),
              const SizedBox(height: 12),
              myClubs.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        "You haven't followed any clubs yet. Explore and follow clubs to see them here.",
                        style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
                      ),
                    )
                  : SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: myClubs.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 16),
                        itemBuilder: (ctx, i) {
                          final club = myClubs[i];
                          final color = _clubColor(i);
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) => ClubProfileScreen(club: club, color: color),
                              ),
                            ).then((_) => setState(() {})),
                            child: Column(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: color.withValues(alpha: 0.3)),
                                  ),
                                  child: Center(
                                    child: Text(
                                      club.name[0],
                                      style: TextStyle(
                                          fontSize: 22, fontWeight: FontWeight.bold, color: color),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    club.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: AppColors.text),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
              const SizedBox(height: 12),
            ],
          ),
        ),

        // ── Board Members (visible when this user manages a club) ──
        if (managedClub != null) ...[
          const Divider(height: 1),
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row — taps into the club's Board tab
                GestureDetector(
                  onTap: () {
                    final idx = clubs.indexOf(managedClub);
                    final color = _clubColor(idx < 0 ? 0 : idx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ClubProfileScreen(club: managedClub, color: color),
                      ),
                    ).then((_) => setState(() {}));
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          size: 18, color: Color(0xFF1565C0)),
                      const SizedBox(width: 8),
                      const Text(
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
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${managedClub.boardMemberIds.length}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1565C0)),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.secondaryText),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (boardMembers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'No board members yet. Approved requests will appear here.',
                      style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
                    ),
                  )
                else
                  ...boardMembers.map((u) => Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => UserProfileScreen(user: u)),
                            ),
                            leading: UserAvatar(
                              userId: u.id,
                              name: u.name,
                              size: 44,
                              fontSize: 18,
                              backgroundColor:
                                  const Color(0xFF1565C0).withValues(alpha: 0.12),
                              textColor: const Color(0xFF1565C0),
                            ),
                            title: Text(u.name,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text)),
                            subtitle: Text(u.email,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondaryText)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Board',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1565C0)),
                              ),
                            ),
                          ),
                          const Divider(height: 1, indent: 60),
                        ],
                      )),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ],
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
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
      ],
    );
  }
}

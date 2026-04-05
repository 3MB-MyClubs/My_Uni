import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import 'settings_screen.dart';

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

    final myId = user?.id ?? admin?.id ?? '';

    final myAuthoredPosts = newsPosts
        .where((p) => p.authorId == myId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final myPostCount = myAuthoredPosts.length;

    final myEventCount = events
        .where((e) => myClubs.any((c) => c.id == e.clubId))
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, displayName),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileHeader(displayName, displayEmail, isAdmin, myClubs.length, myPostCount, myEventCount),
                const Divider(height: 1),
                _buildMyClubsSection(myClubs),
                const Divider(height: 1),
                _buildMyPostsSection(myAuthoredPosts),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
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
    int postCount,
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
                          _StatCell(value: '$postCount', label: 'Posts'),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyClubsSection(List myClubs) {
    return Container(
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
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'You haven\'t followed any clubs yet. Explore and follow clubs to see them here.',
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                  ),
                )
              : SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: myClubs.length,
                    separatorBuilder: (context, i) => const SizedBox(width: 16),
                    itemBuilder: (context, i) {
                      final club = myClubs[i];
                      final color = _clubColor(i);
                      return Column(
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
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
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
                      );
                    },
                  ),
                ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMyPostsSection(List myAuthoredPosts) {
    return Container(
      color: AppColors.card,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'My Posts',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
            ),
          ),
          if (myAuthoredPosts.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'You haven\'t posted anything yet.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
              ),
            )
          else
            ...myAuthoredPosts.map((post) {
              final club = clubs.firstWhere((c) => c.id == post.clubId);
              final likeCount = postLikeCount(post.id);
              final commentCount = comments.where((c) => c.postId == post.id).length;
              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.lightRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          club.name[0],
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryRed, fontSize: 16),
                        ),
                      ),
                    ),
                    title: Text(post.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.text)),
                    subtitle: Text(club.name, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite, size: 14, color: Colors.pink),
                        const SizedBox(width: 3),
                        Text('$likeCount', style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                        const SizedBox(width: 8),
                        const Icon(Icons.comment_outlined, size: 14, color: AppColors.secondaryText),
                        const SizedBox(width: 3),
                        Text('$commentCount', style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                      ],
                    ),
                  ),
                  const Divider(height: 1, indent: 72),
                ],
              );
            }),
        ],
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
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
      ],
    );
  }
}

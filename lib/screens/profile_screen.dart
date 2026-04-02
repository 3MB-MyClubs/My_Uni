import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
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
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar with gradient ring
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
                  child: Container(
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
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Stats row
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
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text)),
          const SizedBox(height: 2),
          Text(email, style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
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
                style: TextStyle(fontSize: 12, color: AppColors.primaryRed, fontWeight: FontWeight.w600),
              ),
            ),
          ],
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
                    title: Text(post.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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

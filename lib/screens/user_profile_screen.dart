import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/user_state.dart';

class UserProfileScreen extends StatefulWidget {
  final User user;

  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  static const List<Color> _clubColors = [
    Color(0xFF8C1D40), Color(0xFF1565C0), Color(0xFF2E7D32),
    Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00838F),
  ];

  Color _colorForClub(String clubId) {
    final idx = clubs.indexWhere((c) => c.id == clubId);
    return _clubColors[(idx < 0 ? 0 : idx) % _clubColors.length];
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  bool get _isOwnProfile {
    final myId = authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    return widget.user.id == myId;
  }

  List _subscribedClubs() {
    return widget.user.subscribedClubIds
        .map((id) => clubs.firstWhere((c) => c.id == id, orElse: () => clubs.first))
        .where((c) => widget.user.subscribedClubIds.contains(c.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final userPosts = newsPosts
        .where((p) => p.authorId == widget.user.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final subClubs = _subscribedClubs();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App bar ──
          SliverAppBar(
            backgroundColor: AppColors.card,
            surfaceTintColor: Colors.transparent,
            foregroundColor: AppColors.text,
            pinned: true,
            title: Text(
              widget.user.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Profile header ──
                _buildHeader(userPosts.length, subClubs.length),

                const Divider(height: 1),

                // ── Subscribed clubs ──
                if (subClubs.isNotEmpty) ...[
                  _buildClubsSection(subClubs),
                  const Divider(height: 1),
                ],

                // ── Posts section ──
                _buildPostsSection(userPosts),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int postCount, int clubCount) {
    final user = widget.user;
    final isFollowingUser = userState.isFollowingUser(user.id);

    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
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
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.card,
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.lightRed,
                    ),
                    child: Center(
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
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
              // Stats
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatCell(value: '$postCount', label: 'Posts'),
                    _StatCell(value: '$clubCount', label: 'Clubs'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(user.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text)),
          const SizedBox(height: 2),
          Text(user.email,
              style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
          if (user.role == 'admin') ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.lightRed,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Club Admin',
                style: TextStyle(fontSize: 12, color: AppColors.primaryRed, fontWeight: FontWeight.w600),
              ),
            ),
          ],

          // Follow button — only shown when viewing another user's profile
          if (!_isOwnProfile) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => setState(() => userState.toggleFollowUser(user.id)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isFollowingUser ? Colors.transparent : AppColors.primaryRed,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isFollowingUser
                          ? AppColors.secondaryText.withValues(alpha: 0.5)
                          : AppColors.primaryRed,
                    ),
                  ),
                  child: Text(
                    isFollowingUser ? 'Following' : 'Follow',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isFollowingUser ? AppColors.secondaryText : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClubsSection(List subClubs) {
    const List<Color> colors = [
      Color(0xFF8C1D40), Color(0xFF1565C0), Color(0xFF2E7D32),
      Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00838F),
    ];

    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Subscribed Clubs',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: subClubs.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 16),
              itemBuilder: (context, i) {
                final club = subClubs[i];
                final idx = clubs.indexOf(club);
                final color = colors[(idx < 0 ? i : idx) % colors.length];
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
                        club.name.split(' ').first,
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

  Widget _buildPostsSection(List userPosts) {
    return Container(
      color: AppColors.card,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Posts',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
            ),
          ),
          if (userPosts.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'No posts yet.',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
              ),
            )
          else
            ...userPosts.map((post) {
              final club = clubs.firstWhere((c) => c.id == post.clubId);
              final clubColor = _colorForClub(club.id);
              final likeCount = postLikeCount(post.id);
              final commentCount = comments.where((c) => c.postId == post.id).length;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Club icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: clubColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              club.name[0],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: clubColor,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Club name + time
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      club.name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primaryRed,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    _timeAgo(post.createdAt),
                                    style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              // Post content preview
                              Text(
                                post.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.secondaryText,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Engagement
                              Row(
                                children: [
                                  const Icon(Icons.favorite, size: 13, color: Colors.pink),
                                  const SizedBox(width: 3),
                                  Text('$likeCount',
                                      style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.chat_bubble_outline,
                                      size: 13, color: AppColors.secondaryText),
                                  const SizedBox(width: 3),
                                  Text('$commentCount',
                                      style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                                ],
                              ),
                            ],
                          ),
                        ),
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
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
      ],
    );
  }
}

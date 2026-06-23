import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/news_post.dart';
import '../services/app_colors.dart';
import '../services/mock_data.dart';
import '../services/auth_service.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import '../widgets/club_avatar.dart';
import 'post_detail_screen.dart';

/// Lists every post the current user has bookmarked via the save button.
/// Tapping a row opens the full post; the bookmark icon removes it.
class SavedPostsScreen extends StatelessWidget {
  const SavedPostsScreen({super.key});

  static const List<Color> _clubColors = [
    Color(0xFF8C1D40),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
  ];

  Color _clubColor(String clubId) {
    final idx = clubs.indexWhere((c) => c.id == clubId);
    return _clubColors[(idx < 0 ? 0 : idx) % _clubColors.length];
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays >= 7) return '${diff.inDays ~/ 7}w';
    if (diff.inDays >= 1) return '${diff.inDays}d';
    if (diff.inHours >= 1) return '${diff.inHours}h';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m';
    return 'now';
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = authService.currentUser != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Saved'),
        backgroundColor: AppColors.card,
      ),
      body: ListenableBuilder(
        listenable: userState,
        builder: (context, _) {
          if (!isStudent) {
            return Center(
              child: Text(
                'Saved posts are only available for students.',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            );
          }

          final saved = newsPosts.where((p) => userState.isSaved(p.id)).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (saved.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bookmark_border_rounded,
                    size: 56,
                    color: AppColors.secondaryText,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No saved posts yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      'Tap the bookmark icon on any post to keep it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: saved.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, index) {
              final post = saved[index];
              final club = clubs.cast<Club?>().firstWhere(
                (c) => c?.id == post.clubId,
                orElse: () => null,
              );
              final color = _clubColor(post.clubId);
              return _SavedPostRow(
                post: post,
                club: club,
                color: color,
                timeAgo: _timeAgo(post.createdAt),
                onOpen: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PostDetailScreen(post: post, clubColor: color),
                  ),
                ),
                onRemove: () {
                  userState.toggleSave(post.id);
                  userPrefsService.save(authService.currentUser?.id ?? '');
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SavedPostRow extends StatelessWidget {
  final NewsPost post;
  final Club? club;
  final Color color;
  final String timeAgo;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _SavedPostRow({
    required this.post,
    required this.club,
    required this.color,
    required this.timeAgo,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClubAvatar(
              clubId: club?.id ?? post.clubId,
              clubName: club?.name ?? 'Club',
              color: color,
              size: 42,
              fontSize: 16,
              shape: 'circle',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          club?.name ?? 'Campus post',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.bookmark, color: color),
              tooltip: 'Remove from saved',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

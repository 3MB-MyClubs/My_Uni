import 'package:flutter/material.dart';
import '../models/news_post.dart';
import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/content_store.dart';
import '../services/mock_data.dart';
import '../services/post_like_helper.dart';
import '../services/user_state.dart';
import '../services/moderation_service.dart';
import '../widgets/club_avatar.dart';
import '../widgets/moderation_reason_sheet.dart';
import '../widgets/poll_card.dart';
import 'create_post_screen.dart' show buildPostBanner;

class PostDetailScreen extends StatefulWidget {
  final NewsPost post;
  final Color clubColor;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.clubColor,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  String get _currentAdminId => authService.currentAdmin?.id ?? '';

  bool get _canDeletePost =>
      contentStore.canDeletePost(widget.post.id, _currentAdminId);

  void _confirmDelete() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        title: Text(
          'Delete post?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text),
        ),
        content: Text(
          'This post will be permanently removed.',
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed != true || !mounted) return;
      final ok = contentStore.deletePost(widget.post.id, _currentAdminId);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
      } else {
        Navigator.popUntil(context, (r) => r.isFirst);
      }
    });
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  void _toggleLike() {
    if (!authService.isStudentSession) return;
    togglePostLike(widget.post.id);
    setState(() {});
  }

  Future<void> _reportPost() async {
    final reason = await showModerationReasonSheet(
      context,
      title: S.whyReportPost,
    );
    if (reason == null || !mounted) return;

    var delivered = true;
    try {
      await moderationService.reportPost(widget.post, reason: reason);
    } catch (_) {
      delivered = false;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.maybePop(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            delivered ? S.postReportedAndRemoved : S.postHiddenOffline,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final club = clubs.firstWhere((c) => c.id == widget.post.clubId);
    final isStudent = authService.isStudentSession;
    final isLiked = userState.isLiked(widget.post.id);
    final likeCount = postLikeCount(widget.post.id);
    final hasImage =
        widget.post.imagePath != null && widget.post.imagePath!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        title: Text(
          club.name,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (isStudent)
            IconButton(
              tooltip: S.reportPost,
              icon: Icon(Icons.flag_outlined, color: AppColors.secondaryText),
              onPressed: _reportPost,
            ),
          if (_canDeletePost)
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Club header ──
                  Container(
                    color: AppColors.card,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      children: [
                        ClubAvatar(
                          clubId: club.id,
                          clubName: club.name,
                          size: 42,
                          fontSize: 18,
                          color: widget.clubColor,
                          imageUrl: club.logoUrl,
                          shape: 'circle',
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                club.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.text,
                                ),
                              ),
                              Text(
                                _timeAgo(widget.post.createdAt),
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

                  // ── Banner image ──
                  if (hasImage)
                    buildPostBanner(
                      imagePath: widget.post.imagePath,
                      fallbackColor: widget.clubColor,
                      fallbackLetter: club.name[0],
                      height: 220,
                    ),

                  // ── Like count ──
                  Container(
                    color: AppColors.card,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: isStudent ? _toggleLike : null,
                          child: Row(
                            children: [
                              Icon(
                                isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isLiked
                                    ? Colors.pink
                                    : AppColors.secondaryText,
                                size: 22,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$likeCount',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Full content ──
                  Container(
                    color: AppColors.card,
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.content,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.text,
                            height: 1.6,
                          ),
                        ),
                        if (widget.post.poll != null)
                          PollCard(post: widget.post, accent: widget.clubColor),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/news_post.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/content_store.dart';
import '../services/mock_data.dart';
import '../services/user_state.dart';
import '../models/like.dart';
import '../models/comment.dart';
import '../widgets/club_avatar.dart';
import '../widgets/user_avatar.dart';
import '../widgets/mention_text_field.dart';
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
  final _commentController = TextEditingController();

  String get _loggedInId =>
      authService.currentAdmin?.id ?? authService.currentUser?.id ?? '';

  bool get _isOwner => widget.post.authorId == _loggedInId;

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

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _confirmDelete() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed != true || !mounted) return;
      final ok = contentStore.deletePost(widget.post.id, _loggedInId);
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
    final userId = authService.currentUser?.id ?? 'guest';
    if (userState.isLiked(widget.post.id)) {
      userState.toggleLike(widget.post.id);
      likes.removeWhere(
        (l) => l.postId == widget.post.id && l.userId == userId,
      );
    } else {
      userState.toggleLike(widget.post.id);
      likes.add(
        Like(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          postId: widget.post.id,
          userId: userId,
        ),
      );
    }
    contentStore.saveLikes();
    setState(() {});
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final userId = authService.currentUser?.id ?? 'guest';
    comments.add(
      Comment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        postId: widget.post.id,
        userId: userId,
        content: text,
        createdAt: DateTime.now(),
      ),
    );
    contentStore.saveComments();
    _commentController.clear();
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final club = clubs.firstWhere((c) => c.id == widget.post.clubId);
    final isLiked = userState.isLiked(widget.post.id);
    final likeCount = postLikeCount(widget.post.id);
    final hasImage =
        widget.post.imagePath != null && widget.post.imagePath!.isNotEmpty;
    final postComments =
        comments.where((c) => c.postId == widget.post.id).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

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
          if (_isOwner)
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

                  // ── Like + comment counts ──
                  Container(
                    color: AppColors.card,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _toggleLike,
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
                        const SizedBox(width: 18),
                        Icon(
                          Icons.chat_bubble_outline,
                          color: AppColors.secondaryText,
                          size: 22,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${postComments.length}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.secondaryText,
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
                    child: Text(
                      widget.post.content,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.text,
                        height: 1.6,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Comments ──
                  if (postComments.isNotEmpty) ...[
                    Container(
                      color: AppColors.card,
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                      child: Text(
                        'Comments (${postComments.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    ...postComments.map((c) {
                      final commenter = users.firstWhere(
                        (u) => u.id == c.userId,
                        orElse: () => users.first,
                      );
                      return Container(
                        color: AppColors.card,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UserAvatar(
                              userId: commenter.id,
                              name: commenter.name,
                              size: 34,
                              fontSize: 14,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        commenter.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _timeAgo(c.createdAt),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    c.content,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.text,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    Divider(height: 1),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // ── Add comment bar ──
          Container(
            color: AppColors.card,
            padding: EdgeInsets.only(
              left: 14,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: MentionTextField(
                      controller: _commentController,
                      options: _mentionOptions,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(color: AppColors.secondaryText),
                        filled: true,
                        fillColor: AppColors.lightGray,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _submitComment,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryRed,
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

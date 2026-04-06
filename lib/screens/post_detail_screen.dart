import 'package:flutter/material.dart';
import '../models/news_post.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/user_state.dart';
import '../models/like.dart';
import '../models/comment.dart';
import '../widgets/user_avatar.dart';
import 'user_profile_screen.dart';
import 'create_post_screen.dart' show buildPostBanner;

class PostDetailScreen extends StatefulWidget {
  final NewsPost post;
  final Color clubColor;

  const PostDetailScreen({super.key, required this.post, required this.clubColor});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  void _toggleLike() {
    final userId = authService.currentUser?.id ?? 'guest';
    if (userState.isLiked(widget.post.id)) {
      userState.toggleLike(widget.post.id);
      likes.removeWhere((l) => l.postId == widget.post.id && l.userId == userId);
    } else {
      userState.toggleLike(widget.post.id);
      likes.add(Like(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        postId: widget.post.id,
        userId: userId,
      ));
    }
    setState(() {});
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final userId = authService.currentUser?.id ?? 'guest';
    comments.add(Comment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      postId: widget.post.id,
      userId: userId,
      content: text,
      createdAt: DateTime.now(),
    ));
    _commentController.clear();
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final club = clubs.firstWhere((c) => c.id == widget.post.clubId);
    final author = users.firstWhere((u) => u.id == widget.post.authorId,
        orElse: () => users.first);
    final isLiked = userState.isLiked(widget.post.id);
    final likeCount = postLikeCount(widget.post.id);
    final postComments = comments
        .where((c) => c.postId == widget.post.id)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        title: Text(club.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Author header ──
                  Container(
                    color: AppColors.card,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) => UserProfileScreen(user: author))),
                          child: UserAvatar(
                            userId: author.id,
                            name: author.name,
                            size: 42,
                            fontSize: 18,
                            backgroundColor: widget.clubColor.withValues(alpha: 0.18),
                            textColor: widget.clubColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) => UserProfileScreen(user: author))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(author.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.primaryRed)),
                                Text(_timeAgo(widget.post.createdAt),
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.secondaryText)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Banner image ──
                  buildPostBanner(
                    imagePath: widget.post.imagePath,
                    fallbackColor: widget.clubColor,
                    fallbackLetter: clubs.firstWhere(
                      (c) => c.id == widget.post.clubId,
                      orElse: () => clubs.first,
                    ).name[0],
                    height: 220,
                  ),

                  // ── Like + comment counts ──
                  Container(
                    color: AppColors.card,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _toggleLike,
                          child: Row(
                            children: [
                              Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                color: isLiked ? Colors.pink : AppColors.secondaryText,
                                size: 22,
                              ),
                              const SizedBox(width: 5),
                              Text('$likeCount',
                                  style: const TextStyle(
                                      fontSize: 14, color: AppColors.secondaryText)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 18),
                        const Icon(Icons.chat_bubble_outline,
                            color: AppColors.secondaryText, size: 22),
                        const SizedBox(width: 5),
                        Text('${postComments.length}',
                            style: const TextStyle(
                                fontSize: 14, color: AppColors.secondaryText)),
                      ],
                    ),
                  ),

                  // ── Full content ──
                  Container(
                    color: AppColors.card,
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(widget.post.content,
                        style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.text,
                            height: 1.6)),
                  ),

                  const SizedBox(height: 8),

                  // ── Comments ──
                  if (postComments.isNotEmpty) ...[
                    Container(
                      color: AppColors.card,
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                      child: Text('Comments (${postComments.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.text)),
                    ),
                    ...postComments.map((c) {
                      final commenter = users.firstWhere((u) => u.id == c.userId,
                          orElse: () => users.first);
                      return Container(
                        color: AppColors.card,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                                      Text(commenter.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: AppColors.text)),
                                      const SizedBox(width: 6),
                                      Text(_timeAgo(c.createdAt),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.secondaryText)),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(c.content,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.text,
                                          height: 1.4)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 1),
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
                    child: TextField(
                      controller: _commentController,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle:
                            const TextStyle(color: AppColors.secondaryText),
                        filled: true,
                        fillColor: AppColors.lightGray,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
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
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryRed,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 18),
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

import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../models/news_post.dart';
import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/comment_store.dart';
import '../services/content_store.dart';
import '../services/mock_data.dart';
import '../services/people_service.dart';
import '../services/post_like_helper.dart';
import '../services/user_state.dart';
import '../widgets/club_avatar.dart';
import '../widgets/poll_card.dart';
import '../widgets/user_avatar.dart';
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
  bool _sendingComment = false;

  String get _currentAdminId => authService.currentAdmin?.id ?? '';

  String get _myId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  bool get _canDeletePost =>
      contentStore.canDeletePost(widget.post.id, _currentAdminId);

  @override
  void initState() {
    super.initState();
    commentStore.hydrate(widget.post.id);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _commenterName(String userId) {
    for (final u in users) {
      if (u.id == userId) return userState.displayNameFor(u.id, u.name);
    }
    for (final u in peopleService.cachedPeople) {
      if (u.id == userId) return userState.displayNameFor(u.id, u.name);
    }
    final me = authService.currentUser;
    if (me?.id == userId) return userState.displayNameFor(me!.id, me.name);
    for (final admin in clubAdmins) {
      if (admin.id == userId) return admin.name;
    }
    return 'Student';
  }

  bool _canDeleteComment(Comment comment) =>
      comment.userId == _myId ||
      contentStore.canDeletePost(widget.post.id, _currentAdminId);

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sendingComment) return;
    setState(() => _sendingComment = true);
    _commentController.clear();
    await commentStore.add(post: widget.post, content: text);
    if (mounted) setState(() => _sendingComment = false);
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: isStudent ? _toggleLike : null,
                    child: Row(
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
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

                  const SizedBox(height: 8),

                  // ── Comments ──
                  ListenableBuilder(
                    listenable: commentStore,
                    builder: (_, _) {
                      final postComments = commentStore.commentsFor(
                        widget.post.id,
                      );
                      return Container(
                        color: AppColors.card,
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.mode_comment_outlined,
                                  size: 16,
                                  color: AppColors.secondaryText,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  '${S.comments} · ${postComments.length}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (postComments.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                child: Text(
                                  S.noCommentsYet,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              )
                            else
                              ...postComments.map(_commentRow),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Comment composer (students and the owning club admin) ──
          if (isStudent || _canDeletePost) _buildComposer(),
        ],
      ),
    );
  }

  Widget _commentRow(Comment comment) {
    final name = _commenterName(comment.userId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            userId: comment.userId,
            name: name,
            size: 34,
            fontSize: 13,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _timeAgo(comment.createdAt),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.content,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
          if (_canDeleteComment(comment))
            GestureDetector(
              onTap: () => commentStore.remove(comment),
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 17,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendComment(),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  hintText: S.addComment,
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: AppColors.secondaryText,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(fontSize: 14, color: AppColors.text),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: _sendingComment ? null : _sendComment,
              icon: Icon(
                Icons.send_rounded,
                size: 22,
                color: AppColors.primaryRed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

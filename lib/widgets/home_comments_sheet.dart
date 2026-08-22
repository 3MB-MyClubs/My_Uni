import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/comment.dart';
import '../models/news_post.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/comment_store.dart';
import '../services/content_safety_service.dart';
import '../services/mock_data.dart';
import '../services/moderation_service.dart';
import '../services/people_service.dart';
import '../services/user_state.dart';
import 'clubup_design.dart';
import 'moderation_reason_sheet.dart';
import 'user_avatar.dart';

/// `comments-light/dark` (Figma `239:10` / `239:107`) and `reply-thread-light/dark`
/// (`281:537` / `281:621`) from the ClubUp-Desings HOME section.
///
/// A local copy for the redesigned student Home: [showCommentsSheet] in
/// `comments_sheet.dart` is still what the club-admin Home opens, and it is
/// left exactly as it was.
///
/// **Comment likes and replies are session-only.** The app has no store for
/// either — `Comment.parentCommentId` is never written and there is no
/// comment-likes table — and adding one is backend work, which this redesign
/// pass deliberately does not touch. They live in [homeCommentExtras] for as
/// long as the app is running and are never persisted or synced.
class HomeCommentExtras extends ChangeNotifier {
  final Map<String, int> _likes = {};
  final Set<String> _likedByMe = {};
  final Map<String, List<HomeLocalReply>> _replies = {};

  int likeCountFor(String commentId) => _likes[commentId] ?? 0;

  bool isLikedByMe(String commentId) => _likedByMe.contains(commentId);

  void toggleLike(String commentId) {
    if (_likedByMe.remove(commentId)) {
      _likes[commentId] = (_likes[commentId] ?? 1) - 1;
    } else {
      _likedByMe.add(commentId);
      _likes[commentId] = (_likes[commentId] ?? 0) + 1;
    }
    notifyListeners();
  }

  List<HomeLocalReply> repliesFor(String commentId) =>
      List.unmodifiable(_replies[commentId] ?? const <HomeLocalReply>[]);

  int replyCountFor(String commentId) => _replies[commentId]?.length ?? 0;

  void addReply(String commentId, HomeLocalReply reply) {
    _replies.putIfAbsent(commentId, () => <HomeLocalReply>[]).add(reply);
    notifyListeners();
  }
}

/// One session-only reply under a comment.
class HomeLocalReply {
  HomeLocalReply({
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  final String userId;
  final String content;
  final DateTime createdAt;
}

final HomeCommentExtras homeCommentExtras = HomeCommentExtras();

/// Opens the redesigned comments sheet for [post].
Future<void> showHomeCommentsSheet(
  BuildContext context, {
  required NewsPost post,
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x59000000),
    builder: (_) => HomeCommentsSheet(post: post, onChanged: onChanged),
  );
}

class HomeCommentsSheet extends StatefulWidget {
  const HomeCommentsSheet({
    super.key,
    required this.post,
    required this.onChanged,
  });

  final NewsPost post;
  final VoidCallback onChanged;

  @override
  State<HomeCommentsSheet> createState() => _HomeCommentsSheetState();
}

class _HomeCommentsSheetState extends State<HomeCommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  bool _sending = false;
  String? _sendError;

  /// Non-null while the `Replies` view of the design is showing.
  Comment? _replyTarget;

  @override
  void initState() {
    super.initState();
    commentStore.addListener(_onStoreChanged);
    moderationService.addListener(_onStoreChanged);
    homeCommentExtras.addListener(_onStoreChanged);
    _controller.addListener(_onStoreChanged);
    commentStore.watch(widget.post.id);
    unawaited(_load());
  }

  @override
  void dispose() {
    commentStore.removeListener(_onStoreChanged);
    moderationService.removeListener(_onStoreChanged);
    homeCommentExtras.removeListener(_onStoreChanged);
    unawaited(commentStore.unwatch());
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (commentStore.commentsFor(widget.post.id).isNotEmpty) {
      setState(() => _loading = false);
    }
    await commentStore.hydrate(widget.post.id, force: true);
    if (!mounted) return;
    setState(() => _loading = false);
    widget.onChanged();
  }

  String _nameFor(String userId) {
    final cached = peopleService.cachedPeople.where((u) => u.id == userId);
    final known = users.where((u) => u.id == userId);
    final fallback = cached.isNotEmpty
        ? cached.first.name
        : (known.isNotEmpty ? known.first.name : '');
    return userState.displayNameFor(userId, fallback);
  }

  String _timeAgo(DateTime dt) {
    final l10n = AppLocalizations.of(context)!;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inMinutes < 60) return l10n.minutesAgoSuffix(diff.inMinutes);
    if (diff.inHours < 24) return l10n.hoursAgoSuffix(diff.inHours);
    return l10n.daysAgoSuffix(diff.inDays);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    // Replies never reach the backend: there is nothing to write them to.
    final target = _replyTarget;
    if (target != null) {
      final me = authService.currentUser?.id ?? '';
      homeCommentExtras.addReply(
        target.id,
        HomeLocalReply(userId: me, content: text, createdAt: DateTime.now()),
      );
      _controller.clear();
      HapticFeedback.lightImpact();
      setState(() => _sendError = null);
      return;
    }

    setState(() => _sending = true);
    var message = '';
    try {
      await commentStore.add(post: widget.post, content: text);
      _controller.clear();
    } on ContentSafetyException catch (error) {
      message = error.message;
    } on CommentNotDeliveredException catch (error) {
      message = error.userMessage ?? S.commentFailed;
    } catch (_) {
      message = S.commentFailed;
    } finally {
      if (mounted) setState(() => _sending = false);
    }

    if (!mounted) return;
    widget.onChanged();
    setState(() => _sendError = message.isEmpty ? null : message);
    if (message.isNotEmpty || !_scrollController.hasClients) return;
    unawaited(
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      ),
    );
  }

  void _openCommentOptions(Comment comment) {
    final isMine = comment.userId == authService.currentUser?.id;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ClubUpColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: ClubUpColors.border,
                borderRadius: const BorderRadius.all(Radius.circular(2.5)),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                isMine ? Icons.delete_outline_rounded : Icons.flag_outlined,
                color: isMine ? Colors.red : ClubUpColors.accentText,
              ),
              title: Text(
                isMine ? S.deleteComment : S.reportComment,
                style: figtree(
                  size: 14,
                  weight: FontWeight.w600,
                  color: isMine ? Colors.red : ClubUpColors.accentText,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                unawaited(
                  isMine ? _deleteComment(comment) : _reportComment(comment),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteComment(Comment comment) async {
    String? failure;
    try {
      await commentStore.remove(comment);
    } catch (_) {
      failure = S.commentDeleteFailed;
    }
    if (!mounted) return;
    widget.onChanged();
    setState(() => _sendError = failure);
  }

  Future<void> _reportComment(Comment comment) async {
    final reason = await showModerationReasonSheet(
      context,
      title: S.whyReportComment,
    );
    if (reason == null || !mounted) return;
    var delivered = true;
    try {
      await moderationService.reportComment(comment, reason: reason);
    } catch (_) {
      delivered = false;
    }
    if (!mounted) return;
    widget.onChanged();
    setState(() => _sendError = delivered ? null : S.commentHiddenOffline);
  }

  @override
  Widget build(BuildContext context) {
    final comments = commentStore.commentsFor(widget.post.id);
    final target = _replyTarget;
    final height = MediaQuery.sizeOf(context).height * 0.7;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height,
        child: Container(
          key: ValueKey('home-comments-sheet-${widget.post.id}'),
          padding: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: ClubUpColors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(top: BorderSide(color: ClubUpColors.border)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                offset: const Offset(0, -8),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            children: [
              _dragHandle(),
              _sheetHeader(target, comments.length),
              Expanded(
                child: target == null
                    ? _commentsList(comments)
                    : _repliesView(target),
              ),
              if (_sendError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    _sendError!,
                    style: figtree(
                      size: 12,
                      weight: FontWeight.w500,
                      color: Colors.red,
                    ),
                  ),
                ),
              _composer(target),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dragHandle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: Container(
          width: 40,
          height: 5,
          decoration: BoxDecoration(
            color: ClubUpColors.border,
            borderRadius: const BorderRadius.all(Radius.circular(2.5)),
          ),
        ),
      ),
    );
  }

  /// `sheet-header` — title, burgundy count badge and the close X; the replies
  /// view puts a back arrow in front of the title.
  Widget _sheetHeader(Comment? target, int commentCount) {
    final count = target == null
        ? commentCount
        : homeCommentExtras.replyCountFor(target.id);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: ClubUpColors.border)),
      ),
      child: Row(
        children: [
          if (target != null) ...[
            GestureDetector(
              key: const ValueKey('home-replies-back'),
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                _replyTarget = null;
                _controller.clear();
              }),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: ClubUpColors.text,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            target == null
                ? AppLocalizations.of(context)!.comments
                : S.repliesTitle,
            style: figtree(
              size: 18,
              weight: FontWeight.w800,
              color: ClubUpColors.text,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: const BoxDecoration(
              color: ClubUpColors.accent,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: Text(
              '$count',
              style: figtree(
                size: 11,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            key: const ValueKey('home-comments-close'),
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: ClubUpColors.text,
            ),
          ),
        ],
      ),
    );
  }

  /// `comments-list`
  Widget _commentsList(List<Comment> comments) {
    if (_loading && comments.isEmpty) {
      return Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: ClubUpColors.accent,
          ),
        ),
      );
    }
    if (comments.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noCommentsYet,
          textAlign: TextAlign.center,
          style: figtree(
            size: 13,
            weight: FontWeight.w500,
            color: ClubUpColors.muted,
          ),
        ),
      );
    }
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (context, index) => _commentRow(comments[index]),
    );
  }

  Widget _commentRow(Comment comment) {
    final name = _nameFor(comment.userId);
    final replyCount = homeCommentExtras.replyCountFor(comment.id);
    return GestureDetector(
      key: ValueKey('home-comment-${comment.id}'),
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _openCommentOptions(comment),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            userId: comment.userId,
            name: name,
            size: 32,
            fontSize: 13,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _metaRow(name, comment.createdAt),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: figtree(
                    size: 13,
                    weight: FontWeight.w400,
                    color: ClubUpColors.text,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  key: ValueKey('home-comment-reply-${comment.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() {
                    _replyTarget = comment;
                    _controller.clear();
                  }),
                  child: Text(
                    replyCount == 0
                        ? S.replyAction
                        : '${S.replyAction} · $replyCount',
                    style: figtree(
                      size: 11,
                      weight: FontWeight.w600,
                      color: ClubUpColors.muted,
                    ).copyWith(decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _likeColumn(comment.id),
        ],
      ),
    );
  }

  /// `like-comment` — the session-only heart described on [HomeCommentExtras].
  Widget _likeColumn(String commentId) {
    final liked = homeCommentExtras.isLikedByMe(commentId);
    return GestureDetector(
      key: ValueKey('home-comment-like-$commentId'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        homeCommentExtras.toggleLike(commentId);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 14,
            color: liked ? ClubUpColors.accent : ClubUpColors.muted,
          ),
          const SizedBox(height: 2),
          Text(
            '${homeCommentExtras.likeCountFor(commentId)}',
            style: figtree(
              size: 9,
              weight: FontWeight.w600,
              color: ClubUpColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(String name, DateTime createdAt) {
    return Row(
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: figtree(
              size: 13,
              weight: FontWeight.w700,
              color: ClubUpColors.text,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _timeAgo(createdAt),
          style: figtree(
            size: 11,
            weight: FontWeight.w400,
            color: ClubUpColors.muted,
          ),
        ),
      ],
    );
  }

  /// `sheet-scroll` of `reply-thread` — the parent comment on a tinted band,
  /// then the thread-lined replies.
  Widget _repliesView(Comment parent) {
    final replies = homeCommentExtras.repliesFor(parent.id);
    return ListView(
      key: ValueKey('home-replies-list-${parent.id}'),
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: ClubUpColors.background,
            border: Border(bottom: BorderSide(color: ClubUpColors.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(
                userId: parent.userId,
                name: _nameFor(parent.userId),
                size: 36,
                fontSize: 14,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _metaRow(_nameFor(parent.userId), parent.createdAt),
                    const SizedBox(height: 4),
                    Text(
                      parent.content,
                      style: figtree(
                        size: 13,
                        weight: FontWeight.w400,
                        color: ClubUpColors.text,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (replies.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
            child: Text(
              S.noRepliesYetLine,
              textAlign: TextAlign.center,
              style: figtree(
                size: 13,
                weight: FontWeight.w500,
                color: ClubUpColors.muted,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                for (var i = 0; i < replies.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == replies.length - 1 ? 0 : 16,
                    ),
                    child: _replyRow(replies[i]),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _replyRow(HomeLocalReply reply) {
    final name = _nameFor(reply.userId);
    // `thread-line` runs the full height of the reply, so the row needs an
    // intrinsic height to stretch against inside the scroller.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 2, color: ClubUpColors.border),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  userId: reply.userId,
                  name: name,
                  size: 32,
                  fontSize: 13,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _metaRow(name, reply.createdAt),
                      const SizedBox(height: 4),
                      Text(
                        reply.content,
                        style: figtree(
                          size: 13,
                          weight: FontWeight.w400,
                          color: ClubUpColors.text,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// `composer` — avatar plus a rounded field; the send button appears once
  /// there is something to send, as in the replies frame.
  Widget _composer(Comment? target) {
    final me = authService.currentUser;
    final canSend = _controller.text.trim().isNotEmpty && !_sending;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClubUpColors.card,
        border: Border(top: BorderSide(color: ClubUpColors.border)),
      ),
      child: Row(
        children: [
          UserAvatar(
            userId: me?.id ?? '',
            name: me?.name ?? '',
            size: 36,
            fontSize: 14,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: 16, right: 12),
              decoration: BoxDecoration(
                color: ClubUpColors.chip,
                borderRadius: const BorderRadius.all(Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('home-comment-field'),
                      controller: _controller,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => unawaited(_send()),
                      style: figtree(
                        size: 14,
                        weight: FontWeight.w400,
                        color: ClubUpColors.text,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        hintText: target == null
                            ? AppLocalizations.of(context)!.addComment
                            : S.replyToHint(_nameFor(target.userId)),
                        hintStyle: figtree(
                          size: 14,
                          weight: FontWeight.w400,
                          color: ClubUpColors.muted,
                        ),
                      ),
                    ),
                  ),
                  if (canSend)
                    GestureDetector(
                      key: const ValueKey('home-comment-send'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => unawaited(_send()),
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: const BoxDecoration(
                          color: ClubUpColors.accent,
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
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

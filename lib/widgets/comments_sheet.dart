import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/comment.dart';
import '../models/news_post.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/comment_store.dart';
import '../services/content_safety_service.dart';
import '../services/mock_data.dart';
import '../services/moderation_service.dart';
import '../services/people_service.dart';
import '../services/user_state.dart';
import 'loading_skeleton.dart';
import 'moderation_reason_sheet.dart';
import 'user_avatar.dart';

/// Opens the comment list for [post] with a composer at the bottom.
///
/// [onChanged] fires whenever the comment count for this post may have moved,
/// so the caller can refresh the badge it shows on the feed card.
Future<void> showCommentsSheet(
  BuildContext context, {
  required NewsPost post,
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CommentsSheet(post: post, onChanged: onChanged),
  );
}

class CommentsSheet extends StatefulWidget {
  final NewsPost post;
  final VoidCallback onChanged;

  const CommentsSheet({super.key, required this.post, required this.onChanged});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  bool _sending = false;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    commentStore.addListener(_onStoreChanged);
    moderationService.addListener(_onStoreChanged);
    // Typing enables the send button, so the field drives a rebuild too.
    _controller.addListener(_onStoreChanged);
    // Other people's comments land while this sheet is open.
    commentStore.watch(widget.post.id);
    unawaited(_load());
  }

  @override
  void dispose() {
    commentStore.removeListener(_onStoreChanged);
    moderationService.removeListener(_onStoreChanged);
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
    // Anything cached from a previous open shows straight away; only a thread
    // with nothing to show waits behind the skeleton. Either way the fetch is
    // forced, so reopening a sheet never serves a stale thread.
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

  String _timeAgo(BuildContext context, DateTime dt) {
    final l10n = AppLocalizations.of(context)!;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return l10n.minutesAgoSuffix(diff.inMinutes);
    if (diff.inHours < 24) return l10n.hoursAgoSuffix(diff.inHours);
    return l10n.daysAgoSuffix(diff.inDays);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    var message = '';
    try {
      await commentStore.add(post: widget.post, content: text);
      _controller.clear();
    } on ContentSafetyException catch (error) {
      message = error.message;
    } on CommentNotDeliveredException catch (error) {
      // In a debug build show why, so a failing backend is diagnosable from
      // the device instead of only from the attached console.
      message = kDebugMode ? error.reason : S.commentFailed;
    } catch (error) {
      debugPrint('[comments] send failed: $error');
      message = S.commentFailed;
    } finally {
      if (mounted) setState(() => _sending = false);
    }

    if (!mounted) return;
    widget.onChanged();
    if (message.isNotEmpty) {
      // Inline, not a snackbar: this sheet is a modal route, so a snackbar
      // from the ScaffoldMessenger below it is drawn behind the sheet and the
      // user never learns why their comment did not go through.
      setState(() => _sendError = message);
      return;
    }
    setState(() => _sendError = null);
    // New comments land at the bottom of the oldest-first list.
    if (_scrollController.hasClients) {
      unawaited(
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  void _openCommentOptions(Comment comment) {
    final isMine = comment.userId == authService.currentUser?.id;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
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
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: const BorderRadius.all(Radius.circular(999)),
              ),
            ),
            const SizedBox(height: 8),
            // Supabase only lets an author delete their own row, so anything
            // written by somebody else is handled through the report queue.
            if (isMine)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
                title: Text(
                  S.deleteComment,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_deleteComment(comment));
                },
              )
            else
              ListTile(
                leading: Icon(Icons.flag_outlined, color: AppColors.primaryRed),
                title: Text(
                  S.reportComment,
                  style: TextStyle(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_reportComment(comment));
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
      // The store restored the comment; say so instead of claiming success.
      failure = S.commentDeleteFailed;
    }
    if (!mounted) return;
    widget.onChanged();
    // A successful delete needs no message — the row leaves the list.
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
    // Either way the comment is gone from the list; only the offline case
    // needs saying, because the report has not reached the queue yet.
    setState(() => _sendError = delivered ? null : S.commentHiddenOffline);
  }

  @override
  Widget build(BuildContext context) {
    final list = commentStore.commentsFor(widget.post.id);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return Padding(
      // Lift the whole sheet above the keyboard so the composer stays visible.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          key: ValueKey('post-comments-sheet-${widget.post.id}'),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.mode_comment_outlined,
                      size: 19,
                      color: AppColors.primaryRed,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      list.isEmpty
                          ? S.comments
                          : S.commentsWithCount(list.length),
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.divider),
              Flexible(child: _buildBody(list)),
              Divider(height: 1, color: AppColors.divider),
              _buildComposer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<Comment> list) {
    if (_loading && list.isEmpty) return const _CommentListSkeleton();
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mode_comment_outlined,
              size: 34,
              color: AppColors.secondaryText,
            ),
            const SizedBox(height: 12),
            Text(
              S.noCommentsYet,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, i) => _buildTile(list[i]),
    );
  }

  Widget _buildTile(Comment comment) {
    final name = _nameFor(comment.userId);

    return Padding(
      key: ValueKey('post-comment-${comment.id}'),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            userId: comment.userId,
            name: name,
            size: 36,
            fontSize: 14,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name.isEmpty ? '—' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo(context, comment.createdAt),
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  comment.content,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: AppColors.secondaryText,
            ),
            visualDensity: VisualDensity.compact,
            tooltip: S.reportComment,
            onPressed: () => _openCommentOptions(comment),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    final currentUser = authService.currentUser;
    // Club-admin sessions read the discussion but post as the club elsewhere.
    if (currentUser == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Text(
          S.commentsStudentsOnly,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
        ),
      );
    }

    final canSend = _controller.text.trim().isNotEmpty && !_sending;
    final error = _sendError;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (error != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: Border.all(
                color: AppColors.primaryRed.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 17,
                  color: AppColors.primaryRed,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    error,
                    style: TextStyle(
                      color: AppColors.primaryRed,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        _buildComposerRow(currentUser, canSend),
      ],
    );
  }

  Widget _buildComposerRow(User currentUser, bool canSend) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          UserAvatar(
            userId: currentUser.id,
            name: userState.displayNameFor(currentUser.id, currentUser.name),
            size: 34,
            fontSize: 13,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                style: TextStyle(color: AppColors.text, fontSize: 14),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: S.addComment,
                  hintStyle: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                    borderSide: BorderSide(color: AppColors.primaryRed),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            key: const ValueKey('post-comment-send'),
            icon: _sending
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryRed,
                    ),
                  )
                : Icon(
                    Icons.send_rounded,
                    color: canSend
                        ? AppColors.primaryRed
                        : AppColors.secondaryText,
                  ),
            onPressed: canSend
                ? () {
                    HapticFeedback.selectionClick();
                    unawaited(_send());
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _CommentListSkeleton extends StatelessWidget {
  const _CommentListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox.circle(size: 36),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(
                        width: 110,
                        height: 12,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SkeletonBox(
                        width: double.infinity,
                        height: 12,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

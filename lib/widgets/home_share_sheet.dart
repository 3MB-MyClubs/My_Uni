import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/news_post.dart';
import '../models/share.dart';
import '../models/user.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/chat_store.dart';
import '../services/content_store.dart';
import '../services/mock_data.dart';
import '../services/people_service.dart';
import '../services/user_state.dart';
import 'clubup_design.dart';
import 'group_avatar_stack.dart';
import 'user_avatar.dart';

/// `share-light` / `share-dark` (Figma `239:207` / `239:311`) from the HOME
/// section — the conversation picker a post's share plane opens.
///
/// A local copy for the redesigned student Home. `post_share_sheet.dart` is
/// what the club-admin Home still opens and is left untouched. Club
/// announcement channels stay excluded here too: sharing is limited to DMs and
/// user-created groups.
Future<void> showHomeShareSheet(
  BuildContext context, {
  required NewsPost post,
  required VoidCallback onChanged,
}) async {
  final currentUser = authService.currentUser;
  if (currentUser == null) return;
  final result = await showModalBottomSheet<_ShareOutcome>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x59000000),
    builder: (_) => _HomeShareSheet(
      post: post,
      currentUserId: currentUser.id,
      onShared: onChanged,
    ),
  );
  if (result == null || !context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          result == _ShareOutcome.linkCopied
              ? AppLocalizations.of(context)!.postLinkCopied
              : S.postShared,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
}

enum _ShareOutcome { sentToChat, linkCopied }

class _HomeShareSheet extends StatefulWidget {
  const _HomeShareSheet({
    required this.post,
    required this.currentUserId,
    required this.onShared,
  });

  final NewsPost post;
  final String currentUserId;
  final VoidCallback onShared;

  @override
  State<_HomeShareSheet> createState() => _HomeShareSheetState();
}

class _HomeShareSheetState extends State<_HomeShareSheet> {
  final TextEditingController _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  String _nameForUser(String userId) {
    final cached = peopleService.cachedPeople.where((u) => u.id == userId);
    final known = users.where((u) => u.id == userId);
    final fallback = cached.isNotEmpty
        ? cached.first.name
        : (known.isNotEmpty ? known.first.name : '');
    return userState.displayNameFor(userId, fallback);
  }

  String _titleFor(ChatThreadSummary thread) {
    if (thread.isGroup) {
      return chatStore.groupDisplayName(thread.threadId, widget.currentUserId);
    }
    return _nameForUser(thread.peerId ?? '');
  }

  /// The `@handle` line. Students have no handle field, so the username the
  /// profile screen copies, or the local part of the KU address, stands in.
  String _handleFor(ChatThreadSummary thread) {
    if (thread.isGroup) return '';
    final peerId = thread.peerId ?? '';
    final username = userState.usernameFor(peerId);
    if (username != null && username.trim().isNotEmpty) {
      return '@${username.trim()}';
    }
    final User? user = users.where((u) => u.id == peerId).firstOrNull;
    final local = (user?.email ?? '').split('@').first.trim();
    return local.isEmpty ? '' : '@$local';
  }

  List<ChatThreadSummary> get _threads => chatStore
      .threadsFor(widget.currentUserId)
      .where((thread) => !thread.isClub)
      .toList(growable: false);

  List<ChatThreadSummary> get _results {
    final query = _query.text.trim().toLowerCase();
    if (query.isEmpty) return _threads;
    return _threads
        .where((thread) => _titleFor(thread).toLowerCase().contains(query))
        .toList(growable: false);
  }

  void _recordShare(String shareId, DateTime createdAt) {
    final already = shares.any(
      (share) =>
          share.targetId == widget.post.id &&
          share.userId == widget.currentUserId,
    );
    if (already) return;
    shares.add(
      Share(
        id: shareId,
        targetId: widget.post.id,
        userId: widget.currentUserId,
        createdAt: createdAt,
      ),
    );
    contentStore.scheduleSave('shares');
  }

  void _send(ChatThreadSummary thread) {
    final sent = chatStore.sendMessage(
      threadId: thread.threadId,
      senderId: widget.currentUserId,
      content: widget.post.content.trim(),
      kind: ChatMessageKind.postShare,
      sharedPostId: widget.post.id,
    );
    if (sent == null) return;
    _recordShare(sent.id, sent.createdAt);
    widget.onShared();
    HapticFeedback.lightImpact();
    Navigator.pop(context, _ShareOutcome.sentToChat);
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: 'kuclubs://post/${widget.post.id}'));
    _recordShare(
      DateTime.now().millisecondsSinceEpoch.toString(),
      DateTime.now(),
    );
    widget.onShared();
    Navigator.pop(context, _ShareOutcome.linkCopied);
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final quickSend = _threads.take(4).toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        key: const ValueKey('home-share-sheet'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: ClubUpColors.border,
                  borderRadius: const BorderRadius.all(Radius.circular(2.5)),
                ),
              ),
            ),
            _header(),
            _searchField(),
            Flexible(
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  if (quickSend.isNotEmpty && _query.text.trim().isEmpty) ...[
                    _sectionLabel(S.quickSendLabel, topPadding: 8),
                    _quickSendRow(quickSend),
                    Container(height: 1, color: ClubUpColors.border),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.shareResultsLabel,
                          style: figtree(
                            size: 11,
                            weight: FontWeight.w500,
                            color: ClubUpColors.muted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (results.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Text(
                              _threads.isEmpty
                                  ? S.noStudentChatsYet
                                  : S.noShareMatches,
                              style: figtree(
                                size: 13,
                                weight: FontWeight.w500,
                                color: ClubUpColors.muted,
                                height: 1.4,
                              ),
                            ),
                          )
                        else
                          for (final thread in results) _resultRow(thread),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: ClubUpColors.border),
            _copyLinkRow(),
            _cancelButton(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Text(
            S.shareSheetTitle,
            style: figtree(
              size: 18,
              weight: FontWeight.w800,
              color: ClubUpColors.text,
            ),
          ),
          const Spacer(),
          GestureDetector(
            key: const ValueKey('home-share-close'),
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

  /// `search-input`
  Widget _searchField() {
    final hasQuery = _query.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: ClubUpColors.chip,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: Border.all(color: ClubUpColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: ClubUpColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const ValueKey('home-share-search'),
                controller: _query,
                style: figtree(
                  size: 14,
                  weight: FontWeight.w600,
                  color: ClubUpColors.text,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: S.shareSearchHint,
                  hintStyle: figtree(
                    size: 14,
                    weight: FontWeight.w400,
                    color: ClubUpColors.muted,
                  ),
                ),
              ),
            ),
            if (hasQuery)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _query.clear,
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: Center(
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: ClubUpColors.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, {double topPadding = 0}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 0),
      child: Text(
        text,
        style: figtree(
          size: 11,
          weight: FontWeight.w500,
          color: ClubUpColors.muted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// `quick-send-row` — the four most recent conversations as 52pt avatars.
  Widget _quickSendRow(List<ChatThreadSummary> threads) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          for (final thread in threads)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                key: ValueKey('home-share-quick-${thread.threadId}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _send(thread),
                child: SizedBox(
                  width: 60,
                  child: Column(
                    children: [
                      _threadAvatar(thread, 52),
                      const SizedBox(height: 6),
                      Text(
                        _titleFor(thread),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: figtree(
                          size: 11,
                          weight: FontWeight.w600,
                          color: ClubUpColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// `result-row`
  Widget _resultRow(ChatThreadSummary thread) {
    final title = _titleFor(thread);
    final handle = _handleFor(thread);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: ClubUpColors.border)),
      ),
      child: Row(
        children: [
          _threadAvatar(thread, 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: figtree(
                    size: 14,
                    weight: FontWeight.w800,
                    color: ClubUpColors.text,
                  ),
                ),
                if (handle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: figtree(
                      size: 12,
                      weight: FontWeight.w500,
                      color: ClubUpColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            key: ValueKey('home-share-send-${thread.threadId}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _send(thread),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: ClubUpColors.accent,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: Text(
                S.sendAction,
                style: figtree(
                  size: 12,
                  weight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _threadAvatar(ChatThreadSummary thread, double size) {
    if (!thread.isGroup) {
      return UserAvatar(
        userId: thread.peerId ?? '',
        name: _titleFor(thread),
        size: size,
        fontSize: size * 0.34,
      );
    }
    final memberIds = chatStore
        .groupParticipants(thread.threadId)
        .where((id) => id != widget.currentUserId)
        .toList(growable: false);
    return GroupAvatarStack(
      memberIds: memberIds,
      nameForUser: _nameForUser,
      photoPath: chatStore.groupForThread(thread.threadId)?.photoUrl,
      size: size,
    );
  }

  /// `copy-link-row`
  Widget _copyLinkRow() {
    return GestureDetector(
      key: const ValueKey('home-share-copy-link'),
      behavior: HitTestBehavior.opaque,
      onTap: _copyLink,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Transform.rotate(
                  angle: -0.35,
                  child: Icon(
                    Icons.send_outlined,
                    size: 20,
                    color: ClubUpColors.text,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              S.copyLinkAction,
              style: figtree(
                size: 14,
                weight: FontWeight.w700,
                color: ClubUpColors.text,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: ClubUpColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  /// `cancel-btn`
  Widget _cancelButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: GestureDetector(
        key: const ValueKey('home-share-cancel'),
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ClubUpColors.chip,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
          ),
          child: Text(
            AppLocalizations.of(context)!.cancel,
            style: figtree(
              size: 14,
              weight: FontWeight.w700,
              color: ClubUpColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

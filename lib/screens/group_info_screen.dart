import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/user.dart';
import '../navigation/chat_page_route.dart';
import '../services/admin_moderation_service.dart';
import '../services/app_strings.dart';
import '../services/chat_group_prefs.dart';
import '../services/chat_store.dart';
import '../services/club_chat_prefs.dart';
import '../services/people_service.dart';
import '../services/user_state.dart';
import '../widgets/chats_design.dart';
import '../widgets/clubup_design.dart';
import '../widgets/group_avatar_stack.dart';
import '../widgets/moderation_reason_sheet.dart';
import '../widgets/user_avatar.dart';
import 'add_members_screen.dart';
import 'edit_group_info_screen.dart';
import 'shared_media_screen.dart';
import 'user_profile_screen.dart';

/// What a [GroupInfoScreen] hands back to the thread that opened it.
enum GroupInfoOutcome {
  /// The viewer left or deleted the group; the thread should close too.
  left,

  /// The viewer tapped the Search quick action; the thread should open its
  /// in-thread search. `group-info`'s Search arrow points at `search-results`.
  search,
}

/// `group-info` — Figma `104:6` / `104:94`, and the `group-menu` sheet
/// (`105:59`) plus the `leave-group` dialog (`105:474`) it opens.
///
/// The description shown here comes from [chatGroupPrefs] and is device-local:
/// `ChatGroup` has no description column. Mute reuses
/// [ClubChatPrefs.isMuted], which is already per-device and per-thread.
class GroupInfoScreen extends StatefulWidget {
  final String threadId;
  final String myId;

  const GroupInfoScreen({
    super.key,
    required this.threadId,
    required this.myId,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  @override
  void initState() {
    super.initState();
    chatStore.addListener(_refresh);
    clubChatPrefs.addListener(_refresh);
    chatGroupPrefs.addListener(_refresh);
    unawaited(_hydratePeople());
  }

  @override
  void dispose() {
    chatStore.removeListener(_refresh);
    clubChatPrefs.removeListener(_refresh);
    chatGroupPrefs.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _hydratePeople() async {
    await peopleService.hydrateProfilesByIds(
      chatStore.groupParticipants(widget.threadId),
    );
    if (mounted) setState(() {});
  }

  User? _userFor(String id) {
    final cached = peopleService.cachedPeople.where((user) => user.id == id);
    return cached.isEmpty ? null : cached.first;
  }

  String _nameFor(String id) =>
      userState.displayNameFor(id, _userFor(id)?.name ?? id);

  bool get _muted => clubChatPrefs.isMuted(widget.threadId);
  bool get _favourite => chatGroupPrefs.isFavourite(widget.threadId);

  // ── actions ────────────────────────────────────────────────────────────────

  void _toggleMute() => clubChatPrefs.setMuted(widget.threadId, !_muted);

  void _toggleFavourite() =>
      chatGroupPrefs.setFavourite(widget.threadId, !_favourite);

  Future<void> _openEdit() async {
    await Navigator.push<bool>(
      context,
      ChatPageRoute(
        builder: (_) =>
            EditGroupInfoScreen(threadId: widget.threadId, myId: widget.myId),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openAddMembers() async {
    await Navigator.push<int>(
      context,
      ChatPageRoute(
        builder: (_) =>
            AddMembersScreen(threadId: widget.threadId, myId: widget.myId),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openSharedMedia() {
    Navigator.push(
      context,
      ChatPageRoute(
        builder: (_) =>
            SharedMediaScreen(threadId: widget.threadId, myId: widget.myId),
      ),
    );
  }

  void _openMemberProfile(String memberId) {
    final user = _userFor(memberId);
    if (user == null || memberId == widget.myId) return;
    Navigator.push(
      context,
      ChatPageRoute(builder: (_) => UserProfileScreen(user: user)),
    );
  }

  /// The design's Report Group row. There is no `group` report target in the
  /// remote schema and adding one is backend work, so the report is written to
  /// the **local** moderation log via [AdminModerationService.recordReport]
  /// rather than through `moderationService`, which also inserts remotely.
  Future<void> _reportGroup() async {
    final l10n = AppLocalizations.of(context)!;
    final reason = await showModerationReasonSheet(
      context,
      title: S.chatsReportGroup,
    );
    if (reason == null || !mounted) return;
    await adminModerationService.recordReport(
      reporterId: widget.myId,
      targetType: 'group',
      targetId: widget.threadId,
      reason: reason,
      contentSnapshot: chatStore.groupDisplayName(widget.threadId, widget.myId),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.userReported),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmLeave() async {
    final confirmed = await showChatsConfirmDialog(
      context,
      title: S.chatsLeaveGroupQuestion,
      body: S.chatsLeaveGroupBody(
        chatStore.groupDisplayName(widget.threadId, widget.myId),
      ),
      confirmLabel: S.chatsLeaveGroup,
      cancelLabel: S.cancel,
      confirmKey: const ValueKey('confirm-leave-group'),
    );
    if (!confirmed || !mounted) return;
    if (chatStore.leaveGroup(widget.threadId, userId: widget.myId)) {
      Navigator.pop(context, GroupInfoOutcome.left);
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showChatsConfirmDialog(
      context,
      title: l10n.deleteGroupConfirmTitle,
      body: l10n.deleteGroupConfirmBody,
      confirmLabel: l10n.deleteGroupAction,
      cancelLabel: S.cancel,
      confirmKey: const ValueKey('confirm-delete-group'),
    );
    if (!confirmed || !mounted) return;
    if (chatStore.deleteGroup(widget.threadId, actorId: widget.myId)) {
      Navigator.pop(context, GroupInfoOutcome.left);
    }
  }

  /// `group-menu` 105:59.
  void _openOverflowMenu({required bool canManage, required bool canLeave}) {
    showChatsMenuSheet(
      context,
      sheetKey: const ValueKey('group-menu-sheet'),
      actions: [
        if (canManage)
          ChatsMenuAction(
            rowKey: const ValueKey('group-menu-edit'),
            icon: Icons.edit_outlined,
            label: S.chatsEditGroupInfo,
            onTap: _openEdit,
          ),
        ChatsMenuAction(
          rowKey: const ValueKey('group-menu-favourite'),
          icon: _favourite ? Icons.star_rounded : Icons.star_outline_rounded,
          label: _favourite
              ? S.chatsRemoveFromFavorites
              : S.chatsAddToFavorites,
          onTap: _toggleFavourite,
        ),
        ChatsMenuAction(
          rowKey: const ValueKey('group-menu-mute'),
          icon: _muted
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
          label: _muted ? S.chatsUnmuteNotifications : S.chatsMuteNotifications,
          onTap: _toggleMute,
        ),
        ChatsMenuAction(
          rowKey: const ValueKey('group-menu-report'),
          icon: Icons.flag_outlined,
          label: S.chatsReportGroup,
          destructive: true,
          dividerAbove: true,
          onTap: _reportGroup,
        ),
        if (canLeave)
          ChatsMenuAction(
            rowKey: const ValueKey('group-menu-leave'),
            icon: Icons.logout_rounded,
            label: S.chatsLeaveGroup,
            destructive: true,
            onTap: _confirmLeave,
          ),
        if (canManage)
          ChatsMenuAction(
            rowKey: const ValueKey('group-menu-delete'),
            icon: Icons.delete_outline_rounded,
            label: AppLocalizations.of(context)!.deleteGroupAction,
            destructive: true,
            onTap: _confirmDelete,
          ),
      ],
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final group = chatStore.groupForThread(widget.threadId);
    if (group == null) {
      return Scaffold(
        backgroundColor: ChatsColors.background,
        body: Center(
          child: Text(
            l10n.groupUnavailable,
            style: figtree(
              size: 14,
              weight: FontWeight.w500,
              color: ChatsColors.muted,
            ),
          ),
        ),
      );
    }
    final canManage = group.isAdmin(widget.myId);
    final canLeave = group.memberIds.contains(widget.myId) && !canManage;
    final visibleIds = group.memberIds
        .where((id) => id != widget.myId)
        .toList();
    final description = chatGroupPrefs.descriptionFor(widget.threadId);
    final photos = chatStore
        .messagesFor(widget.threadId, viewerId: widget.myId)
        .where(
          (m) =>
              m.kind == ChatMessageKind.photo &&
              (m.attachmentPath ?? '').isNotEmpty,
        )
        .toList()
        .reversed
        .take(4)
        .toList();

    return Scaffold(
      backgroundColor: ChatsColors.background,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            ChatsTopBar(
              title: l10n.groupInfoTitle,
              trailing: GestureDetector(
                key: const ValueKey('group-info-overflow'),
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    _openOverflowMenu(canManage: canManage, canLeave: canLeave),
                child: SizedBox(
                  width: 24,
                  height: 48,
                  child: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: ChatsColors.text,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  // `profile-card` 104:26 — no fill, no outline; the avatar and
                  // the title sit straight on the page.
                  Center(
                    child: GroupAvatarStack(
                      memberIds: visibleIds,
                      nameForUser: _nameFor,
                      photoPath: group.photoUrl,
                      size: 88,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    chatStore.groupDisplayName(widget.threadId, widget.myId),
                    textAlign: TextAlign.center,
                    style: figtree(
                      size: 20,
                      weight: FontWeight.w800,
                      color: ChatsColors.text,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.groupMemberCount(group.memberIds.length),
                    textAlign: TextAlign.center,
                    style: figtree(
                      size: 13,
                      weight: FontWeight.w500,
                      color: ChatsColors.muted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildActionBar(),
                  const SizedBox(height: 16),
                  ChatsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ChatsSectionLabel(S.chatsDescriptionLabel),
                        const SizedBox(height: 12),
                        Text(
                          description.isEmpty
                              ? S.chatsDescriptionHint
                              : description,
                          key: const ValueKey('group-info-description'),
                          style: figtree(
                            size: 14,
                            weight: FontWeight.w400,
                            color: description.isEmpty
                                ? ChatsColors.muted
                                : ChatsColors.text,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMembersCard(
                    group.memberIds,
                    group.creatorId,
                    l10n,
                    canManage: canManage,
                  ),
                  if (photos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSharedMediaCard(photos),
                  ],
                  const SizedBox(height: 16),
                  _buildDangerCard(canLeave: canLeave, canManage: canManage),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// `action-bar` 104:36 — Mute / Search / Media.
  Widget _buildActionBar() {
    return Row(
      children: [
        Expanded(
          child: ChatsCircleAction(
            key: const ValueKey('group-info-mute'),
            icon: _muted
                ? Icons.notifications_off_rounded
                : Icons.notifications_outlined,
            label: _muted ? S.chatsUnmuteAction : S.chatsMuteAction,
            active: _muted,
            onTap: _toggleMute,
          ),
        ),
        Expanded(
          child: ChatsCircleAction(
            key: const ValueKey('group-info-search'),
            icon: Icons.search_rounded,
            label: S.search,
            onTap: () => Navigator.pop(context, GroupInfoOutcome.search),
          ),
        ),
        Expanded(
          child: ChatsCircleAction(
            key: const ValueKey('group-info-media'),
            icon: Icons.image_outlined,
            label: S.chatsMediaAction,
            onTap: _openSharedMedia,
          ),
        ),
      ],
    );
  }

  /// `section-card` 104:52 — the Add-member row, then one row per member with
  /// an Admin chip on the right.
  Widget _buildMembersCard(
    List<String> memberIds,
    String creatorId,
    AppLocalizations l10n, {
    required bool canManage,
  }) {
    final group = chatStore.groupForThread(widget.threadId);
    return ChatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatsSectionLabel(S.chatsMembersLabel),
          if (canManage) ...[
            const SizedBox(height: 12),
            InkWell(
              key: const ValueKey('group-info-add-member'),
              onTap: _openAddMembers,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ChatsColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 20,
                        color: ChatsColors.onAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      S.chatsAddMemberRow,
                      style: figtree(
                        size: 14,
                        weight: FontWeight.w700,
                        color: ChatsColors.accentText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const ChatsCardDivider(),
          ],
          for (final id in memberIds) ...[
            const SizedBox(height: 12),
            InkWell(
              key: ValueKey('group-info-member-$id'),
              onTap: () => _openMemberProfile(id),
              child: Row(
                children: [
                  UserAvatar(
                    userId: id,
                    name: _nameFor(id),
                    size: 38,
                    fontSize: 14,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      id == widget.myId
                          ? l10n.memberNameYouSuffix(_nameFor(id))
                          : _nameFor(id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: figtree(
                        size: 14,
                        weight: FontWeight.w600,
                        color: ChatsColors.text,
                      ),
                    ),
                  ),
                  if (group?.isAdmin(id) ?? false)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ChatsColors.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        S.admin,
                        style: figtree(
                          size: 10,
                          weight: FontWeight.w700,
                          color: ChatsColors.accentText,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// `section-card` 104:77 — a four-up strip that opens `shared-media`.
  Widget _buildSharedMediaCard(List<ChatMessage> photos) {
    return ChatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: ChatsSectionLabel(S.chatsSharedMedia)),
              GestureDetector(
                key: const ValueKey('group-info-see-all-media'),
                behavior: HitTestBehavior.opaque,
                onTap: _openSharedMedia,
                child: Text(
                  S.seeAll,
                  style: figtree(
                    size: 12,
                    weight: FontWeight.w700,
                    color: ChatsColors.accentText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: Row(
              children: [
                for (var i = 0; i < photos.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _openSharedMedia,
                      child: SharedMediaTile(
                        key: ValueKey('group-info-media-${photos[i].id}'),
                        path: photos[i].attachmentPath!,
                      ),
                    ),
                  ),
                ],
                for (var i = photos.length; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// `section-card` 104:84 — Exit Group and Report Group in red.
  Widget _buildDangerCard({required bool canLeave, required bool canManage}) {
    return ChatsCard(
      child: Column(
        children: [
          if (canLeave)
            _dangerRow(
              rowKey: const ValueKey('leave-group-button'),
              icon: Icons.logout_rounded,
              label: S.chatsExitGroup,
              onTap: _confirmLeave,
            ),
          if (canManage)
            _dangerRow(
              rowKey: const ValueKey('delete-group-button'),
              icon: Icons.delete_outline_rounded,
              label: AppLocalizations.of(context)!.deleteGroupAction,
              onTap: _confirmDelete,
            ),
          if (canLeave || canManage) ...[
            const SizedBox(height: 12),
            const ChatsCardDivider(),
            const SizedBox(height: 12),
          ],
          _dangerRow(
            rowKey: const ValueKey('report-group-button'),
            icon: Icons.warning_amber_rounded,
            label: S.chatsReportGroup,
            onTap: _reportGroup,
          ),
        ],
      ),
    );
  }

  Widget _dangerRow({
    required Key rowKey,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: rowKey,
      onTap: onTap,
      child: SizedBox(
        height: 34,
        child: Row(
          children: [
            Icon(icon, size: 18, color: ChatsColors.danger),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: figtree(
                  size: 14,
                  weight: FontWeight.w600,
                  color: ChatsColors.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

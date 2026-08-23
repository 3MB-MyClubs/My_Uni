import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/user.dart';
import '../navigation/chat_page_route.dart';
import '../services/app_strings.dart';
import '../services/chat_group_prefs.dart';
import '../services/chat_store.dart';
import '../services/people_service.dart';
import '../services/user_state.dart';
import '../widgets/chats_design.dart';
import '../widgets/clubup_design.dart';
import '../widgets/group_photo_picker.dart';
import '../widgets/user_avatar.dart';
import 'add_members_screen.dart';
import 'chat_thread_screen.dart';
import 'user_profile_screen.dart';

/// `edit-group-info` — Figma `107:6` / `107:84`, plus the `member-actions`
/// sheet (`108:61`) that its member rows open.
///
/// The name and the photo are stored on the group. The **description is not**:
/// `ChatGroup` has no such field, so it lives in [chatGroupPrefs], per device.
/// See that file for why.
class EditGroupInfoScreen extends StatefulWidget {
  final String threadId;
  final String myId;

  const EditGroupInfoScreen({
    super.key,
    required this.threadId,
    required this.myId,
  });

  @override
  State<EditGroupInfoScreen> createState() => _EditGroupInfoScreenState();
}

class _EditGroupInfoScreenState extends State<EditGroupInfoScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: chatStore.groupDisplayName(widget.threadId, widget.myId),
    );
    _descriptionController = TextEditingController(
      text: chatGroupPrefs.descriptionFor(widget.threadId),
    );
    chatStore.addListener(_refresh);
    unawaited(_hydrate());
  }

  @override
  void dispose() {
    chatStore.removeListener(_refresh);
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _hydrate() async {
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

  void _save() {
    chatStore.setGroupCustomName(widget.threadId, _nameController.text);
    chatGroupPrefs.setDescription(widget.threadId, _descriptionController.text);
    Navigator.pop(context, true);
  }

  // ── member-actions sheet ───────────────────────────────────────────────────

  Future<void> _openMemberActions(String memberId) async {
    final group = chatStore.groupForThread(widget.threadId);
    if (group == null) return;
    final l10n = AppLocalizations.of(context)!;
    final isSelf = memberId == widget.myId;
    final isCreator = memberId == group.creatorId;
    final isAdmin = group.isAdmin(memberId);
    final canManage = group.isAdmin(widget.myId);
    final name = _nameFor(memberId);
    await showChatsMenuSheet(
      context,
      sheetKey: ValueKey('member-actions-sheet-$memberId'),
      header: Row(
        children: [
          UserAvatar(userId: memberId, name: name, size: 48, fontSize: 18),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: figtree(
                    size: 17,
                    weight: FontWeight.w700,
                    color: ChatsColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isCreator
                      ? l10n.groupCreatorAdminLabel
                      : isAdmin
                      ? l10n.groupAdminLabel
                      : S.chatsMemberRole,
                  style: figtree(
                    size: 13,
                    weight: FontWeight.w500,
                    color: ChatsColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (canManage && !isSelf && !isCreator)
          ChatsMenuAction(
            rowKey: ValueKey('member-action-admin-$memberId'),
            icon: Icons.shield_outlined,
            label: isAdmin ? S.chatsDismissAdmin : S.chatsMakeAdmin,
            onTap: () => chatStore.setGroupMemberAdmin(
              widget.threadId,
              actorId: widget.myId,
              memberId: memberId,
              isAdmin: !isAdmin,
            ),
          ),
        if (!isSelf)
          ChatsMenuAction(
            rowKey: ValueKey('member-action-message-$memberId'),
            icon: Icons.chat_bubble_outline_rounded,
            label: S.message,
            onTap: () => _openDirectMessage(memberId),
          ),
        if (!isSelf)
          ChatsMenuAction(
            rowKey: ValueKey('member-action-profile-$memberId'),
            icon: Icons.person_outline_rounded,
            label: S.viewProfile,
            onTap: () => _openProfile(memberId),
          ),
        if (canManage && !isSelf && !isCreator && group.memberIds.length > 2)
          ChatsMenuAction(
            rowKey: ValueKey('member-action-remove-$memberId'),
            icon: Icons.person_remove_outlined,
            label: S.chatsRemoveFromGroup,
            destructive: true,
            dividerAbove: true,
            onTap: () => _confirmRemove(memberId),
          ),
      ],
    );
  }

  void _openDirectMessage(String memberId) {
    final user = _userFor(memberId);
    if (user == null) return;
    final threadId = chatStore.ensureDirectThread(widget.myId, memberId);
    if (threadId == null) return;
    Navigator.push(
      context,
      ChatPageRoute(
        builder: (_) => ChatThreadScreen(threadId: threadId, recipient: user),
      ),
    );
  }

  void _openProfile(String memberId) {
    final user = _userFor(memberId);
    if (user == null) return;
    Navigator.push(
      context,
      ChatPageRoute(builder: (_) => UserProfileScreen(user: user)),
    );
  }

  Future<void> _confirmRemove(String memberId) async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameFor(memberId);
    final confirmed = await showChatsConfirmDialog(
      context,
      title: l10n.removeMemberConfirmTitle(name),
      body: l10n.removeMemberConfirmBody(name),
      confirmLabel: l10n.removeLabel,
      cancelLabel: S.cancel,
      confirmKey: const ValueKey('confirm-remove-group-member'),
    );
    if (!confirmed) return;
    chatStore.removeGroupMember(
      widget.threadId,
      actorId: widget.myId,
      memberId: memberId,
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
    final visibleIds = group.memberIds
        .where((id) => id != widget.myId)
        .toList();

    return Scaffold(
      backgroundColor: ChatsColors.background,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            ChatsTopBar(
              title: S.chatsEditGroupInfo,
              trailing: GestureDetector(
                key: const ValueKey('edit-group-cancel'),
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context),
                child: Text(
                  S.cancel,
                  style: figtree(
                    size: 14,
                    weight: FontWeight.w600,
                    color: ChatsColors.muted,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  Center(
                    child: Column(
                      children: [
                        // `GroupPhotoPicker` already owns the whole
                        // pick → crop → save flow and is shared with the
                        // create-group screen, so it is reused rather than
                        // restyled.
                        GroupPhotoPicker(
                          imagePath: group.photoUrl,
                          memberIds: visibleIds,
                          nameForUser: _nameFor,
                          onChanged: (path) =>
                              chatStore.setGroupPhoto(widget.threadId, path),
                          size: 88,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          S.chatsChangeGroupPhoto,
                          style: figtree(
                            size: 13,
                            weight: FontWeight.w600,
                            color: ChatsColors.accentText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ChatsInputField(
                    label: S.chatsGroupNameLabel,
                    controller: _nameController,
                    hint: l10n.groupNameHint,
                    maxLength: 100,
                    trailingIcon: Icons.edit_outlined,
                    fieldKey: const ValueKey('edit-group-name-field'),
                  ),
                  const SizedBox(height: 20),
                  ChatsInputField(
                    label: S.chatsDescriptionLabel,
                    controller: _descriptionController,
                    hint: S.chatsDescriptionHint,
                    maxLines: 4,
                    maxLength: 280,
                    fieldKey: const ValueKey('edit-group-description-field'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    S.chatsDescriptionLocalNote,
                    style: figtree(
                      size: 11,
                      weight: FontWeight.w400,
                      color: ChatsColors.muted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ChatsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ChatsSectionLabel(
                                S.chatsMembersCount(group.memberIds.length),
                              ),
                            ),
                            if (canManage)
                              GestureDetector(
                                key: const ValueKey('edit-group-add-member'),
                                behavior: HitTestBehavior.opaque,
                                onTap: _openAddMembers,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.add_rounded,
                                      size: 14,
                                      color: ChatsColors.accentText,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      l10n.add,
                                      style: figtree(
                                        size: 12,
                                        weight: FontWeight.w700,
                                        color: ChatsColors.accentText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final id in group.memberIds)
                          _buildMemberRow(id, group.creatorId, l10n),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ChatsPrimaryButton(
                    key: const ValueKey('edit-group-save'),
                    label: S.chatsSaveChanges,
                    onTap: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberRow(String id, String creatorId, AppLocalizations l10n) {
    final group = chatStore.groupForThread(widget.threadId);
    final isAdmin = group?.isAdmin(id) ?? false;
    return InkWell(
      key: ValueKey('edit-group-member-$id'),
      onTap: () => _openMemberActions(id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            UserAvatar(userId: id, name: _nameFor(id), size: 38, fontSize: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
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
                  const SizedBox(height: 1),
                  Text(
                    id == creatorId
                        ? l10n.groupCreatorAdminLabel
                        : isAdmin
                        ? l10n.groupAdminLabel
                        : S.chatsMemberRole,
                    style: figtree(
                      size: 11,
                      weight: FontWeight.w500,
                      color: ChatsColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.more_horiz_rounded, size: 18, color: ChatsColors.muted),
          ],
        ),
      ),
    );
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
}

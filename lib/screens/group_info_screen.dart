import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/chat_store.dart';
import '../services/people_service.dart';
import '../services/user_state.dart';
import '../widgets/group_avatar_stack.dart';
import '../widgets/group_photo_picker.dart';
import '../widgets/user_avatar.dart';

enum _GroupMemberAction { makeAdmin, dismissAdmin, remove }

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
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: chatStore.groupForThread(widget.threadId)?.customName ?? '',
    );
    chatStore.addListener(_refresh);
    unawaited(_hydratePeople());
  }

  @override
  void dispose() {
    chatStore.removeListener(_refresh);
    _nameController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _hydratePeople() async {
    final ids = chatStore.groupParticipants(widget.threadId);
    await peopleService.hydrateProfilesByIds(ids);
    if (mounted) setState(() {});
  }

  User? _userFor(String id) {
    final cached = peopleService.cachedPeople.where((user) => user.id == id);
    if (cached.isNotEmpty) return cached.first;
    return null;
  }

  String _nameFor(String id) {
    final user = _userFor(id);
    return userState.displayNameFor(id, user?.name ?? id);
  }

  void _saveName() {
    chatStore.setGroupCustomName(widget.threadId, _nameController.text);
    FocusScope.of(context).unfocus();
  }

  Future<void> _confirmAndRemoveMember(String memberId) async {
    final memberName = _nameFor(memberId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove $memberName?'),
        content: Text(
          'Are you sure you want to remove $memberName from this group?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-remove-group-member'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    chatStore.removeGroupMember(
      widget.threadId,
      actorId: widget.myId,
      memberId: memberId,
    );
  }

  Future<void> _handleMemberAction(
    _GroupMemberAction action,
    String memberId,
  ) async {
    switch (action) {
      case _GroupMemberAction.makeAdmin:
        chatStore.setGroupMemberAdmin(
          widget.threadId,
          actorId: widget.myId,
          memberId: memberId,
          isAdmin: true,
        );
        return;
      case _GroupMemberAction.dismissAdmin:
        chatStore.setGroupMemberAdmin(
          widget.threadId,
          actorId: widget.myId,
          memberId: memberId,
          isAdmin: false,
        );
        return;
      case _GroupMemberAction.remove:
        await _confirmAndRemoveMember(memberId);
        return;
    }
  }

  Future<void> _showAddMembers() async {
    try {
      await peopleService.fetchPeople(excludeId: widget.myId);
    } catch (_) {
      // The locally cached directory still provides a complete offline flow.
    }
    if (!mounted) return;
    var query = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final existing = chatStore.groupParticipants(widget.threadId).toSet();
          final known =
              <String, User>{
                for (final user in peopleService.cachedPeople) user.id: user,
              }.values.where((user) {
                if (existing.contains(user.id) || user.id == widget.myId) {
                  return false;
                }
                final needle = query.trim().toLowerCase();
                return needle.isEmpty ||
                    _nameFor(user.id).toLowerCase().contains(needle);
              }).toList();
          return Container(
            height: MediaQuery.sizeOf(context).height * 0.7,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Add members',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      autofocus: true,
                      onChanged: (value) => setSheetState(() => query = value),
                      decoration: InputDecoration(
                        hintText: 'Search people',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: AppColors.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: known.isEmpty
                        ? Center(
                            child: Text(
                              'No more people to add',
                              style: TextStyle(color: AppColors.secondaryText),
                            ),
                          )
                        : ListView.builder(
                            itemCount: known.length,
                            itemBuilder: (context, index) {
                              final user = known[index];
                              return ListTile(
                                leading: UserAvatar(
                                  userId: user.id,
                                  name: _nameFor(user.id),
                                  size: 42,
                                  fontSize: 15,
                                ),
                                title: Text(
                                  _nameFor(user.id),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.add_circle_rounded,
                                  color: AppColors.primaryRed,
                                ),
                                onTap: () {
                                  chatStore.addGroupMembers(widget.threadId, [
                                    user.id,
                                  ], actorId: widget.myId);
                                  Navigator.pop(sheetContext);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = chatStore.groupForThread(widget.threadId);
    if (group == null) {
      return const Scaffold(body: Center(child: Text('Group unavailable')));
    }
    final canManage = group.isAdmin(widget.myId);
    final visibleIds = group.memberIds
        .where((id) => id != widget.myId)
        .toList();
    final title = chatStore.groupDisplayName(widget.threadId, widget.myId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
        title: const Text('Group info'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          Center(
            child: canManage
                ? GroupPhotoPicker(
                    imagePath: group.photoUrl,
                    memberIds: visibleIds,
                    nameForUser: _nameFor,
                    onChanged: (path) =>
                        chatStore.setGroupPhoto(widget.threadId, path),
                    size: 88,
                  )
                : GroupAvatarStack(
                    memberIds: visibleIds,
                    nameForUser: _nameFor,
                    photoPath: group.photoUrl,
                    size: 88,
                  ),
          ),
          const SizedBox(height: 13),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 18),
          if (canManage)
            TextField(
              key: const ValueKey('edit-group-name-field'),
              controller: _nameController,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _saveName(),
              decoration: InputDecoration(
                labelText: 'Group name (optional)',
                hintText: 'Enter group name',
                counterText: '',
                suffixIcon: IconButton(
                  tooltip: 'Save group name',
                  onPressed: _saveName,
                  icon: const Icon(Icons.check_rounded),
                ),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                '${group.memberIds.length} members',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              if (canManage)
                TextButton.icon(
                  onPressed: _showAddMembers,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Add'),
                ),
            ],
          ),
          ...group.memberIds.map((id) {
            final isCreator = id == group.creatorId;
            final isAdmin = group.isAdmin(id);
            final canActOnMember = canManage && id != widget.myId && !isCreator;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: UserAvatar(
                userId: id,
                name: _nameFor(id),
                size: 44,
                fontSize: 16,
              ),
              title: Text(
                id == widget.myId ? '${_nameFor(id)} (You)' : _nameFor(id),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              subtitle: isCreator
                  ? const Text('Group creator · Admin')
                  : isAdmin
                  ? const Text('Group admin')
                  : null,
              trailing: canActOnMember
                  ? PopupMenuButton<_GroupMemberAction>(
                      key: ValueKey('group-member-actions-$id'),
                      tooltip: 'Member actions',
                      onSelected: (action) => _handleMemberAction(action, id),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: isAdmin
                              ? _GroupMemberAction.dismissAdmin
                              : _GroupMemberAction.makeAdmin,
                          child: Text(
                            isAdmin
                                ? 'Dismiss as group admin'
                                : 'Make group admin',
                          ),
                        ),
                        if (group.memberIds.length > 2)
                          const PopupMenuItem(
                            value: _GroupMemberAction.remove,
                            child: Text('Remove member'),
                          ),
                      ],
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.secondaryText,
                      ),
                    )
                  : null,
            );
          }),
        ],
      ),
    );
  }
}

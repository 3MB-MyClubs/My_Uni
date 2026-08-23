import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/chat_group.dart';
import '../models/user.dart';
import '../services/app_strings.dart';
import '../services/chat_store.dart';
import '../services/people_service.dart';
import '../services/user_state.dart';
import '../widgets/chats_design.dart';
import '../widgets/clubup_design.dart';
import '../widgets/group_photo_picker.dart';
import '../widgets/user_avatar.dart';

class CreateGroupScreen extends StatefulWidget {
  final String myId;
  final List<User> initialMembers;

  const CreateGroupScreen({
    super.key,
    required this.myId,
    required this.initialMembers,
  });

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  late final Map<String, User> _selected;
  String _query = '';
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _selected = {
      for (final member in widget.initialMembers)
        if (member.id != widget.myId) member.id: member,
    };
    _nameController.addListener(_refresh);
    unawaited(_hydratePeople());
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_refresh)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _hydratePeople() async {
    try {
      await peopleService.fetchPeople(excludeId: widget.myId);
    } catch (_) {
      // The local directory remains available offline and in widget tests.
    }
    if (mounted) setState(() {});
  }

  List<User> get _candidates {
    final known = <String, User>{
      for (final user in peopleService.cachedPeople) user.id: user,
      ..._selected,
    }.values.where((user) => user.id != widget.myId);
    final query = _query.trim().toLowerCase();
    final filtered = known.where((user) {
      if (query.isEmpty) return true;
      final displayName = _nameFor(user.id, fallback: user.name);
      return displayName.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query);
    }).toList();
    filtered.sort((a, b) {
      final aSelected = _selected.containsKey(a.id);
      final bSelected = _selected.containsKey(b.id);
      if (aSelected != bSelected) return aSelected ? -1 : 1;
      return _nameFor(
        a.id,
        fallback: a.name,
      ).compareTo(_nameFor(b.id, fallback: b.name));
    });
    return filtered;
  }

  String _nameFor(String userId, {String? fallback}) {
    final known = _selected[userId];
    return userState.displayNameFor(userId, fallback ?? known?.name ?? userId);
  }

  String get _automaticName => ChatGroup.automaticName(
    _selected.values.map(
      (member) => _nameFor(member.id, fallback: member.name),
    ),
  );

  String get _displayName {
    final custom = _nameController.text.trim();
    return custom.isEmpty ? _automaticName : custom;
  }

  void _toggle(User user) {
    setState(() {
      if (_selected.containsKey(user.id)) {
        _selected.remove(user.id);
      } else {
        _selected[user.id] = user;
      }
    });
  }

  void _createGroup() {
    if (_selected.length < 2) return;
    final threadId = chatStore.createGroupThread(
      creatorId: widget.myId,
      recipientIds: _selected.keys,
      customName: _nameController.text,
      photoPath: _photoPath,
    );
    if (threadId != null) Navigator.pop(context, threadId);
  }

  // The handoff has no create-group frame — the CHATS section jumps straight
  // from the inbox to a thread — so this screen keeps its own structure and
  // borrows the area's type, palette and row shapes from `add-member`
  // (`105:358`) and `edit-group-info` (`107:82`) so the compose flow does not
  // hand off into the old chrome mid-way.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canCreate = _selected.length >= 2;

    return Scaffold(
      backgroundColor: ChatsColors.background,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            ChatsTopBar(title: l10n.createGroupTitle),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: GroupPhotoPicker(
                      key: ValueKey(_selected.keys.join('|')),
                      memberIds: _selected.keys.toList(),
                      nameForUser: _nameFor,
                      imagePath: _photoPath,
                      onChanged: (path) => setState(() => _photoPath = path),
                      size: 82,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _photoPath == null
                        ? l10n.addGroupPhoto
                        : l10n.changeGroupPhoto,
                    style: figtree(
                      size: 13,
                      weight: FontWeight.w600,
                      color: ChatsColors.accentText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      _displayName,
                      key: ValueKey(_displayName),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: figtree(
                        size: 20,
                        weight: FontWeight.w800,
                        color: ChatsColors.text,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ChatsInputField(
                    label: S.chatsGroupNameLabel,
                    controller: _nameController,
                    hint: l10n.groupNameHint,
                    maxLength: 100,
                    trailingIcon: Icons.edit_outlined,
                    fieldKey: const ValueKey('group-name-field'),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      ChatsSectionLabel(
                        S.chatsMembersCount(_selected.length + 1),
                      ),
                      const Spacer(),
                      if (!canCreate)
                        Text(
                          S.chatsSelectAtLeastTwo,
                          style: figtree(
                            size: 11,
                            weight: FontWeight.w500,
                            color: ChatsColors.muted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: ChatsColors.fill,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 16,
                          color: ChatsColors.muted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            key: const ValueKey('create-group-member-search'),
                            controller: _searchController,
                            onChanged: (value) =>
                                setState(() => _query = value),
                            style: figtree(
                              size: 13,
                              weight: FontWeight.w500,
                              color: ChatsColors.text,
                            ),
                            decoration: InputDecoration(
                              hintText: S.chatsSearchContacts,
                              hintStyle: figtree(
                                size: 13,
                                weight: FontWeight.w400,
                                color: ChatsColors.muted,
                              ),
                              isDense: true,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: _candidates.length,
                itemBuilder: (context, index) {
                  final user = _candidates[index];
                  final selected = _selected.containsKey(user.id);
                  return InkWell(
                    key: ValueKey('create-group-member-${user.id}'),
                    onTap: () => _toggle(user),
                    child: SizedBox(
                      height: 54,
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          UserAvatar(
                            userId: user.id,
                            name: _nameFor(user.id, fallback: user.name),
                            size: 38,
                            fontSize: 14,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _nameFor(user.id, fallback: user.name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: figtree(
                                size: 14,
                                weight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: ChatsColors.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? ChatsColors.accent
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? ChatsColors.accent
                                    : ChatsColors.border,
                                width: 1.5,
                              ),
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: ChatsColors.onAccent,
                                    size: 14,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: ChatsPrimaryButton(
                  key: const ValueKey('create-group-button'),
                  label: l10n.createGroupTitle,
                  onTap: canCreate ? _createGroup : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

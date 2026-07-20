import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../models/chat_group.dart';
import '../models/user.dart';
import '../services/app_colors.dart';
import '../services/chat_store.dart';
import '../services/mock_data.dart';
import '../services/people_service.dart';
import '../services/user_state.dart';
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
      for (final user in users) user.id: user,
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
    final mockIndex = users.indexWhere((user) => user.id == userId);
    return userState.displayNameFor(
      userId,
      fallback ??
          known?.name ??
          (mockIndex == -1 ? userId : users[mockIndex].name),
    );
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

  @override
  Widget build(BuildContext context) {
    final canCreate = _selected.length >= 2;
    final selectedIds = _selected.keys.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
        title: const Text(
          'Create Group',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Column(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: GroupPhotoPicker(
                      key: ValueKey(selectedIds.join('|')),
                      memberIds: selectedIds,
                      nameForUser: _nameFor,
                      imagePath: _photoPath,
                      onChanged: (path) => setState(() => _photoPath = path),
                      size: 82,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _photoPath == null
                        ? 'Add group photo'
                        : 'Change group photo',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryText,
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
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const ValueKey('group-name-field'),
                    controller: _nameController,
                    maxLength: 100,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(color: AppColors.text),
                    decoration: InputDecoration(
                      hintText: 'Enter group name',
                      counterText: '',
                      prefixIcon: const Icon(Icons.edit_rounded, size: 20),
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Members',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(width: 7),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lightRed,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_selected.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!canCreate)
                        Text(
                          'Select at least 2',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    key: const ValueKey('create-group-member-search'),
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    style: TextStyle(fontSize: 13.5, color: AppColors.text),
                    decoration: InputDecoration(
                      hintText: 'Search people',
                      prefixIcon: const Icon(Icons.search_rounded, size: 19),
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 9,
                      ),
                      child: Row(
                        children: [
                          UserAvatar(
                            userId: user.id,
                            name: _nameFor(user.id, fallback: user.name),
                            size: 42,
                            fontSize: 15,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _nameFor(user.id, fallback: user.name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primaryRed
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? AppColors.primaryRed
                                    : AppColors.divider,
                                width: 1.5,
                              ),
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  key: const ValueKey('create-group-button'),
                  onPressed: canCreate ? _createGroup : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    disabledBackgroundColor: AppColors.surfaceAlt,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Create Group',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

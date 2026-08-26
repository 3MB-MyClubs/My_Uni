import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/user.dart';
import '../services/app_strings.dart';
import '../services/chat_store.dart';
import '../services/moderation_service.dart';
import '../services/people_service.dart';
import '../services/user_state.dart';
import '../widgets/chats_design.dart';
import '../widgets/clubup_design.dart';
import '../widgets/user_avatar.dart';

/// `add-member` — Figma `105:329` / `105:390`.
///
/// A full screen rather than the sheet the old group-info opened, and it
/// batches: pick several people, then Done adds them in one call. The
/// "Suggested" list is the cached people directory minus the current members,
/// which is the only candidate source the app has.
class AddMembersScreen extends StatefulWidget {
  final String threadId;
  final String myId;

  const AddMembersScreen({
    super.key,
    required this.threadId,
    required this.myId,
  });

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  String _query = '';
  final Map<String, User> _selected = {};

  @override
  void initState() {
    super.initState();
    unawaited(_hydrate());
  }

  Future<void> _hydrate() async {
    try {
      await peopleService.fetchPeople(excludeId: widget.myId);
    } catch (_) {
      // The cached directory still gives a complete offline flow.
    }
    if (mounted) setState(() {});
  }

  String _nameFor(User user) => userState.displayNameFor(user.id, user.name);

  void _commit() {
    if (_selected.isNotEmpty) {
      chatStore.addGroupMembers(
        widget.threadId,
        _selected.keys.toList(),
        actorId: widget.myId,
      );
    }
    Navigator.pop(context, _selected.length);
  }

  @override
  Widget build(BuildContext context) {
    final existing = chatStore.groupParticipants(widget.threadId).toSet();
    final needle = _query.trim().toLowerCase();
    final candidates =
        <String, User>{
            for (final user in peopleService.cachedPeople) user.id: user,
            ..._selected,
          }.values.where((user) {
            if (existing.contains(user.id) || user.id == widget.myId) {
              return false;
            }
            if (moderationService.isUserBlocked(user.id)) return false;
            if (needle.isEmpty) return true;
            return _nameFor(user).toLowerCase().contains(needle) ||
                user.email.toLowerCase().contains(needle);
          }).toList()
          ..sort(
            (a, b) =>
                _nameFor(a).toLowerCase().compareTo(_nameFor(b).toLowerCase()),
          );

    return Scaffold(
      backgroundColor: ChatsColors.background,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            ChatsTopBar(
              title: AppLocalizations.of(context)!.addMembersTitle,
              trailing: GestureDetector(
                key: const ValueKey('add-members-done'),
                behavior: HitTestBehavior.opaque,
                onTap: _commit,
                child: Text(
                  S.done,
                  style: figtree(
                    size: 14,
                    weight: FontWeight.w700,
                    color: _selected.isEmpty
                        ? ChatsColors.muted
                        : ChatsColors.accentText,
                  ),
                ),
              ),
            ),
            _buildSearch(),
            if (_selected.isNotEmpty) _buildSelectedTrack(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ChatsSectionLabel(S.chatsSuggested),
              ),
            ),
            Expanded(
              child: candidates.isEmpty
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context)!.noMorePeopleToAdd,
                        style: figtree(
                          size: 13,
                          weight: FontWeight.w400,
                          color: ChatsColors.muted,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 40),
                      itemCount: candidates.length,
                      itemBuilder: (context, index) =>
                          _buildRow(candidates[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// `search-bar` 105:348.
  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: ChatsColors.fill,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 16, color: ChatsColors.muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const ValueKey('add-members-search'),
                onChanged: (value) => setState(() => _query = value),
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
    );
  }

  /// `selected-track` 105:351 — accent-tinted chips with a clear button.
  Widget _buildSelectedTrack() {
    return SizedBox(
      height: 41,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        itemCount: _selected.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final user = _selected.values.elementAt(index);
          return Container(
            height: 29,
            padding: const EdgeInsets.only(left: 12, right: 6),
            decoration: BoxDecoration(
              color: ChatsColors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Text(
                  _nameFor(user),
                  style: figtree(
                    size: 12,
                    weight: FontWeight.w600,
                    color: ChatsColors.accentText,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  key: ValueKey('add-members-chip-remove-${user.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selected.remove(user.id)),
                  child: Icon(
                    Icons.cancel_rounded,
                    size: 14,
                    color: ChatsColors.accentText,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// `member-row` 105:358 — 54pt tall with a 22pt radio on the right.
  Widget _buildRow(User user) {
    final selected = _selected.containsKey(user.id);
    return InkWell(
      key: ValueKey('add-members-row-${user.id}'),
      onTap: () => setState(() {
        if (selected) {
          _selected.remove(user.id);
        } else {
          _selected[user.id] = user;
        }
      }),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            const SizedBox(width: 16),
            UserAvatar(
              userId: user.id,
              name: _nameFor(user),
              size: 38,
              fontSize: 14,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _nameFor(user),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: figtree(
                  size: 14,
                  weight: FontWeight.w600,
                  color: ChatsColors.text,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? ChatsColors.accent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? ChatsColors.accent : ChatsColors.border,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: ChatsColors.onAccent,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

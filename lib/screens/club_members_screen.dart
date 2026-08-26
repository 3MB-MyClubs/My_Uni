import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../models/club.dart';
import '../models/user.dart';
import '../navigation/chat_page_route.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/chat_store.dart';
import '../services/people_service.dart';
import '../services/student_club_role_service.dart';
import '../services/user_state.dart';
import '../widgets/chats_design.dart';
import '../widgets/clubup_design.dart';
import '../widgets/user_avatar.dart';
import 'chat_thread_screen.dart';
import 'user_profile_screen.dart';

/// `club-member-list` — Figma `142:231` / `142:323`.
///
/// Grouped Admins / Moderators / Members, from the club's own
/// `adminUserIds` + `boardMemberIds` and the member directory
/// `peopleService.fetchClubMembers` already serves the club room.
///
/// Two lines on the frame have **no data behind them** and are not drawn:
/// the activity lines ("Active 2 hours ago", "Joined 3 months ago") — nothing
/// stores a last-seen or a join date — and the `+ Invite` control, because the
/// app has no club-invite concept at all. The secondary line carries the
/// member's real board title instead.
class ClubMembersScreen extends StatefulWidget {
  final Club club;
  final String myId;

  const ClubMembersScreen({super.key, required this.club, required this.myId});

  @override
  State<ClubMembersScreen> createState() => _ClubMembersScreenState();
}

class _ClubMembersScreenState extends State<ClubMembersScreen> {
  List<User> _members = const [];
  bool _loading = true;
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    List<User> fetched = const [];
    try {
      fetched = await peopleService.fetchClubMembers(widget.club.id);
    } catch (_) {
      // Offline, or before the first sync — fall through to the local ids.
    }
    if (!mounted) return;
    setState(() {
      _members = fetched.isNotEmpty ? fetched : _localMembers();
      _loading = false;
    });
  }

  /// What the device already knows about this club's people: its admin and
  /// board ids, plus any cached profile that subscribes to it. Used when the
  /// directory fetch returns nothing, so the screen is never blank offline.
  List<User> _localMembers() {
    final club = widget.club;
    final wanted = {...club.adminUserIds, ...club.boardMemberIds};
    final byId = <String, User>{};
    for (final user in peopleService.cachedPeople) {
      if (wanted.contains(user.id) ||
          user.subscribedClubIds.contains(club.id)) {
        byId[user.id] = user;
      }
    }
    final me = authService.currentUser;
    if (me != null) byId[me.id] = me;
    return byId.values.toList();
  }

  String _nameFor(User user) => userState.displayNameFor(user.id, user.name);

  /// The frame's secondary line. "Created the club" for the first admin, the
  /// board title for a board member, otherwise the plain member label.
  String _subtitleFor(User user) {
    final club = widget.club;
    if (club.adminUserIds.isNotEmpty && user.id == club.adminUserIds.first) {
      return S.clubCreatedTheClub;
    }
    final title = studentClubRoleService.roleTitleFor(club, user.id);
    return title ?? S.clubMemberRole;
  }

  void _openProfile(User user) {
    if (user.id == widget.myId) return;
    Navigator.push(
      context,
      ChatPageRoute(builder: (_) => UserProfileScreen(user: user)),
    );
  }

  void _openDirectMessage(User user) {
    final threadId = chatStore.ensureDirectThread(widget.myId, user.id);
    if (threadId == null) return;
    Navigator.push(
      context,
      ChatPageRoute(
        builder: (_) => ChatThreadScreen(threadId: threadId, recipient: user),
      ),
    );
  }

  void _openMemberActions(User user) {
    showChatsMenuSheet(
      context,
      sheetKey: ValueKey('club-member-actions-${user.id}'),
      actions: [
        ChatsMenuAction(
          rowKey: ValueKey('club-member-message-${user.id}'),
          icon: Icons.chat_bubble_outline_rounded,
          label: S.message,
          onTap: () => _openDirectMessage(user),
        ),
        ChatsMenuAction(
          rowKey: ValueKey('club-member-profile-${user.id}'),
          icon: Icons.person_outline_rounded,
          label: S.viewProfile,
          onTap: () => _openProfile(user),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.club;
    final needle = _query.trim().toLowerCase();
    final visible = _members
        .where(
          (user) =>
              needle.isEmpty || _nameFor(user).toLowerCase().contains(needle),
        )
        .toList();
    final admins = visible
        .where((user) => club.adminUserIds.contains(user.id))
        .toList();
    final moderators = visible
        .where(
          (user) =>
              !club.adminUserIds.contains(user.id) &&
              club.boardMemberIds.contains(user.id),
        )
        .toList();
    final plain = visible
        .where(
          (user) =>
              !club.adminUserIds.contains(user.id) &&
              !club.boardMemberIds.contains(user.id),
        )
        .toList();

    return Scaffold(
      backgroundColor: ChatsColors.background,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            ChatsTopBar(
              title: S.clubMembersTitle,
              trailing: GestureDetector(
                key: const ValueKey('club-members-search-toggle'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) _query = '';
                }),
                child: SizedBox(
                  width: 24,
                  height: 48,
                  child: Icon(
                    _searching ? Icons.close_rounded : Icons.search_rounded,
                    size: 20,
                    color: ChatsColors.text,
                  ),
                ),
              ),
            ),
            if (_searching) _buildSearchField(),
            _buildCountRow(club),
            Expanded(
              child: _loading
                  ? Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ChatsColors.accent,
                        ),
                      ),
                    )
                  : visible.isEmpty
                  ? Center(
                      child: Text(
                        S.clubNoMemberMatches,
                        style: figtree(
                          size: 13,
                          weight: FontWeight.w400,
                          color: ChatsColors.muted,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 40),
                      children: [
                        if (admins.isNotEmpty) ...[
                          _sectionLabel(S.clubSectionAdmins),
                          for (final user in admins)
                            _memberRow(user, badge: S.admin),
                        ],
                        if (moderators.isNotEmpty) ...[
                          _sectionLabel(S.clubSectionModerators),
                          for (final user in moderators)
                            _memberRow(user, badge: S.clubRoleMod, mod: true),
                        ],
                        if (plain.isNotEmpty) ...[
                          _sectionLabel(S.clubSectionMembers),
                          for (final user in plain) _memberRow(user),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// `search-field` 142:253.
  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                key: const ValueKey('club-members-search'),
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                style: figtree(
                  size: 13,
                  weight: FontWeight.w500,
                  color: ChatsColors.text,
                ),
                decoration: InputDecoration(
                  hintText: S.clubSearchMembers,
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

  /// `142:257` — the count row. The frame's `+ Invite` sits on the right; the
  /// app has no invite flow, so the row carries only the count.
  Widget _buildCountRow(Club club) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            S.clubMembersAndUnread(_members.length, 0),
            style: figtree(
              size: 13,
              weight: FontWeight.w700,
              color: ChatsColors.text,
            ),
          ),
        ],
      ),
    );
  }

  /// `142:263` — an uppercase muted section label.
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: figtree(
          size: 11,
          weight: FontWeight.w700,
          color: ChatsColors.muted,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  /// `member-row` 142:265 — 64pt tall, a 44pt avatar and a role chip or an
  /// overflow button on the right.
  Widget _memberRow(User user, {String? badge, bool mod = false}) {
    final isMe = user.id == widget.myId;
    return InkWell(
      key: ValueKey('club-member-row-${user.id}'),
      onTap: isMe ? null : () => _openProfile(user),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            const SizedBox(width: 16),
            UserAvatar(
              userId: user.id,
              name: _nameFor(user),
              size: 44,
              fontSize: 17,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nameFor(user),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: figtree(
                      size: 14,
                      weight: FontWeight.w700,
                      color: ChatsColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _subtitleFor(user),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: figtree(
                      size: 11,
                      weight: FontWeight.w500,
                      color: ChatsColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (isMe)
              _RoleChip(label: S.clubRoleYou, neutral: true)
            else if (badge != null)
              _RoleChip(label: badge, mod: mod)
            else
              GestureDetector(
                key: ValueKey('club-member-overflow-${user.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _openMemberActions(user),
                child: SizedBox(
                  width: 24,
                  height: 64,
                  child: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: ChatsColors.muted,
                  ),
                ),
              ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

/// `badge` 142:270 — accent for Admin, a cool tint for Mod, neutral for You.
class _RoleChip extends StatelessWidget {
  final String label;
  final bool mod;
  final bool neutral;

  const _RoleChip({
    required this.label,
    this.mod = false,
    this.neutral = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = neutral
        ? ChatsColors.muted
        : mod
        ? const Color(0xFF2563EB)
        : ChatsColors.accentText;
    return Container(
      height: 21,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: neutral ? ChatsColors.fill : tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: figtree(size: 11, weight: FontWeight.w700, color: tint),
      ),
    );
  }
}

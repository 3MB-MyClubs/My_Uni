import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/club.dart';
import '../models/user.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/club_role_localization.dart';
import '../services/people_service.dart';
import '../services/student_club_role_service.dart';
import '../services/user_state.dart';
import '../widgets/club_profile_design.dart';
import '../widgets/user_avatar.dart';
import 'user_profile_screen.dart';

/// The full member directory opened from the Members stat on a club profile.
///
/// Its chrome intentionally mirrors the Board Members screen: a compact
/// profile header, the same search card, and the same member row cards. The
/// data itself comes from the club-followers directory, so only students who
/// joined this club are shown.
class ClubProfileMembersScreen extends StatefulWidget {
  const ClubProfileMembersScreen({
    super.key,
    required this.club,
    this.initialMembers = const [],
  });

  final Club club;

  /// Locally known members keep the directory useful while the live follower
  /// query is loading or when the device is offline.
  final List<User> initialMembers;

  @override
  State<ClubProfileMembersScreen> createState() =>
      _ClubProfileMembersScreenState();
}

class _ClubProfileMembersScreenState extends State<ClubProfileMembersScreen> {
  final TextEditingController _search = TextEditingController();
  late List<User> _members = _sorted(widget.initialMembers);
  String _query = '';
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMembers());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<User> _sorted(Iterable<User> source) {
    final byId = <String, User>{for (final user in source) user.id: user};
    final members = byId.values.toList();
    members.sort((a, b) {
      final aBoard = widget.club.boardMemberIds.contains(a.id);
      final bBoard = widget.club.boardMemberIds.contains(b.id);
      if (aBoard != bBoard) return aBoard ? -1 : 1;
      final aName = userState.displayNameFor(a.id, a.name).toLowerCase();
      final bName = userState.displayNameFor(b.id, b.name).toLowerCase();
      return aName.compareTo(bName);
    });
    return members;
  }

  Future<void> _loadMembers() async {
    try {
      final fetched = await peopleService.fetchClubMembers(widget.club.id);
      if (!mounted) return;
      setState(() {
        _members = _sorted(
          peopleService.reconcileCurrentClubMember(
            fetchedMembers: fetched,
            fallbackMembers: _members,
            currentUser: authService.currentUser,
            currentUserIsFollowing: userState.isFollowing(widget.club.id),
          ),
        );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _members = _sorted(
          peopleService.reconcileCurrentClubMember(
            fetchedMembers: const [],
            fallbackMembers: _members,
            currentUser: authService.currentUser,
            currentUserIsFollowing: userState.isFollowing(widget.club.id),
          ),
        );
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  List<User> get _shown {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _members;
    return _members.where((member) {
      final name = userState.displayNameFor(member.id, member.name);
      return name.toLowerCase().contains(query) ||
          member.email.toLowerCase().contains(query);
    }).toList();
  }

  String _roleFor(BuildContext context, User member) {
    if (widget.club.adminUserIds.isNotEmpty &&
        member.id == widget.club.adminUserIds.first) {
      return S.clubCreatedTheClub;
    }
    final role = studentClubRoleService.roleTitleFor(widget.club, member.id);
    return role == null
        ? S.clubMemberRole
        : localizedClubRole(AppLocalizations.of(context)!, role);
  }

  void _openProfile(User member) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(user: member)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shown = _shown;

    return Scaffold(
      backgroundColor: ClubProfileColors.page,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClubProfileHeaderBar(
              key: const ValueKey('club-profile-members-header'),
              title: l10n.members,
              compact: true,
              onBack: () => Navigator.maybePop(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kClubProfileGutter,
                12,
                kClubProfileGutter,
                12,
              ),
              child: ClubProfileCard(
                key: const ValueKey('club-profile-members-search-card'),
                padding: const EdgeInsets.all(16),
                child: ClubProfileSearchField(
                  controller: _search,
                  hint: S.clubProfileSearchMembers,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            ),
            Expanded(
              child: _loading && _members.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        key: ValueKey('club-profile-members-loading'),
                      ),
                    )
                  : shown.isEmpty
                  ? ListView(
                      children: [
                        ClubProfileEmptyState(
                          icon: Icons.people_outline_rounded,
                          title: _query.trim().isNotEmpty
                              ? S.clubNoMemberMatches
                              : l10n.noMembersToShowYet,
                          message: _query.trim().isEmpty && _loadFailed
                              ? l10n.memberProfilesLoadError
                              : null,
                        ),
                      ],
                    )
                  : ListView.separated(
                      key: const ValueKey('club-profile-members-list'),
                      padding: const EdgeInsets.fromLTRB(
                        kClubProfileGutter,
                        0,
                        kClubProfileGutter,
                        28,
                      ),
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final member = shown[index];
                        return ClubProfileMemberRow(
                          key: ValueKey('club-profile-member-${member.id}'),
                          avatar: UserAvatar(
                            userId: member.id,
                            name: member.name,
                            size: 44,
                            fontSize: 18,
                          ),
                          name: userState.displayNameFor(
                            member.id,
                            member.name,
                          ),
                          role: _roleFor(context, member),
                          showChevron: true,
                          onTap: () => _openProfile(member),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

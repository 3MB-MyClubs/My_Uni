import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/club.dart';
import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../services/auth_service.dart';
import '../services/chat_store.dart';
import '../services/mock_data.dart';
import '../services/people_service.dart';
import '../services/student_club_role_service.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import '../widgets/club_avatar.dart';
import '../widgets/student_campus_profile.dart';
import '../widgets/user_avatar.dart';
import 'chat_thread_screen.dart';
import 'club_profile_screen.dart';
import 'saved_posts_screen.dart';

// ── Design palette ─────────────────────────────────────────────────────────────
const _burgundy = Color(0xFF8C1D40);

class UserProfileScreen extends StatefulWidget {
  final User user;
  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _connectionsLoading = false;
  String? _connectionsError;
  static const List<Color> _clubColors = [
    Color(0xFF8C1D40),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
  ];

  Color _clubColor(Club club) {
    final idx = clubOrdinal(club.id);
    return _clubColors[(idx < 0 ? 0 : idx) % _clubColors.length];
  }

  bool get _isOwnProfile {
    final myId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    return widget.user.id == myId;
  }

  Map<String, User> get _knownPeopleById {
    final knownPeople = <String, User>{
      for (final user in users) user.id: user,
      for (final user in peopleService.cachedPeople) user.id: user,
    };
    final currentUser = authService.currentUser;
    if (currentUser != null) knownPeople[currentUser.id] = currentUser;
    return knownPeople;
  }

  List<User> get _following {
    if (_isOwnProfile) {
      final knownPeople = _knownPeopleById;
      return userState.followedUserIds
          .map((id) => knownPeople[id])
          .whereType<User>()
          .toList();
    }

    final liveFollowing = peopleService.followingFor(widget.user.id);
    if (liveFollowing.isNotEmpty) return liveFollowing;

    final knownPeople = _knownPeopleById;
    return widget.user.followingUserIds
        .map((id) => knownPeople[id])
        .whereType<User>()
        .toList();
  }

  List<User> get _followers {
    final liveFollowers = peopleService.followersFor(widget.user.id);
    final followers = <String, User>{
      for (final user in liveFollowers) user.id: user,
      for (final user in users.where(
        (u) => u.followingUserIds.contains(widget.user.id),
      ))
        user.id: user,
    };

    final currentUser = authService.currentUser;
    if (!_isOwnProfile &&
        currentUser != null &&
        userState.isFollowingUser(widget.user.id)) {
      followers[currentUser.id] = currentUser;
    }

    return followers.values.toList();
  }

  @override
  void initState() {
    super.initState();
    _hydrateProfile();
  }

  @override
  void didUpdateWidget(covariant UserProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) _hydrateProfile();
  }

  Future<void> _hydrateProfile() async {
    setState(() {
      _connectionsLoading = true;
      _connectionsError = null;
    });
    try {
      await Future.wait([
        peopleService.hydrateConnectionsFor(widget.user.id),
        peopleService.hydrateProfileDetailsFor(widget.user.id),
      ]);
      if (mounted) {
        setState(() => _connectionsLoading = false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connectionsLoading = false;
        _connectionsError = 'Could not load connections.';
      });
    }
  }

  List<Club> get _subscribedClubs {
    final liveIds = peopleService.clubIdsFor(widget.user.id);
    final ids = _isOwnProfile
        ? userState.followedClubIds
        : liveIds.isNotEmpty
        ? liveIds
        : widget.user.subscribedClubIds.toSet();

    return studentClubRoleService.orderedProfileClubs(
      userId: widget.user.id,
      followedClubIds: ids,
      allClubs: clubs,
    );
  }

  void _openClub(Club club) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClubProfileScreen(club: club, color: _clubColor(club)),
      ),
    );
  }

  Future<void> _handleFollowTap() =>
      _toggleUserFollow(widget.user, () => setState(() {}));

  void _openUserProfile(User u) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(user: u)),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return ListenableBuilder(
      listenable: userState,
      builder: (context, _) {
        final subClubs = _subscribedClubs;
        final followingList = _following;
        final followersList = _followers;
        final isFollowingUser = userState.isFollowingUser(user.id);
        final isPending = userState.hasPendingRequest(user.id);
        final memberships = [
          for (final club in subClubs.take(4))
            StudentCampusMembership(
              club: club,
              color: _clubColor(club),
              role: _roleTitleFor(club) ?? 'Member',
              detail:
                  '${subscriptions.where((s) => s.clubId == club.id).length} members',
            ),
        ];

        return StudentCampusProfileView(
          profile: StudentCampusProfile(
            userId: user.id,
            name: userState.displayNameFor(user.id, user.name),
            email: user.email,
            major: userState.majors[user.id] ?? '',
            year: userState.years[user.id] ?? '',
            bio: userState.bios[user.id] ?? '',
            clubs: subClubs.length,
            following: followingList.length,
            followers: followersList.length,
            doubleMajors: userState.doubleMajors[user.id] ?? const [],
            minors: userState.minors[user.id] ?? const [],
          ),
          title: _isOwnProfile ? 'My Profile' : 'Student Profile',
          leading: StudentProfileIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Back',
            onTap: () => Navigator.maybePop(context),
          ),
          trailing: _isOwnProfile
              ? StudentProfileIconButton(
                  icon: Icons.bookmark_outline_rounded,
                  tooltip: 'Saved posts',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SavedPostsScreen()),
                  ),
                )
              : const SizedBox(width: 36, height: 36),
          primaryAction: !_isOwnProfile && authService.isStudentSession
              ? Row(
                  children: [
                    Expanded(
                      child: StudentProfilePrimaryButton(
                        label: isPending
                            ? 'Requested'
                            : isFollowingUser
                            ? 'Following'
                            : _userFollowsMe(user)
                            ? 'Follow back'
                            : 'Follow',
                        filled: !isFollowingUser && !isPending,
                        onTap: _handleFollowTap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StudentProfilePrimaryButton(
                        label: S.message,
                        filled: false,
                        onTap: () {
                          final myId = authService.currentUser?.id ?? '';
                          final threadId = chatStore.ensureDirectThread(
                            myId,
                            user.id,
                          );
                          if (threadId == null) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatThreadScreen(
                                threadId: threadId,
                                recipient: user,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                )
              : null,
          memberships: memberships,
          clubsTitle: 'CLUBS · ${subClubs.length}',
          clubsActionLabel: subClubs.length > 4 ? 'See all' : null,
          onClubsAction: () => _openConnections(_ConnTab.clubs),
          onClubTap: _openClub,
          onClubsTap: () => _openConnections(_ConnTab.clubs),
          onFollowingTap: () => _openConnections(_ConnTab.following),
          onFollowersTap: () => _openConnections(_ConnTab.followers),
        );
      },
    );
  }

  /// The board role title this student holds at [club], or null if none.
  /// Empty stored titles fall back to a generic "Board Member" label.
  String? _roleTitleFor(Club club) {
    return studentClubRoleService.roleTitleFor(club, widget.user.id);
  }

  void _openConnections(_ConnTab tab) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ConnectionsScreen(
          title: userState.displayNameFor(widget.user.id, widget.user.name),
          initialTab: tab,
          clubsOf: () => _subscribedClubs,
          followersOf: () => _followers,
          followingOf: () => _following,
          roleTitleFor: _roleTitleFor,
          clubColor: _clubColor,
          onOpenClub: _openClub,
          onOpenUser: _openUserProfile,
          peopleLoading: _connectionsLoading,
          peopleError: _connectionsError,
        ),
      ),
    );
  }
}

// ── Follow toggle helper ────────────────────────────────────────────────────────
// Shared by the name-block follow button and every row button inside
// _ConnectionsScreen, so following/unfollowing works the same way regardless
// of which list a person is tapped from.

Future<void> _toggleUserFollow(User target, VoidCallback rebuild) async {
  if (!authService.isStudentSession) return;
  final myId =
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
  if (target.id == myId) return;

  final isFollowing = userState.isFollowingUser(target.id);
  final isPending = userState.hasPendingRequest(target.id);

  if (isFollowing && !isPending) {
    userState.toggleFollowUser(target.id);
    rebuild();
    userPrefsService.save(myId);
    try {
      await peopleService.setFollowing(
        followerId: myId,
        followingId: target.id,
        follow: false,
      );
    } catch (_) {
      userState.toggleFollowUser(target.id);
      rebuild();
      userPrefsService.save(myId);
    }
    return;
  }
  if (isPending) {
    userState.pendingFollowRequests.remove(target.id);
    userState.followedUserIds.remove(target.id);
    rebuild();
    userPrefsService.save(myId);
    return;
  }
  userState.followedUserIds.add(target.id);
  rebuild();
  userPrefsService.save(myId);
  try {
    await peopleService.setFollowing(
      followerId: myId,
      followingId: target.id,
      follow: true,
    );
  } catch (_) {
    userState.followedUserIds.remove(target.id);
    rebuild();
    userPrefsService.save(myId);
  }
}

/// Whether [other] already follows the current session user (drives the
/// "Follow back" vs. plain "Follow" label, same distinction Instagram makes).
bool _userFollowsMe(User other) {
  final myId =
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
  if (myId.isEmpty || other.id == myId) return false;
  if (peopleService.followersFor(myId).any((u) => u.id == other.id)) {
    return true;
  }
  return other.followingUserIds.contains(myId);
}

// ── Connections screen ──────────────────────────────────────────────────────────
// Instagram-style full-screen list with tabs to shuffle between a profile's
// Clubs, Followers and Following, plus a search field — replaces the old
// separate bottom sheets so all three live behind one consistent UI.

enum _ConnTab { clubs, followers, following }

class _ConnectionsScreen extends StatefulWidget {
  final String title;
  final _ConnTab initialTab;
  final List<Club> Function() clubsOf;
  final List<User> Function() followersOf;
  final List<User> Function() followingOf;
  final String? Function(Club) roleTitleFor;
  final Color Function(Club) clubColor;
  final ValueChanged<Club> onOpenClub;
  final ValueChanged<User> onOpenUser;
  final bool peopleLoading;
  final String? peopleError;

  const _ConnectionsScreen({
    required this.title,
    required this.initialTab,
    required this.clubsOf,
    required this.followersOf,
    required this.followingOf,
    required this.roleTitleFor,
    required this.clubColor,
    required this.onOpenClub,
    required this.onOpenUser,
    required this.peopleLoading,
    required this.peopleError,
  });

  @override
  State<_ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<_ConnectionsScreen> {
  late _ConnTab _tab = widget.initialTab;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Club> _matchClubs(List<Club> list) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  List<User> _matchPeople(List<User> list) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((u) {
      final displayName = userState.displayNameFor(u.id, u.name).toLowerCase();
      return displayName.contains(q) || u.name.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: ListenableBuilder(
        listenable: userState,
        builder: (_, _) {
          final clubs = widget.clubsOf();
          final followers = widget.followersOf();
          final following = widget.followingOf();

          return Column(
            children: [
              _buildTabBar(clubs.length, followers.length, following.length),
              Divider(height: 1, color: AppColors.divider),
              _buildSearchBar(),
              Expanded(
                child: switch (_tab) {
                  _ConnTab.clubs => _buildClubsList(_matchClubs(clubs)),
                  _ConnTab.followers => _buildPeopleList(
                    _matchPeople(followers),
                    'No followers yet.',
                  ),
                  _ConnTab.following => _buildPeopleList(
                    _matchPeople(following),
                    'Not following anyone yet.',
                  ),
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabBar(int clubsCount, int followersCount, int followingCount) {
    Widget tabItem(String label, int count, _ConnTab tab) {
      final selected = _tab == tab;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _tab = tab),
          child: Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 12),
            child: Column(
              children: [
                Text(
                  '$count $label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AppColors.text : AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 2,
                  color: selected ? _burgundy : Colors.transparent,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tabItem('Clubs', clubsCount, _ConnTab.clubs),
        tabItem('Followers', followersCount, _ConnTab.followers),
        tabItem('Following', followingCount, _ConnTab.following),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: AppColors.secondaryText),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(fontSize: 14, color: AppColors.text),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search',
                  hintStyle: TextStyle(color: AppColors.secondaryText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClubsList(List<Club> clubs) {
    if (clubs.isEmpty) {
      return _emptyState(_query.isEmpty ? 'No clubs yet.' : 'No clubs found.');
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: clubs.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, indent: 72, color: AppColors.divider),
      itemBuilder: (_, i) => _clubTile(clubs[i]),
    );
  }

  Widget _buildPeopleList(List<User> people, String emptyFallback) {
    if (people.isEmpty) {
      final message = _query.isNotEmpty
          ? 'No matches found.'
          : widget.peopleLoading
          ? 'Loading connections...'
          : widget.peopleError ?? emptyFallback;
      return _emptyState(message);
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: people.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, indent: 72, color: AppColors.divider),
      itemBuilder: (_, i) => _personTile(people[i]),
    );
  }

  Widget _emptyState(String text) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.secondaryText),
        ),
      ),
    );
  }

  Widget _clubTile(Club club) {
    final role = widget.roleTitleFor(club);
    final isLeader = role != null;
    return ListTile(
      onTap: () => widget.onOpenClub(club),
      leading: ClubAvatar(
        clubId: club.id,
        clubName: club.name,
        color: widget.clubColor(club),
        imageUrl: club.logoUrl,
        size: 44,
        fontSize: 18,
        borderRadius: 13,
      ),
      title: Text(
        club.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isLeader ? _burgundy : AppColors.surfaceAlt,
          borderRadius: BorderRadius.all(Radius.circular(999)),
          border: isLeader ? null : Border.all(color: AppColors.divider),
        ),
        child: Text(
          role ?? 'Member',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isLeader ? Colors.white : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _personTile(User user) {
    final myId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    final isMe = user.id == myId;
    final hasUsername = userState.usernameFor(user.id) != null;

    return ListTile(
      onTap: () => widget.onOpenUser(user),
      leading: UserAvatar(
        userId: user.id,
        name: user.name,
        size: 44,
        fontSize: 16,
      ),
      title: Text(
        userState.displayNameFor(user.id, user.name),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
      subtitle: hasUsername
          ? Text(
              user.name,
              style: TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
            )
          : null,
      trailing: isMe || !authService.isStudentSession
          ? null
          // ListTile.trailing needs a bounded width or it throws — the
          // longest label ("Follow back") sets the fixed width for all.
          : SizedBox(
              width: 108,
              height: 34,
              child: _FollowButton(
                isFollowing: userState.isFollowingUser(user.id),
                isPending: userState.hasPendingRequest(user.id),
                followsMe: _userFollowsMe(user),
                onTap: () => _toggleUserFollow(user, () => setState(() {})),
              ),
            ),
    );
  }
}

// ── Follow button ──────────────────────────────────────────────────────────────

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final bool isPending;
  final bool followsMe;
  final VoidCallback onTap;

  const _FollowButton({
    required this.isFollowing,
    required this.isPending,
    this.followsMe = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final filled = !isFollowing && !isPending;
    final label = isPending
        ? 'Requested'
        : isFollowing
        ? 'Following'
        : followsMe
        ? 'Follow back'
        : 'Follow';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: filled ? _burgundy : Colors.transparent,
          borderRadius: BorderRadius.all(Radius.circular(999)),
          border: Border.all(
            color: filled ? _burgundy : AppColors.divider,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: filled ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
